# Interactive terminal UI (TUI) front-ends built on Nushell's native `tui` command family.
# Commands: monitor, t ui, obs tui, h tui (htui), skills tui, plus shared _tui-* helpers.

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

# Build a per-process NUON state file path under $nu.temp-dir.
@category tui
@example 'build state path' { _tui-state-path "monitor" | path basename | str starts-with "tui-monitor-" } --result true
export def _tui-state-path [
    name: string # Short component name for the state file
]: nothing -> path {
    $nu.temp-dir | path join $"tui-($name)-($nu.pid).nuon"
}

# Read a TUI state record from disk, returning the default record when absent.
@category tui
export def _tui-state-get [
    path: path          # Path to the NUON state file
    default: record = {} # Fallback record when file does not exist
]: nothing -> record {
    if ($path | path exists) {
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
# Phase 2: t ui (Transmission) — Data Layer
# ==============================================================================

# Call Transmission JSON-RPC on port 9091 with 409 session-id handshake and Basic auth.
@category tui
export def _t-rpc [
    method: string               # Transmission RPC method (e.g. "torrent-get")
    arguments: record = {}       # RPC arguments record
    --host: string = "127.0.0.1" # Transmission daemon host
    --post: any                  # Optional custom HTTP poster closure(url, headers, body) for tests
]: nothing -> any {
    if ($env.MOCK_TRANSMISSION_RPC? | is-not-empty) {
        return (do $env.MOCK_TRANSMISSION_RPC $method $arguments)
    }

    let url = $"http://($host):9091/transmission/rpc"
    let auth = $"Basic ('transmission:transmission' | encode base64)"
    let body = { method: $method, arguments: $arguments }
    let body_json = $body | to json
    let poster = if ($post != null) {
        $post
    } else {
        {|u, h, b|
            http post --full --allow-errors --content-type application/json --headers $h $u $b
        }
    }

    mut sid = ""
    for _ in 1..2 {
        let headers = [Authorization $auth X-Transmission-Session-Id $sid]
        let resp = try {
            do $poster $url $headers $body_json
        } catch {
            error make {
                msg: $"(ansi red)Transmission daemon is not responding. Ensure it is started via 't start'.(ansi reset)"
            }
        }
        if $resp.status == 409 {
            $sid = (
                $resp.headers.response
                | where { |h| ($h.name | str lowercase) == "x-transmission-session-id" }
                | get value
                | first
            )
        } else if $resp.status == 200 {
            let rpc_result = $resp.body.result? | default "success"
            if $rpc_result != "success" {
                error make { msg: $"Transmission RPC error: ($rpc_result)" }
            }
            return ($resp.body.arguments? | default {})
        } else {
            error make { msg: $"Transmission RPC failed: HTTP ($resp.status)" }
        }
    }
    error make { msg: "Transmission RPC session handshake failed after retry" }
}

# Format Transmission ETA seconds and completion ratio to match `t list` style.
@category tui
@example 'done eta' { _t-eta (-1) 1.0 } --result "Done"
export def _t-eta [
    eta_s: int  # Remaining seconds (-1 when unknown or finished)
    pct: float  # Completion ratio in [0.0, 1.0]
]: nothing -> string {
    if $eta_s < 0 {
        if $pct >= 1.0 { "Done" } else { "Unknown" }
    } else if $eta_s < 60 {
        $"($eta_s) sec"
    } else if $eta_s < 3600 {
        $"($eta_s // 60) min"
    } else if $eta_s < 86400 {
        $"($eta_s // 3600) hrs"
    } else {
        $"($eta_s // 86400) days"
    }
}

# Map Transmission numeric torrent status code to display label.
@category tui
@example 'downloading status' { _t-status 4 } --result "Downloading"
export def _t-status [
    code: int # Transmission status code (0..6)
]: nothing -> string {
    match $code {
        0 => "Stopped"
        1 => "CheckWait"
        2 => "Checking"
        3 => "Queued"
        4 => "Downloading"
        5 => "SeedWait"
        6 => "Seeding"
        _ => $"Unknown(($code))"
    }
}

# Format transfer rate in bytes/sec as kB/s with one decimal place.
@category tui
@example 'format 153400 B/s' { _t-speed 153400 } --result "153.4"
export def _t-speed [
    bytes_per_sec: number # Rate in bytes per second
]: nothing -> string {
    (($bytes_per_sec | into float) / 1000.0) | math round --precision 1 | into string --decimals 1
}

# Shape Transmission RPC torrent records into TUI display rows plus hidden raw numeric sort fields.
@category tui
export def _t-rows [
    torrents: list<any> # List of torrent records from `torrent-get`
]: nothing -> list<any> {
    $torrents | each { |t|
        let pct = ($t.percentDone? | default 0.0) | into float
        let eta_s = ($t.eta? | default (-1)) | into int
        let have_b = ($t.haveValid? | default 0) | into int
        let up_b = ($t.rateUpload? | default 0) | into int
        let down_b = ($t.rateDownload? | default 0) | into int
        let eta_sort = if $eta_s < 0 {
            if $pct >= 1.0 { 0 } else { 9999999999 }
        } else {
            $eta_s
        }
        {
            ID: $t.id
            Done: (_tui-bar $pct 10)
            Have: ($have_b | into filesize)
            ETA: (_t-eta $eta_s $pct)
            Up: (_t-speed $up_b)
            Down: (_t-speed $down_b)
            Status: (_t-status ($t.status? | default 0))
            Name: ($t.name? | default "")
            pct: $pct
            have_b: $have_b
            eta_s: $eta_s
            up_b: $up_b
            down_b: $down_b
            eta_sort: $eta_sort
        }
    }
}

# Fetch torrents from Transmission RPC and return shaped TUI rows.
@category tui
export def _t-list-torrents [
    --host: string = "127.0.0.1" # Transmission daemon host
]: nothing -> list<any> {
    let fields = [
        "id" "name" "percentDone" "status" "rateDownload" "rateUpload"
        "eta" "sizeWhenDone" "haveValid" "uploadRatio" "peersConnected"
        "error" "errorString" "downloadDir" "addedDate"
    ]
    let res = _t-rpc "torrent-get" { fields: $fields } --host $host
    _t-rows ($res.torrents? | default [])
}

# Start one or more torrents by ID via Transmission RPC.
@category tui
export def _t-start [
    ids: list<int>               # Torrent IDs to start
    --host: string = "127.0.0.1" # Transmission daemon host
]: nothing -> nothing {
    if ($ids | is-empty) { return }
    _t-rpc "torrent-start" { ids: $ids } --host $host | ignore
}

# Stop one or more torrents by ID via Transmission RPC.
@category tui
export def _t-stop [
    ids: list<int>               # Torrent IDs to stop
    --host: string = "127.0.0.1" # Transmission daemon host
]: nothing -> nothing {
    if ($ids | is-empty) { return }
    _t-rpc "torrent-stop" { ids: $ids } --host $host | ignore
}

# Remove torrents from queue without deleting local data.
@category tui
export def _t-remove [
    ids: list<int>               # Torrent IDs to remove
    --host: string = "127.0.0.1" # Transmission daemon host
]: nothing -> nothing {
    if ($ids | is-empty) { return }
    _t-rpc "torrent-remove" { ids: $ids, "delete-local-data": false } --host $host | ignore
}

# Remove torrents from queue and delete downloaded local data.
@category tui
export def _t-remove-delete [
    ids: list<int>               # Torrent IDs to remove and delete
    --host: string = "127.0.0.1" # Transmission daemon host
]: nothing -> nothing {
    if ($ids | is-empty) { return }
    _t-rpc "torrent-remove" { ids: $ids, "delete-local-data": true } --host $host | ignore
}

# Remove finished torrents (matching `t remove-done`), scoped to selected IDs when non-empty.
@category tui
export def _t-remove-done [
    rows: list<any>              # Shaped torrent rows
    selected_ids: list<int>      # Selected torrent IDs (empty => all torrents)
    --host: string = "127.0.0.1" # Transmission daemon host
]: nothing -> list<int> {
    let candidates = if ($selected_ids | is-empty) {
        $rows
    } else {
        $rows | where ID in $selected_ids
    }
    let done_ids = $candidates | where { |r| $r.pct >= 1.0 and $r.ETA == "Done" } | get ID
    if ($done_ids | is-empty) {
        return []
    }
    _t-remove $done_ids --host $host
    $done_ids
}

# Query whether Transmission alternate-speed (turtle) mode is enabled.
@category tui
export def _t-turtle-get [
    --host: string = "127.0.0.1" # Transmission daemon host
]: nothing -> bool {
    let res = _t-rpc "session-get" { fields: ["alt-speed-enabled"] } --host $host
    ($res | get -o "alt-speed-enabled" | default false) | into bool
}

# Set Transmission alternate-speed (turtle) mode enabled state.
@category tui
export def _t-turtle-set [
    enabled: bool                # Desired turtle mode state
    --host: string = "127.0.0.1" # Transmission daemon host
]: nothing -> nothing {
    _t-rpc "session-set" { "alt-speed-enabled": $enabled } --host $host | ignore
}

# Add a magnet link, URL, local .torrent file, or text file of links (1 per line).
@category tui
export def _t-add [
    target: string               # Magnet link, URL, local .torrent file, or line-delimited list file
    --host: string = "127.0.0.1" # Transmission daemon host
]: nothing -> nothing {
    let clean = $target | str trim
    if ($clean | is-empty) { return }

    let expanded = $clean | path expand
    if ($expanded | path exists) and (($expanded | path type) == "file") {
        let ext = $expanded | path parse | get extension | str lowercase
        if $ext == "torrent" {
            let b64 = open --raw $expanded | encode base64
            _t-rpc "torrent-add" { metainfo: $b64 } --host $host | ignore
        } else {
            let entries = open --raw $expanded | lines | str trim | where { |l| $l | is-not-empty }
            for entry in $entries {
                _t-add $entry --host $host
            }
        }
    } else {
        _t-rpc "torrent-add" { filename: $clean } --host $host | ignore
    }
}

# ==============================================================================
# Phase 2: t ui (Transmission) — Interaction State Reducers
# ==============================================================================

# Initialize and persist the default `t ui` state record.
@category tui
export def _t-ui-init-state [
    state_path: path # Path to NUON state file
]: nothing -> record {
    let default_st = {
        sort: "ID"
        reverse: false
        selected: []
        confirm_delete: null
        turtle: false
        status_msg: ""
    }
    _tui-state-set $state_path $default_st
}

# Advance `t ui` sort column through display columns and reset reverse to false.
@category tui
export def _t-ui-cycle-sort [
    state_path: path # Path to NUON state file
]: nothing -> record {
    let cols = ["ID" "Done" "Have" "ETA" "Up" "Down" "Status" "Name"]
    let cur = _tui-state-get $state_path { sort: "ID", reverse: false }
    let next = _tui-cycle-sort $cols $cur.sort $cur.reverse
    _tui-state-merge $state_path { sort: $next.column, reverse: $next.reverse }
}

# Reverse the current `t ui` sort direction.
@category tui
export def _t-ui-flip-sort [
    state_path: path # Path to NUON state file
]: nothing -> record {
    let cur = _tui-state-get $state_path { sort: "ID", reverse: false }
    _tui-state-merge $state_path { reverse: (not $cur.reverse) }
}

# Sort `t ui` torrent rows using raw numeric fields for Done, Have, ETA, Up, and Down.
@category tui
export def _t-ui-sort-rows [
    rows: list<any>  # Shaped torrent rows from `_t-rows`
    sort_col: string # Display column name
    --reverse (-r)   # Sort descending
]: nothing -> list<any> {
    let key_map = {
        ID: "ID"
        Done: "pct"
        Have: "have_b"
        ETA: "eta_sort"
        Up: "up_b"
        Down: "down_b"
        Status: "Status"
        Name: "Name"
    }
    let raw_col = $key_map | get -o $sort_col | default "ID"
    _tui-sort-rows $rows $raw_col --reverse=$reverse
}

# Toggle a torrent ID in `t ui` multi-selection state.
@category tui
export def _t-ui-toggle-select [
    state_path: path # Path to NUON state file
    id: int          # Torrent ID to toggle
]: nothing -> record {
    let cur = _tui-state-get $state_path { selected: [] }
    let next_sel = if ($id in $cur.selected) {
        $cur.selected | where $it != $id
    } else {
        $cur.selected | append $id
    }
    _tui-state-merge $state_path { selected: $next_sel }
}

# Select all currently listed torrent IDs.
@category tui
export def _t-ui-select-all [
    state_path: path # Path to NUON state file
    rows: list<any>  # Current torrent rows
]: nothing -> record {
    let ids = if ($rows | is-empty) { [] } else { $rows | get ID }
    _tui-state-merge $state_path { selected: $ids }
}

# Clear all selected torrent IDs.
@category tui
export def _t-ui-select-none [
    state_path: path # Path to NUON state file
]: nothing -> record {
    _tui-state-merge $state_path { selected: [] }
}

# Drop any selected IDs that are no longer present in the live torrent list.
@category tui
export def _t-ui-prune-selected [
    state_path: path # Path to NUON state file
    rows: list<any>  # Current torrent rows
]: nothing -> record {
    let cur = _tui-state-get $state_path { selected: [] }
    let valid_ids = if ($rows | is-empty) { [] } else { $rows | get ID }
    let pruned = $cur.selected | where { |id| $id in $valid_ids }
    if $pruned == $cur.selected {
        $cur
    } else {
        _tui-state-merge $state_path { selected: $pruned }
    }
}

# Resolve action target IDs: explicit selection when non-empty, else the cursor row ID.
@category tui
export def _t-ui-target-ids [
    state_path: path # Path to NUON state file
    cursor_row: any  # Currently highlighted row record or null
]: nothing -> list<int> {
    let cur = _tui-state-get $state_path { selected: [] }
    if ($cur.selected | is-not-empty) {
        return $cur.selected
    }
    let cid = $cursor_row | get -o ID
    if $cid == null { [] } else { [$cid] }
}

# Prepend a `Sel` marker column ("✓" or "") to each torrent row for table display.
@category tui
export def _t-ui-mark-rows [
    rows: list<any>         # Torrent rows
    selected_ids: list<int> # Currently selected torrent IDs
]: nothing -> list<any> {
    $rows | each { |r|
        let mark = if ($r.ID in $selected_ids) { "✓" } else { "" }
        { Sel: $mark } | merge $r
    }
}

# Record pending torrent IDs for delete-with-data confirmation.
@category tui
export def _t-ui-confirm-request [
    state_path: path # Path to NUON state file
    ids: list<int>   # Torrent IDs awaiting delete confirmation
]: nothing -> record {
    _tui-state-merge $state_path { confirm_delete: $ids }
}

# Clear any pending delete-with-data confirmation state.
@category tui
export def _t-ui-confirm-clear [
    state_path: path # Path to NUON state file
]: nothing -> record {
    _tui-state-merge $state_path { confirm_delete: null }
}

# ==============================================================================
# Phase 2: t ui (Transmission) — TUI Builders & Command
# ==============================================================================

# Fetch live torrents, prune stale selections, sync turtle flag, sort, and mark rows.
export def _t-state-rows [
    state_path: path             # Path to NUON state file
    --host: string = "127.0.0.1" # Transmission daemon host
]: nothing -> list<any> {
    let rows = _t-list-torrents --host $host
    let pruned = _t-ui-prune-selected $state_path $rows
    let turtle = try { _t-turtle-get --host $host } catch { $pruned.turtle? | default false }
    let st = _tui-state-merge $state_path { turtle: $turtle }
    let sorted = _t-ui-sort-rows $rows $st.sort --reverse=$st.reverse
    _t-ui-mark-rows $sorted $st.selected
}

# Format detailed torrent info text matching `t info <id>` for the right preview pane.
export def _t-info-text [
    id: any                      # Torrent ID (or null when list is empty)
    --host: string = "127.0.0.1" # Transmission daemon host
]: nothing -> string {
    if $id == null {
        return "No torrent selected."
    }
    if ($env.MOCK_TRANSMISSION_RPC? | is-empty) and (which transmission-remote | is-not-empty) {
        let res = (do { ^transmission-remote $"($host):9091" -t $id -n 'transmission:transmission' -i } | complete)
        if $res.exit_code == 0 {
            return ($res.stdout | str trim)
        }
    }
    let fields = [
        "id" "name" "percentDone" "status" "rateDownload" "rateUpload"
        "eta" "sizeWhenDone" "haveValid" "uploadRatio" "peersConnected"
        "error" "errorString" "downloadDir" "addedDate"
    ]
    let res = _t-rpc "torrent-get" { ids: [$id], fields: $fields } --host $host
    let list = $res.torrents? | default []
    if ($list | is-empty) {
        return $"Torrent ($id) not found."
    }
    let t = $list | first
    let pct = (($t.percentDone? | default 0.0) | into float)
    let pct_str = (($pct * 100.0) | math round --precision 1 | into string) + "%"
    [
        "NAME"
        $"  Id: ($t.id)"
        $"  Name: ($t.name? | default '')"
        $"  Location: ($t.downloadDir? | default '')"
        ""
        "TRANSFER"
        $"  State: (_t-status ($t.status? | default 0))"
        $"  Percent Done: ($pct_str)"
        $"  ETA: (_t-eta (($t.eta? | default (-1)) | into int) $pct)"
        $"  Download Speed: (_t-speed ($t.rateDownload? | default 0)) kB/s"
        $"  Upload Speed: (_t-speed ($t.rateUpload? | default 0)) kB/s"
        $"  Have: (($t.haveValid? | default 0) | into filesize)"
        $"  Total size: (($t.sizeWhenDone? | default 0) | into filesize)"
        $"  Ratio: ($t.uploadRatio? | default 0)"
        $"  Peers: ($t.peersConnected? | default 0)"
    ] | str join (char nl)
}

# Build confirmation TUI for `t remove-delete`.
export def _t-build-confirm-ui [
    ids: list<int> # Torrent IDs queued for deletion with local data
]: nothing -> any {
    let id_text = $ids | each { |x| $x | into string } | str join ", "
    tui label --titlebar "Confirm Delete (+ Local Data)"
    | tui label $"Delete torrent\(s\) [($id_text)] AND remove downloaded files from disk?"
    | tui button "Yes (Delete)" {|| { action: submit, selected: "yes" } }
    | tui button "Cancel" {|| { action: quit } }
    | tui label --status "enter: confirm  esc/q: cancel"
}

# Build basic or full stats view TUI.
export def _t-build-stats-ui [
    kind: string                 # "basic" or "full"
    --host: string = "127.0.0.1" # Transmission daemon host
]: nothing -> any {
    let stats = _t-rpc "session-stats" {} --host $host
    let cum = $stats | get -o "cumulative-stats" | default {}
    let cur = $stats | get -o "current-stats" | default {}
    let rows = [
        { Metric: "Active Torrents" Value: ($stats.activeTorrentCount? | default 0 | into string) }
        { Metric: "Total Torrents" Value: ($stats.torrentCount? | default 0 | into string) }
        { Metric: "Download Speed" Value: $"(_t-speed ($stats.downloadSpeed? | default 0)) kB/s" }
        { Metric: "Upload Speed" Value: $"(_t-speed ($stats.uploadSpeed? | default 0)) kB/s" }
    ] | if $kind == "full" {
        append [
            { Metric: "Cumulative Downloaded" Value: (($cum.downloadedBytes? | default 0) | into filesize | into string) }
            { Metric: "Cumulative Uploaded" Value: (($cum.uploadedBytes? | default 0) | into filesize | into string) }
            { Metric: "Cumulative Files Added" Value: ($cum.filesAdded? | default 0 | into string) }
            { Metric: "Session Downloaded" Value: (($cur.downloadedBytes? | default 0) | into filesize | into string) }
            { Metric: "Session Uploaded" Value: (($cur.uploadedBytes? | default 0) | into filesize | into string) }
        ]
    } else { }

    let title = if $kind == "full" { "Transmission Full Stats" } else { "Transmission Basic Stats" }
    $rows
    | tui label --titlebar $title
    | tui table
    | tui button "Back (Enter/q)" {|| { action: quit } }
    | tui label --status "enter/q/esc: back to torrents"
}

# Build add-torrent form with text input and fuzzy `.torrent` file browser.
export def _t-build-add-form [
    download_dir: path # Root directory to scan for `.torrent` files
]: nothing -> any {
    let torrent_files = if ($download_dir | path exists) {
        glob ($download_dir | path join "**" "*.torrent") --no-dir
        | each { |f| { name: ($f | path basename), path: $f } }
        | sort-by --natural name
    } else {
        []
    }

    $torrent_files
    | tui label --titlebar "Add Torrent · Enter submits input · / filters .torrent files · Esc/q cancels"
    | tui textbox --id target --placeholder "Magnet link, .torrent URL, local .torrent path, or links .txt" --focus
    | tui search --fuzzy --bind /
    | tui table --id files --columns [name]
    | tui button "Add"
    | tui button "Cancel" {|| { action: quit } }
    | tui label --status "tab: switch widget  /: filter .torrent files  enter: add  esc: cancel"
}

# Build keybindings help screen.
def _t-build-help-ui []: nothing -> any {
    [
        { Key: "o" Action: "Cycle sort column (ID, Done, Have, ETA, Up, Down, Status, Name)" }
        { Key: "r" Action: "Reverse sort direction" }
        { Key: "space" Action: "Toggle selection on cursor row" }
        { Key: "a / n" Action: "Select all / Select none" }
        { Key: "s / p" Action: "Start / Stop selected (or cursor) torrent(s)" }
        { Key: "d" Action: "Remove finished torrents (selected if any, else all)" }
        { Key: "Shift+D" Action: "Remove + delete local data (asks confirmation)" }
        { Key: "t" Action: "Toggle alternate speed (turtle) mode" }
        { Key: "b / f" Action: "Show basic / full session stats" }
        { Key: "+" Action: "Add torrent (magnet, URL, .torrent, or links file)" }
        { Key: "q / esc" Action: "Quit" }
    ]
    | tui label --titlebar "Transmission TUI Help"
    | tui table
    | tui button "Back" {|| { action: quit } }
    | tui label --status "enter/q/esc: back to torrents"
}

# Shared action dispatcher used by both `t ui` keybinds and buttons.
export def _t-do-action [
    state_path: path
    ui_state: record
    op: string
    --host: string = "127.0.0.1"
]: nothing -> any {
    let cursor_row = $ui_state.selected?
    match $op {
        "cycle_sort" => { _t-ui-cycle-sort $state_path | ignore }
        "flip_sort" => { _t-ui-flip-sort $state_path | ignore }
        "toggle_select" => {
            let cid = $cursor_row | get -o ID
            if $cid != null { _t-ui-toggle-select $state_path $cid | ignore }
        }
        "select_all" => {
            let rows = _t-list-torrents --host $host
            _t-ui-select-all $state_path $rows | ignore
        }
        "select_none" => { _t-ui-select-none $state_path | ignore }
        "start" => {
            let ids = _t-ui-target-ids $state_path $cursor_row
            if ($ids | is-not-empty) { _t-start $ids --host $host }
        }
        "stop" => {
            let ids = _t-ui-target-ids $state_path $cursor_row
            if ($ids | is-not-empty) { _t-stop $ids --host $host }
        }
        "remove_done" => {
            let cur = _tui-state-get $state_path { selected: [] }
            let rows = _t-list-torrents --host $host
            let removed = _t-remove-done $rows $cur.selected --host $host
            let msg = if ($removed | is-empty) { "no finished torrents in target" } else { $"removed ($removed | length) done" }
            _tui-state-merge $state_path { status_msg: $msg } | ignore
        }
        "confirm_delete" => {
            let ids = _t-ui-target-ids $state_path $cursor_row
            if ($ids | is-empty) {
                _tui-state-merge $state_path { status_msg: "nothing selected" } | ignore
                return (_t-state-rows $state_path --host $host)
            }
            return { action: submit, selected: { op: "confirm_delete", ids: $ids } }
        }
        "toggle_turtle" => {
            let cur = try { _t-turtle-get --host $host } catch { false }
            _t-turtle-set (not $cur) --host $host
            _tui-state-merge $state_path { turtle: (not $cur) } | ignore
        }
        _ => {}
    }
    _t-state-rows $state_path --host $host
}

# Build the main `t ui` interactive pipeline (exposed for headless `tui debug` testing).
export def _t-build-ui [
    state_path: path             # Path to NUON state file
    --host: string = "127.0.0.1" # Transmission daemon host
]: nothing -> any {
    let initial_rows = _t-state-rows $state_path --host $host
    let legend = _tui-key-help [
        { key: "o" label: "sort" }
        { key: "r" label: "rev" }
        { key: "space" label: "sel" }
        { key: "s/p" label: "start/stop" }
        { key: "d" label: "done" }
        { key: "D" label: "del" }
        { key: "t" label: "turtle" }
        { key: "b/f" label: "stats" }
        { key: "+" label: "add" }
        { key: "?" label: "help" }
    ]

    $initial_rows
    | tui label --titlebar $"Transmission \(($host):9091\)"
    | tui split --sizes [65% 1fr] [
        (tui table --id torrents --columns [Sel ID Done Have ETA Up Down Status Name] --focus)
        (tui preview --from torrents {|row| _t-info-text ($row.ID?) --host $host })
    ]
    | tui button "Start (s)" {|s| _t-do-action $state_path $s "start" --host $host }
    | tui button "Stop (p)" {|s| _t-do-action $state_path $s "stop" --host $host }
    | tui button "Done (d)" {|s| _t-do-action $state_path $s "remove_done" --host $host }
    | tui button "Delete (D)" {|s| _t-do-action $state_path $s "confirm_delete" --host $host }
    | tui button "Turtle (t)" {|s| _t-do-action $state_path $s "toggle_turtle" --host $host }
    | tui button "Stats (b)" {|| { action: submit, selected: { op: "stats", kind: "basic" } } }
    | tui button "Full (f)" {|| { action: submit, selected: { op: "stats", kind: "full" } } }
    | tui button "Add (+)" {|| { action: submit, selected: { op: "add" } } }
    | tui label --status {|_|
        let st = _tui-state-get $state_path { sort: "ID", reverse: false, selected: [], turtle: false, status_msg: "" }
        let arrow = if $st.reverse { "↓" } else { "↑" }
        let turtle_txt = if ($st.turtle? | default false) { "ON" } else { "off" }
        let msg = if ($st.status_msg? | default "" | is-not-empty) { $" · ($st.status_msg)" } else { "" }
        $"sort:($st.sort)($arrow) · sel:($st.selected | length) · turtle:($turtle_txt)($msg) · ($legend)"
    }
    | tui bind o {|s| _t-do-action $state_path $s "cycle_sort" --host $host }
    | tui bind r {|s| _t-do-action $state_path $s "flip_sort" --host $host }
    | tui bind space {|s| _t-do-action $state_path $s "toggle_select" --host $host }
    | tui bind a {|s| _t-do-action $state_path $s "select_all" --host $host }
    | tui bind n {|s| _t-do-action $state_path $s "select_none" --host $host }
    | tui bind s {|s| _t-do-action $state_path $s "start" --host $host }
    | tui bind p {|s| _t-do-action $state_path $s "stop" --host $host }
    | tui bind d {|s| _t-do-action $state_path $s "remove_done" --host $host }
    | tui bind shift+d {|s| _t-do-action $state_path $s "confirm_delete" --host $host }
    | tui bind t {|s| _t-do-action $state_path $s "toggle_turtle" --host $host }
    | tui bind b {|| { action: submit, selected: { op: "stats", kind: "basic" } } }
    | tui bind f {|| { action: submit, selected: { op: "stats", kind: "full" } } }
    | tui bind "+" {|| { action: submit, selected: { op: "add" } } }
    | tui bind "?" {|| { action: submit, selected: { op: "help" } } }
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

    let state_path = _tui-state-path "t-ui"
    try {
        _t-ui-init-state $state_path | ignore
        # Fail fast if daemon is unreachable before opening the alternate screen
        _t-list-torrents --host $host | ignore

        let dl_dir = try { $env.MY_ENV_VARS.download_dir } catch { "~/Downloads" } | path expand

        loop {
            let res = (_t-build-ui $state_path --host $host)
                | tui run --refresh $refresh {|| _t-state-rows $state_path --host $host }

            if $res.action != "submit" {
                break
            }

            let op = $res.selected?.op? | default ""
            match $op {
                "confirm_delete" => {
                    let ids = $res.selected?.ids? | default []
                    if ($ids | is-not-empty) {
                        let conf = (_t-build-confirm-ui $ids) | tui run
                        if $conf.action == "submit" and ($conf.selected? == "yes") {
                            _t-remove-delete $ids --host $host
                            _t-ui-select-none $state_path | ignore
                            _tui-state-merge $state_path { status_msg: $"deleted ($ids | length)" } | ignore
                        }
                    }
                }
                "stats" => {
                    let kind = $res.selected?.kind? | default "basic"
                    (_t-build-stats-ui $kind --host $host) | tui run | ignore
                }
                "add" => {
                    let add_res = (_t-build-add-form $dl_dir) | tui run
                    if $add_res.action == "submit" {
                        let typed = $add_res.values?.target? | default "" | str trim
                        let picked = $add_res.selected?.path? | default ""
                        let chosen = if ($typed | is-not-empty) { $typed } else { $picked }
                        if ($chosen | is-not-empty) {
                            _t-add $chosen --host $host
                            _tui-state-merge $state_path { status_msg: "torrent added" } | ignore
                        }
                    }
                }
                "help" => {
                    (_t-build-help-ui) | tui run | ignore
                }
                _ => { break }
            }
        }
    } finally {
        _tui-state-cleanup $state_path
    }
}
