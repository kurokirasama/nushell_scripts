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
                let add = ($shortstat | parse --regex '(\d+) insertion' | get 0.capture0? | default "0")
                let del = ($shortstat | parse --regex '(\d+) deletion' | get 0.capture0? | default "0")
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
    let context_part = $"(ansi green)($used_pct)% \(($tokens_k)\)(ansi reset)"

    # 5. Enhanced Fields: Quota, Execution Mode, Sandbox
    let quota = ($input.quota? | default {})
    mut quota_parts = []

    if ($quota | is-not-empty) {
        if (($quota | columns | where $it == "gemini-5h" | length) > 0) {
            let q = $quota.gemini-5h
            let pct = (($q.remaining_fraction? | default 1.0) * 100 | math round | into int)
            let reset = ($q.reset_in_seconds? | default 0)
            let reset_str = (if $reset > 0 {
                let h = ($reset / 3600 | math floor)
                let m = (($reset mod 3600) / 60 | math floor)
                $"↻ ($h)h ($m)m"
            } else { "" })
            $quota_parts = ($quota_parts | append $"(ansi cyan)5h: ($pct)% ($reset_str)(ansi reset)")
        }
        if (($quota | columns | where $it == "gemini-weekly" | length) > 0) {
            let q = $quota.gemini-weekly
            let pct = (($q.remaining_fraction? | default 1.0) * 100 | math round | into int)
            let reset = ($q.reset_in_seconds? | default 0)
            let reset_str = (if $reset > 0 {
                let d = ($reset / 86400 | math floor)
                $"↻ ($d)d"
            } else { "" })
            $quota_parts = ($quota_parts | append $"(ansi cyan)Wk: ($pct)% ($reset_str)(ansi reset)")
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
    let mem_part = (if ($agy_mem != "") { $"(ansi white)Mem: ($agy_mem)(ansi reset)" } else { "" })

    # 7. Counters
    let tasks_count = ($input.task_count? | default 0)
    let subagents_count = ($input.subagents? | default [] | length)
    let artifacts_count = ($input.artifact_count? | default 0)
    let pending_count = ($input.pending_input_count? | default 0)
    
    mut counters = []
    if ($width > 100 or $tasks_count > 0) { $counters = ($counters | append $"Tk:($tasks_count)") }
    if ($width > 100 or $subagents_count > 0) { $counters = ($counters | append $"Ag:($subagents_count)") }
    if ($width > 120 or $artifacts_count > 0) { $counters = ($counters | append $"Ar:($artifacts_count)") }
    if ($width > 120 or $pending_count > 0) { $counters = ($counters | append $"Pn:($pending_count)") }
    
    let counters_part = (if ($counters | length) > 0 { $"(ansi white)($counters | str join ' ')(ansi reset)" } else { "" })

    # 8. Version
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
    if ($exec_mode_part != "") { $stats_parts = ($stats_parts | append $exec_mode_part) }
    if ($sandbox_part != "") { $stats_parts = ($stats_parts | append $sandbox_part) }
    if ($mem_part != "") { $stats_parts = ($stats_parts | append $mem_part) }
    if ($counters_part != "") { $stats_parts = ($stats_parts | append $counters_part) }
    if ($version_part != "") { $stats_parts = ($stats_parts | append $version_part) }
    
    let base = $"($main_info) | ($stats_parts | str join ' | ')"
    let output = (if ($confirm != "") { $"($base) | ($confirm)" } else { $base })
    
    print $output
}
