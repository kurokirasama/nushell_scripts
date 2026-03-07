# obsidian.nu - Obsidian CLI integration for Nushell (Backward Compatible)

# Search Obsidian vault for query and return matches
# Original signature: obs search [...query, --tag(-t):string, --edit(-e), --raw(-r)]
export def "obs search" [
    ...query: string, # Search query (title and body)
    --tag(-t): string, # Search in tag
    --edit(-e), # Edit selected note
    --raw(-r), # Don't use syntax highlight (original behavior showed content)
    --vault: string, # New: Target a specific vault
    --limit: int = 50 # New: Max search results
] {
    let query_str = if ($query | is-empty) { 
        if ($tag | is-not-empty) { "" } else { error make {msg: "empty search query!"} }
    } else { 
        $query | str join " " 
    }

    let vault_arg = if ($vault | is-empty) { "" } else { $"vault=($vault) " }
    
    # obsidian-cli search
    let search_output = (run-external obsidian $"($vault_arg)search" $"query=($query_str)" $"limit=($limit)" "format=json" | lines | str join "\n")
    
    # Extract JSON part
    let json_results = if ($search_output | str contains "[") {
        let start = ($search_output | str index-of "[")
        $search_output | str substring $start.. | from json
    } else {
        []
    }
    
    # obsidian-cli files (filename search)
    let files_output = (run-external obsidian $"($vault_arg)files" | lines)
    let file_results = if ($query_str | is-not-empty) { $files_output | where $it =~ $query_str } else { [] }
    
    let combined = ($json_results | each { |it| { path: $it, match_type: "content" } })
    let file_matches = ($file_results | each { |it| { path: $it, match_type: "filename" } })
    let all_matches = ($combined | append $file_matches | uniq-by path)
    
    # Filter by tag if requested
    let filtered_matches = if ($tag | is-not-empty) {
        $all_matches | where { |it| 
            let tags_output = (run-external obsidian $"($vault_arg)tags" $"file=($it.path)" | lines | str join "\n")
            let tags_json = if ($tags_output | str contains "[") {
                let start = ($tags_output | str index-of "[")
                $tags_output | str substring $start.. | from json
            } else { [] }
            ($tags_json | where name =~ $tag | length) > 0
        }
    } else {
        $all_matches
    }

    if ($filtered_matches | is-empty) {
        return []
    }

    # If --edit or no explicit output requested, we follow old behavior of interactive selection
    # But for Nushell consistency, if piped or assigned, we return the table.
    # However, to be "as close as possible", if called interactively without assignment:
    
    let selected_note = ($filtered_matches | get path | input list -f "Select note:")
    
    if ($selected_note | is-empty) { return }

    if $edit {
        obs edit $selected_note --vault $vault
    } else {
        let content = (run-external obsidian $"($vault_arg)read" $"path=($selected_note)")
        if $raw { $content } else { $content | glow }
    }
}

# Create a new note in Obsidian
# Original signature: obs create [name:string, content?:string, --v_path(-v):string, --sub_path(-s)]
export def "obs create" [
    name: string, # Name of the note
    content?: string, # Content of the note
    --v_path(-v): string, # Path for the note in vault
    --sub_path(-s), # Select subpath interactively
    --tags: list<string> = [], # New: Tags to add
    --vault: string, # New: Target vault
    --overwrite # New: Overwrite if file exists
] {
    let input_content = if ($in | is-not-empty) { $in } else { $content | default "" }
    
    let vault_arg = if ($vault | is-empty) { "" } else { $"vault=($vault) " }
    let overwrite_flag = if $overwrite { "overwrite" } else { "" }

    # Resolve v_path if not provided (old behavior was interactive if missing)
    let final_v_path = if ($v_path | is-empty) {
        # This part requires knowledge of the vault structure
        # For now, we'll try to list folders from the CLI
        let folders = (run-external obsidian $"($vault_arg)folders" | lines)
        $folders | input list -f "Select path for the note:"
    } else {
        $v_path
    }

    let final_sub_path = if $sub_path {
        let subfolders = (run-external obsidian $"($vault_arg)folders" $"folder=($final_v_path)" | lines)
        if ($subfolders | is-empty) { "" } else { $subfolders | input list -f "Select sub_path for the note:" }
    } else {
        ""
    }

    let target_dir = if ($final_sub_path | is-not-empty) { $"($final_v_path)/($final_sub_path)" } else { $final_v_path }
    let full_note_path = if ($target_dir | is-not-empty) { $"($target_dir)/($name)" } else { $name }

    # Prepare content with tags in frontmatter if provided
    let final_content = if ($tags | length) > 0 {
        let tag_lines = ($tags | each { |it| $"- ($it)" } | str join "\n")
        $"---\ntags:\n($tag_lines)\n---\n\n($input_content)"
    } else {
        $input_content
    }

    run-external obsidian $"($vault_arg)create" $"path=($full_note_path)" $"content=($final_content)" $overwrite_flag
}

# Edit a note in Obsidian using ox
export def "obs edit" [
    name: string, # Note name or path
    --vault: string # Target vault
] {
    let vault_arg = if ($vault | is-empty) { "" } else { $"vault=($vault) " }
    
    # Get the file info to resolve path
    let file_output = (run-external obsidian $"($vault_arg)file" $"file=($name)" | lines | str join "\n")
    
    # Parse path from file info output
    # Example output: "path       Notes/Recipe.md"
    let path_line = ($file_output | lines | find "path" | first)
    let rel_path = ($path_line | split row -r '\s+' | last)

    if ($rel_path | is-not-empty) {
        let vault_path = (run-external obsidian $"($vault_arg)vault" "info=path" | str trim)
        let absolute_path = ($vault_path | path join $rel_path)
        
        run-external ox $absolute_path
    } else {
        error make {msg: $"Note '($name)' not found."}
    }
}
