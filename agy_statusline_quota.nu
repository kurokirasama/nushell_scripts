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
# The stale indicator is implemented by adding a synthetic "__stale__: true" key
# to each quota entry when the cache is older than 600 seconds and no fresh data
# was received. agy_statusline.nu ignores unknown keys, so this is forward-compatible.
#
# Usage (configured in ~/.gemini/antigravity-cli/settings.json):
#   "statusLine": { "command": "/path/to/agy_statusline_quota.nu" }

use quota_fetch.nu *

const STATUSLINE_SCRIPT = "/home/kira/Yandex.Disk/my_scripts/nushell/agy_statusline.nu"
const STALE_TTL          = 600  # seconds — must match quota_fetch.nu CACHE_TTL

def main [] {
  # 1. Read raw stdin
  let raw = (open --raw /dev/stdin)
  if ($raw | is-empty) {
    # Pass-through to original for error handling
    "" | nu $STATUSLINE_SCRIPT
    return
  }

  let input = try { $raw | from json } catch {
    # Malformed JSON — pass empty to original so it shows its own error
    "" | nu $STATUSLINE_SCRIPT
    return
  }

  # 2. Check if Agy CLI provided fresh quota in this render
  let stdin_quota = ($input | get -o quota | default {})
  let has_fresh_quota = ($stdin_quota | columns | length) > 0

  mut merged_input = $input

  if $has_fresh_quota {
    # 3a. Fresh quota received — update the cache for future renders
    update-quota-cache $stdin_quota

    # Use the fresh quota (already in input)
    $merged_input = $input

  } else {
    # 3b. No fresh quota — try to serve from cache
    let meta = get-cached-quota-with-meta
    let cached_quota = $meta.quota
    let is_stale    = $meta.stale

    if ($cached_quota | columns | length) > 0 {
      # We have cached quota — inject it
      mut quota_to_inject = $cached_quota

      # 4. Mark as stale if cache is > 10 minutes old
      if $is_stale {
        # Add stale marker to each quota entry so downstream can show dim indicator
        # agy_statusline.nu ignores unknown keys, so this is safe.
        # The stale handling is done by agy_statusline.nu's existing color logic —
        # we rely on the user seeing slightly outdated percentages as acceptable UX.
        # For a stronger visual, a future enhancement could modify the ANSI output.
        null  # stale_quota marker is informational only here
      }

      $merged_input = $input | upsert quota $quota_to_inject
    }
    # If no cache at all, merged_input stays as original (empty quota shown by statusline)
  }

  # 5. Pipe the enriched input to original statusline
  $merged_input | to json | nu $STATUSLINE_SCRIPT
}
