# Module: keybinding_helpers.nu
# Provides pure, modular helpers for interactive native input list keybindings.

# Lists files in the target directory (non-recursive), sorted by name.
export def keybind-list-files [
    --dir: string = "." # Target directory to inspect
]: nothing -> list<string> {
    let resolved = ($dir | path expand)
    if not ($resolved | path exists) {
        return []
    }
    ls $resolved
    | where type == file
    | sort-by name
    | get name
    | each { |p| $p | path basename }
}

# Recursively lists files in the target directory, excluding version control and build caches.
export def keybind-list-files-recursive [
    --dir: string = "." # Root directory to search from
]: nothing -> list<string> {
    let resolved = ($dir | path expand)
    if not ($resolved | path exists) {
        return []
    }

    if (which fd | is-not-empty) {
        try {
            ^fd -t f -H -E .git -E node_modules -E target --base-directory $resolved
            | lines
            | where { |it| $it | str trim | is-not-empty }
            | sort
        } catch {
            _fallback-glob-recursive $resolved
        }
    } else {
        _fallback-glob-recursive $resolved
    }
}

# Fallback recursive file scanner using native glob
def _fallback-glob-recursive [resolved: string]: nothing -> list<string> {
    glob --no-dir ($"($resolved)/**/*")
    | where { |it|
        let rel = ($it | path relative-to $resolved)
        not ($rel =~ '^(\.git|node_modules|target)/') and not ($rel =~ '/(\.git|node_modules|target)/')
    }
    | each { |it| $it | path relative-to $resolved }
    | sort
}

# Lists immediate subdirectories in the target directory, sorted by name.
export def keybind-list-dirs [
    --dir: string = "." # Target directory to inspect
]: nothing -> list<string> {
    let resolved = ($dir | path expand)
    if not ($resolved | path exists) {
        return []
    }
    ls $resolved
    | where type == dir
    | sort-by name
    | get name
    | each { |p| $p | path basename }
}

# Pure helper to reverse and deduplicate history commands.
export def keybind-process-history-list [
    cmds: list<string> # Raw list of command strings
]: nothing -> list<string> {
    $cmds
    | where { |it| ($it | str trim | is-not-empty) }
    | reverse
    | uniq
}

# Extracts recent command history, reversed and deduplicated for fuzzy picking.
export def keybind-list-history [
    --limit: int = 1000 # Number of recent history entries to sample
]: nothing -> list<string> {
    try {
        history
        | last $limit
        | get command
        | keybind-process-history-list $in
    } catch {
        []
    }
}

# Safely formats a selected path or token for appending to the interactive commandline.
# Defaults to single quotes ('...'), and falls back to escaped double quotes ("...")
# if the path contains a single quote. Returns empty string for null or whitespace.
export def keybind-format-arg [
    item: any # Selected item
]: nothing -> string {
    if ($item == null) {
        return ""
    }
    let s = ($item | into string)
    if ($s | str trim | is-empty) {
        return ""
    }
    if ($s =~ "'") {
        let escaped = ($s | str replace --all '\' '\\' | str replace --all '"' '\"' | str replace --all '$' '\$')
        $" \"($escaped)\""
    } else {
        $" '($s)'"
    }
}
