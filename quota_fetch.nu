#!/usr/bin/env nu

# Quota Fetch & Cache Module for agy_statusline
#
# Provides cached quota data to avoid blocking statusline renders.
# The cache is populated by the wrapper script (agy_statusline_quota.nu)
# which intercepts quota from the Agy CLI's stdin JSON on each render.
#
# Cache location: ~/.cache/agy/quota_cache.json (override: AGY_QUOTA_CACHE_FILE)
# Cache TTL:      600 seconds (10 minutes)
#
# Exports:
#   update-quota-cache     - Write quota record + timestamp to cache
#   get-cached-quota       - Read cache, return quota record (empty if cache missing)
#   is-cache-stale         - Return true if cache is older than 600 seconds
#   parse-agy-usage-json   - Parse `agy -p /usage --output-format json` into a quota record
#   refresh-quota-cache    - Synchronously refresh cache from the agy CLI (lock-guarded)
#   trigger-background-fetch - Spawn a detached refresh process

const CACHE_TTL = 600  # seconds

def _cache-dir [] {
  let base = ($env.XDG_CACHE_HOME? | default ("~/.cache" | path expand))
  $base | path join "agy"
}

def _cache-file [] {
  $env.AGY_QUOTA_CACHE_FILE? | default ((_cache-dir) | path join "quota_cache.json")
}

def _lock-dir [] {
  $env.AGY_QUOTA_FETCH_LOCK? | default ((_cache-dir) | path join "quota_fetch.lock")
}

# Read and validate the cache file. Returns null when missing, a symlink,
# corrupt, or structurally invalid (so callers never trust poisoned data).
def _read-cache [] {
  let file = ((_cache-file) | path expand)
  if not ($file | path exists) { return null }
  if (($file | path type) != "file") { return null }

  let raw = try { open --raw $file } catch { return null }
  if ($raw | is-empty) { return null }
  let parsed = try { $raw | from json } catch { return null }
  if not ((($parsed | describe) | str starts-with "record")) { return null }
  $parsed
}

# Atomically write quota + timestamp to the cache (temp file + rename, so a
# planted symlink or partial write cannot redirect/corrupt the cache).
def _write-cache [quota: record] {
  let file = ((_cache-file) | path expand)
  try {
    mkdir ($file | path dirname)
    let tmp = $"($file).tmp.(random int 1000..999999)"
    { timestamp: (date now | into int), quota: $quota } | to json | save -f $tmp
    mv -f $tmp $file
  } catch { }
}

# Write a quota record and timestamp to the cache file.
#
# Usage: update-quota-cache $quota_record
# Input: record with quota keys (e.g. {"gemini-5h": {...}, "gemini-weekly": {...}})
export def update-quota-cache [quota: record] {
  _write-cache $quota
}

# Return true if the cache file is older than CACHE_TTL seconds or missing.
export def is-cache-stale [] {
  let cache = (_read-cache)
  if $cache == null { return true }

  let cached_ts = ($cache | get -o timestamp)
  if not ((($cached_ts | describe) | str starts-with "int")) { return true }

  let age_ns = ((date now | into int) - $cached_ts)
  let age_sec = ($age_ns / 1_000_000_000 | math floor)
  $age_sec >= $CACHE_TTL
}

# Return the cached quota record, or an empty record if unavailable/stale.
#
# This never blocks — if the cache is stale or missing it returns {}
# so the caller can decide how to handle it (e.g., show stale indicator).
#
# Usage:  let q = get-cached-quota
# Output: record with quota keys, or empty record {}
export def get-cached-quota [] {
  let cache = (_read-cache)
  if $cache == null { return {} }

  let quota = ($cache | get -o quota | default {})
  if not ((($quota | describe) | str starts-with "record")) { return {} }
  $quota
}

# Return the cached quota record AND its age in seconds.
# Useful for showing a stale indicator when the cache is old.
#
# Output: record { quota: record, age_sec: int, stale: bool }
export def get-cached-quota-with-meta [] {
  let cache = (_read-cache)
  if $cache == null {
    return { quota: {}, age_sec: -1, stale: true }
  }

  let cached_ts = ($cache | get -o timestamp)
  if not ((($cached_ts | describe) | str starts-with "int")) {
    return { quota: {}, age_sec: -1, stale: true }
  }

  let age_ns = ((date now | into int) - $cached_ts)
  let age_sec = ($age_ns / 1_000_000_000 | math floor)
  let quota = ($cache | get -o quota | default {})
  let quota = (if ((($quota | describe) | str starts-with "record")) { $quota } else { {} })

  { quota: $quota, age_sec: $age_sec, stale: ($age_sec >= $CACHE_TTL) }
}

