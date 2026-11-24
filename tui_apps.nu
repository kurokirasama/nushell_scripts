# Lazy-loaded interactive TUI applications for tui.nu (t ui, obs tui, h tui / htui, skills tui).
# Loaded on demand at command invocation or directly by unit tests so shell startup stays < 50 ms.

# Normalize an arbitrary selection/row value into a record, returning `{}` for null/scalars.
def _tui-as-record [val: any]: nothing -> record {
    if ($val != null) and (($val | describe) | str starts-with "record") {
        $val
    } else {
        {}
    }
}

# ==============================================================================
# Phase 2: t ui (Transmission) — Data Layer
# ==============================================================================

# Validate Transmission RPC/remote hostname against empty strings, whitespace, or leading dashes.
def _t-validate-host [host: string]: nothing -> string {
    let trimmed = $host | str trim
    if ($trimmed | is-empty) or ($trimmed | str starts-with "-") or ($trimmed =~ '\s') {
        error make { msg: $"Invalid Transmission host: '($host)'" }
    }
    $trimmed
}

# Resolve Transmission username:password pair from MY_ENV_VARS, falling back to local default.
def _t-auth-pair []: nothing -> string {
    let mv = $env.MY_ENV_VARS? | default {}
    let direct = $mv.transmission_auth? | default ""
    if ($direct | is-not-empty) {
        return $direct
    }
    let u = $mv.transmission_user? | default "transmission"
    let p = $mv.transmission_pass? | default "transmission"
    $"($u):($p)"
}

# Invoke transmission-remote using TR_AUTH (--authenv) so credentials are not exposed in CLI args.
def _t-remote [host: string, args: list<string>]: nothing -> record {
    let safe_host = _t-validate-host $host
    with-env { TR_AUTH: (_t-auth-pair) } {
        (do { ^transmission-remote $"($safe_host):9091" -ne ...$args } | complete)
    }
}

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

    let safe_host = _t-validate-host $host
    let url = $"http://($safe_host):9091/transmission/rpc"
    let auth = $"Basic ((_t-auth-pair) | encode base64)"
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
            Name: ($t.name? | default "" | ansi strip)
            Done: (_tui-bar $pct 10)
            Have: ($have_b | into filesize)
            ETA: (_t-eta $eta_s $pct)
            Up: (_t-speed $up_b)
            Down: (_t-speed $down_b)
            Status: (_t-status ($t.status? | default 0))
            pct: $pct
            have_b: $have_b
            eta_s: $eta_s
            up_b: $up_b
            down_b: $down_b
            eta_sort: $eta_sort
            raw_id: $t.id
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

# Add one or more magnet links, URLs, local .torrent files, or text files of links (1 per line).
@category tui
export def _t-add [
    target: string               # Magnet link(s), URL(s), local .torrent file, or line-delimited list file
    --host: string = "127.0.0.1" # Transmission daemon host
    --depth: int = 0             # Current list-file recursion depth guard
    --visited: list<string> = [] # Visited file paths to prevent symlink/self cycles
]: nothing -> nothing {
    if $depth > 5 {
        return
    }
    let entries = $target | lines | str trim | where { |l| $l | is-not-empty }
    if ($entries | is-empty) { return }
    if ($entries | length) > 1 {
        for entry in $entries {
            _t-add $entry --host $host --depth $depth --visited $visited
        }
        return
    }

    let clean = $entries | first
    let expanded = if ($clean =~ '^(?:magnet:\?|https?://)') { "" } else { try { $clean | path expand } catch { "" } }
    if ($expanded | is-not-empty) and ($expanded | path exists) and (($expanded | path type) == "file") {
        if ($expanded in $visited) {
            return
        }
        let next_visited = $visited | append $expanded
        let ext = $expanded | path parse | get extension | str lowercase
        if $ext == "torrent" {
            let b64 = open --raw $expanded | encode base64
            _t-rpc "torrent-add" { metainfo: $b64 } --host $host | ignore
        } else {
            let file_entries = open --raw $expanded | lines | str trim | where { |l| $l | is-not-empty }
            for entry in $file_entries {
                _t-add $entry --host $host --depth ($depth + 1) --visited $next_visited
            }
        }
    } else {
        let urls = $clean | split row -r '\s+(?=(?:magnet:\?|https?://))' | str trim | where { |u| $u | is-not-empty }
        if ($urls | length) > 1 {
            for u in $urls {
                _t-add $u --host $host --depth $depth --visited $visited
            }
        } else {
            _t-rpc "torrent-add" { filename: $clean } --host $host | ignore
        }
    }
}

# Extract integer torrent ID from a shaped or marked row record.
def _t-row-id [row: any]: nothing -> any {
    if $row == null { return null }
    let raw = $row | get -o raw_id
    if $raw != null { return ($raw | into int) }
    let id_val = $row | get -o ID
    if $id_val == null { return null }
    if ($id_val | describe) == "int" {
        $id_val
    } else {
        try { ($id_val | into string | str replace "✓" "" | str trim | into int) } catch { null }
    }
}

# Compute `tui table` cell color matching `t list` rules for Name, Status, Up, and Down.
@category tui
export def _t-cell-color [
    val: string # Table string cell value (with optional zero-width Up/Down markers)
]: nothing -> any {
    let zwsp = (char -u '200b')
    let zwnj = (char -u '200c')
    if ($val | str starts-with "✓ ") {
        { fg: "yellow", attr: "b" }
    } else if ($val | str contains "█") or ($val | str contains "░") {
        "default"
    } else if ($val | str ends-with $zwsp) {
        "cyan"
    } else if ($val | str ends-with $zwnj) {
        "green"
    } else if $val in ["Stopped" "Downloading" "Seeding" "Paused" "Queued" "Idle" "CheckWait" "Checking" "SeedWait"] {
        match $val {
            "Stopped" => "red"
            "Downloading" => "green"
            "Seeding" => "cyan"
            "Paused" => "#ffa500"
            "Queued" => "yellow"
            "Idle" => "blue"
            _ => "default"
        }
    } else if ($val =~ '^(Done|Unknown|\d+ (sec|min|hrs|days)|\d+\.\d+)$') {
        "default"
    } else {
        let ext = try { $val | path parse | get extension | str lowercase } catch { "" }
        if ($ext | is-empty) {
            { fg: "blue", attr: "b" }
        } else if $ext in ["mp4" "mkv" "mp3" "avi" "mov" "webm" "flv" "png" "jpg" "jpeg" "gif"] {
            { fg: "purple", attr: "b" }
        } else {
            { fg: "#ffffff", attr: "b" }
        }
    }
}

# Build `$env.config` override for `t ui` combining custom TUI colors and `t list` cell coloring.
@category tui
export def _t-tui-config []: nothing -> record {
    let base = $env.config? | default {}
    let tui_cfg = ($base.tui? | default {}) | merge {
        title_bar: { fg: "#000000", bg: "#00ff00", attr: "b" }
        button: { fg: "#000000", bg: "#00ff00" }
        status_bar: { fg: "#ffffff", bg: "dark_gray" }
    }
    let cc = ($base.color_config? | default {}) | merge {
        string: {|val| _t-cell-color $val }
    }
    $base | upsert tui $tui_cfg | upsert color_config $cc
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
        preview: "off"
        hide_extra_cols: false
        add_queue: []
    }
    _tui-state-set $state_path $default_st
}

# Return the currently visible display column names based on `hide_extra_cols`.
@category tui
export def _t-ui-visible-cols [
    st: record # `t ui` state record
]: nothing -> list<string> {
    if ($st.hide_extra_cols? | default false) {
        ["ID" "Name" "Done" "Have" "ETA"]
    } else {
        ["ID" "Name" "Done" "Have" "ETA" "Up" "Down" "Status"]
    }
}

# Toggle visibility of Up, Down, and Status columns and reset sort if sorting by a hidden column.
@category tui
export def _t-ui-toggle-cols [
    state_path: path # Path to NUON state file
]: nothing -> record {
    let cur = _tui-state-get $state_path { sort: "ID", reverse: false, hide_extra_cols: false }
    let hide = not ($cur.hide_extra_cols? | default false)
    let patch = if $hide and ($cur.sort in ["Up" "Down" "Status"]) {
        { hide_extra_cols: $hide, sort: "ID", reverse: false }
    } else {
        { hide_extra_cols: $hide }
    }
    _tui-state-merge $state_path $patch
}

# Toggle or switch `t ui` right preview pane mode ("off" <-> "info" <-> "stats").
@category tui
export def _t-ui-toggle-preview [
    state_path: path   # Path to NUON state file
    target_mode: string # Desired preview mode ("info" or "stats")
]: nothing -> record<preview: string, relaunch: bool> {
    let cur = _tui-state-get $state_path { preview: "off" }
    let cur_mode = $cur.preview? | default "off"
    let next_mode = if $cur_mode == $target_mode { "off" } else { $target_mode }
    let relaunch = ($cur_mode == "off") or ($next_mode == "off")
    _tui-state-merge $state_path { preview: $next_mode } | ignore
    { preview: $next_mode, relaunch: $relaunch }
}

