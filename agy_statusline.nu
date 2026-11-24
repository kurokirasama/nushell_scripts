#!/usr/bin/env nu

# Agy Statusline Script
# Replicates Gemini CLI statusline and adds Agy-specific elements.

# Format a reasoning-effort string into its display label.
def _format-effort [effort: string]: nothing -> string {
  let e = ($effort | str trim | str lowercase)
  match $e {
    "" => ""
    "low" => "Low"
    "medium" | "med" => "Medium"
    "high" => "High"
    "xhigh" => "XHigh"
    "extra" => "Extra"
    "max" => "Max"
    $other => ($other | str capitalize)
  }
}

# Resolve the Orchestrator planner and executor sub-models:
# payload override > settings file > variant fallback defaults.
def _resolve-orchestrator-submodels [input: record]: nothing -> record {
  let payload_raw = ($input | get -o orchestrator | default {})
  let payload = (if ((($payload_raw | describe) | str starts-with "record")) { $payload_raw } else { {} })
  let payload_planner = ($payload | get -o planner | default "" | into string | str trim)
  let payload_executor = ($payload | get -o executor | default "" | into string | str trim)

  let settings_path = ($env.AGY_SETTINGS_FILE? | default ("~/.gemini/antigravity-cli/settings.json" | path expand))
  let settings_raw = (
    if ($settings_path | path exists) {
      try { open --raw $settings_path | from json | get -o orchestrator | default {} } catch { {} }
    } else {
      {}
    }
  )
  let settings = (if ((($settings_raw | describe) | str starts-with "record")) { $settings_raw } else { {} })
  let settings_planner = ($settings | get -o planner | default "" | into string | str trim)
  let settings_executor = ($settings | get -o executor | default "" | into string | str trim)

  let model_str = ($"($input.model?.id? | default '') ($input.model?.display_name? | default '')" | str lowercase)
  let default_planner = (
    if ($model_str | str contains "argon") or ($model_str | str contains "g1-pro") {
      "Gemini 4 Argon (High)"
    } else if ($model_str | str contains "carbon") {
      "Gemini 4 Carbon (High)"
    } else {
      "Gemini 4 Neon (High)"
    }
  )
  let default_executor = "Gemini 4 Hydrogen (High)"

  {
    planner: (if $payload_planner != "" { $payload_planner } else if $settings_planner != "" { $settings_planner } else { $default_planner })
    executor: (if $payload_executor != "" { $payload_executor } else if $settings_executor != "" { $settings_executor } else { $default_executor })
  }
}

# Resolve the display label for the active model (orchestrator + effort aware).
def _format-model-display [input: record]: nothing -> string {
  let raw_display = ($input.model?.display_name? | default "" | into string | str trim)
  let raw_id = ($input.model?.id? | default "" | into string | str trim)
  let combined = ($"($raw_id) ($raw_display)" | str lowercase)

  if ($combined | str contains "orchestrator") {
    let sub = (_resolve-orchestrator-submodels $input)
    return $"Orchestrator \(($sub.planner) -> ($sub.executor)\)"
  }

  let base = (
    if $raw_display != "" { $raw_display } else if $raw_id != "" { $raw_id } else { "no-model" }
  )
  let effort = ($input.model?.effort? | default "" | into string | str trim)
  if ($effort == "") or ($base == "no-model") { return $base }
  if ($base =~ '(?i)\((low|medium|med|high|xhigh|extra|max)\)') { return $base }

  let eff_label = (_format-effort $effort)
  $"($base) \(($eff_label)\)"
}

# Return true for removed pre-v1.5.15 Argon / Gemini 4 separate quota keys.
def _is-legacy-quota-key [key: string]: nothing -> bool {
  let kl = ($key | str lowercase)
  ($kl | str contains "argon") or ($kl | str starts-with "gemini-4")
}

# Classify a model string into one of the two quota groups: gemini or 3p.
def _classify-model-group [model_str: string]: nothing -> string {
  let m = ($model_str | str trim | str lowercase)
  if ($m == "") or ($m | str contains "gemini") or ($m | str contains "neon") or ($m | str contains "hydrogen") or ($m | str contains "carbon") or ($m | str contains "argon") or ($m | str contains "g1-pro") or ($m | str contains "flash") {
    "gemini"
  } else {
    "3p"
  }
}