# Parse `agy -p "/usage" --output-format json` output into a normalized quota record.
#
# Input:  raw JSON string from the agy CLI
# Output: record keyed by bucket id with
#         { remaining_fraction, remaining_amount, reset_time, reset_in_seconds, disabled }
# Note: remaining_fraction is null when the CLI reports remaining_amount instead.
export def parse-agy-usage-json [raw_json: string] {
  if ($raw_json | str trim | is-empty) { return {} }
  let parsed = try { $raw_json | from json } catch { return {} }
  if not ((($parsed | describe) | str starts-with "record")) { return {} }

  let groups = ($parsed | get -o command.data.groups | default [])
  let groups_desc = ($groups | describe)
  if (($groups | is-empty)) or (not (($groups_desc | str starts-with "list") or ($groups_desc | str starts-with "table"))) { return {} }

  mut out = {}
  for g in $groups {
    if not ((($g | describe) | str starts-with "record")) { continue }
    let buckets = ($g | get -o buckets | default [])
    for b in $buckets {
      if not ((($b | describe) | str starts-with "record")) { continue }
      let id = ($b | get -o id | default "")
      if ($id | is-empty) { continue }

      let rem_fraction = ($b | get -o remaining_fraction)
      let rem_amount = ($b | get -o remaining_amount)
      let reset_time = ($b | get -o reset_time | default "")
      let disabled = ($b | get -o disabled | default false)
      let reset_sec = (
        if ((($reset_time | describe) | str starts-with "string")) and ($reset_time | is-not-empty) {
          try {
            let d = (((($reset_time | into datetime) - (date now)) / 1sec) | math floor | into int)
            if $d > 0 { $d } else { 0 }
          } catch { 0 }
        } else {
          0
        }
      )

      $out = ($out | upsert $id {
        remaining_fraction: $rem_fraction
        remaining_amount: $rem_amount
        reset_time: $reset_time
        reset_in_seconds: $reset_sec
        disabled: $disabled
      })
    }
  }

  $out
}

# Refresh the quota cache synchronously from the agy CLI.
#
# Writes a fresh quota record (+ timestamp) when `agy -p "/usage"` succeeds.
# Falls back to preserving the existing quota with a fresh timestamp when agy
# is unavailable or returns no bucket data. Concurrent runs are lock-guarded.
export def refresh-quota-cache [] {
  # Check/cleanup stale lock
  let lock_dir = (_lock-dir)
  if ($lock_dir | path exists) {
    let stat = (try { ls -d $lock_dir | get 0 } catch { {} })
    if ($stat | is-not-empty) {
      let age = ((date now) - $stat.modified)
      if $age > 120sec {
        try { rm -rf $lock_dir } catch { }
      }
    }
  }

  # Try to acquire lock (parent dir is private, created on demand)
  try { mkdir (($lock_dir) | path dirname) } catch { }
  let lock_res = (^mkdir $lock_dir o+e>| complete)
  if $lock_res.exit_code != 0 { return }

  try {
    let refreshed = (
      try {
        let agy_bin = (try { which agy | get -o 0.path } catch { "" })
        if ($agy_bin | is-empty) {
          {}
        } else {
          let res = (^timeout 50 $agy_bin -p "/usage" --output-format json | complete)
          if $res.exit_code == 0 { parse-agy-usage-json $res.stdout } else { {} }
        }
      } catch { {} }
    )

    if ($refreshed | is-not-empty) {
      _write-cache $refreshed
    } else {
      let cache = (_read-cache)
      if $cache != null {
        let quota = ($cache | get -o quota | default {})
        if (($quota | describe) | str starts-with "record") {
          _write-cache $quota
        }
      }
    }
  } catch { }

  try { rm -rf $lock_dir } catch { }
}

# Spawn a detached background refresh of the quota cache.
#
# A `job spawn` thread dies when the statusline process exits, so the refresh
# is launched as a real detached OS process instead. The module path is passed
# as an argv positional (never interpolated into the shell command), so no
# quoting/injection is possible. Executing this file as a script runs `main`.
export def trigger-background-fetch [] {
  let script = ($env.AGY_QUOTA_FETCH_MODULE? | default "")
  if ($script | is-empty) { return }
  if not ($script | path exists) { return }

  try {
    ^bash -c 'nohup nu --no-config-file "$1" >/dev/null 2>&1 &' _ $script
  } catch { }
}

def main [] {
  refresh-quota-cache
}