# Advance `t ui` sort column through visible display columns and reset reverse to false.
@category tui
export def _t-ui-cycle-sort [
    state_path: path # Path to NUON state file
]: nothing -> record {
    let cur = _tui-state-get $state_path { sort: "ID", reverse: false, hide_extra_cols: false }
    let cols = _t-ui-visible-cols $cur
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

# Sort `t ui` torrent rows using raw numeric fields for ID, Done, Have, ETA, Up, and Down.
@category tui
export def _t-ui-sort-rows [
    rows: list<any>  # Shaped torrent rows from `_t-rows`
    sort_col: string # Display column name
    --reverse (-r)   # Sort descending
]: nothing -> list<any> {
    let key_map = {
        ID: "ID"
        Done: "pct"
        Name: "Name"
        Have: "have_b"
        ETA: "eta_sort"
        Up: "up_b"
        Down: "down_b"
        Status: "Status"
    }
    let raw_col = $key_map | get -o $sort_col | default "ID"
    let actual_col = if $sort_col == "ID" and ($rows | is-not-empty) and ("raw_id" in ($rows | first | columns)) {
        "raw_id"
    } else {
        $raw_col
    }
    _tui-sort-rows $rows $actual_col --reverse=$reverse
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
    let ids = if ($rows | is-empty) { [] } else { $rows | each { |r| _t-row-id $r } | where $it != null }
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
    let valid_ids = if ($rows | is-empty) { [] } else { $rows | each { |r| _t-row-id $r } | where $it != null }
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
    let cid = _t-row-id $cursor_row
    if $cid == null { [] } else { [$cid] }
}

# Format `ID` with a "✓ " selection marker, keep `Sel` / `raw_id`, and tag active `Up`/`Down` cells for color_config.
@category tui
export def _t-ui-mark-rows [
    rows: list<any>         # Torrent rows
    selected_ids: list<int> # Currently selected torrent IDs
]: nothing -> list<any> {
    let zwsp = (char -u '200b')
    let zwnj = (char -u '200c')
    $rows | each { |r|
        let raw_id = _t-row-id $r
        let is_sel = ($raw_id in $selected_ids)
        let mark = if $is_sel { "✓" } else { "" }
        let id_disp = if $is_sel { $"✓ ($raw_id)" } else { $raw_id }
        let up_s = $r.Up | into string
        let down_s = $r.Down | into string
        let up_disp = if (($r.up_b? | default 0) > 0) and not ($up_s | str ends-with $zwsp) { $"($up_s)($zwsp)" } else { $up_s }
        let down_disp = if (($r.down_b? | default 0) > 0) and not ($down_s | str ends-with $zwnj) { $"($down_s)($zwnj)" } else { $down_s }
        { Sel: $mark, raw_id: $raw_id }
        | merge $r
        | upsert ID $id_disp
        | upsert Up $up_disp
        | upsert Down $down_disp
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
    let marked = _t-ui-mark-rows $sorted $st.selected
    let vis_cols = _t-ui-visible-cols $st
    if ($marked | is-empty) { [] } else { $marked | select ...$vis_cols }
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
        let res = _t-remote $host ["-t" ($id | into string) "-i"]
        if $res.exit_code == 0 {
            return ($res.stdout | str trim | ansi strip)
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
        $"  Name: ($t.name? | default '' | ansi strip)"
        $"  Location: ($t.downloadDir? | default '' | ansi strip)"
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

# Format combined Basic + Full Transmission statistics for the right preview pane.
export def _t-stats-text [
    --host: string = "127.0.0.1" # Transmission daemon host
]: nothing -> string {
    let stats = _t-rpc "session-stats" {} --host $host
    let cum = $stats | get -o "cumulative-stats" | default {}
    let cur = $stats | get -o "current-stats" | default {}
    let basic_lines = [
        "BASIC STATS"
        $"  Active Torrents: ($stats.activeTorrentCount? | default 0)"
        $"  Total Torrents: ($stats.torrentCount? | default 0)"
        $"  Download Speed: (_t-speed ($stats.downloadSpeed? | default 0)) kB/s"
        $"  Upload Speed: (_t-speed ($stats.uploadSpeed? | default 0)) kB/s"
    ]
    let live_extra = if ($env.MOCK_TRANSMISSION_RPC? | is-empty) and (which transmission-remote | is-not-empty) {
        let st_res = _t-remote $host ["-st"]
        let si_res = _t-remote $host ["-si"]
        {
            st: (if $st_res.exit_code == 0 { $st_res.stdout | str trim | ansi strip } else { "" })
            si: (if $si_res.exit_code == 0 { $si_res.stdout | str trim | ansi strip } else { "" })
        }
    } else {
        { st: "", si: "" }
    }
    mut out = $basic_lines
    $out = ($out | append [
        ""
        "FULL STATS"
        $"  Current Downloaded: (($cur.downloadedBytes? | default 0) | into filesize)"
        $"  Current Uploaded: (($cur.uploadedBytes? | default 0) | into filesize)"
        $"  Cumulative Downloaded: (($cum.downloadedBytes? | default 0) | into filesize)"
        $"  Cumulative Uploaded: (($cum.uploadedBytes? | default 0) | into filesize)"
        $"  Cumulative Files Added: ($cum.filesAdded? | default 0)"
    ])
    if ($live_extra.st | is-not-empty) {
        $out = ($out | append "" | append $live_extra.st)
    }
    if ($live_extra.si | is-not-empty) {
        $out = ($out | append "" | append $live_extra.si)
    }
    $out | str join (char nl)
}

# Resolve right preview pane text depending on current preview mode ("info" vs "stats").
export def _t-preview-text [
    state_path: path             # Path to NUON state file
    row: any                     # Currently highlighted torrent row
    --host: string = "127.0.0.1" # Transmission daemon host
]: nothing -> string {
    let st = _tui-state-get $state_path { preview: "off" }
    if ($st.preview? | default "off") == "stats" {
        _t-stats-text --host $host
    } else {
        _t-info-text (_t-row-id $row) --host $host
    }
}

# Read text from Wayland/X11 system clipboard when available.
def _t-read-clipboard []: nothing -> string {
    if (which wl-paste | is-not-empty) {
        let res = (do { ^wl-paste --no-newline } | complete)
        if $res.exit_code == 0 { return $res.stdout }
    }
    if (which xclip | is-not-empty) {
        let res = (do { ^xclip -o -selection clipboard } | complete)
        if $res.exit_code == 0 { return $res.stdout }
    }
    if (which xsel | is-not-empty) {
        let res = (do { ^xsel -ob } | complete)
        if $res.exit_code == 0 { return $res.stdout }
    }
    ""
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

# Build add-torrent form with text input, multi-line queue, clipboard paste, and `.torrent` file browser.
export def _t-build-add-form [
    download_dir: path        # Root directory to scan for `.torrent` files
    queued: list<string> = [] # Previously queued URLs/lines in this add session
]: nothing -> any {
    let torrent_files = if ($download_dir | path exists) {
        glob ($download_dir | path join "**" "*.torrent") --no-dir
        | each { |f| { name: ($f | path basename), path: $f } }
        | sort-by --natural name
    } else {
        []
    }

    let queue_txt = if ($queued | is-empty) {
        "Queue empty (Ctrl+N: queue line · Ctrl+V: paste multi-line clipboard)"
    } else {
        let preview = $queued | first ([($queued | length) 2] | math min) | str join ", "
        let suffix = if ($queued | length) > 2 { " ..." } else { "" }
        $"Queued links \(($queued | length)\): ($preview)($suffix)"
    }

    $torrent_files
    | tui label --titlebar "Add Torrent\(s\) · Ctrl+N queues line · Ctrl+V pastes clipboard · Enter submits · Esc/q cancels"
    | tui label $queue_txt
    | tui textbox --id target --placeholder "Magnet link(s), .torrent URL(s), local .torrent path, or links .txt" --focus
    | tui search --fuzzy --bind /
    | tui table --id files --title "Torrent Files" --columns [name]
    | tui button "Add"
    | tui button "Queue Line (Ctrl+N)" {|s| { action: submit, selected: { op: "queue_line", target: ($s.values.target? | default "") } } }
    | tui button "Paste Clipboard (Ctrl+V)" {|s| { action: submit, selected: { op: "paste_clipboard", target: ($s.values.target? | default "") } } }
    | tui button "Cancel" {|| { action: quit } }
    | tui label --status "tab: switch widget  /: filter .torrent  ctrl+n: queue line  ctrl+v: paste  enter: add  esc: cancel"
    | tui bind ctrl+n {|s| { action: submit, selected: { op: "queue_line", target: ($s.values.target? | default "") } } }
    | tui bind ctrl+v {|s| { action: submit, selected: { op: "paste_clipboard", target: ($s.values.target? | default "") } } }
}

# Build keybindings help screen.
def _t-build-help-ui []: nothing -> any {
    [
        { Key: "s" Action: "Cycle sort column (ID, Name, Done, Have, ETA, Up, Down, Status)" }
        { Key: "r" Action: "Reverse sort direction" }
        { Key: "space" Action: "Toggle selection on cursor row" }
        { Key: "a / n" Action: "Select all / Select none" }
        { Key: "u / x" Action: "Start / Stop selected (or cursor) torrent(s)" }
        { Key: "d" Action: "Remove finished torrents (selected if any, else all)" }
        { Key: "Shift+D" Action: "Remove + delete local data (asks confirmation)" }
        { Key: "t" Action: "Toggle alternate speed (turtle) mode" }
        { Key: "p" Action: "Toggle right torrent info preview pane" }
        { Key: "Shift+P" Action: "Toggle combined basic + full stats in preview pane" }
        { Key: "c" Action: "Show/hide Up, Down, and Status columns" }
        { Key: "+" Action: "Add torrent(s) (magnet, multi-line URLs, clipboard, .torrent, links file)" }
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
            let cid = _t-row-id $cursor_row
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
        "preview_info" => {
            let res = _t-ui-toggle-preview $state_path "info"
            if $res.relaunch {
                return { action: submit, selected: { op: "toggle_preview", mode: "info" } }
            }
        }
        "preview_stats" => {
            let res = _t-ui-toggle-preview $state_path "stats"
            if $res.relaunch {
                return { action: submit, selected: { op: "toggle_preview", mode: "stats" } }
            }
        }
        "toggle_cols" => { _t-ui-toggle-cols $state_path | ignore }
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
    let st_init = _tui-state-get $state_path { preview: "off" }
    let preview_mode = $st_init.preview? | default "off"
    let legend = _tui-key-help [
        { key: "s" label: "sort" }
        { key: "r" label: "rev" }
        { key: "space" label: "sel" }
        { key: "u/x" label: "start/stop" }
        { key: "d" label: "done" }
        { key: "D" label: "del" }
        { key: "t" label: "turtle" }
        { key: "p/P" label: "preview/stats" }
        { key: "c" label: "cols" }
        { key: "+" label: "add" }
        { key: "?" label: "help" }
    ]

    let base_ui = $initial_rows
        | tui label --titlebar $"Transmission \(($host):9091\)"
        | if $preview_mode == "off" {
            tui table --id torrents --title "Torrents" --focus
        } else {
            tui split --sizes [65% 1fr] [
                (tui table --id torrents --title "Torrents" --focus)
                (tui preview --from torrents {|row| _t-preview-text $state_path $row --host $host })
            ]
        }

    $base_ui
    | tui button "Start (u)" {|s| _t-do-action $state_path $s "start" --host $host }
    | tui button "Stop (x)" {|s| _t-do-action $state_path $s "stop" --host $host }
    | tui button "Done (d)" {|s| _t-do-action $state_path $s "remove_done" --host $host }
    | tui button "Delete (D)" {|s| _t-do-action $state_path $s "confirm_delete" --host $host }
    | tui button "Turtle (t)" {|s| _t-do-action $state_path $s "toggle_turtle" --host $host }
    | tui button "Preview (p)" {|s| _t-do-action $state_path $s "preview_info" --host $host }
    | tui button "Stats (P)" {|s| _t-do-action $state_path $s "preview_stats" --host $host }
    | tui button "Cols (c)" {|s| _t-do-action $state_path $s "toggle_cols" --host $host }
    | tui button "Add (+)" {|| { action: submit, selected: { op: "add" } } }
    | tui label --status {|_|
        let st = _tui-state-get $state_path { sort: "ID", reverse: false, selected: [], turtle: false, status_msg: "", preview: "off" }
        let arrow = if $st.reverse { "↓" } else { "↑" }
        let turtle_txt = if ($st.turtle? | default false) { "ON" } else { "off" }
        let pv_txt = $st.preview? | default "off"
        let msg = if ($st.status_msg? | default "" | is-not-empty) { $" · ($st.status_msg)" } else { "" }
        $"sort:($st.sort)($arrow) · sel:($st.selected | length) · turtle:($turtle_txt) · pv:($pv_txt)($msg) · ($legend)"
    }
    | tui bind s {|s| _t-do-action $state_path $s "cycle_sort" --host $host }
    | tui bind r {|s| _t-do-action $state_path $s "flip_sort" --host $host }
    | tui bind space {|s| _t-do-action $state_path $s "toggle_select" --host $host }
    | tui bind a {|s| _t-do-action $state_path $s "select_all" --host $host }
    | tui bind n {|s| _t-do-action $state_path $s "select_none" --host $host }
    | tui bind u {|s| _t-do-action $state_path $s "start" --host $host }
    | tui bind x {|s| _t-do-action $state_path $s "stop" --host $host }
    | tui bind d {|s| _t-do-action $state_path $s "remove_done" --host $host }
    | tui bind shift+d {|s| _t-do-action $state_path $s "confirm_delete" --host $host }
    | tui bind t {|s| _t-do-action $state_path $s "toggle_turtle" --host $host }
    | tui bind p {|s| _t-do-action $state_path $s "preview_info" --host $host }
    | tui bind shift+p {|s| _t-do-action $state_path $s "preview_stats" --host $host }
    | tui bind c {|s| _t-do-action $state_path $s "toggle_cols" --host $host }
    | tui bind "+" {|| { action: submit, selected: { op: "add" } } }
    | tui bind "?" {|| { action: submit, selected: { op: "help" } } }
}

# Process one submit/cancel result from `_t-build-add-form` without unguarded cell-path access on string selections.
@category tui
export def _t-add-step [
    add_res: any         # Result record returned by `_t-build-add-form | tui run`
    queued: list<string> # Previously queued URL/path lines
]: nothing -> record {
    if ($add_res.action? | default "") != "submit" {
        return { done: true, queued: $queued, targets: [] }
    }
    let sel_rec = _tui-as-record $add_res.selected?
    let sub_op = $sel_rec.op? | default ""
    if $sub_op == "queue_line" {
        let line = $sel_rec.target? | default ($add_res.values?.target? | default "") | str trim
        let next_q = if ($line | is-not-empty) {
            $queued | append ($line | lines | str trim | where { |l| $l | is-not-empty })
        } else {
            $queued
        }
        return { done: false, queued: $next_q, targets: [] }
    } else if $sub_op == "paste_clipboard" {
        let typed = $sel_rec.target? | default ($add_res.values?.target? | default "") | str trim
        let clip = _t-read-clipboard | str trim
        mut next_q = $queued
        for src in [$typed $clip] {
            if ($src | is-not-empty) {
                $next_q = ($next_q | append ($src | lines | str trim | where { |l| $l | is-not-empty }))
            }
        }
        return { done: false, queued: $next_q, targets: [] }
    }
    let typed = $add_res.values?.target? | default "" | str trim
    let picked = $sel_rec.path? | default ""
    let chosen = if ($typed | is-not-empty) { $typed } else { $picked }
    let targets = if ($chosen | is-not-empty) { $queued | append $chosen } else { $queued }
    { done: true, queued: $queued, targets: $targets }
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
    let safe_host = _t-validate-host $host

    let state_path = _tui-state-path "t-ui"
    try {
        _t-ui-init-state $state_path | ignore
        # Fail fast if daemon is unreachable before opening the alternate screen
        _t-list-torrents --host $safe_host | ignore

        let dl_dir = try { $env.MY_ENV_VARS.download_dir } catch { "~/Downloads" } | path expand

        with-env { config: (_t-tui-config) } {
            loop {
                let res = (_t-build-ui $state_path --host $safe_host)
                    | tui run --refresh $refresh {|| _t-state-rows $state_path --host $safe_host }

                if $res.action != "submit" {
                    break
                }

                let sel_rec = _tui-as-record $res.selected?
                let op = $sel_rec.op? | default ""
                match $op {
                    "toggle_preview" => {}
                    "confirm_delete" => {
                        let ids = $sel_rec.ids? | default []
                        if ($ids | is-not-empty) {
                            let conf = (_t-build-confirm-ui $ids) | tui run
                            if $conf.action == "submit" and ($conf.selected? == "yes") {
                                _t-remove-delete $ids --host $safe_host
                                _t-ui-select-none $state_path | ignore
                                _tui-state-merge $state_path { status_msg: $"deleted ($ids | length)" } | ignore
                            }
                        }
                    }
                    "add" => {
                        mut queued: list<string> = []
                        loop {
                            let add_res = (_t-build-add-form $dl_dir $queued) | tui run
                            let step = _t-add-step $add_res $queued
                            $queued = $step.queued
                            if not $step.done {
                                continue
                            }
                            if ($step.targets | is-not-empty) {
                                _t-add ($step.targets | str join (char nl)) --host $safe_host
                                _tui-state-merge $state_path { status_msg: $"added ($step.targets | length) target\(s\)" } | ignore
                            }
                            break
                        }
                    }
                    "help" => {
                        (_t-build-help-ui) | tui run | ignore
                    }
                    _ => { break }
                }
            }
        }
    } finally {
        _tui-state-cleanup $state_path
    }
}

# ==============================================================================
# Phase 4: obs tui (Obsidian Vault Browser)
# ==============================================================================

# Resolve the target Obsidian vault directory matching `obs search` / `obs create`.
@category tui
export def _obs-resolve-vault [
    --vault (-v): string # Optional vault name override
]: nothing -> path {
    let mock_vault = $env.MOCK_OBS_VAULT? | default ""
    if ($mock_vault | is-not-empty) {
        return ($mock_vault | path expand)
    }

    let root_fallback = try { $env.MY_ENV_VARS.OBSIDIAN_VAULT_ROOT } catch { "~/obsidian/vaults" } | path expand
    let has_cli = which obsidian | is-not-empty

    if ($vault | is-not-empty) {
        if $has_cli {
            let res = do { run-external obsidian $"vault=($vault)" "vault" "info=path" } | complete
            let cli_path = $res.stdout | lines | first | default "" | str trim
            if $res.exit_code == 0 and ($cli_path | is-not-empty) and ($cli_path | path exists) and (($cli_path | path type) == "dir") {
                return ($cli_path | path expand)
            }
        }
        let candidate = $root_fallback | path join $vault
        if ($candidate | path exists) and (($candidate | path type) == "dir") {
            return ($candidate | path expand)
        }
        let direct = try { $vault | path expand } catch { "" }
        if ($direct | is-not-empty) and ($direct | path exists) and (($direct | path type) == "dir") {
            return $direct
        }
        error make { msg: $"Obsidian vault '($vault)' not found." }
    }

    if $has_cli {
        let res = do { run-external obsidian "vault" "info=path" } | complete
        let cli_path = $res.stdout | lines | first | default "" | str trim
        if $res.exit_code == 0 and ($cli_path | is-not-empty) and ($cli_path | path exists) and (($cli_path | path type) == "dir") {
            return ($cli_path | path expand)
        }
    }

    if not (($root_fallback | path exists) and (($root_fallback | path type) == "dir")) {
        error make { msg: "Default Obsidian vault path could not be resolved." }
    }
    $root_fallback
}

# Check whether a vault-relative path contains any hidden dot-segment (.obsidian, .git, .trash, etc.).
def _obs-is-hidden-rel [rel_path: string]: nothing -> bool {
    if $rel_path == "." {
        return false
    }
    $rel_path | path split | any { |seg| $seg | str starts-with "." }
}

# List all visible directories in an Obsidian vault as sorted relative paths, prepended with ".".
@category tui
export def _obs-folders [
    vault: path # Root directory of the Obsidian vault
]: nothing -> list<string> {
    let root = $vault | path expand
    if not ($root | path exists) {
        return ["."]
    }
    let dirs = glob ($root | path join "**" "*") --no-file
        | where $it != $root
        | each { |d| $d | path relative-to $root }
        | where { |rel| not (_obs-is-hidden-rel $rel) }
        | sort --natural
    $dirs | prepend "."
}

# Build visible tree-table rows for the folder pane from sorted folders and expanded state.
@category tui
export def _obs-tree-rows [
    folders: list<string>  # Sorted folder list starting with "."
    expanded: list<string> # List of currently expanded folder relative paths
]: nothing -> list<record> {
    let folder_set = $folders
    $folders | each { |f|
        let is_root = $f == "."
        let visible = if $is_root {
            true
        } else {
            let parts = $f | path split
            mut ok = "." in $expanded
            mut prefix = ""
            let parent_count = ($parts | length) - 1
            for idx in 0..<$parent_count {
                let seg = $parts | get $idx
                $prefix = if ($prefix | is-empty) { $seg } else { $prefix | path join $seg }
                if not ($prefix in $expanded) {
                    $ok = false
                }
            }
            $ok
        }
        if not $visible {
            null
        } else {
            let has_children = if $is_root {
                $folder_set | any { |other| $other != "." }
            } else {
                let child_prefix = $"($f)(char path_sep)"
                $folder_set | any { |other| $other | str starts-with $child_prefix }
            }
            let is_exp = $f in $expanded
            let depth = if $is_root { 0 } else { ($f | path split | length) }
            let indent = if $depth > 0 { "" | fill --character " " --width ($depth * 2) } else { "" }
            let icon = if $has_children {
                if $is_exp { "▾ " } else { "▸ " }
            } else {
                "  "
            }
            let disp_name = if $is_root { "." } else { $f | path basename }
            {
                Folder: $"($indent)($icon)($disp_name)"
                rel_path: $f
                depth: $depth
                has_children: $has_children
                expanded: $is_exp
            }
        }
    } | compact
}

# Match a trimmed lowercase query against one or more field values using exact substring or fuzzy subsequence.
def _tui-fields-match [
    fields: list<string> # Candidate field values for a row
    query: string        # Normalized lowercase query (already trimmed)
    --fuzzy (-f)         # Use fuzzy character subsequence matching instead of substring
]: nothing -> bool {
    if ($query | is-empty) {
        return true
    }
    $fields | any { |raw|
        let cand = ($raw | into string | str lowercase)
        if $fuzzy {
            _skills-is-subseq $cand $query
        } else {
            $cand | str contains $query
        }
    }
}

# Construct a configured `tui search` widget shared across obs, Habitica, and skills TUIs.
def _tui-search-widget [
    id: string             # Widget id
    cols: list<string>     # Columns to search
    match_mode: string     # "exact" or "fuzzy"
    active_query: string   # Pre-applied search filter query (empty when live)
    --focus                # Focus this search widget on launch
]: nothing -> any {
    let ph = if ($active_query | is-not-empty) {
        $"filter: ($active_query) \(/ reset\)"
    } else {
        "search"
    }
    tui search --id $id --bind / --placeholder $ph --columns $cols --fuzzy=($match_mode == "fuzzy") --focus=$focus
}

# Read and normalize Markdown note content for search indexing (up to 64 KB).
def _obs-read-note-content [note_path: path]: nothing -> string {
    let raw = try { open --raw $note_path } catch { "" }
    let capped = if ($raw | str length) > 65536 { $raw | str substring 0..65536 } else { $raw }
    $capped | str replace --all -r '\s+' ' ' | str trim
}

# Format a list of Markdown file paths into structured note table rows.
def _obs-format-note-rows [
    vault_root: path
    files: list<path>
    use_rel_name: bool
    --with-content
    --time-only
]: nothing -> list<record> {
    if ($files | is-empty) {
        return []
    }
    let rows = $files | each { |f|
        let meta = try { ls -d $f | get 0? } catch { null }
        let mod_dt = $meta.modified? | default (date now)
        let rel = $f | path relative-to $vault_root
        let base = {
            name: (if $use_rel_name { $rel } else { $f | path basename })
            rel_path: $rel
            modified: ($mod_dt | format date "%Y-%m-%d %H:%M")
            modified_ts: ($mod_dt | into int)
            path: $f
        }
        if $with_content {
            $base | upsert content (_obs-read-note-content $f)
        } else {
            $base
        }
    } | sort-by --reverse modified_ts
    if $time_only { $rows } else { $rows | sort-by --natural name }
}

# List direct child Markdown notes inside a single vault folder (non-recursive).
@category tui
export def _obs-notes [
    vault: path    # Root directory of the Obsidian vault
    folder: string # Vault-relative folder path ("." for root)
    --with-content # Include normalized file content column for content search
]: nothing -> list<record> {
    let root = $vault | path expand
    let target_dir = if $folder == "." or ($folder | is-empty) {
        $root
    } else {
        $root | path join $folder
    }
    if not ($target_dir | path exists) {
        return []
    }
    let files = glob ($target_dir | path join "*.md") --no-dir
    _obs-format-note-rows $root $files false --with-content=$with_content --time-only
}

# List all visible Markdown notes across the entire Obsidian vault (for global filter mode).
@category tui
export def _obs-all-notes [
    vault: path    # Root directory of the Obsidian vault
    --with-content # Include normalized file content column for content search
]: nothing -> list<record> {
    let root = $vault | path expand
    if not ($root | path exists) {
        return []
    }
    let files = glob ($root | path join "**" "*.md") --no-dir
        | where { |f| not (_obs-is-hidden-rel ($f | path relative-to $root)) }
    _obs-format-note-rows $root $files true --with-content=$with_content
}

# Filter note rows case-insensitively by filename / relative path (and optionally note content, exact or fuzzy).
@category tui
export def _obs-filter-notes [
    rows: list<record> # Note rows from `_obs-notes` or `_obs-all-notes`
    query: string      # Search query string
    --content (-c)     # Match against note content as well as filename
    --fuzzy (-f)       # Use fuzzy character subsequence matching instead of exact substring
]: nothing -> list<record> {
    let q = $query | str trim | str lowercase
    if ($q | is-empty) {
        return $rows
    }
    $rows | where { |r|
        let fields = if $content {
            let body = $r.content? | default (if ($r.path? | default "" | path exists) { _obs-read-note-content $r.path } else { "" })
            [($r.name? | default "") $body]
        } else {
            [($r.name? | default "")]
        }
        _tui-fields-match $fields $q --fuzzy=$fuzzy
    }
}

# Create a new Markdown note inside the specified vault folder, appending `.md` and refusing overwrites.
@category tui
export def _obs-new-note [
    vault: path    # Root directory of the Obsidian vault
    folder: string # Vault-relative target folder ("." for vault root)
    name: string   # Note name (with or without `.md`)
]: nothing -> path {
    let root = $vault | path expand
    let trimmed = $name | str trim | str trim --char "/"
    if ($trimmed | is-empty) {
        error make { msg: "Note name cannot be empty." }
    }
    if ($trimmed | str contains "..") or (".." in ($folder | path split)) or ($folder | str starts-with "/") {
        error make { msg: $"Invalid note name '($trimmed)': path traversal is not allowed." }
    }
    let file_name = if (($trimmed | str lowercase) | str ends-with ".md") {
        $trimmed
    } else {
        $"($trimmed).md"
    }
    let target_dir = if $folder == "." or ($folder | is-empty) {
        $root
    } else {
        $root | path join $folder
    }
    let resolved_dir = $target_dir | path expand
    let expanded_target = ($resolved_dir | path join $file_name | path expand)
    let root_prefix = $"($root | str trim --right --char (char path_sep))(char path_sep)"
    if not ($expanded_target | str starts-with $root_prefix) {
        error make { msg: $"Invalid note path outside vault: ($expanded_target)" }
    }
    if ($expanded_target | path exists) {
        error make { msg: $"Note already exists: ($expanded_target)" }
    }
    mkdir ($expanded_target | path dirname)
    "" | save --raw $expanded_target
    $expanded_target
}

# Render preview text for an Obsidian note row using glow, bat, or raw fallback.
@category tui
export def _obs-preview-text [
    row: any # Highlighted note row record or null
]: nothing -> string {
    if $row == null {
        return "No note selected."
    }
    let note_path = $row.path? | default ""
    if ($note_path | is-empty) or (not ($note_path | path exists)) {
        return "No note selected."
    }
    let raw = try { open --raw $note_path } catch { "" }
    let snippet = if ($raw | str length) > 16384 {
        $raw | str substring 0..16384
    } else {
        $raw
    }
    if (which glow | is-not-empty) {
        let res = do { $snippet | ^glow -s dark -w 70 - } | complete
        if $res.exit_code == 0 and ($res.stdout | is-not-empty) {
            return $res.stdout
        }
    }
    if (which bat | is-not-empty) {
        let res = do { $snippet | ^bat --color=always --style=plain -l md - } | complete
        if $res.exit_code == 0 {
            return $res.stdout
        }
    }
    $snippet | ansi strip
}

# Choose interactive editor command for `obs tui` ("ttt" preferred, fallback "ox").
@category tui
export def _obs-editor-cmd [
    --has-ttt: oneof<bool, nothing> # Optional override for ttt availability (for testing)
]: nothing -> string {
    let ttt_ok = $has_ttt | default (which ttt | is-not-empty)
    if $ttt_ok { "ttt" } else { "ox" }
}

# Open a note in the preferred interactive editor (`ttt`, falling back to `ox`).
def _obs-run-editor [note_path: path]: nothing -> nothing {
    match (_obs-editor-cmd) {
        "ttt" => { ^ttt $note_path }
        _ => { ^ox $note_path }
    }
}

# Initialize and persist the default `obs tui` state record.
@category tui
export def _obs-ui-init-state [
    state_path: path # Path to NUON state file
]: nothing -> record {
    _tui-state-set $state_path {
        expanded: ["."]
        global: false
        content_search: false
        match_mode: "exact"
        search_query: ""
        focus_target: "folders"
        status_msg: ""
    }
}

# Toggle expand/collapse state of a folder in `obs tui`.
@category tui
export def _obs-ui-toggle-expand [
    state_path: path # Path to NUON state file
    folder: string   # Vault-relative folder path
    --mode: string = "toggle" # "toggle", "expand", or "collapse"
]: nothing -> record {
    let cur = _tui-state-get $state_path { expanded: ["."] }
    let exp = $cur.expanded? | default ["."]
    let next_exp = match $mode {
        "expand" => { if ($folder in $exp) { $exp } else { $exp | append $folder } }
        "collapse" => { if $folder == "." { $exp } else { $exp | where $it != $folder } }
        _ => {
            if ($folder in $exp) {
                if $folder == "." { $exp } else { $exp | where $it != $folder }
            } else {
                $exp | append $folder
            }
        }
    }
    _tui-state-merge $state_path { expanded: $next_exp }
}

# Toggle global filename filter mode in `obs tui`.
@category tui
export def _obs-ui-toggle-global [
    state_path: path # Path to NUON state file
]: nothing -> record {
    let cur = _tui-state-get $state_path { global: false }
    _tui-state-merge $state_path { global: (not ($cur.global? | default false)) }
}

# Toggle content search mode for `obs tui` note filtering (`Shift+G`).
@category tui
export def _obs-ui-toggle-content [
    state_path: path # Path to NUON state file
]: nothing -> record {
    let cur = _tui-state-get $state_path { content_search: false }
    _tui-state-merge $state_path { content_search: (not ($cur.content_search? | default false)) }
}

# Toggle `obs tui` search match mode between "fuzzy" and "exact" substring matching (`m`).
@category tui
export def _obs-ui-toggle-match [
    state_path: path # Path to NUON state file
]: nothing -> record {
    let cur = _tui-state-get $state_path { match_mode: "exact" }
    let next = if ($cur.match_mode? | default "exact") == "fuzzy" { "exact" } else { "fuzzy" }
    _tui-state-merge $state_path { match_mode: $next }
}

# Build current folder tree rows from vault filesystem and state.
def _obs-state-tree-rows [
    vault: path
    state_path: path
]: nothing -> list<record> {
    let st = _tui-state-get $state_path { expanded: ["."] }
    let folders = _obs-folders $vault
    _obs-tree-rows $folders ($st.expanded? | default ["."])
}

# Build new-note creation form for the active vault folder.
@category tui
export def _obs-build-new-note-form [
    folder: string # Target vault-relative folder
]: nothing -> any {
    tui label --titlebar $"New Note in ($folder)"
    | tui textbox --id note_name --placeholder "Note name (.md appended automatically)" --focus
    | tui button "Create" { |s| { action: submit, selected: ($s.values.note_name? | default "") } }
    | tui button "Cancel" { || { action: quit } }
    | tui label --status "enter: create  esc: cancel"
}

# Build confirmation dialog asking whether to open a newly created note in the editor.
@category tui
export def _obs-build-confirm-edit-ui [
    note_path: path # Newly created note file path
]: nothing -> any {
    let ed = _obs-editor-cmd
    tui label --titlebar "Note Created"
    | tui label $"Created ($note_path | path basename). Open in ($ed) now?"
    | tui button $"Yes \(Open in ($ed)\)" { || { action: submit, selected: "yes" } }
    | tui button "No" { || { action: quit } }
    | tui label --status $"enter: open in ($ed)  esc/q: back to browser"
}

# Build `obs tui` keybindings help screen.
@category tui
export def _obs-build-help-ui []: nothing -> any {
    [
        { Key: "up / down" Action: "Navigate folders or notes" }
        { Key: "tab" Action: "Switch focus between Folders, Notes, and buttons" }
        { Key: "enter (on Folders)" Action: "Expand / collapse folder" }
        { Key: "enter (on Notes) / e" Action: "Edit highlighted note in ttt (or ox fallback)" }
        { Key: "/" Action: "Filter notes (Enter with query moves cursor to Notes; / resets)" }
        { Key: "ctrl+u" Action: "Clear active search filter" }
        { Key: "g" Action: "Toggle global filter across entire vault" }
        { Key: "Shift+G" Action: "Toggle note content search (search inside .md files)" }
        { Key: "m" Action: "Toggle search match mode (exact substring vs fuzzy)" }
        { Key: "n" Action: "Create a new note in the current folder" }
        { Key: "r" Action: "Refresh folders and notes from disk" }
        { Key: "q / esc" Action: "Quit" }
    ]
    | tui label --titlebar "Obsidian TUI Help"
    | tui table
    | tui button "Back" { || { action: quit } }
    | tui label --status "enter/q/esc: back to vault"
}

# Resolve highlighted folder path and note path from TUI state.
def _obs-extract-selection [ui_state: record]: nothing -> record<folder: string, note_path: string> {
    let folder = $ui_state.values?.folders?.row?.rel_path? | default "."
    let note_path = $ui_state.values?.notes?.row?.path? | default ""
    { folder: $folder, note_path: $note_path }
}

# Build the main `obs tui` three-pane interactive pipeline (exposed for `tui debug` testing).
@category tui
export def _obs-build-ui [
    vault: path      # Resolved vault directory path
    state_path: path # Path to NUON state file
]: nothing -> any {
    let initial_tree = _obs-state-tree-rows $vault $state_path
    let st_init = _tui-state-get $state_path { global: false, content_search: false, match_mode: "exact", search_query: "", focus_target: "folders" }
    let content_on = $st_init.content_search? | default false
    let match_mode = $st_init.match_mode? | default "exact"
    let search_query = $st_init.search_query? | default ""
    let focus_target = $st_init.focus_target? | default "folders"
    let search_cols = if $content_on { [name content] } else { [name] }
    let search_widget = _tui-search-widget "search_notes" $search_cols $match_mode $search_query --focus=($focus_target == "search")

    let legend = _tui-key-help [
        { key: "enter" label: "expand/edit" }
        { key: "/" label: "filter" }
        { key: "g" label: "global" }
        { key: "G" label: "content" }
        { key: "m" label: "match" }
        { key: "n" label: "new" }
        { key: "e" label: "edit" }
        { key: "r" label: "refresh" }
        { key: "?" label: "help" }
        { key: "q" label: "quit" }
    ]

    $initial_tree
    | tui label --titlebar $"Obsidian Vault \(($vault | path basename)\)"
    | tui split --sizes [22% 36% 1fr] [
        (tui table --id folders --title "Folders" --columns [Folder] --focus=($focus_target == "folders"))
        (tui box "Notes" [
            $search_widget
            (tui table --id notes --title "Notes" --from folders --columns [name modified] --focus=($focus_target == "notes") { |folder_row|
                let st = _tui-state-get $state_path { global: false, content_search: false, match_mode: "exact", search_query: "" }
                let with_c = $st.content_search? | default false
                let sq = $st.search_query? | default ""
                let is_fuzzy = ($st.match_mode? | default "exact") == "fuzzy"
                let rows = if ($st.global? | default false) {
                    _obs-all-notes $vault --with-content=$with_c
                } else {
                    _obs-notes $vault ($folder_row.rel_path? | default ".") --with-content=$with_c
                }
                if ($sq | is-not-empty) {
                    _obs-filter-notes $rows $sq --content=$with_c --fuzzy=$is_fuzzy
                } else {
                    $rows
                }
            })
        ])
        (tui preview --from notes { |row| _obs-preview-text $row })
    ]
    | tui button --id btn_edit "Edit (e)" { |s|
        let sel = _obs-extract-selection $s
        if ($sel.note_path | is-empty) {
            _tui-state-merge $state_path { status_msg: "no note selected" } | ignore
            _obs-state-tree-rows $vault $state_path
        } else {
            { action: submit, selected: { op: "edit", path: $sel.note_path } }
        }
    }
    | tui button --id btn_new "New (n)" { |s|
        let sel = _obs-extract-selection $s
        { action: submit, selected: { op: "new_note", folder: $sel.folder } }
    }
    | tui button --id btn_global "Global (g)" { |_|
        _obs-ui-toggle-global $state_path | ignore
        _obs-state-tree-rows $vault $state_path
    }
    | tui button --id btn_content "Content (G)" { |_|
        _obs-ui-toggle-content $state_path | ignore
        { action: submit, selected: { op: "toggle_content" } }
    }
    | tui button --id btn_match "Match (m)" { |_|
        _obs-ui-toggle-match $state_path | ignore
        { action: submit, selected: { op: "toggle_match" } }
    }
    | tui button --id btn_refresh "Refresh (r)" { |_|
        _tui-state-merge $state_path { status_msg: "refreshed" } | ignore
        _obs-state-tree-rows $vault $state_path
    }
    | tui button --id btn_help "Help (?)" { |_|
        { action: submit, selected: { op: "help" } }
    }
    | tui button --id btn_quit "Quit (q)" { |_| { action: quit } }
    | tui label --status { |st|
        let disk_st = _tui-state-get $state_path { global: false, content_search: false, match_mode: "exact", search_query: "", status_msg: "" }
        let cur_folder = $st.values?.folders?.row?.rel_path? | default "."
        let glob_txt = if ($disk_st.global? | default false) { "ON" } else { "off" }
        let cnt_txt = if ($disk_st.content_search? | default false) { "ON" } else { "off" }
        let mm_txt = $disk_st.match_mode? | default "exact"
        let sq = $disk_st.search_query? | default ""
        let sq_txt = if ($sq | is-not-empty) { $" · filter:($sq)" } else { "" }
        let msg = if ($disk_st.status_msg? | default "" | is-not-empty) { $" · ($disk_st.status_msg)" } else { "" }
        $"folder:($cur_folder) · global:($glob_txt) · content:($cnt_txt) · match:($mm_txt)($sq_txt)($msg) · ($legend)"
    }
    | tui bind enter { |s|
        match ($s.focused? | default "") {
            "folders" => {
                let folder = $s.values?.folders?.row?.rel_path? | default "."
                _obs-ui-toggle-expand $state_path $folder | ignore
                _obs-state-tree-rows $vault $state_path
            }
            "notes" | "btn_edit" => {
                let sel = _obs-extract-selection $s
                if ($sel.note_path | is-empty) {
                    _tui-state-merge $state_path { status_msg: "no note selected" } | ignore
                    _obs-state-tree-rows $vault $state_path
                } else {
                    { action: submit, selected: { op: "edit", path: $sel.note_path } }
                }
            }
            "btn_new" => {
                let sel = _obs-extract-selection $s
                { action: submit, selected: { op: "new_note", folder: $sel.folder } }
            }
            "btn_global" => {
                _obs-ui-toggle-global $state_path | ignore
                _obs-state-tree-rows $vault $state_path
            }
            "btn_content" => {
                _obs-ui-toggle-content $state_path | ignore
                { action: submit, selected: { op: "toggle_content" } }
            }
            "btn_match" => {
                _obs-ui-toggle-match $state_path | ignore
                { action: submit, selected: { op: "toggle_match" } }
            }
            "btn_refresh" => {
                _tui-state-merge $state_path { status_msg: "refreshed" } | ignore
                _obs-state-tree-rows $vault $state_path
            }
            "btn_help" => { { action: submit, selected: { op: "help" } } }
            "btn_quit" => { { action: quit } }
            _ => { null }
        }
    }
    | tui bind e { |s|
        let sel = _obs-extract-selection $s
        if ($sel.note_path | is-empty) {
            _tui-state-merge $state_path { status_msg: "no note selected" } | ignore
            _obs-state-tree-rows $vault $state_path
        } else {
            { action: submit, selected: { op: "edit", path: $sel.note_path } }
        }
    }
    | tui bind n { |s|
        let sel = _obs-extract-selection $s
        { action: submit, selected: { op: "new_note", folder: $sel.folder } }
    }
    | tui bind g { |_|
        _obs-ui-toggle-global $state_path | ignore
        _obs-state-tree-rows $vault $state_path
    }
    | tui bind shift+g { |_|
        _obs-ui-toggle-content $state_path | ignore
        { action: submit, selected: { op: "toggle_content" } }
    }
    | tui bind m { |_|
        _obs-ui-toggle-match $state_path | ignore
        { action: submit, selected: { op: "toggle_match" } }
    }
    | tui bind r { |_|
        _tui-state-merge $state_path { status_msg: "refreshed" } | ignore
        _obs-state-tree-rows $vault $state_path
    }
    | tui bind "?" { |_| { action: submit, selected: { op: "help" } } }
    | if ($search_query | is-not-empty) {
        tui bind "/" { |_|
            _tui-state-merge $state_path { search_query: "", focus_target: "search", status_msg: "" } | ignore
            { action: submit, selected: { op: "focus_search" } }
        }
        | tui bind ctrl+u { |_|
            _tui-state-merge $state_path { search_query: "", focus_target: "notes", status_msg: "" } | ignore
            { action: submit, selected: { op: "clear_search" } }
        }
    } else { }
}

# Interactive three-pane Obsidian vault browser (folder tree, notes table, Markdown preview).
@category tui
@example "Browse the default Obsidian vault" { obs tui }
@example "Browse a specific Obsidian vault by name" { obs tui --vault "Work" }
export def "obs tui" [
    --vault (-v): string               # Optional Obsidian vault name
    --stdin-tty: oneof<bool, nothing>  # Optional override for stdin TTY status (for testing)
    --stdout-tty: oneof<bool, nothing> # Optional override for stdout TTY status (for testing)
]: nothing -> nothing {
    _tui-require-tty --stdin-tty=$stdin_tty --stdout-tty=$stdout_tty
    let vault_path = _obs-resolve-vault --vault $vault
    let state_path = _tui-state-path "obs-tui"

    try {
        _obs-ui-init-state $state_path | ignore
        loop {
            let res = (_obs-build-ui $vault_path $state_path) | tui run
            if $res.action != "submit" {
                break
            }
            let sel_rec = _tui-as-record $res.selected?
            let op = $sel_rec.op? | default ""
            if ($res.focused? == "search_notes") and ($op | is-empty) {
                let q = $res.values?.search_notes? | default "" | str trim
                if ($q | is-not-empty) {
                    _tui-state-merge $state_path { search_query: $q, focus_target: "notes", status_msg: $"filter: ($q)" } | ignore
                } else {
                    _tui-state-merge $state_path { focus_target: "notes" } | ignore
                }
                continue
            }
            match $op {
                "edit" => {
                    let note_path = $sel_rec.path? | default ""
                    if ($note_path | is-not-empty) and ($note_path | path exists) {
                        _obs-run-editor $note_path
                        _tui-state-merge $state_path { status_msg: $"edited ($note_path | path basename)" } | ignore
                    }
                }
                "new_note" => {
                    let folder = $sel_rec.folder? | default "."
                    let form_res = (_obs-build-new-note-form $folder) | tui run
                    if $form_res.action == "submit" {
                        let raw_name = $form_res.values?.note_name? | default ""
                        let created_res = try {
                            { ok: true, path: (_obs-new-note $vault_path $folder $raw_name) }
                        } catch { |e|
                            { ok: false, err: $e.msg }
                        }
                        if $created_res.ok {
                            let new_path = $created_res.path
                            _tui-state-merge $state_path { status_msg: $"created ($new_path | path basename)" } | ignore
                            let conf = (_obs-build-confirm-edit-ui $new_path) | tui run
                            if $conf.action == "submit" and ($conf.selected? == "yes") {
                                _obs-run-editor $new_path
                            }
                        } else {
                            _tui-state-merge $state_path { status_msg: $created_res.err } | ignore
                        }
                    }
                }
                "toggle_content" | "toggle_match" | "focus_search" | "clear_search" => { }
                "help" => {
                    (_obs-build-help-ui) | tui run | ignore
                }
                _ => { break }
            }
        }
    } finally {
        _tui-state-cleanup $state_path
    }
}

# ==============================================================================
# Phase 5: h tui / htui (Habitica)
# ==============================================================================

# Return sortable column list for a Habitica task type.
def _h-tui-sort-columns [task_type: string, --hide-extra]: nothing -> list<string> {
    let cols = match $task_type {
        "todos" => ["text" "tags" "due" "checklist"]
        "habits" => ["text" "tags" "dir" "counter"]
        "dailys" => ["text" "tags" "frequency" "due_today" "completed" "streak"]
        _ => ["text"]
    }
    if $hide_extra {
        $cols | where { |c| $c not-in ["tags" "due" "due_today"] }
    } else {
        $cols
    }
}

# Return visible columns for a Habitica task type based on `hide_extra_cols`.
@category tui
export def _h-tui-visible-cols [
    task_type: string # "todos", "habits", or "dailys"
    st: record        # `h tui` state record
]: nothing -> list<string> {
    _h-tui-sort-columns $task_type --hide-extra=($st.hide_extra_cols? | default false)
}

# Resolve Habitica tag UUIDs into a comma-separated tag label string.
def _h-tui-tag-labels [tag_ids: list<any>, tags_map: record]: nothing -> string {
    if ($tag_ids | is-empty) {
        return ""
    }
    $tag_ids
    | each { |tid| $tags_map | get -o ($tid | into string) | default ($tid | into string) }
    | str join ", "
}

# Fetch tag ID -> name mapping via Habitica API.
def _h-tui-fetch-tags []: nothing -> record {
    try {
        _h-request "GET" "/api/v3/tags"
        | get data
        | reduce -f {} { |tag, acc| $acc | insert $tag.id $tag.name }
    } catch {
        {}
    }
}

# Fetch raw Habitica tasks for the given type via `_h-request`.
def _h-tui-fetch-raw [task_type: string]: nothing -> list<any> {
    _h-request "GET" "/api/v3/tasks/user" --params { type: $task_type }
    | get -o data
    | default []
}

# Shape raw Habitica task records into type-appropriate display table rows.
@category tui
export def _h-tui-rows [
    task_type: string    # "todos", "habits", or "dailys"
    raw_tasks: list<any> # Raw task records from Habitica API
    tags_map: record     # Tag UUID -> label map
]: nothing -> list<record> {
    if ($raw_tasks | is-empty) {
        return []
    }
    match $task_type {
        "todos" => {
            $raw_tasks | each { |t|
                let raw_due = $t.date? | default ""
                let due = if ($raw_due | is-not-empty) {
                    try { $raw_due | into datetime | format date "%Y-%m-%d" } catch { ($raw_due | into string | str substring 0..10) }
                } else {
                    ""
                }
                let cl = $t.checklist? | default []
                let cl_str = if ($cl | is-empty) {
                    ""
                } else {
                    let done_n = $cl | where { |item| $item.completed? | default false } | length
                    $"($done_n)/($cl | length)"
                }
                {
                    text: ($t.text? | default "")
                    tags: (_h-tui-tag-labels ($t.tags? | default []) $tags_map)
                    due: $due
                    checklist: $cl_str
                }
            }
        }
        "habits" => {
            $raw_tasks | each { |t|
                let can_up = $t.up? | default false
                let can_down = $t.down? | default false
                let dir_str = match [$can_up $can_down] {
                    [true true] => "+/−"
                    [true false] => "+"
                    [false true] => "−"
                    _ => ""
                }
                let cu = $t.counterUp? | default 0
                let cd = $t.counterDown? | default 0
                {
                    text: ($t.text? | default "")
                    tags: (_h-tui-tag-labels ($t.tags? | default []) $tags_map)
                    dir: $dir_str
                    counter: $"+($cu) / -($cd)"
                }
            }
        }
        "dailys" => {
            $raw_tasks | each { |t|
                let is_due = ($t.isDue? | default false) | into bool
                let is_done = ($t.completed? | default false) | into bool
                {
                    text: ($t.text? | default "")
                    tags: (_h-tui-tag-labels ($t.tags? | default []) $tags_map)
                    frequency: ($t.frequency? | default "daily")
                    due_today: (if $is_due { "yes" } else { "no" })
                    completed: (if $is_done { "✓" } else { " " })
                    streak: (($t.streak? | default 0) | into int)
                }
            }
        }
        _ => { [] }
    }
}

# Sort raw Habitica tasks by a display column using natural/numeric sort keys.
@category tui
export def _h-tui-sort-raw [
    task_type: string    # "todos", "habits", or "dailys"
    raw_tasks: list<any> # Raw task records
    tags_map: record     # Tag UUID -> label map
    column: string       # Active sort column name
    --reverse (-r)       # Sort descending
]: nothing -> list<any> {
    if ($raw_tasks | is-empty) {
        return []
    }
    let keyed = $raw_tasks | each { |t|
        let key_val = match $column {
            "text" => ($t.text? | default "")
            "tags" => (_h-tui-tag-labels ($t.tags? | default []) $tags_map)
            "due" => {
                let d = $t.date? | default ""
                if ($d | is-not-empty) { $d | into string } else { "9999-12-31" }
            }
            "checklist" => ($t.checklist? | default [] | length)
            "dir" => $"($t.up? | default false)-($t.down? | default false)"
            "counter" => (($t.counterUp? | default 0) - ($t.counterDown? | default 0))
            "frequency" => ($t.frequency? | default "")
            "due_today" => (if ($t.isDue? | default false) { 0 } else { 1 })
            "completed" => (if ($t.completed? | default false) { 0 } else { 1 })
            "streak" => (($t.streak? | default 0) | into int)
            _ => ($t.text? | default "")
        }
        $t | upsert _tui_sk $key_val
    }
    let sorted = $keyed | sort-by --natural _tui_sk | reject _tui_sk
    if $reverse { $sorted | reverse } else { $sorted }
}

# Initialize and persist the default `h tui` state record.
@category tui
export def _h-tui-init-state [
    state_path: path # Path to NUON state file
]: nothing -> record {
    _tui-state-set $state_path {
        active_type: "todos"
        tags_map: null
        cache: { todos: null, habits: null, dailys: null }
        sort: {
            todos: { col: "text", reverse: false }
            habits: { col: "text", reverse: false }
            dailys: { col: "frequency", reverse: false }
        }
        preview: "off"
        hide_extra_cols: false
        content_search: false
        match_mode: "exact"
        search_query: ""
        focus_target: "tasks"
        stats_text: null
        status_msg: ""
    }
}

# Toggle content search mode (search task notes and checklist items) in `h tui`.
@category tui
export def _h-tui-toggle-content [
    state_path: path # Path to NUON state file
]: nothing -> record {
    let cur = _tui-state-get $state_path { content_search: false }
    _tui-state-merge $state_path { content_search: (not ($cur.content_search? | default false)) }
}

# Toggle `h tui` search match mode between "exact" substring and "fuzzy" matching.
@category tui
export def _h-tui-toggle-match [
    state_path: path # Path to NUON state file
]: nothing -> record {
    let cur = _tui-state-get $state_path { match_mode: "exact" }
    let next = if ($cur.match_mode? | default "exact") == "fuzzy" { "exact" } else { "fuzzy" }
    _tui-state-merge $state_path { match_mode: $next }
}

# Return search columns for `h tui` active type, adding hidden `content` when content search is enabled.
def _h-tui-search-cols [task_type: string, st: record]: nothing -> list<string> {
    let vis = _h-tui-visible-cols $task_type $st
    if ($st.content_search? | default false) {
        $vis | append "content"
    } else {
        $vis
    }
}

# Toggle or switch `h tui` right preview pane mode ("off" <-> "detail" <-> "stats").
@category tui
export def _h-tui-toggle-preview [
    state_path: path    # Path to NUON state file
    target_mode: string # Desired preview mode ("detail" or "stats")
]: nothing -> record<preview: string, relaunch: bool> {
    let cur = _tui-state-get $state_path { preview: "off" }
    let cur_mode = $cur.preview? | default "off"
    let next_mode = if $cur_mode == $target_mode { "off" } else { $target_mode }
    let patch = if $next_mode == "stats" {
        { preview: $next_mode, stats_text: null }
    } else {
        { preview: $next_mode }
    }
    _tui-state-merge $state_path $patch | ignore
    { preview: $next_mode, relaunch: true }
}

# Toggle visibility of `tags`, `due`, and `due_today` columns in `h tui` and reset hidden sort columns.
@category tui
export def _h-tui-toggle-cols [
    state_path: path # Path to NUON state file
]: nothing -> record {
    let cur = _tui-state-get $state_path { sort: {}, hide_extra_cols: false }
    let hide = not ($cur.hide_extra_cols? | default false)
    let hidden_set = ["tags" "due" "due_today"]
    let cur_sort = $cur.sort? | default {}
    let next_sort = if $hide {
        $cur_sort | transpose k v | reduce -f {} { |it, acc|
            let s_rec = if ($it.v.col? | default "text") in $hidden_set {
                { col: "text", reverse: false }
            } else {
                $it.v
            }
            $acc | insert $it.k $s_rec
        }
    } else {
        $cur_sort
    }
    _tui-state-merge $state_path { hide_extra_cols: $hide, sort: $next_sort }
}

# Switch the active Habitica task type in state.
@category tui
export def _h-tui-set-type [
    state_path: path  # Path to NUON state file
    task_type: string # "todos", "habits", or "dailys"
]: nothing -> record {
    _tui-state-merge $state_path { active_type: $task_type, status_msg: "" }
}

# Explicitly set the sort column and direction for a Habitica task type.
@category tui
export def _h-tui-set-sort [
    state_path: path  # Path to NUON state file
    task_type: string # "todos", "habits", or "dailys"
    column: string    # Sort column name
    --reverse (-r)    # Sort descending
]: nothing -> record {
    let cur = _tui-state-get $state_path { sort: {} }
    let next_sort = ($cur.sort? | default {}) | upsert $task_type { col: $column, reverse: $reverse }
    _tui-state-merge $state_path { sort: $next_sort }
}

# Cycle the sort column for the currently active Habitica task type.
@category tui
export def _h-tui-cycle-sort [
    state_path: path # Path to NUON state file
]: nothing -> record {
    let cur = _tui-state-get $state_path { active_type: "todos", sort: {}, hide_extra_cols: false }
    let active = $cur.active_type? | default "todos"
    let cols = _h-tui-visible-cols $active $cur
    let cur_s = ($cur.sort? | default {} | get -o $active) | default { col: ($cols | first), reverse: false }
    let next = _tui-cycle-sort $cols $cur_s.col $cur_s.reverse
    let next_sort = ($cur.sort? | default {}) | upsert $active { col: $next.column, reverse: $next.reverse }
    _tui-state-merge $state_path { sort: $next_sort }
}

# Reverse sort direction for the currently active Habitica task type.
@category tui
export def _h-tui-flip-sort [
    state_path: path # Path to NUON state file
]: nothing -> record {
    let cur = _tui-state-get $state_path { active_type: "todos", sort: {}, hide_extra_cols: false }
    let active = $cur.active_type? | default "todos"
    let cols = _h-tui-visible-cols $active $cur
    let cur_s = ($cur.sort? | default {} | get -o $active) | default { col: ($cols | first), reverse: false }
    let next_sort = ($cur.sort? | default {}) | upsert $active { col: $cur_s.col, reverse: (not $cur_s.reverse) }
    _tui-state-merge $state_path { sort: $next_sort }
}

# Ensure tags and tasks for the active type are loaded in session cache.
export def _h-tui-ensure-loaded [
    state_path: path # Path to NUON state file
    --force          # Bypass session cache and re-fetch from API
]: nothing -> record {
    let cur = _tui-state-get $state_path {
        active_type: "todos"
        tags_map: null
        cache: { todos: null, habits: null, dailys: null }
    }
    let active = $cur.active_type? | default "todos"
    let tags_map = if ($cur.tags_map? == null) or $force {
        _h-tui-fetch-tags
    } else {
        $cur.tags_map
    }
    let cached_list = $cur.cache? | default {} | get -o $active
    let next_cache = if ($cached_list == null) or $force {
        let fetched = _h-tui-fetch-raw $active
        ($cur.cache? | default {}) | upsert $active $fetched
    } else {
        $cur.cache
    }
    _tui-state-merge $state_path { tags_map: $tags_map, cache: $next_cache }
}

# Produce sorted display rows for the currently active Habitica task type.
export def _h-tui-state-rows [
    state_path: path # Path to NUON state file
    --force          # Bypass session cache and re-fetch
]: nothing -> list<record> {
    let st = _h-tui-ensure-loaded $state_path --force=$force
    let active = $st.active_type? | default "todos"
    let tags_map = $st.tags_map? | default {}
    let raw_tasks = ($st.cache? | default {} | get -o $active) | default []
    let cols = _h-tui-visible-cols $active $st
    let s = ($st.sort? | default {} | get -o $active) | default { col: ($cols | first), reverse: false }
    let sorted = _h-tui-sort-raw $active $raw_tasks $tags_map $s.col --reverse=$s.reverse
    let base_rows = _h-tui-rows $active $sorted $tags_map
    let with_content = if ($st.content_search? | default false) and ($base_rows | is-not-empty) {
        $base_rows | enumerate | each { |it|
            let raw = $sorted | get $it.index
            let cl_txt = ($raw.checklist? | default [] | each { |c| $c.text? | default "" } | str join " ")
            let body = $"($raw.notes? | default '') ($cl_txt)" | str replace --all -r '\s+' ' ' | str trim
            $it.item | upsert content $body
        }
    } else {
        $base_rows
    }
    let shaped = if ($st.hide_extra_cols? | default false) and ($with_content | is-not-empty) {
        $with_content | reject -o tags due due_today
    } else {
        $with_content
    }
    let sq = $st.search_query? | default "" | str trim | str lowercase
    if ($sq | is-not-empty) and ($shaped | is-not-empty) {
        let scols = _h-tui-search-cols $active $st
        let is_fuzzy = ($st.match_mode? | default "exact") == "fuzzy"
        $shaped | where { |r|
            let fields = $scols | each { |c| $r | get -o $c | default "" | into string }
            _tui-fields-match $fields $sq --fuzzy=$is_fuzzy
        }
    } else {
        $shaped
    }
}

# Find the raw Habitica task record matching a highlighted display row.
def _h-tui-find-raw [state_path: path, ui_row: any]: nothing -> any {
    let row_rec = _tui-as-record $ui_row
    let target_text = $row_rec.text? | default ""
    if ($target_text | is-empty) {
        return null
    }
    let st = _tui-state-get $state_path { active_type: "todos", cache: {} }
    let active = $st.active_type? | default "todos"
    let raw_tasks = ($st.cache? | default {} | get -o $active) | default []
    $raw_tasks | where { |t| ($t.text? | default "") == $target_text } | get 0?
}

# Format right-hand detail pane (notes and checklist) for the highlighted Habitica task.
@category tui
export def _h-tui-detail-text [
    state_path: path # Path to NUON state file
    ui_row: any      # Highlighted row record from tasks table
]: nothing -> string {
    let raw = _h-tui-find-raw $state_path $ui_row
    if $raw == null {
        return "No task selected."
    }
    let st = _tui-state-get $state_path { active_type: "todos", tags_map: {} }
    let active = $st.active_type? | default "todos"
    let tags_map = $st.tags_map? | default {}
    let tag_str = _h-tui-tag-labels ($raw.tags? | default []) $tags_map

    mut lines = [
        $"TASK: ($raw.text? | default '')"
        $"  Type: ($active)"
        $"  ID: ($raw._id? | default '')"
        $"  Tags: (if ($tag_str | is-empty) { '-' } else { $tag_str })"
    ]
    if $active == "todos" {
        let due = $raw.date? | default ""
        $lines = ($lines | append $"  Due: (if ($due | is-empty) { '-' } else { $due | into string | str substring 0..10 })")
    } else if $active == "dailys" {
        $lines = ($lines | append $"  Frequency: ($raw.frequency? | default 'daily') · Streak: ($raw.streak? | default 0)")
    } else if $active == "habits" {
        $lines = ($lines | append $"  Up: ($raw.up? | default false) · Down: ($raw.down? | default false) · +($raw.counterUp? | default 0)/-($raw.counterDown? | default 0)")
    }

    let notes = $raw.notes? | default "" | str trim
    $lines = ($lines | append "" | append "NOTES:" | append (if ($notes | is-empty) { "  \(none\)" } else { $"  ($notes)" }))

    let cl = $raw.checklist? | default []
    if ($cl | is-not-empty) {
        $lines = ($lines | append "" | append "CHECKLIST:")
        for item in $cl {
            let mark = if ($item.completed? | default false) { "[x]" } else { "[ ]" }
            $lines = ($lines | append $"  ($mark) ($item.text? | default '')")
        }
    }
    $lines | str join (char nl)
}

# Render Habitica character stats (`h stats -s` / `--no-avatar`) formatted for the preview pane.
@category tui
export def _h-tui-stats-text [
    state_path: path # Path to NUON state file
]: nothing -> string {
    let st = _tui-state-get $state_path { stats_text: null }
    let cached = $st.stats_text?
    if ($cached != null) and ($cached | is-not-empty) {
        return $cached
    }
    let term_cols = try { (term size).columns } catch { 120 }
    let pane_cols = (($term_cols * 0.44) | math floor)
    try {
        let raw = if $pane_cols >= 74 {
            with-env { MOCK_TERM_COLUMNS: 90 } { h stats -s }
        } else {
            h stats --no-avatar
        }
        let esc = (char -u '1b')
        let cleaned = $raw
            | str replace --all $"($esc)[?25l" ""
            | str replace --all $"($esc)[?25h" ""
        _tui-state-merge $state_path { stats_text: $cleaned } | ignore
        $cleaned
    } catch { |e|
        $"Unable to load Habitica stats: ($e.msg)"
    }
}

# Select right preview pane content for `h tui` ("detail" vs "stats").
export def _h-tui-preview-text [
    state_path: path # Path to NUON state file
    ui_row: any      # Highlighted row record from tasks table
]: nothing -> string {
    let st = _tui-state-get $state_path { preview: "off" }
    if ($st.preview? | default "off") == "stats" {
        _h-tui-stats-text $state_path
    } else {
        _h-tui-detail-text $state_path $ui_row
    }
}

# Validate and normalize `h tui` add-form fields for todos, dailys, or habits.
@category tui
export def _h-tui-validate-add [
    task_type: string # "todos", "dailys", or "habits"
    fields: record    # Raw string field values from form
]: nothing -> record {
    let text = $fields.text? | default "" | str trim
    if ($text | is-empty) {
        error make { msg: "Task text is required." }
    }
    let notes = $fields.notes? | default "" | str trim

    let prio_raw = $fields.priority? | default "" | str trim
    let priority = if ($prio_raw | is-empty) {
        1.0
    } else if $prio_raw in ["1" "1.0" "1.5" "2" "2.0" "2.5"] {
        $prio_raw | into float
    } else {
        error make { msg: $"Invalid priority '($prio_raw)'. Allowed: 1, 1.5, 2, 2.5." }
    }

    let tags_raw = $fields.tags? | default "" | str trim
    let tags = if ($tags_raw | is-empty) {
        []
    } else {
        $tags_raw | split row "," | str trim | where { |x| $x | is-not-empty }
    }

    match $task_type {
        "todos" => {
            let due_raw = $fields.due? | default "" | str trim
            if ($due_raw | is-not-empty) {
                if $due_raw !~ '^\d{4}-\d{2}-\d{2}$' {
                    error make { msg: $"Invalid due date '($due_raw)'. Expected YYYY-MM-DD." }
                }
                let parsed = try { $due_raw | into datetime --format "%Y-%m-%d"; true } catch { false }
                if not $parsed {
                    error make { msg: $"Invalid due calendar date '($due_raw)'. Expected YYYY-MM-DD." }
                }
            }
            let cl_raw = $fields.checklist? | default "" | str trim
            let checklist = if ($cl_raw | is-empty) {
                []
            } else {
                $cl_raw | split row ";" | str trim | where { |x| $x | is-not-empty }
            }
            {
                text: $text
                notes: $notes
                priority: $priority
                due: $due_raw
                checklist: $checklist
                tags: $tags
            }
        }
        "dailys" => {
            let freq_raw = $fields.frequency? | default "daily" | str trim | str lowercase
            let frequency = if ($freq_raw | is-empty) { "daily" } else { $freq_raw }
            if $frequency not-in ["daily" "weekly" "monthly" "yearly"] {
                error make { msg: $"Invalid frequency '($frequency)'. Allowed: daily, weekly, monthly, yearly." }
            }
            let ex_raw = $fields.every_x? | default "" | str trim
            let every_x = if ($ex_raw | is-empty) {
                1
            } else {
                let n = try { $ex_raw | into int } catch { 0 }
                if $n <= 0 {
                    error make { msg: $"Invalid every-x '($ex_raw)'. Must be a positive integer." }
                }
                $n
            }
            let valid_days = ["m" "t" "w" "th" "f" "s" "su"]
            let days_raw = $fields.days? | default "" | str trim | str lowercase
            let days = if ($days_raw | is-empty) {
                $valid_days
            } else {
                let parsed_days = $days_raw | split row "," | str trim | where { |d| $d | is-not-empty }
                let bad = $parsed_days | where { |d| $d not-in $valid_days }
                if ($bad | is-not-empty) {
                    error make { msg: $"Invalid day code\(s\) '($bad | str join ', ')'. Allowed: m, t, w, th, f, s, su." }
                }
                $parsed_days
            }
            {
                text: $text
                notes: $notes
                priority: $priority
                frequency: $frequency
                every_x: $every_x
                days: $days
                tags: $tags
            }
        }
        "habits" => {
            let dir_raw = $fields.direction? | default "both" | str trim | str lowercase
            let direction = if ($dir_raw | is-empty) { "both" } else { $dir_raw }
            if $direction not-in ["positive" "negative" "both"] {
                error make { msg: $"Invalid direction '($direction)'. Allowed: positive, negative, both." }
            }
            {
                text: $text
                notes: $notes
                priority: $priority
                direction: $direction
                tags: $tags
            }
        }
        _ => { error make { msg: $"Unsupported task type: ($task_type)" } }
    }
}

# Submit a validated Habitica task to `h add` without interactive prompts.
@category tui
export def _h-tui-submit-add [
    task_type: string # "todos", "dailys", or "habits"
    valid: record     # Validated record from `_h-tui-validate-add`
    --dry-run         # Forward `--dry-run` to `h add`
]: nothing -> any {
    let has_tags = $valid.tags? | default [] | is-not-empty
    match $task_type {
        "todos" => {
            if $has_tags {
                h add todos --text $valid.text --notes $valid.notes --priority $valid.priority --due $valid.due --checklist $valid.checklist --tag-name $valid.tags --quiet --dry-run=$dry_run
            } else {
                h add todos --text $valid.text --notes $valid.notes --priority $valid.priority --due $valid.due --checklist $valid.checklist --quiet --dry-run=$dry_run
            }
        }
        "dailys" => {
            if $has_tags {
                h add dailys --text $valid.text --notes $valid.notes --priority $valid.priority --frequency $valid.frequency --every-x $valid.every_x --days $valid.days --tag-name $valid.tags --quiet --dry-run=$dry_run
            } else {
                h add dailys --text $valid.text --notes $valid.notes --priority $valid.priority --frequency $valid.frequency --every-x $valid.every_x --days $valid.days --quiet --dry-run=$dry_run
            }
        }
        "habits" => {
            if $has_tags {
                h add habits --text $valid.text --notes $valid.notes --priority $valid.priority --direction $valid.direction --tag-name $valid.tags --quiet --dry-run=$dry_run
            } else {
                h add habits --text $valid.text --notes $valid.notes --priority $valid.priority --direction $valid.direction --quiet --dry-run=$dry_run
            }
        }
        _ => { error make { msg: $"Unsupported task type: ($task_type)" } }
    }
}

# Complete a Habitica todo or daily silently via direct Habitica score/up API.
@category tui
export def _h-tui-complete [
    task_type: string # "todos" or "dailys"
    task_id: string   # Habitica task UUID
    --dry-run         # Return payload without sending
]: nothing -> any {
    if $task_type not-in ["todos" "dailys"] {
        error make { msg: $"Cannot complete task type: ($task_type)" }
    }
    if $dry_run {
        return { task_id: $task_id, task_type: $task_type, action: "score/up" }
    }
    let res = _h-request "POST" $"/api/v3/tasks/($task_id)/score/up" --quiet --allow-errors
    if ($res.success? | default true) == false {
        error make { msg: ($res.message? | default "Failed to complete task") }
    }
    $res
}

# Score a Habitica habit up or down silently via direct Habitica score API.
@category tui
export def _h-tui-score-habit [
    task_id: string   # Habitica habit UUID
    direction: string # "up" or "down"
    --dry-run         # Return payload without sending
]: nothing -> any {
    if $direction not-in ["up" "down"] {
        error make { msg: $"Invalid habit direction: ($direction)" }
    }
    if $dry_run {
        return { task_id: $task_id, direction: $direction, action: $"score/($direction)" }
    }
    let res = _h-request "POST" $"/api/v3/tasks/($task_id)/score/($direction)" --quiet --allow-errors
    if ($res.success? | default true) == false {
        error make { msg: ($res.message? | default "Failed to score habit") }
    }
    $res
}

# Delete a Habitica task using existing `h del`.
@category tui
export def _h-tui-delete [
    task_type: string # "todos", "habits", or "dailys"
    task_id: string   # Habitica task UUID
    --dry-run         # Return payload without sending
]: nothing -> any {
    h del $task_type --id $task_id --quiet --dry-run=$dry_run
}

# Build add-task form for the active Habitica task type, preserving values across validation errors.
@category tui
export def _h-build-add-form [
    task_type: string      # "todos", "habits", or "dailys"
    values: record = {}    # Carried field values
    err_msg: string = ""   # Optional inline validation error
    focus_id: string = "text" # Initial focused widget id
]: nothing -> any {
    let base = tui label --titlebar $"Add Habitica ($task_type) · Ctrl+S submits · Esc cancels"
        | if ($err_msg | is-not-empty) {
            tui label $"Error: ($err_msg)"
        } else { }
        | tui label "Text (required):"
        | tui textbox --id text --value ($values.text? | default "") --placeholder "Task title" --focus=($focus_id == "text")
        | tui label "Notes:"
        | tui textbox --id notes --value ($values.notes? | default "") --placeholder "Optional notes" --focus=($focus_id == "notes")
        | tui label "Priority (1, 1.5, 2, 2.5):"
        | tui textbox --id priority --value ($values.priority? | default "1") --placeholder "1" --focus=($focus_id == "priority")

    let typed_fields = match $task_type {
        "todos" => {
            $base
            | tui label "Due (YYYY-MM-DD):"
            | tui textbox --id due --value ($values.due? | default "") --placeholder "2026-12-31 (optional)" --focus=($focus_id == "due")
            | tui label "Checklist (semicolon-separated):"
            | tui textbox --id checklist --value ($values.checklist? | default "") --placeholder "step 1; step 2" --focus=($focus_id == "checklist")
        }
        "dailys" => {
            $base
            | tui label "Frequency (daily/weekly/monthly/yearly):"
            | tui textbox --id frequency --value ($values.frequency? | default "daily") --placeholder "daily" --focus=($focus_id == "frequency")
            | tui label "Every X:"
            | tui textbox --id every_x --value ($values.every_x? | default "1") --placeholder "1" --focus=($focus_id == "every_x")
            | tui label "Weekly days (m, t, w, th, f, s, su):"
            | tui textbox --id days --value ($values.days? | default "m, t, w, th, f, s, su") --placeholder "m, w, f" --focus=($focus_id == "days")
        }
        "habits" => {
            $base
            | tui label "Direction (positive/negative/both):"
            | tui textbox --id direction --value ($values.direction? | default "both") --placeholder "both" --focus=($focus_id == "direction")
        }
        _ => { $base }
    }

    $typed_fields
    | tui label "Tags (comma-separated):"
    | tui textbox --id tags --value ($values.tags? | default "") --placeholder "Work, Health" --focus=($focus_id == "tags")
    | tui button --id btn_submit "Add (Ctrl+S)" { |s| { action: submit, selected: { op: "submit_add", values: $s.values } } }
    | tui button --id btn_cancel "Cancel" { || { action: quit } }
    | tui label --status "tab/enter: next field  ctrl+s: add  esc: cancel"
    | tui bind ctrl+s { |s| { action: submit, selected: { op: "submit_add", values: $s.values } } }
}

# Build delete confirmation TUI for `h tui`.
@category tui
export def _h-build-confirm-delete-ui [
    task_type: string # "todos", "habits", or "dailys"
    task_text: string # Human-readable task title
]: nothing -> any {
    tui label --titlebar "Confirm Delete Habitica Task"
    | tui label $"Delete ($task_type) task '($task_text)'?"
    | tui button "Yes (Delete)" { || { action: submit, selected: "yes" } }
    | tui button "Cancel" { || { action: quit } }
    | tui label --status "enter: confirm  esc/q: cancel"
}

# Build `h tui` keybindings help screen.
@category tui
export def _h-build-help-ui []: nothing -> any {
    [
        { Key: "1 / 2 / 3" Action: "Switch between Todos, Habits, and Dailys" }
        { Key: "/" Action: "Filter active pane (Enter with query focuses tasks; / resets)" }
        { Key: "ctrl+u" Action: "Clear active search filter" }
        { Key: "Shift+G / m" Action: "Toggle content search (notes/checklist) / match mode (exact vs fuzzy)" }
        { Key: "o / r" Action: "Cycle sort column / Reverse sort direction (per type)" }
        { Key: "c / enter" Action: "Complete highlighted Todo or Daily" }
        { Key: "+ / -" Action: "Score highlighted Habit up / down" }
        { Key: "a" Action: "Add a new task of the active type" }
        { Key: "x" Action: "Delete highlighted task (asks confirmation)" }
        { Key: "p" Action: "Toggle task detail preview pane" }
        { Key: "Shift+P" Action: "Toggle Habitica character stats (`hs`) in preview pane" }
        { Key: "h" Action: "Show/hide tags, due, and due_today columns" }
        { Key: "ctrl+r" Action: "Refresh active type from Habitica API" }
        { Key: "?" Action: "Show this help screen" }
        { Key: "q / esc" Action: "Quit" }
    ]
    | tui label --titlebar "Habitica TUI Help"
    | tui table
    | tui button "Back" { || { action: quit } }
    | tui label --status "enter/q/esc: back to Habitica"
}

# Shared action dispatcher for `h tui` keybinds and buttons.
def _h-do-action [
    state_path: path
    ui_state: record
    op: string
]: nothing -> any {
    let st = _tui-state-get $state_path { active_type: "todos" }
    let active = $st.active_type? | default "todos"
    let cursor_row = $ui_state.values?.tasks?.row? | default ($ui_state.selected?)
    let raw = _h-tui-find-raw $state_path $cursor_row

    match $op {
        "type_todos" => {
            if $active != "todos" {
                _tui-state-merge $state_path { active_type: "todos", search_query: "", focus_target: "tasks", status_msg: "" } | ignore
                return { action: submit, selected: { op: "switch_type", task_type: "todos" } }
            }
        }
        "type_habits" => {
            if $active != "habits" {
                _tui-state-merge $state_path { active_type: "habits", search_query: "", focus_target: "tasks", status_msg: "" } | ignore
                return { action: submit, selected: { op: "switch_type", task_type: "habits" } }
            }
        }
        "type_dailys" => {
            if $active != "dailys" {
                _tui-state-merge $state_path { active_type: "dailys", search_query: "", focus_target: "tasks", status_msg: "" } | ignore
                return { action: submit, selected: { op: "switch_type", task_type: "dailys" } }
            }
        }
        "cycle_sort" => { _h-tui-cycle-sort $state_path | ignore }
        "flip_sort" => { _h-tui-flip-sort $state_path | ignore }
        "refresh" => {
            _tui-state-merge $state_path { stats_text: null, status_msg: "refreshed" } | ignore
            return (_h-tui-state-rows $state_path --force)
        }
        "complete" => {
            if $raw == null {
                _tui-state-merge $state_path { status_msg: "no task selected" } | ignore
            } else if $active in ["todos" "dailys"] {
                try {
                    _h-tui-complete $active $raw._id | ignore
                    _tui-state-merge $state_path { stats_text: null, status_msg: $"completed ($raw.text)" } | ignore
                    return (_h-tui-state-rows $state_path --force)
                } catch { |e|
                    _tui-state-merge $state_path { status_msg: $"failed to complete: ($e.msg)" } | ignore
                }
            } else {
                _tui-state-merge $state_path { status_msg: "use + or - for habits" } | ignore
            }
        }
        "score_up" => {
            if $raw == null or $active != "habits" {
                _tui-state-merge $state_path { status_msg: "select a habit first" } | ignore
            } else if not ($raw.up? | default false) {
                _tui-state-merge $state_path { status_msg: "habit cannot be scored +" } | ignore
            } else {
                try {
                    _h-tui-score-habit $raw._id "up" | ignore
                    _tui-state-merge $state_path { stats_text: null, status_msg: $"scored + ($raw.text)" } | ignore
                    return (_h-tui-state-rows $state_path --force)
                } catch { |e|
                    _tui-state-merge $state_path { status_msg: $"failed to score +: ($e.msg)" } | ignore
                }
            }
        }
        "score_down" => {
            if $raw == null or $active != "habits" {
                _tui-state-merge $state_path { status_msg: "select a habit first" } | ignore
            } else if not ($raw.down? | default false) {
                _tui-state-merge $state_path { status_msg: "habit cannot be scored -" } | ignore
            } else {
                try {
                    _h-tui-score-habit $raw._id "down" | ignore
                    _tui-state-merge $state_path { stats_text: null, status_msg: $"scored - ($raw.text)" } | ignore
                    return (_h-tui-state-rows $state_path --force)
                } catch { |e|
                    _tui-state-merge $state_path { status_msg: $"failed to score -: ($e.msg)" } | ignore
                }
            }
        }
        "preview_detail" => {
            let res = _h-tui-toggle-preview $state_path "detail"
            if $res.relaunch {
                return { action: submit, selected: { op: "toggle_preview", mode: "detail" } }
            }
        }
        "preview_stats" => {
            let res = _h-tui-toggle-preview $state_path "stats"
            if $res.relaunch {
                return { action: submit, selected: { op: "toggle_preview", mode: "stats" } }
            }
        }
        "toggle_cols" => {
            _h-tui-toggle-cols $state_path | ignore
            return { action: submit, selected: { op: "toggle_cols" } }
        }
        "toggle_content" => {
            _h-tui-toggle-content $state_path | ignore
            return { action: submit, selected: { op: "toggle_content" } }
        }
        "toggle_match" => {
            _h-tui-toggle-match $state_path | ignore
            return { action: submit, selected: { op: "toggle_match" } }
        }
        "add" => {
            return { action: submit, selected: { op: "add", task_type: $active } }
        }
        "confirm_delete" => {
            if $raw == null {
                _tui-state-merge $state_path { status_msg: "no task selected" } | ignore
            } else {
                return { action: submit, selected: { op: "confirm_delete", task_type: $active, id: $raw._id, text: $raw.text } }
            }
        }
        "help" => {
            return { action: submit, selected: { op: "help" } }
        }
        _ => {}
    }
    _h-tui-state-rows $state_path
}

# Build the main `h tui` interactive pipeline (exposed for headless `tui debug` testing).
@category tui
export def _h-build-ui [
    state_path: path # Path to NUON state file
]: nothing -> any {
    let initial_rows = _h-tui-state-rows $state_path
    let st_init = _tui-state-get $state_path {
        active_type: "todos"
        preview: "off"
        hide_extra_cols: false
        content_search: false
        match_mode: "exact"
        search_query: ""
        focus_target: "tasks"
    }
    let active_type = $st_init.active_type? | default "todos"
    let preview_mode = $st_init.preview? | default "off"
    let match_mode = $st_init.match_mode? | default "exact"
    let search_query = $st_init.search_query? | default ""
    let focus_target = $st_init.focus_target? | default "tasks"
    let vis_cols = _h-tui-visible-cols $active_type $st_init
    let search_cols = _h-tui-search-cols $active_type $st_init
    let tbl_title = match $active_type {
        "todos" => "Todos"
        "habits" => "Habits"
        "dailys" => "Dailys"
        _ => "Tasks"
    }
    let search_widget = _tui-search-widget "search_tasks" $search_cols $match_mode $search_query --focus=($focus_target == "search")
    let legend = _tui-key-help [
        { key: "1/2/3" label: "type" }
        { key: "/" label: "search" }
        { key: "G" label: "content" }
        { key: "m" label: "match" }
        { key: "o/r" label: "sort" }
        { key: "c" label: "complete" }
        { key: "+/-" label: "habit" }
        { key: "a" label: "add" }
        { key: "x" label: "del" }
        { key: "p/P" label: "pv/stats" }
        { key: "h" label: "cols" }
        { key: "ctrl+r" label: "refresh" }
        { key: "?" label: "help" }
    ]

    let split_sizes = if $preview_mode == "stats" { [55% 1fr] } else { [62% 1fr] }
    let base_ui = $initial_rows
        | tui label --titlebar "Habitica TUI"
        | if $preview_mode == "off" {
            tui box $tbl_title [
                $search_widget
                (tui table --id tasks --title $tbl_title --columns $vis_cols --focus=($focus_target == "tasks"))
            ]
        } else {
            tui split --sizes $split_sizes [
                (tui box $tbl_title [
                    $search_widget
                    (tui table --id tasks --title $tbl_title --columns $vis_cols --focus=($focus_target == "tasks"))
                ])
                (tui preview --from tasks { |row| _h-tui-preview-text $state_path $row })
            ]
        }

    $base_ui
    | tui button --id btn_todos "Todos(1)" { |s| _h-do-action $state_path $s "type_todos" }
    | tui button --id btn_habits "Habits(2)" { |s| _h-do-action $state_path $s "type_habits" }
    | tui button --id btn_dailys "Dailys(3)" { |s| _h-do-action $state_path $s "type_dailys" }
    | tui button --id btn_sort "Sort(o)" { |s| _h-do-action $state_path $s "cycle_sort" }
    | tui button --id btn_rev "Rev(r)" { |s| _h-do-action $state_path $s "flip_sort" }
    | tui button --id btn_complete "Done(c)" { |s| _h-do-action $state_path $s "complete" }
    | tui button --id btn_up "Up(+)" { |s| _h-do-action $state_path $s "score_up" }
    | tui button --id btn_down "Down(-)" { |s| _h-do-action $state_path $s "score_down" }
    | tui button --id btn_add "Add(a)" { |s| _h-do-action $state_path $s "add" }
    | tui button --id btn_del "Del(x)" { |s| _h-do-action $state_path $s "confirm_delete" }
    | tui button --id btn_preview "Preview(p)" { |s| _h-do-action $state_path $s "preview_detail" }
    | tui button --id btn_stats "Stats(P)" { |s| _h-do-action $state_path $s "preview_stats" }
    | tui button --id btn_cols "Cols(h)" { |s| _h-do-action $state_path $s "toggle_cols" }
    | tui button --id btn_content "Content(G)" { |s| _h-do-action $state_path $s "toggle_content" }
    | tui button --id btn_match "Match(m)" { |s| _h-do-action $state_path $s "toggle_match" }
    | tui button --id btn_refresh "Ref(^R)" { |s| _h-do-action $state_path $s "refresh" }
    | tui button --id btn_help "Help(?)" { |s| _h-do-action $state_path $s "help" }
    | tui label --status { |_|
        let st = _tui-state-get $state_path {
            active_type: "todos"
            sort: {}
            preview: "off"
            hide_extra_cols: false
            content_search: false
            match_mode: "exact"
            search_query: ""
            status_msg: ""
        }
        let active = $st.active_type? | default "todos"
        let cols = _h-tui-visible-cols $active $st
        let s = ($st.sort? | default {} | get -o $active) | default { col: ($cols | first), reverse: false }
        let arrow = if ($s.reverse? | default false) { "↓" } else { "↑" }
        let pv_txt = $st.preview? | default "off"
        let cols_txt = if ($st.hide_extra_cols? | default false) { "compact" } else { "all" }
        let cnt_txt = if ($st.content_search? | default false) { "ON" } else { "off" }
        let mm_txt = $st.match_mode? | default "exact"
        let sq = $st.search_query? | default ""
        let sq_txt = if ($sq | is-not-empty) { $" · filter:($sq)" } else { "" }
        let msg = if ($st.status_msg? | default "" | is-not-empty) { $" · ($st.status_msg)" } else { "" }
        $"type:($active) · sort:($s.col)($arrow) · pv:($pv_txt) · cols:($cols_txt) · content:($cnt_txt) · match:($mm_txt)($sq_txt)($msg) · ($legend)"
    }
    | tui bind 1 { |s| _h-do-action $state_path $s "type_todos" }
    | tui bind 2 { |s| _h-do-action $state_path $s "type_habits" }
    | tui bind 3 { |s| _h-do-action $state_path $s "type_dailys" }
    | tui bind o { |s| _h-do-action $state_path $s "cycle_sort" }
    | tui bind r { |s| _h-do-action $state_path $s "flip_sort" }
    | tui bind c { |s| _h-do-action $state_path $s "complete" }
    | tui bind enter { |s|
        match ($s.focused? | default "") {
            "tasks" | "btn_complete" => { _h-do-action $state_path $s "complete" }
            "btn_todos" => { _h-do-action $state_path $s "type_todos" }
            "btn_habits" => { _h-do-action $state_path $s "type_habits" }
            "btn_dailys" => { _h-do-action $state_path $s "type_dailys" }
            "btn_sort" => { _h-do-action $state_path $s "cycle_sort" }
            "btn_rev" => { _h-do-action $state_path $s "flip_sort" }
            "btn_up" => { _h-do-action $state_path $s "score_up" }
            "btn_down" => { _h-do-action $state_path $s "score_down" }
            "btn_add" => { _h-do-action $state_path $s "add" }
            "btn_del" => { _h-do-action $state_path $s "confirm_delete" }
            "btn_preview" => { _h-do-action $state_path $s "preview_detail" }
            "btn_stats" => { _h-do-action $state_path $s "preview_stats" }
            "btn_cols" => { _h-do-action $state_path $s "toggle_cols" }
            "btn_content" => { _h-do-action $state_path $s "toggle_content" }
            "btn_match" => { _h-do-action $state_path $s "toggle_match" }
            "btn_refresh" => { _h-do-action $state_path $s "refresh" }
            "btn_help" => { _h-do-action $state_path $s "help" }
            _ => { null }
        }
    }
    | tui bind "+" { |s| _h-do-action $state_path $s "score_up" }
    | tui bind "-" { |s| _h-do-action $state_path $s "score_down" }
    | tui bind a { |s| _h-do-action $state_path $s "add" }
    | tui bind x { |s| _h-do-action $state_path $s "confirm_delete" }
    | tui bind p { |s| _h-do-action $state_path $s "preview_detail" }
    | tui bind shift+p { |s| _h-do-action $state_path $s "preview_stats" }
    | tui bind h { |s| _h-do-action $state_path $s "toggle_cols" }
    | tui bind shift+g { |s| _h-do-action $state_path $s "toggle_content" }
    | tui bind m { |s| _h-do-action $state_path $s "toggle_match" }
    | tui bind ctrl+r { |s| _h-do-action $state_path $s "refresh" }
    | tui bind "?" { |s| _h-do-action $state_path $s "help" }
    | if ($search_query | is-not-empty) {
        tui bind "/" { |_|
            _tui-state-merge $state_path { search_query: "", focus_target: "search", status_msg: "" } | ignore
            { action: submit, selected: { op: "focus_search" } }
        }
        | tui bind ctrl+u { |_|
            _tui-state-merge $state_path { search_query: "", focus_target: "tasks", status_msg: "" } | ignore
            { action: submit, selected: { op: "clear_search" } }
        }
    } else { }
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
    let state_path = _tui-state-path "h-tui"

    with-env { HABITICA_QUIET: true } {
        try {
            _h-tui-init-state $state_path | ignore
            # Prime initial todos cache before opening alternate screen
            _h-tui-state-rows $state_path | ignore

            loop {
                let res = (_h-build-ui $state_path) | tui run
                if $res.action != "submit" {
                    break
                }
                let sel_rec = _tui-as-record $res.selected?
                let op = $sel_rec.op? | default ""
                if ($res.focused? == "search_tasks") and ($op not-in ["toggle_preview" "switch_type" "toggle_content" "toggle_match" "focus_search" "clear_search" "confirm_delete" "add" "help"]) {
                    let q = $res.values?.search_tasks? | default "" | str trim
                    if ($q | is-not-empty) {
                        _tui-state-merge $state_path { search_query: $q, focus_target: "tasks", status_msg: $"filter: ($q)" } | ignore
                    } else {
                        _tui-state-merge $state_path { focus_target: "tasks" } | ignore
                    }
                    continue
                }
                match $op {
                    "confirm_delete" => {
                        let task_type = $sel_rec.task_type? | default "todos"
                        let task_id = $sel_rec.id? | default ""
                        let task_text = $sel_rec.text? | default ""
                        if ($task_id | is-not-empty) {
                            let conf = (_h-build-confirm-delete-ui $task_type $task_text) | tui run
                            if $conf.action == "submit" and ($conf.selected? == "yes") {
                                try {
                                    _h-tui-delete $task_type $task_id | ignore
                                    _h-tui-state-rows $state_path --force | ignore
                                    _tui-state-merge $state_path { status_msg: $"deleted ($task_text)" } | ignore
                                } catch { |e|
                                    _tui-state-merge $state_path { status_msg: $"failed to delete: ($e.msg)" } | ignore
                                }
                            }
                        }
                    }
                    "add" => {
                        let task_type = $sel_rec.task_type? | default "todos"
                        let field_order = match $task_type {
                            "todos" => ["text" "notes" "priority" "due" "checklist" "tags"]
                            "dailys" => ["text" "notes" "priority" "frequency" "every_x" "days" "tags"]
                            "habits" => ["text" "notes" "priority" "direction" "tags"]
                            _ => ["text" "notes" "priority" "tags"]
                        }
                        mut values: record = {}
                        mut err_msg = ""
                        mut focus_id = "text"
                        loop {
                            let form_res = (_h-build-add-form $task_type $values $err_msg $focus_id) | tui run
                            if $form_res.action != "submit" {
                                break
                            }
                            let form_sel = $form_res.selected?
                            let sub_op = if ($form_sel != null) and (($form_sel | describe) | str starts-with "record") {
                                $form_sel.op? | default ""
                            } else {
                                ""
                            }
                            $values = ($form_res.values? | default {})
                            if $sub_op != "submit_add" {
                                let cur_idx = $field_order | enumerate | where item == ($form_res.focused? | default "text") | get index.0?
                                if $cur_idx != null and ($cur_idx + 1) < ($field_order | length) {
                                    $focus_id = ($field_order | get ($cur_idx + 1))
                                    $err_msg = ""
                                    continue
                                }
                            }
                            let validated = try {
                                { ok: true, data: (_h-tui-validate-add $task_type $values) }
                            } catch { |e|
                                { ok: false, err: $e.msg }
                            }
                            if not $validated.ok {
                                $err_msg = $validated.err
                                continue
                            }
                            try {
                                _h-tui-submit-add $task_type $validated.data | ignore
                                _h-tui-state-rows $state_path --force | ignore
                                _tui-state-merge $state_path { status_msg: $"added ($validated.data.text)" } | ignore
                            } catch { |e|
                                _tui-state-merge $state_path { status_msg: $"failed to add: ($e.msg)" } | ignore
                            }
                            break
                        }
                    }
                    "toggle_preview" | "switch_type" | "toggle_content" | "toggle_match" | "toggle_cols" | "focus_search" | "clear_search" => { }
                    "help" => {
                        (_h-build-help-ui) | tui run | ignore
                    }
                    _ => { break }
                }
            }
        } finally {
            _tui-state-cleanup $state_path
        }
    }
}

export alias htui = h tui

# ==============================================================================
# Phase 7: skills tui (Agent Skills Browser)
# ==============================================================================

# Resolve skills directory from explicit override or `$env.MY_ENV_VARS.llms_configs/skills`.
@category tui
export def _skills-resolve-dir [
    override_dir: string = "" # Optional `--dir` path override
]: nothing -> path {
    let raw_dir = if ($override_dir | str trim | is-not-empty) {
        $override_dir | path expand
    } else {
        let cfg = try { $env.MY_ENV_VARS.llms_configs } catch { "" }
        if ($cfg | is-empty) {
            error make { msg: "Skills directory not configured ($env.MY_ENV_VARS.llms_configs missing). Pass --dir." }
        }
        ($cfg | path join "skills") | path expand
    }
    if not (($raw_dir | path exists) and (($raw_dir | path type) == "dir")) {
        error make { msg: $"Skills directory not found: ($raw_dir)" }
    }
    $raw_dir
}

# Parse YAML frontmatter name/description from SKILL.md, tolerating missing or malformed YAML.
@category tui
export def _skills-parse-frontmatter [
    text: string          # Raw SKILL.md file content
    fallback_name: string # Directory basename fallback when name is absent
]: nothing -> record<name: string, description: string> {
    let trimmed = $text | str trim --left
    if not ($trimmed | str starts-with "---") {
        return { name: $fallback_name, description: "" }
    }
    let parts = $trimmed | split row "---"
    let fm_raw = $parts | get -o 1 | default ""
    if ($fm_raw | str trim | is-empty) {
        return { name: $fallback_name, description: "" }
    }

    let parsed = try { $fm_raw | from yaml } catch { null }
    if ($parsed != null) and (($parsed | describe) | str starts-with "record") {
        return {
            name: ($parsed.name? | default $fallback_name | into string | str trim)
            description: ($parsed.description? | default "" | into string | str trim)
        }
    }

    # Regex fallback for odd frontmatter (e.g. unquoted colons in description)
    mut name_val = $fallback_name
    mut desc_val = ""
    for line in ($fm_raw | lines) {
        let m_name = $line | parse --regex '^\s*name\s*:\s*(?P<v>.+?)\s*$'
        if ($m_name | is-not-empty) {
            $name_val = ($m_name.0.v | str trim --char '"' | str trim --char "'")
        }
        let m_desc = $line | parse --regex '^\s*description\s*:\s*(?P<v>.+?)\s*$'
        if ($m_desc | is-not-empty) {
            $desc_val = ($m_desc.0.v | str trim --char '"' | str trim --char "'")
        }
    }
    { name: $name_val, description: $desc_val }
}

# Build sorted skill index from `<dir>/*/SKILL.md`.
@category tui
export def _skills-index [
    dir: path # Root skills directory
]: nothing -> list<record> {
    let root = $dir | path expand
    if not ($root | path exists) {
        return []
    }
    glob ($root | path join "*" "SKILL.md") --no-dir
    | each { |f|
        let skill_dir = $f | path dirname
        let fallback = $skill_dir | path basename
        let text = try { open --raw $f } catch { "" }
        let fm = _skills-parse-frontmatter $text $fallback
        let clean_content = $text | str replace --all -r '\s+' ' ' | str trim
        {
            name: $fm.name
            description: $fm.description
            content: $clean_content
            path: $f
            skill_dir: $skill_dir
        }
    }
    | sort-by --natural name
}

# Check whether query characters appear in order inside candidate string (subsequence match).
def _skills-is-subseq [candidate: string, query: string]: nothing -> bool {
    let c_chars = $candidate | split chars
    let q_chars = $query | split chars
    mut qi = 0
    let q_len = $q_chars | length
    for ch in $c_chars {
        if $qi >= $q_len { break }
        if $ch == ($q_chars | get $qi) {
            $qi = $qi + 1
        }
    }
    $qi == $q_len
}

# Rank skills fuzzily over name + description (prefix/substring/subsequence, name prioritized).
@category tui
export def _skills-fuzzy-rank [
    skills: list<record> # Skill index from `_skills-index`
    query: string        # Search query string
]: nothing -> list<record> {
    let q = $query | str trim | str lowercase
    if ($q | is-empty) {
        return $skills
    }
    $skills | each { |s|
        let nm = $s.name | str lowercase
        let ds = $s.description | str lowercase
        let score = if $nm == $q {
            1000
        } else if ($nm | str starts-with $q) {
            800
        } else if ($nm | str contains $q) {
            600
        } else if (_skills-is-subseq $nm $q) {
            400
        } else if ($ds | str contains $q) {
            200
        } else if (_skills-is-subseq $ds $q) {
            100
        } else {
            0
        }
        if $score > 0 { $s | upsert _rank $score } else { null }
    }
    | compact
    | sort-by --reverse _rank
    | reject _rank
}

# Choose Markdown preview renderer command ("glow", "bat", or "plain").
@category tui
export def _skills-preview-cmd [
    --has-glow: oneof<bool, nothing> # Optional override for glow availability (for testing)
    --has-bat: oneof<bool, nothing>  # Optional override for bat availability (for testing)
]: nothing -> string {
    let glow_ok = $has_glow | default (which glow | is-not-empty)
    if $glow_ok {
        return "glow"
    }
    let bat_ok = $has_bat | default (which bat | is-not-empty)
    if $bat_ok {
        return "bat"
    }
    "plain"
}

# Choose full-screen Markdown viewer command ("mdfried", "glow", or "less").
@category tui
export def _skills-fullscreen-cmd [
    --has-mdfried: oneof<bool, nothing> # Optional override for mdfried availability (for testing)
    --has-glow: oneof<bool, nothing>    # Optional override for glow availability (for testing)
]: nothing -> string {
    let mdf_ok = $has_mdfried | default (which mdfried | is-not-empty)
    if $mdf_ok {
        return "mdfried"
    }
    let glow_ok = $has_glow | default (which glow | is-not-empty)
    if $glow_ok {
        return "glow"
    }
    "less"
}

# Render SKILL.md preview text via glow, bat, or raw fallback.
@category tui
export def _skills-preview-text [
    row: any             # Highlighted skill row record or null
    --width: int = 70    # Wrap width for glow
]: nothing -> string {
    if $row == null {
        return "No skill selected."
    }
    let skill_path = $row.path? | default ""
    if ($skill_path | is-empty) or (not ($skill_path | path exists)) {
        return "No skill selected."
    }
    let raw = try { open --raw $skill_path } catch { "" }
    let snippet = if ($raw | str length) > 16384 {
        $raw | str substring 0..16384
    } else {
        $raw
    }
    match (_skills-preview-cmd) {
        "glow" => {
            let res = do { $snippet | ^glow -s dark -w $width - } | complete
            if $res.exit_code == 0 and ($res.stdout | is-not-empty) {
                return $res.stdout
            }
        }
        "bat" => {
            let res = do { $snippet | ^bat --color=always --style=plain -l md - } | complete
            if $res.exit_code == 0 {
                return $res.stdout
            }
        }
        _ => {}
    }
    $snippet | ansi strip
}

# List all files inside a skill directory (scripts, references, SKILL.md) as relative paths.
@category tui
export def _skills-files [
    skill_dir: path # Skill directory path
]: nothing -> list<record> {
    let root = $skill_dir | path expand
    if not ($root | path exists) {
        return []
    }
    glob ($root | path join "**" "*") --no-dir
    | each { |f|
        let sz = try { (ls -d $f | get 0.size) | into string } catch { "0 B" }
        {
            file: ($f | path relative-to $root)
            size: $sz
            path: $f
        }
    }
    | sort-by --natural file
}

# Build secondary view listing all files belonging to a skill.
@category tui
export def _skills-build-files-ui [
    skill_name: string   # Display name of the skill
    files: list<record>  # File rows from `_skills-files`
]: nothing -> any {
    $files
    | tui label --titlebar $"Skill Files: ($skill_name) · Enter/e: edit in ox · Esc/q: back"
    | tui split --sizes [45% 1fr] [
        (tui table --id skill_files --title "Files" --columns [file size] --focus)
        (tui preview --from skill_files { |r| try { open --raw $r.path | ansi strip } catch { "" } })
    ]
    | tui button --id btn_edit_file "Edit (e)" { |s| { action: submit, selected: { op: "edit_file", row: $s.values.skill_files?.row? } } }
    | tui button --id btn_back "Back (q)" { || { action: quit } }
    | tui label --status "enter/e: edit file in ox  esc/q: back to skills"
    | tui bind e { |s| { action: submit, selected: { op: "edit_file", row: $s.values.skill_files?.row? } } }
}

# Filter skill rows by query across name/description (and optional content) using exact substring or fuzzy matching.
@category tui
export def _skills-filter-rows [
    skills: list<record>           # Skill index from `_skills-index`
    query: string                  # Filter query string
    --content-search (-c)          # Include full SKILL.md content
    --match-mode: string = "exact" # "exact" or "fuzzy"
]: nothing -> list<record> {
    let q = $query | str trim | str lowercase
    if ($q | is-empty) {
        return $skills
    }
    let is_fuzzy = ($match_mode == "fuzzy")
    $skills | where { |s|
        let fields = if $content_search {
            [($s.name? | default "") ($s.description? | default "") ($s.content? | default "")]
        } else {
            [($s.name? | default "") ($s.description? | default "")]
        }
        _tui-fields-match $fields $q --fuzzy=$is_fuzzy
    }
}

# Build `skills tui` keybindings help screen.
@category tui
export def _skills-build-help-ui []: nothing -> any {
    [
        { Key: "/ or type" Action: "Filter skills (Enter with query focuses Skills list; / resets)" }
        { Key: "ctrl+u" Action: "Clear active search filter" }
        { Key: "esc" Action: "Leave search box to use table shortcuts" }
        { Key: "c" Action: "Toggle SKILL.md full content search (after Esc)" }
        { Key: "m" Action: "Toggle search match mode (exact substring vs fuzzy, after Esc)" }
        { Key: "enter" Action: "Open SKILL.md in full-screen renderer (mdfried / glow -p)" }
        { Key: "e" Action: "Edit SKILL.md in ox" }
        { Key: "l" Action: "List all files (scripts/references) in the skill" }
        { Key: "?" Action: "Show this help screen" }
        { Key: "q / esc" Action: "Quit" }
    ]
    | tui label --titlebar "Skills Browser Help"
    | tui table
    | tui button "Back" { || { action: quit } }
    | tui label --status "enter/q/esc: back to skills"
}

# Build main `skills tui` browser pipeline (exposed for headless `tui debug` testing).
@category tui
export def _skills-build-ui [
    skills: list<record>            # Skill index from `_skills-index`
    dir: path                       # Resolved skills root directory
    --content-search (-c)           # Include full SKILL.md content in search columns
    --match-mode: string = "exact"  # Search match mode ("exact" or "fuzzy")
    --search-query (-q): string = "" # Pre-applied search filter query (when focusing skills table)
    --focus-target: string = "search" # Initial focus widget ("search" or "skills")
]: nothing -> any {
    let display_skills = _skills-filter-rows $skills $search_query --content-search=$content_search --match-mode $match_mode
    let search_cols = if $content_search { [name description content] } else { [name description] }
    let search_widget = _tui-search-widget "skill_search" $search_cols $match_mode $search_query --focus=($focus_target == "search")
    let legend = _tui-key-help [
        { key: "/" label: "search" }
        { key: "c" label: "content" }
        { key: "m" label: "match" }
        { key: "enter" label: "open" }
        { key: "e" label: "edit" }
        { key: "l" label: "files" }
        { key: "?" label: "help" }
        { key: "q" label: "quit" }
    ]

    $display_skills
    | tui label --titlebar $"Skills Browser \(($skills | length)\) · ($dir)"
    | tui split --sizes [44% 1fr] [
        (tui box "Skills" [
            $search_widget
            (tui table --id skills --title "Skills" --columns [name description] --focus=($focus_target == "skills"))
        ])
        (tui preview --from skills { |row| _skills-preview-text $row })
    ]
    | tui button --id btn_open "Open (Enter)" { |s| { action: submit, selected: { op: "open", row: $s.values.skills?.row? } } }
    | tui button --id btn_edit "Edit (e)" { |s| { action: submit, selected: { op: "edit", row: $s.values.skills?.row? } } }
    | tui button --id btn_files "Files (l)" { |s| { action: submit, selected: { op: "files", row: $s.values.skills?.row? } } }
    | tui button --id btn_content "Content (c)" { |_| { action: submit, selected: { op: "toggle_content" } } }
    | tui button --id btn_match "Match (m)" { |_| { action: submit, selected: { op: "toggle_match" } } }
    | tui button --id btn_help "Help (?)" { || { action: submit, selected: { op: "help" } } }
    | tui button --id btn_quit "Quit (q)" { || { action: quit } }
    | tui label --status $"content:(if $content_search { 'ON' } else { 'off' }) · match:($match_mode)(if ($search_query | is-not-empty) { $' · filter:($search_query)' } else { '' }) · esc:leave search · ($legend)"
    | tui bind enter { |s|
        match ($s.focused? | default "") {
            "btn_edit" => { { action: submit, selected: { op: "edit", row: $s.values.skills?.row? } } }
            "btn_files" => { { action: submit, selected: { op: "files", row: $s.values.skills?.row? } } }
            "btn_content" => { { action: submit, selected: { op: "toggle_content" } } }
            "btn_match" => { { action: submit, selected: { op: "toggle_match" } } }
            "btn_help" => { { action: submit, selected: { op: "help" } } }
            "btn_quit" => { { action: quit } }
            _ => { { action: submit, selected: { op: "open", row: $s.values.skills?.row? } } }
        }
    }
    | tui bind e { |s| { action: submit, selected: { op: "edit", row: $s.values.skills?.row? } } }
    | tui bind l { |s| { action: submit, selected: { op: "files", row: $s.values.skills?.row? } } }
    | tui bind c { |_| { action: submit, selected: { op: "toggle_content" } } }
    | tui bind m { |_| { action: submit, selected: { op: "toggle_match" } } }
    | tui bind "?" { || { action: submit, selected: { op: "help" } } }
    | if ($search_query | is-not-empty) {
        tui bind "/" { |_| { action: submit, selected: { op: "focus_search" } } }
        | tui bind ctrl+u { |_| { action: submit, selected: { op: "clear_search" } } }
    } else { }
}

# Interactive Agent Skills browser with fuzzy/exact/content search, Markdown preview, mdfried/glow viewer, ox edit, and file list.
@category tui
@example "Browse configured Agent Skills" { skills tui }
@example "Browse skills from a custom directory" { skills tui --dir ~/my-skills }
export def "skills tui" [
    --dir (-d): string = ""            # Optional override path to skills directory
    --stdin-tty: oneof<bool, nothing>  # Optional override for stdin TTY status (for testing)
    --stdout-tty: oneof<bool, nothing> # Optional override for stdout TTY status (for testing)
]: nothing -> nothing {
    _tui-require-tty --stdin-tty=$stdin_tty --stdout-tty=$stdout_tty
    let root_dir = _skills-resolve-dir $dir
    mut content_search = false
    mut match_mode = "exact"
    mut search_query = ""
    mut focus_target = "search"

    loop {
        let skills = _skills-index $root_dir
        let res = (_skills-build-ui $skills $root_dir --content-search=$content_search --match-mode $match_mode --search-query $search_query --focus-target $focus_target) | tui run
        if $res.action != "submit" {
            break
        }
        let sel_rec = _tui-as-record $res.selected?
        let is_rec = $sel_rec | is-not-empty
        let op = $sel_rec.op? | default "open"
        if ($res.focused? == "skill_search") and ($op not-in ["edit" "files" "toggle_content" "toggle_match" "help" "focus_search" "clear_search"]) {
            let q = $res.values?.skill_search? | default "" | str trim
            if ($q | is-not-empty) {
                $search_query = $q
                $focus_target = "skills"
                continue
            }
        }
        let row = if ($sel_rec.row? != null) { _tui-as-record $sel_rec.row } else if $is_rec { $sel_rec } else { {} }
        let skill_path = $row.path? | default ""
        let skill_dir = $row.skill_dir? | default (if ($skill_path | is-not-empty) { $skill_path | path dirname } else { "" })
        let skill_name = $row.name? | default ""

        match $op {
            "open" => {
                if ($skill_path | is-not-empty) and ($skill_path | path exists) {
                    match (_skills-fullscreen-cmd) {
                        "mdfried" => { ^mdfried $skill_path }
                        "glow" => { ^glow -p $skill_path }
                        _ => { ^less $skill_path }
                    }
                }
            }
            "edit" => {
                if ($skill_path | is-not-empty) and ($skill_path | path exists) {
                    ^ox $skill_path
                }
            }
            "files" => {
                if ($skill_dir | is-not-empty) and ($skill_dir | path exists) {
                    loop {
                        let files = _skills-files $skill_dir
                        let fres = (_skills-build-files-ui $skill_name $files) | tui run
                        if $fres.action != "submit" {
                            break
                        }
                        let fsel_rec = _tui-as-record $fres.selected?
                        let frow = _tui-as-record ($fsel_rec.row? | default $fsel_rec)
                        let fpath = $frow.path? | default ""
                        if ($fpath | is-not-empty) and ($fpath | path exists) {
                            ^ox $fpath
                        }
                    }
                }
            }
            "toggle_content" => {
                $content_search = (not $content_search)
            }
            "toggle_match" => {
                $match_mode = (if $match_mode == "fuzzy" { "exact" } else { "fuzzy" })
            }
            "focus_search" => {
                $search_query = ""
                $focus_target = "search"
            }
            "clear_search" => {
                $search_query = ""
                $focus_target = "skills"
            }
            "help" => {
                (_skills-build-help-ui) | tui run | ignore
            }
            _ => { break }
        }
    }
}