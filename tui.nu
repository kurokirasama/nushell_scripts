# Interactive terminal UI (TUI) front-ends built on Nushell's native `tui` command family.
# Commands: monitor, t ui, obs tui, h tui (htui), skills tui, plus shared _tui-* helpers.

export-env {
    $env.config = ($env.config? | default {} | upsert tui (
        $env.config.tui? | default {} | merge {
            title_bar: { fg: "#000000", bg: "#00ff00", attr: "b" }
            button: { fg: "#000000", bg: "#00ff00" }
            status_bar: { fg: "#ffffff", bg: "dark_gray" }
        }
    ))
}

# Verify that stdin and stdout are attached to an interactive terminal; fail fast otherwise.
@category tui
export def _tui-require-tty [
    --stdin-tty: oneof<bool, nothing>   # Optional override for stdin TTY status (for testing)
    --stdout-tty: oneof<bool, nothing>  # Optional override for stdout TTY status (for testing)
]: nothing -> nothing {
    let has_stdin = $stdin_tty | default (is-terminal --stdin)
    let has_stdout = $stdout_tty | default (is-terminal --stdout)
    if (not $has_stdin) or (not $has_stdout) {
        error make {
            msg: $"(ansi red)This command requires an interactive terminal \(TTY\). Run it in a terminal or pass --plain where supported.(ansi reset)"
        }
    }
}

# Create a private per-session NUON state file path (0600 permissions) under XDG_RUNTIME_DIR or $nu.temp-dir.
@category tui
@example 'build state path' { _tui-state-path "monitor" | path basename | str starts-with "tui-monitor-" } --result true
export def _tui-state-path [
    name: string # Short component name for the state file
]: nothing -> path {
    let runtime = $env.XDG_RUNTIME_DIR? | default ""
    let base_dir = if ($runtime | is-not-empty) and ($runtime | path exists) and (($runtime | path type) == "dir") {
        $runtime | path expand
    } else {
        $nu.temp-dir | path expand
    }
    try {
        ^mktemp -p $base_dir --suffix=.nuon $"tui-($name)-($nu.pid)-XXXXXX" | str trim
    } catch {
        let nonce = try { random chars -l 8 } catch { "00000000" }
        $base_dir | path join $"tui-($name)-($nu.pid)-($nonce).nuon"
    }
}

# Read a TUI state record from disk, returning the default record when absent or empty.
@category tui
export def _tui-state-get [
    path: path          # Path to the NUON state file
    default: record = {} # Fallback record when file does not exist or is empty
]: nothing -> record {
    if ($path | path exists) and ((try { open --raw $path | str trim } catch { "" }) | is-not-empty) {
        open $path
    } else {
        $default
    }
}

# Persist a TUI state record to disk.
@category tui
export def _tui-state-set [
    path: path    # Path to the NUON state file
    state: record # State record to write
]: nothing -> record {
    $state | save --force $path
    $state
}

# Merge a patch record into the persisted TUI state file and return the updated record.
@category tui
export def _tui-state-merge [
    path: path    # Path to the NUON state file
    patch: record # Fields to merge into existing state
]: nothing -> record {
    let next = (_tui-state-get $path) | merge $patch
    $next | save --force $path
    $next
}

# Remove a temporary TUI state file if present.
@category tui
export def _tui-state-cleanup [
    path: path # Path to the NUON state file
]: nothing -> nothing {
    if ($path | path exists) {
        try { rm --force $path } catch {}
    }
}

# Render a plain-Unicode progress bar (ANSI-free for tui table cells).
@category tui
@example 'render 50% bar' { _tui-bar 0.5 } --result "█████░░░░░  50%"
export def _tui-bar [
    pct: float     # Completion ratio in [0.0, 1.0] (values outside are clamped)
    width: int = 10 # Number of bar cells
]: nothing -> string {
    let clamped = [0.0 ([1.0 $pct] | math min)] | math max
    let filled = ($clamped * $width) | math round | into int
    let empty_count = $width - $filled
    let bar = ("" | fill --character "█" --width $filled) ++ ("" | fill --character "░" --width $empty_count)
    let percent_str = ($clamped * 100) | math round | into int | into string | fill --alignment right --width 3
    $"($bar) ($percent_str)%"
}

