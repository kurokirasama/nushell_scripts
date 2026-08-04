#!/usr/bin/env nu

# Quota Fetch & Cache Module for agy_statusline
#
# Provides cached quota data to avoid blocking statusline renders.
# The cache is populated by the wrapper script (agy_statusline_quota.nu)
# which intercepts quota from the Agy CLI's stdin JSON on each render.
#
# Cache location: /tmp/agy_quota_cache.json
# Cache TTL:      600 seconds (10 minutes)
#
# Exports:
#   update-quota-cache  - Write quota record + timestamp to cache
#   get-cached-quota    - Read cache, return quota record (empty if cache missing)
#   is-cache-stale      - Return true if cache is older than 600 seconds

const CACHE_FILE = "/tmp/agy_quota_cache.json"
const CACHE_TTL  = 600  # seconds

# Write a quota record and timestamp to the cache file.
#
# Usage: update-quota-cache $quota_record
# Input: record with quota keys (e.g. {"gemini-5h": {...}, "gemini-weekly": {...}})
export def update-quota-cache [quota: record] {
  let cache = {
    timestamp: (date now | into int),
    quota: $quota
  }
  try {
    $cache | to json | save -f $CACHE_FILE
  } catch { |e|
    # Silently ignore write errors to avoid polluting statusline output
  }
}

# Return true if the cache file is older than CACHE_TTL seconds or missing.
export def is-cache-stale [] {
  if not ($CACHE_FILE | path exists) { return true }

  let raw   = try { open --raw $CACHE_FILE } catch { return true }
  let cache = try { $raw | from json } catch { return true }
  if ($cache | describe | str starts-with "string") { return true }

  let cached_ts = ($cache | get -o timestamp | default 0)
  let now_ts    = (date now | into int)

  # timestamp stored as nanoseconds (nushell `date now | into int`)
  # compare in seconds
  let age_ns  = ($now_ts - $cached_ts)
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
  if not ($CACHE_FILE | path exists) { return {} }

  let raw = try { open --raw $CACHE_FILE } catch { return {} }
  let cache = try { $raw | from json } catch { return {} }
  if ($cache | describe | str starts-with "string") { return {} }
  let quota = $cache | get -o quota | default {}
  if ($quota | describe | str starts-with "string") { return {} }

  $quota
}

# Return the cached quota record AND its age in seconds.
# Useful for showing a stale indicator when the cache is old.
#
# Output: record { quota: record, age_sec: int, stale: bool }
export def get-cached-quota-with-meta [] {
  if not ($CACHE_FILE | path exists) {
    return { quota: {}, age_sec: -1, stale: true }
  }

  let raw   = try { open --raw $CACHE_FILE } catch {
    return { quota: {}, age_sec: -1, stale: true }
  }
  let cache = try { $raw | from json } catch {
    return { quota: {}, age_sec: -1, stale: true }
  }
  if ($cache | describe | str starts-with "string") {
    return { quota: {}, age_sec: -1, stale: true }
  }

  let cached_ts = ($cache | get -o timestamp | default 0)
  let now_ts    = (date now | into int)
  let age_ns    = ($now_ts - $cached_ts)
  let age_sec   = ($age_ns / 1_000_000_000 | math floor)
  let stale     = $age_sec >= $CACHE_TTL
  let quota     = $cache | get -o quota | default {}

  { quota: $quota, age_sec: $age_sec, stale: $stale }
}
