#!/usr/bin/env nu

# Agy Statusline Script
# Replicates Gemini CLI statusline and adds Agy-specific elements.

def main [] {
    let raw = (open --raw /dev/stdin)
    if ($raw | is-empty) { return $"(ansi red)agy | no input(ansi reset)" }
    let input = ($raw | from json)
    
    let width = ($input.terminal_width? | default 100)
    
    # --- Data Extraction ---

    # 1. Workspace and Git
    let project_path = ($input.workspace?.project_dir? | str replace "file://" "" | default "")
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

    # 2. Model and User
    let model_display = ($input.model?.display_name? | default "no-model")
    let email = ($input.email? | default "no-email")
    let plan = ($input.plan_tier? | default "Free")

    let model_label = $"(ansi yellow)($model_display)(ansi reset)"

    # Show model+mode at all widths; email only when there's room (> 150)
    let user_part = (if ($width > 150) {
        $"($model_label) | (ansi blue)($email) \(($plan)\)(ansi reset)"
    } else {
        $model_label
    })

    # 4. Context and Tokens
    let used_pct = ($input.context_window?.used_percentage? | default 0 | math round --precision 1)
    let total_tokens = (($input.context_window?.total_input_tokens? | default 0) + ($input.context_window?.total_output_tokens? | default 0))
    let tokens_k = (if $total_tokens >= 1000 { $"($total_tokens / 1000 | math round)k" } else { $"($total_tokens)" })
    let context_color = (if $used_pct >= 70.0 { "#FFA500" } else { "green" })
    let context_part = $"(ansi $context_color)($used_pct)% \(($tokens_k)\)(ansi reset)"

    # 5. Cost (explicit from AGY payload or estimated from session token usage)
    let explicit_cost = (
        if ($input.cost? | describe | str starts-with "record") {
            ($input.cost?.total_cost_usd? | default $input.cost?.estimated_cost_usd? | default $input.cost?.cost?)
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
                if ($m_combined | str contains "flash") {
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

    if ($quota | is-not-empty) {
        let model_id = ($input.model?.id? | default "" | str lowercase)
        let active_group = (
            if ($model_id | str contains "gemini") or ($model_id == "") {
                "gemini"
            } else {
                "others"
            }
        )
        let active_keys = (
            if $active_group == "gemini" {
                $quota | columns | where { |k| $k | str contains "gemini" }
            } else {
                $quota | columns | where { |k| not ($k | str contains "gemini") }
            }
        )
        for key in $active_keys {
            let q = ($quota | get $key)
            let pct = (($q.remaining_fraction? | default 1.0) * 100 | math round | into int)
            let reset = ($q.reset_in_seconds? | default 0)
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
            let label = (
                if ($key | str ends-with "-5h") { "5h:" }
                else if ($key | str ends-with "-weekly") { "Wk:" }
                else { $"($key):" }
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
            $quota_parts = ($quota_parts | append $"($style)($label) ($pct)% ($reset_str)(ansi reset)")
        }
    }

    let exec_mode = ($input.execution_mode? | default "")
    let exec_mode_part = (if ($exec_mode != "" and $width > 100) {
        $"(ansi magenta)[($exec_mode)](ansi reset)"
    } else { "" })

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
    if ($user_part != "") { $stats_parts = ($stats_parts | append $user_part) }
    $stats_parts = ($stats_parts | append $context_part)
    if ($diff_stats != "") { $stats_parts = ($stats_parts | append $diff_stats) }
    let quota_str = ($quota_parts | str join " ")
    if ($quota_str != "") { $stats_parts = ($stats_parts | append $quota_str) }
    if ($cost_part != "") { $stats_parts = ($stats_parts | append $cost_part) }
    if ($exec_mode_part != "") { $stats_parts = ($stats_parts | append $exec_mode_part) }
    if ($sandbox_part != "") { $stats_parts = ($stats_parts | append $sandbox_part) }
    if ($mem_part != "") { $stats_parts = ($stats_parts | append $mem_part) }
    if ($version_part != "") { $stats_parts = ($stats_parts | append $version_part) }
    
    let base = $"($main_info) | ($stats_parts | str join ' | ')"
    let output = (if ($confirm != "") { $"($base) | ($confirm)" } else { $base })
    
    print $output
}