# Sort a table or list of records naturally by a column with optional reverse order.
@category tui
@example 'sort rows by id' { _tui-sort-rows [{id: 10} {id: 2}] "id" | get id } --result [2 10]
export def _tui-sort-rows [
    rows: list<any> # Table or list of records to sort
    column: string  # Column name to sort by
    --reverse (-r)  # Sort in descending order
]: nothing -> list<any> {
    if ($rows | is-empty) {
        return []
    }
    let col_path = [$column] | into cell-path
    let sorted = $rows | sort-by --natural $col_path
    if $reverse { $sorted | reverse } else { $sorted }
}

# Advance to the next sort column in a list, resetting reverse to false.
@category tui
@example 'cycle sort column' { _tui-cycle-sort ["id" "name"] "id" true } --result { column: "name", reverse: false }
export def _tui-cycle-sort [
    columns: list<string> # Ordered list of sortable column names
    current: string       # Currently active sort column
    reverse: bool         # Current sort direction (reset to false on cycle)
]: nothing -> record<column: string, reverse: bool> {
    if ($columns | is-empty) {
        return { column: $current, reverse: false }
    }
    let idx = $columns | enumerate | where item == $current | get index.0?
    let next_idx = if $idx == null {
        0
    } else {
        ($idx + 1) mod ($columns | length)
    }
    { column: ($columns | get $next_idx), reverse: false }
}

# Format key/label pairs into a compact status bar legend.
@category tui
@example 'format key help' { _tui-key-help [{ key: "o" label: "sort" } { key: "q" label: "quit" }] } --result "o:sort  q:quit"
export def _tui-key-help [
    bindings: list<record<key: string, label: string>> # List of { key, label } records
]: nothing -> string {
    if ($bindings | is-empty) {
        return ""
    }
    $bindings | each { |b| $"($b.key):($b.label)" } | str join "  "
}

# ==============================================================================
# Phase 1: monitor
# ==============================================================================

# Normalize any monitor command output (table, record, list, string, or scalar) into table rows.
@category tui
@example 'normalize record' { _monitor-rows { a: 1, b: 2 } } --result [{ key: "a", value: 1 }, { key: "b", value: 2 }]
export def _monitor-rows [
    value: any # Raw command output to normalize into rows
]: nothing -> list<any> {
    let desc = $value | describe --detailed
    if ($desc.detailed_type | str starts-with "table") {
        $value
    } else if $desc.type == "record" {
        $value | transpose key value
    } else if $desc.type == "list" {
        if ($value | is-empty) {
            []
        } else if ($value | all { |el| ($el | describe --detailed | get type) == "record" }) {
            $value
        } else {
            $value | each { |v| { item: $v } }
        }
    } else if $desc.type == "string" {
        let text_lines = $value | lines
        if ($text_lines | is-empty) { [{ output: "" }] } else { $text_lines | each { |l| { output: $l } } }
    } else {
        [{ output: ($value | into string) }]
    }
}

# Evaluate the monitor `until` predicate, supporting both `$in` and 1-parameter closures.
@category tui
export def _monitor-should-continue [
    cnd: closure # Predicate closure returning bool
    res: any     # Latest command output
]: nothing -> bool {
    let val = try { $res | do $cnd } catch { do $cnd $res }
    ($val | default false) | into bool
}

# Execute one monitor refresh step, updating persisted state and checking `until`.
def _monitor-step [
    cmd: closure
    cnd: closure
    state_path: path
]: nothing -> any {
    let res = do $cmd
    if not (_monitor-should-continue $cnd $res) {
        return { action: quit }
    }
    let rows = _monitor-rows $res
    let st = _tui-state-get $state_path { paused: false, count: 1, last_rows: [] }
    _tui-state-merge $state_path { count: ($st.count + 1), last_rows: $rows } | ignore
    $rows
}

# Legacy plain clear-print-sleep monitor loop (used by --plain and non-TTY fallback).
export def _monitor-plain [
    cmd: closure      # Command to execute repeatedly
    cnd: closure      # Condition closure (continues while true)
    interval: duration # Delay between iterations
]: nothing -> nothing {
    loop {
        let res = do $cmd
        clear
        print $res
        sleep $interval
        if not (_monitor-should-continue $cnd $res) {
            break
        }
    }
}