# Return the active (non-legacy) quota bucket keys that belong to a quota group.
def _keys-for-quota-group [group: string, quota_cols: list<string>]: nothing -> list<string> {
  let active_cols = ($quota_cols | where { |k| not (_is-legacy-quota-key $k) })
  match $group {
    "gemini" => ($active_cols | where { |k| ($k | str lowercase) | str contains "gemini" })
    _ => ($active_cols | where { |k| not (($k | str lowercase) | str contains "gemini") })
  }
}

def main [] {
    let raw = (open --raw /dev/stdin)
    if ($raw | is-empty) { return $"(ansi red)agy | no input(ansi reset)" }
    let raw_input = ($raw | from json)
    let model_is_record = (
      let m = ($raw_input.model? | default null);
      ($m == null) or ((($m | describe) | str starts-with "record"))
    )
    let input = (if $model_is_record { $raw_input } else { $raw_input | upsert model {} })

    let width = ($input.terminal_width? | default 100)
    
    # --- Data Extraction ---

    # 1. Workspace and Git
    let project_path = (($input.workspace?.project_dir? | default "") | str replace "file://" "")
    let ws = (if ($project_path != "") { $project_path | path basename } else { $input.vcs?.client? | default "no-ws" })
    
    mut branch = ($input.vcs?.branch? | default "")
    mut dirty = (if ($input.vcs?.dirty? | default false) { "*" } else { "" })
    mut diff_stats = ""
    
    if ($input.vcs?.type? == "git") {
        if ($branch == "") {
            $branch = (try { git branch --show-current | str trim } catch { "" })
        }
        let status = (try { git status --porcelain | str trim } catch { "" })
        if ($status != "") { $dirty = "*" }
        
        # Git Diff Stats (Show if width > 120)
        if ($width > 120) {
            let shortstat = (try { git diff --shortstat | str trim } catch { "" })
            if ($shortstat != "") {
                let add = ($shortstat | parse --regex '(\d+) insertion' | get -o 0.capture0 | default "0")
                let del = ($shortstat | parse --regex '(\d+) deletion' | get -o 0.capture0 | default "0")
                $diff_stats = $"(ansi green)+($add)(ansi reset)/(ansi red)-($del)(ansi reset)"
            }
        }
    }
    if ($branch == "") { $branch = "no-branch" }
    
    let git_part = $"(ansi cyan)[($ws)/($branch)($dirty)](ansi reset)"

    # 2. Model
    let model_display = (_format-model-display $input)
    let model_label = $"(ansi yellow)($model_display)(ansi reset)"

    # 4. Context and Tokens
    let used_pct = ($input.context_window?.used_percentage? | default 0 | math round --precision 1)
    let total_tokens = (($input.context_window?.total_input_tokens? | default 0) + ($input.context_window?.total_output_tokens? | default 0))
    let tokens_k = (if $total_tokens >= 1000 { $"($total_tokens / 1000 | math round)k" } else { $"($total_tokens)" })
    let context_color = (if $used_pct >= 70.0 { "#FFA500" } else { "green" })
    let context_part = $"(ansi $context_color)($used_pct)% \(($tokens_k)\)(ansi reset)"

    # 5. Cost (explicit from AGY payload or estimated from session token usage)
    let explicit_cost = (
        if ($input.cost? | describe | str starts-with "record") {
            ($input.cost?.total_usd? | default $input.cost?.total_cost_usd? | default $input.cost?.estimated_cost_usd? | default $input.cost?.cost?)
        } else if ($input.cost? != null) {
            $input.cost?
        } else if ($input.total_cost_usd? != null) {
            $input.total_cost_usd?
        } else if ($input.estimated_cost_usd? != null) {
            $input.estimated_cost_usd?
        } else if ($input.cost_summary?.estimated_cost_usd? != null) {
            $input.cost_summary?.estimated_cost_usd?
        } else {
            null
        }
    )

    let in_tok = ($input.context_window?.total_input_tokens? | default 0)
    let out_tok = ($input.context_window?.total_output_tokens? | default 0)

    let cost_val = (
        if $explicit_cost != null {
            ($explicit_cost | into float)
        } else if ($in_tok + $out_tok) > 0 {
            let model_name = ($input.model?.display_name? | default "" | str lowercase)
            let model_id = ($input.model?.id? | default "" | str lowercase)
            let m_combined = $"($model_id) ($model_name)"
            let rates = (
                if ($m_combined | str contains "neon") or ($m_combined | str contains "hydrogen") or ($m_combined | str contains "argon") or ($m_combined | str contains "carbon") {
                    { in: 0.00000125, out: 0.00000500 }
                } else if ($m_combined | str contains "flash") {
                    { in: 0.000000075, out: 0.00000030 }
                } else if ($m_combined | str contains "opus") {
                    { in: 0.00001500, out: 0.00007500 }
                } else if ($m_combined | str contains "sonnet") {
                    { in: 0.00000300, out: 0.00001500 }
                } else if ($m_combined | str contains "haiku") {
                    { in: 0.00000080, out: 0.00000400 }
                } else if ($m_combined | str contains "pro") {
                    { in: 0.00000125, out: 0.00000500 }
                } else if ($m_combined | str contains "mini") {
                    { in: 0.00000015, out: 0.00000060 }
                } else if ($m_combined | str contains "gpt-4") {
                    { in: 0.00000250, out: 0.00001000 }
                } else if ($m_combined | str contains "o1") or ($m_combined | str contains "o3") {
                    { in: 0.00001500, out: 0.00006000 }
                } else {
                    { in: 0.00000015, out: 0.00000060 }
                }
            )
            (($in_tok * $rates.in) + ($out_tok * $rates.out))
        } else {
            null
        }
    )

    let cost_str = (
        if $cost_val == null { "" }
        else if $cost_val == 0.0 { "0.00" }
        else if $cost_val < 0.01 { $"($cost_val | math round --precision 4)" }
        else if $cost_val < 1.00 { $"($cost_val | math round --precision 3)" }
        else if $cost_val < 10.00 { $"($cost_val | math round --precision 2)" }
        else { $"($cost_val | math round --precision 1)" }
    )
    let cost_part = (if $cost_str != "" {
        if $width < 80 {
            $"(ansi yellow)\$($cost_str)(ansi reset)"
        } else {
            $"(ansi yellow)Cost: \$($cost_str)(ansi reset)"
        }
    } else { "" })

    let quota = ($input.quota? | default {})
    let quota_stale = ($input.quota_stale? | default false)
    mut quota_parts = []

    if ((($quota | describe) | str starts-with "record") and ($quota | is-not-empty)) {
        let quota_cols = ($quota | columns)
        let raw_id = ($input.model?.id? | default "" | into string | str trim)
        let raw_display = ($input.model?.display_name? | default "" | into string | str trim)
        let is_orchestrator = (($"($raw_id) ($raw_display)" | str lowercase) | str contains "orchestrator")

        let classify_strings = (
            if $is_orchestrator {
                let sub = (_resolve-orchestrator-submodels $input)
                [$sub.planner, $sub.executor]
            } else {
                [ (if $raw_id != "" { $raw_id } else { $raw_display }) ]
            }
        )
        let active_groups = ($classify_strings | each { |m| _classify-model-group $m } | uniq)
        let multi_group = (($active_groups | length) > 1)

        for group in $active_groups {
            let group_keys = (_keys-for-quota-group $group $quota_cols)
            for key in $group_keys {
                let q = ($quota | get $key)
                if not ((($q | describe) | str starts-with "record")) { continue }
                if (($q | get -o disabled | default false) == true) { continue }

                let pct = (
                    try {
                        if ($q | get -o remaining_fraction) != null {
                            ($q.remaining_fraction * 100 | math round | into int)
                        } else if ($q | get -o remaining_amount) != null {
                            ($q.remaining_amount | math round | into int)
                        } else {
                            100
                        }
                    } catch { 100 }
                )
                let rin = ($q | get -o reset_in_seconds | default 0)
                let reset = (
                    let rin_ok = ((($rin | describe) | str starts-with "int") or (($rin | describe) | str starts-with "float"));
                    if $rin_ok and ($rin > 0) {
                        $rin
                    } else {
                        let rtime = ($q | get -o reset_time | default "");
                        if (($rtime | describe) | str starts-with "string") and ($rtime | is-not-empty) {
                            try {
                                let diff = (((($rtime | into datetime) - (date now)) / 1sec) | math floor | into int)
                                if $diff > 0 { $diff } else { 0 }
                            } catch { 0 }
                        } else {
                            0
                        }
                    }
                )
                let reset_str = (if $reset > 0 {
                    if ($key | str ends-with "-weekly") {
                        let d = ($reset / 86400 | math floor)
                        let h = (($reset mod 86400) / 3600 | math floor)
                        if $d > 0 and $h > 0 {
                            $"↻ ($d)d ($h)h"
                        } else if $d > 0 {
                            $"↻ ($d)d"
                        } else {
                            $"↻ ($h)h"
                        }
                    } else {
                        let h = ($reset / 3600 | math floor)
                        let m = (($reset mod 3600) / 60 | math floor)
                        $"↻ ($h)h ($m)m"
                    }
                } else { "" })
                let safe_key = ($key | str replace --regex '[\x00-\x1f\x7f]' '' | str replace --regex '[^A-Za-z0-9_.-]' '' | str substring 0..24)
                let window = (
                    if ($key | str ends-with "-5h") { "5h:" }
                    else if ($key | str ends-with "-weekly") { "Wk:" }
                    else if ($safe_key | is-empty) { "quota:" }
                    else { $"($safe_key):" }
                )
                let label = (
                    if $multi_group and $group == "gemini" {
                        $"Gmn ($window)"
                    } else if $multi_group and $group == "3p" {
                        $"3P ($window)"
                    } else {
                        $window
                    }
                )
                let color = (if $pct <= 30 {
                    if ($key | str ends-with "-weekly") { "red" } else { "#FF6347" }
                } else {
                    if ($key | str ends-with "-weekly") { "cyan" } else { "#32CD32" }
                })
                let style = (if $quota_stale {
                    $"(ansi $color)(ansi d)(ansi i)"
                } else {
                    $"(ansi $color)"
                })
                let seg = (if ($reset_str | is-not-empty) {
                    $"($style)($label) ($pct)% ($reset_str)(ansi reset)"
                } else {
                    $"($style)($label) ($pct)%(ansi reset)"
                })
                $quota_parts = ($quota_parts | append $seg)
            }
        }
    }

    let sandbox_enabled = ($input.sandbox?.enabled? | default false)
    let sandbox_part = (if ($sandbox_enabled and $width > 100) {
        $"(ansi red)sandbox ON(ansi reset)"
    } else { "" })

    # 6. Memory usage
    let ppid = (try { ps | where pid == $nu.pid | get 0.ppid } catch { 0 })
    let agy_mem = (if $ppid > 0 { try { ps | where pid == $ppid | get 0.mem | into string } catch { "" } } else { "" })
    let mem_part = (if ($agy_mem != "") { $"(ansi white)($agy_mem)(ansi reset)" } else { "" })

    # 7. Version
    let version = ($input.version? | default "unknown")
    let version_part = (if ($width > 150) { $"(ansi white)agy v($version)(ansi reset)" } else { "" })

    # 9. Tool Confirmation
    let confirm = (if ($input.tool_confirmation_pending? | default false) { $"(ansi red_bold)CONFIRM(ansi reset)" } else { "" })

    # --- Assembly ---
    let main_info = $git_part
    
    mut stats_parts = []
    $stats_parts = ($stats_parts | append $model_label)
    $stats_parts = ($stats_parts | append $context_part)
    if ($diff_stats != "") { $stats_parts = ($stats_parts | append $diff_stats) }
    let quota_str = ($quota_parts | str join " ")
    if ($quota_str != "") { $stats_parts = ($stats_parts | append $quota_str) }
    if ($cost_part != "") { $stats_parts = ($stats_parts | append $cost_part) }
    if ($sandbox_part != "") { $stats_parts = ($stats_parts | append $sandbox_part) }
    if ($mem_part != "") { $stats_parts = ($stats_parts | append $mem_part) }
    if ($version_part != "") { $stats_parts = ($stats_parts | append $version_part) }
    
    let base = $"($main_info) | ($stats_parts | str join ' | ')"
    let output = (if ($confirm != "") { $"($base) | ($confirm)" } else { $base })
    
    print $output
}
