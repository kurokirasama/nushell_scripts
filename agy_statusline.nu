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

    # 2. Model
    let model = ($input.model?.display_name? | default "no-model")
    let model_part = (if ($width > 150) {
        $"(ansi yellow)($model)(ansi reset)"
    } else { "" })

    # 3. User & Quota
    let email = ($input.email? | default "no-email")
    let plan = ($input.plan_tier? | default "Free")
    let user_part = (if ($width > 150) { 
        $"(ansi blue)($email) \(($plan)\)(ansi reset)" 
    } else if ($width > 100) {
        $"(ansi blue)($email)(ansi reset)"
    } else { "" })

    # 4. Context and Tokens
    let used_pct = ($input.context_window?.used_percentage? | default 0 | math round --precision 1)
    let total_tokens = (($input.context_window?.total_input_tokens? | default 0) + ($input.context_window?.total_output_tokens? | default 0))
    let tokens_k = (if $total_tokens >= 1000 { $"($total_tokens / 1000 | math round)k" } else { $"($total_tokens)" })
    let context_part = $"(ansi green)($used_pct)% \(($tokens_k)\)(ansi reset)"

    # 5. Agent State & RAM
    let state = ($input.agent_state? | default "idle")
    let ppid = (try { ps | where pid == $nu.pid | get 0.ppid } catch { 0 })
    let agy_mem = (if $ppid > 0 { try { ps | where pid == $ppid | get 0.mem | into string } catch { "" } } else { "" })
    let mem_part = (if ($width > 120 and $agy_mem != "") { $"(ansi white)\(($agy_mem)\)(ansi reset)" } else { "" })
    let state_part = $"(ansi magenta)($state)(ansi reset) ($mem_part)"

    # 6. Counters
    let tasks_count = ($input.background_tasks? | default [] | length)
    let subagents_count = ($input.subagents? | default [] | length)
    let artifacts_count = ($input.artifacts? | default [] | length)
    let pending_count = ($input.pending_input_count? | default 0)
    
    mut counters = []
    if ($width > 100 or $tasks_count > 0) { $counters = ($counters | append $"Tk:($tasks_count)") }
    if ($width > 100 or $subagents_count > 0) { $counters = ($counters | append $"Ag:($subagents_count)") }
    if ($width > 120 or $artifacts_count > 0) { $counters = ($counters | append $"Ar:($artifacts_count)") }
    if ($width > 120 or $pending_count > 0) { $counters = ($counters | append $"Pn:($pending_count)") }
    
    let counters_part = $"(ansi white)($counters | str join ' ')(ansi reset)"

    # 7. Version
    let version = ($input.version? | default "unknown")
    let version_part = (if ($width > 150) { $"(ansi white)agy v($version)(ansi reset)" } else { "" })

    # 8. Tool Confirmation
    let confirm = (if ($input.tool_confirmation_pending? | default false) { $"(ansi red_bold)CONFIRM(ansi reset)" } else { "" })

    # --- Assembly ---
    let main_info = (if ($model_part != "") { $"($git_part) ($model_part)" } else { $git_part })
    
    mut stats_parts = []
    if ($user_part != "") { $stats_parts = ($stats_parts | append $user_part) }
    $stats_parts = ($stats_parts | append $context_part)
    if ($diff_stats != "") { $stats_parts = ($stats_parts | append $diff_stats) }
    $stats_parts = ($stats_parts | append $state_part)
    if ($counters_part != "") { $stats_parts = ($stats_parts | append $counters_part) }
    if ($version_part != "") { $stats_parts = ($stats_parts | append $version_part) }
    
    let base = $"($main_info) | ($stats_parts | str join ' | ')"
    let output = (if ($confirm != "") { $"($base) | ($confirm)" } else { $base })
    
    print $output
}