# Build the interactive monitor TUI pipeline (exposed for headless `tui debug` testing).
export def _monitor-build-tui [
    cmd: closure
    cnd: closure
    interval: duration
    state_path: path
    initial_rows: list<any>
]: nothing -> any {
    let legend = _tui-key-help [
        { key: "p" label: "pause" }
        { key: "r" label: "refresh" }
        { key: "q" label: "quit" }
    ]
    $initial_rows
    | tui label --titlebar $"monitor · every ($interval)"
    | tui table
    | tui label --status {|_|
        let st = _tui-state-get $state_path { paused: false, count: 1 }
        let badge = if $st.paused { "PAUSED" } else { "LIVE" }
        $"($badge) · ($interval) · refreshes:($st.count) · ($legend)"
    }
    | tui bind p {||
        let st = _tui-state-get $state_path { paused: false, count: 1, last_rows: $initial_rows }
        let next = _tui-state-merge $state_path { paused: (not $st.paused) }
        $next.last_rows? | default $initial_rows
    }
    | tui bind r {|| _monitor-step $cmd $cnd $state_path }
}

# Monitor the output of a command interactively (or via plain loop with --plain / no TTY).
@category tui
@example "Monitor memory every 2 seconds" { monitor { sys mem | transpose key value } --time 2sec }
@example "Monitor with interval flag" { monitor { sys disks } -t 10sec }
@example "Stop when condition is no longer true" { monitor { t list } {|| (t list | where Done != "100%" | is-not-empty) } }
@example "Run plain clear/print loop" { monitor { ram } --plain }
@example "Monitor a record output" { monitor { { host: (sys host | get hostname), uptime: (sys host | get uptime) } } }
@example "Monitor command returning string" { monitor { date now | format date "%H:%M:%S" } }
export def monitor [
    cmd: closure                       # Command closure to execute repeatedly
    until?: closure                    # Optional condition closure; loop continues while true
    --time (-t): duration = 5sec       # Refresh interval
    --plain (-p)                       # Force plain clear/print loop instead of TUI
    --stdin-tty: oneof<bool, nothing>  # Optional override for stdin TTY status (for testing)
    --stdout-tty: oneof<bool, nothing> # Optional override for stdout TTY status (for testing)
]: nothing -> nothing {
    let cnd = if ($until == null) { {|| true } } else { $until }
    let has_stdin = $stdin_tty | default (is-terminal --stdin)
    let has_stdout = $stdout_tty | default (is-terminal --stdout)

    if $plain or (not $has_stdin) or (not $has_stdout) {
        return (_monitor-plain $cmd $cnd $time)
    }

    let state_path = _tui-state-path "monitor"
    try {
        let first_res = do $cmd
        let initial_rows = _monitor-rows $first_res
        _tui-state-set $state_path { paused: false, count: 1, last_rows: $initial_rows } | ignore

        (_monitor-build-tui $cmd $cnd $time $state_path $initial_rows)
        | tui run --refresh $time {||
            let st = _tui-state-get $state_path { paused: false }
            if $st.paused {
                null
            } else {
                _monitor-step $cmd $cnd $state_path
            }
        }
        | ignore
    } finally {
        _tui-state-cleanup $state_path
    }
}


# ==============================================================================
# Lazy Subprocess Dispatcher for Heavy TUI Front-Ends
# ==============================================================================

const _tui_root = path self | path dirname

# Extract only the MY_ENV_VARS fields needed by a lazy-loaded TUI subcommand (least privilege).
@category tui
export def _tui-scoped-env [
    cmd_name: string    # Target TUI subcommand ("t ui", "obs tui", "h tui", "skills tui")
    env_vars: record = {} # Full $env.MY_ENV_VARS record
]: nothing -> record {
    match $cmd_name {
        "t ui" => {
            mut out = {}
            for k in ["download_dir" "transmission_auth" "transmission_user" "transmission_pass"] {
                let v = $env_vars | get -o $k
                if $v != null { $out = ($out | insert $k $v) }
            }
            $out
        }
        "obs tui" => {
            let v = $env_vars.OBSIDIAN_VAULT_ROOT?
            if $v != null { { OBSIDIAN_VAULT_ROOT: $v } } else { {} }
        }
        "h tui" => {
            mut out = {}
            let hab = $env_vars.api_keys?.habitica?
            if $hab != null { $out = ($out | insert api_keys { habitica: $hab }) }
            let av = $env_vars.habitica_avatar?
            if $av != null { $out = ($out | insert habitica_avatar $av) }
            $out
        }
        "skills tui" => {
            let v = $env_vars.llms_configs?
            if $v != null { { llms_configs: $v } } else { {} }
        }
        _ => { {} }
    }
}

