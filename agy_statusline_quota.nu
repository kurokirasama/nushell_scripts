#!/usr/bin/env nu

# Agy Statusline Quota Wrapper
#
# Drop-in replacement for agy_statusline.nu that adds 10-minute quota caching.
#
# Architecture:
#   Agy CLI → JSON (stdin) → this wrapper → agy_statusline.nu → ANSI output
#
# How it works:
#   1. Read JSON from stdin (same format as agy_statusline.nu)
#   2. If stdin contains a non-empty quota object → cache it (fresh data from Agy CLI)
#   3. If stdin quota is missing or empty → inject cached quota into the input
#   4. If cache is stale (>10min) and no fresh quota → mark quota as stale
#   5. Pass the enriched JSON to agy_statusline.nu for rendering
#
# The stale indicator is implemented by setting the top-level `quota_stale` flag
# when the cache is older than 600 seconds and no fresh data was received.
# agy_statusline.nu dims the quota display when that flag is set.
#
# Usage (configured in ~/.gemini/antigravity-cli/settings.json):
#   "statusLine": { "command": "/path/to/agy_statusline_quota.nu" }

use quota_fetch.nu *

# Resolve paths relative to this script's own location.
def _self-dir [] {
  let f = ($env.CURRENT_FILE? | default "")
  if ($f | is-empty) { return "" }
  $f | path dirname
}

# Ensure the detached refresh can import this module without hardcoded paths.
if ($env.AGY_QUOTA_FETCH_MODULE? | is-empty) {
  let self_dir = (_self-dir)
  if ($self_dir | is-not-empty) {
    $env.AGY_QUOTA_FETCH_MODULE = ($self_dir | path join "quota_fetch.nu")
  }
}

def main [] {
  let self_dir = (_self-dir)
  let statusline_script = (
    if ($self_dir | is-empty) { "agy_statusline.nu" } else { $self_dir | path join "agy_statusline.nu" }
  )

  # 1. Read raw stdin
  let raw = (open --raw /dev/stdin)
  if ($raw | is-empty) {
    # Pass-through to original for error handling
    "" | nu $statusline_script
    return
  }

  let input = try { $raw | from json } catch {
    # Malformed JSON or non-record payload — pass empty to original for its own error
    "" | nu $statusline_script
    return
  }
  if not ((($input | describe) | str starts-with "record")) {
    "" | nu $statusline_script
    return
  }

  # 2. Check if Agy CLI provided fresh quota in this render
  let stdin_quota_raw = ($input | get -o quota | default {})
  let stdin_quota = (
    if ((($stdin_quota_raw | describe) | str starts-with "record")) { $stdin_quota_raw } else { {} }
  )
  let has_fresh_quota = (($stdin_quota | columns | length) > 0)

  mut merged_input = $input

  if $has_fresh_quota {
    # 3a. Fresh quota received — update the cache for future renders
    update-quota-cache $stdin_quota

    # Use the fresh quota (already in input)
    $merged_input = $input

  } else {
    # 3b. No fresh quota — try to serve from cache
    let meta = (get-cached-quota-with-meta)
    let cached_quota = $meta.quota
    let is_stale = $meta.stale

    if ($cached_quota | columns | length) > 0 {
      # We have cached quota — inject it
      if $is_stale {
        # Trigger background validation and mark the injected quota as stale
        trigger-background-fetch
        $merged_input = ($input | upsert quota_stale true)
      }

      $merged_input = ($merged_input | upsert quota $cached_quota)
    }
    # If no cache at all, merged_input stays as original (empty quota shown by statusline)
  }

  # 5. Pipe the enriched input to original statusline
  $merged_input | to json | nu $statusline_script
}