# Execute a TUI app from `tui_apps.nu` in a clean Nushell process so shell startup stays < 50 ms.
def _tui-launch [cmd_name: string, args: record = {}]: nothing -> nothing {
    let args_json = $args | to json --raw
    let scoped = _tui-scoped-env $cmd_name ($env.MY_ENV_VARS? | default {})
    let env_json = $scoped | to json --raw
    let runner = $_tui_root | path join "tui_runner.nu"
    with-env { TUI_LAUNCH_ARGS: $args_json, TUI_MY_ENV_VARS_JSON: $env_json } {
        ^$nu.current-exe -n $runner $cmd_name
    }
}

# Interactive Transmission TUI client replacing tremc.
@category tui
@example "Open Transmission TUI on localhost" { t ui }
@example "Connect to remote Transmission daemon with 5s refresh" { t ui "192.168.1.50" --refresh 5sec }
export def "t ui" [
    host: string = "127.0.0.1"         # Transmission host or IP address
    --refresh (-r): duration = 2sec    # Live refresh interval
    --stdin-tty: oneof<bool, nothing>  # Optional override for stdin TTY status (for testing)
    --stdout-tty: oneof<bool, nothing> # Optional override for stdout TTY status (for testing)
]: nothing -> nothing {
    _tui-require-tty --stdin-tty=$stdin_tty --stdout-tty=$stdout_tty
    _tui-launch "t ui" {
        host: $host
        refresh_ns: ($refresh / 1ns | into int)
    }
}

# Interactive three-pane Obsidian vault browser (folder tree, notes table, Markdown preview).
@category tui
@example "Browse the default Obsidian vault" { obs tui }
@example "Browse a specific Obsidian vault by name" { obs tui --vault "Work" }
export def "obs tui" [
    --vault (-v): string = ""          # Optional Obsidian vault name
    --stdin-tty: oneof<bool, nothing>  # Optional override for stdin TTY status (for testing)
    --stdout-tty: oneof<bool, nothing> # Optional override for stdout TTY status (for testing)
]: nothing -> nothing {
    _tui-require-tty --stdin-tty=$stdin_tty --stdout-tty=$stdout_tty
    _tui-launch "obs tui" {
        vault: $vault
    }
}

# Interactive Habitica TUI for todos, habits, and dailys (`htui` alias).
@category tui
@example "Launch Habitica TUI" { h tui }
@example "Launch Habitica TUI via htui alias" { htui }
export def "h tui" [
    --stdin-tty: oneof<bool, nothing>  # Optional override for stdin TTY status (for testing)
    --stdout-tty: oneof<bool, nothing> # Optional override for stdout TTY status (for testing)
]: nothing -> nothing {
    _tui-require-tty --stdin-tty=$stdin_tty --stdout-tty=$stdout_tty
    _tui-launch "h tui" {}
}

export alias htui = h tui

# Interactive Agent Skills browser with fuzzy search, Markdown preview, mdfried/glow viewer, ox edit, and file list.
@category tui
@example "Browse configured Agent Skills" { skills tui }
@example "Browse skills from a custom directory" { skills tui --dir ~/my-skills }
export def "skills tui" [
    --dir (-d): string = ""            # Optional override path to skills directory
    --stdin-tty: oneof<bool, nothing>  # Optional override for stdin TTY status (for testing)
    --stdout-tty: oneof<bool, nothing> # Optional override for stdout TTY status (for testing)
]: nothing -> nothing {
    _tui-require-tty --stdin-tty=$stdin_tty --stdout-tty=$stdout_tty
    _tui-launch "skills tui" {
        dir: $dir
    }
}
