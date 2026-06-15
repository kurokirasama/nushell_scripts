# --- HELPER FUNCTIONS ---

# Helper to get the vault path from environment or fallback.
def get-vault [] {
    let env_vault = try { $env.MY_ENV_VARS.OBSIDIAN_VAULT_ROOT } catch { null }
    let vault = $env_vault | default $env.OBSIDIAN_VAULT_ROOT? | default "~/Yandex.Disk/obsidian/vaults"
    $vault | path expand
}

# Helper to find the project root by walking up directories.
def find-project-root [start_path: path]: nothing -> record {
    let start_expanded = $start_path | path expand
    let is_file = ($start_expanded | path exists) and (($start_expanded | path type) == "file")
    mut curr = if $is_file { $start_expanded | path dirname } else { $start_expanded }
    loop {
        if ([$curr "conductor"] | path join | path exists) {
            return { path: $curr, type: "conductor" }
        }
        if ([$curr ".git"] | path join | path exists) {
            return { path: $curr, type: "git" }
        }
        let parent = $curr | path dirname
        if $parent == $curr {
            break
        }
        $curr = $parent
    }
    return { path: (if $is_file { $start_expanded | path dirname } else { $start_expanded }), type: "none" }
}

# Helper to get the absolute path of a long-term memory note.
def get-note-path [slug: string, vault: path]: nothing -> path {
    [$vault "AGENTS_MEMORY" $slug $"($slug).md"] | path join
}

# Helper to parse YAML frontmatter from a markdown string.
def parse-frontmatter [content: string]: nothing -> any {
    # Strip UTF-8 BOM if present
    let content = $content | str replace --regex '^\u{FEFF}' ''
    # Extract only the first frontmatter block bounded by leading ---
    let parsed = $content | parse --regex '(?s)\A---\r?\n(?P<fm>.*?)\r?\n---'
    if ($parsed | is-empty) { return null }
    let result = $parsed | get 0.fm
    try { $result | from yaml } catch { null }
}

# Helper to get body text after frontmatter block.
def get-body [content: string]: nothing -> string {
    let content = $content | str replace --regex '^\u{FEFF}' ''
    let lines = $content | lines
    let delimiters = $lines | enumerate | where item == "---" | get index
    if ($delimiters | is-empty) or ($delimiters | get 0) != 0 or ($delimiters | length) < 2 {
        return $content
    }
    let body_start = ($delimiters | get 1) + 1
    $lines | skip $body_start | str join "\n"
}

# Get the path to the consolidation state file.
def get-state-path [vault: path]: nothing -> path {
    [$vault "AGENTS_MEMORY" ".consolidation_state.json"] | path join
}

# Read the last consolidation date from the state file.
def get-consolidation-state [vault: path]: nothing -> any {
    let state_file = get-state-path $vault
    if ($state_file | path exists) {
        return (open $state_file)
    }
    let default_date = (date now) - 30day | format date "%Y-%m-%dT%H:%M:%SZ"
    return { last_consolidation_date: $default_date }
}

# Update the last consolidation date in the state file.
def set-consolidation-state [date: datetime, vault: path]: nothing -> nothing {
    let state_file = get-state-path $vault
    let state = { last_consolidation_date: ($date | format date "%Y-%m-%dT%H:%M:%SZ") }
    let dir = $state_file | path dirname
    if not ($dir | path exists) { mkdir $dir }
    $state | save -f $state_file
}

# Gathers entries from episodic memory notes since the last consolidation.
def gather-unconsolidated-memories [vault: path]: nothing -> list<record> {
    let agents_memory = $"($vault)/AGENTS_MEMORY"
    if not ($agents_memory | path exists) { return [] }

    let state = get-consolidation-state $vault
    let since_date = $state.last_consolidation_date | into datetime

    let files = glob ([$agents_memory "*" "*.md"] | path join)
        | each { |f| ls $f }
        | flatten
        | where type == file and name =~ '\d{4}-\d{2}-\d{2}\.md$'
        | where { |f| 
            let file_date = try { 
                $f.name | path basename | str replace ".md" "" | into datetime 
            } catch { 
                $f.modified 
            }
            $file_date >= $since_date
        }
        | sort-by modified -r
        | get name
    
    $files | each { |f|
        let content = open --raw $f
        let project_dir = $f | path dirname
        let slug = $project_dir | path basename
        let index_file = [$project_dir $"($slug).md"] | path join
        let project_name = if ($index_file | path exists) {
            let index_content = open --raw $index_file
            let fm = parse-frontmatter $index_content
            try { $fm.project_name } catch { null }
        } else { null }
        let body = get-body $content
        let len = $body | str length
        let start = if $len > 2000 { $len - 2000 } else { 0 }
        let recent_body = $body | str substring $start..$len
        let date = $f | path basename | str replace ".md" ""
        {
            project_name: $project_name,
            last_updated: $date,
            recent_body: $recent_body,
            slug: $slug
        }
    } | compact
}

# Helper to check if a slug has a collision.
def resolve-unique-slug [slug: string, absolute_path: path, vault: path]: nothing -> any {
    let path_str = $absolute_path | path expand | into string
    mut current_slug = $slug
    mut counter = 0
    loop {
        if $counter > 99 {
            let ts = date now | format date "%Y%m%d%H%M%S"
            return $"($slug)_($ts)"
        }
        let note_path = get-note-path $current_slug $vault
        if not ($note_path | path exists) { return $current_slug }
        let content = open --raw $note_path
        let data = parse-frontmatter $content
        if $data != null {
            let note_abs_path = if not ($data.absolute_path? | is-empty) {
                try { $data.absolute_path | path expand | into string } catch { "" }
            } else { "" }
            if $note_abs_path == $path_str { return $current_slug }
        }
        $counter = $counter + 1
        $current_slug = $"($slug)_($counter)"
    }
}

# Retrieve project metadata.
def get-init-metadata [path: path, vault: path]: nothing -> any {
    let root_info = find-project-root $path
    let project_dir = $root_info.path
    let project_name_default = $project_dir | path basename
    let product_md = $"($project_dir)/conductor/product.md"
    mut project_name = $project_name_default
    mut description = ""
    if ($product_md | path exists) {
        let content = open --raw $product_md
        let parsed_name = $content | parse --regex '(?m)^# Product Definition: (?P<name>.*)$'
        if not ($parsed_name | is-empty) { $project_name = $parsed_name | get 0.name | str trim }
        let parsed_summary = $content | parse --regex '(?ms)## Summary\s*\n(?P<summary>.*?)(?:\n##|$)'
        if not ($parsed_summary | is-empty) { $description = $parsed_summary | get 0.summary | str trim | str replace --all "\n" " " }
    }
    let has_git_cmd = (which git | is-not-empty)
    let uses_git = ($"($project_dir)/.git" | path exists) or ($has_git_cmd and ((try { ^git -C $project_dir rev-parse --is-inside-work-tree | complete | get exit_code } catch { 1 }) == 0))
    let uses_conductor = $"($project_dir)/conductor" | path exists
    mut raw_slug = $project_name | str downcase | str replace --all " " "_" | str replace --all "-" "_" | str replace --regex --all "[^a-z0-9_]" ""
    if ($raw_slug | is-empty) { $raw_slug = "project" }
    let slug = resolve-unique-slug $raw_slug $project_dir $vault
    { project_name: $project_name, absolute_path: ($project_dir | into string), description: $description, uses_conductor: $uses_conductor, uses_git: $uses_git, slug: $slug }
}

# Helper to clean markdown blocks wrapped by LLMs (e.g. ```markdown)
def clean-markdown-block []: string -> string {
    let content = $in | str trim
    if ($content | str starts-with "```") {
        let lines = $content | lines
        return ($lines | skip 1 | drop 1 | str join "\n")
    }
    return $content
}

# --- HISTORY LOADERS ---

# Load Antigravity history (JSONL)
def load-agy-history []: nothing -> list<record> {
    let path = "~/.gemini/antigravity-cli/history.jsonl" | path expand
    if not ($path | path exists) { return [] }
    
    open $path 
        | lines 
        | each { |line| 
            let e = try { $line | from json } catch { null }
            if ($e == null) or ($e.display? | is-empty) { return null }
            { 
                text: $e.display, 
                timestamp: ($e.timestamp | into datetime), 
                source: "Antigravity" 
            }
        } 
        | compact
}

# Load Claude Code history (JSONL)
def load-claude-history []: nothing -> list<record> {
    let path = "~/.claude/history.jsonl" | path expand
    if not ($path | path exists) { return [] }
    
    open $path 
        | lines 
        | each { |line| 
            let e = try { $line | from json } catch { null }
            if ($e == null) or ($e.display? | is-empty) { return null }
            { 
                text: $e.display, 
                timestamp: ($e.timestamp | into datetime), 
                source: "Claude Code" 
            }
        } 
        | compact
}

# Load Gemini CLI history (Raw shell_history files)
def load-gemini-history []: nothing -> list<record> {
    let tmp_dir = "~/.gemini/tmp" | path expand
    if not ($tmp_dir | path exists) { return [] }
    
    let history_files = glob ([$tmp_dir "*" "shell_history"] | path join)
    
    $history_files | each { |f|
        let modified = (ls $f | get 0.modified)
        open --raw $f 
            | lines 
            | where { |l| $l | is-not-empty }
            | each { |l| 
                { 
                    text: $l, 
                    timestamp: $modified, # Fallback to file modification time
                    source: "Gemini CLI" 
                } 
            }
    } | flatten
}

# Aggregate and sort history from all sources
def aggregate-history [limit: int = 50]: nothing -> string {
    let agy = load-agy-history
    let claude = load-claude-history
    let gemini = load-gemini-history
    
    let all = [$agy $claude $gemini] 
        | flatten 
        | sort-by timestamp 
        | last $limit
    
    $all | each { |e| 
        let ts = ($e.timestamp | format date "%Y-%m-%d %H:%M")
        $"[($ts)] [($e.source)] ($e.text)" 
    } | str join "\n"
}

# --- MAIN AGENT COMMANDS ---

export def agent-self-improve [] {
    let vault = (get-vault)
    let agents_memory = [$vault "AGENTS_MEMORY"] | path join
    let brain_path = [$agents_memory "BRAIN.md"] | path join
    let soul_path = [$agents_memory "SOUL.md"] | path join
    let log_path = [$agents_memory "log.log"] | path join
    
    if not ($brain_path | path exists) or not ($soul_path | path exists) {
        print "Error: BRAIN.md or SOUL.md not found in the vault."
        exit 1
    }
    
    let brain_content = open --raw $brain_path
    let soul_content = open --raw $soul_path
    
    # Gather unconsolidated memories since last successful run
    let memories = gather-unconsolidated-memories $vault
    if ($memories | is-empty) {
        print "No unconsolidated memories found. Skipping curation."
        return
    }
    
    let memories_text = $memories | each { |m|
        $"Project: ($m.project_name)\nDate: ($m.last_updated)\nSlug: ($m.slug)\nSummary:\n($m.recent_body)\n---"
    } | str join "\n"
    
    let context = [
        "=== CURRENT BRAIN ==="
        $brain_content
        ""
        "=== CURRENT SOUL ==="
        $soul_content
        ""
        "=== UNCONSOLIDATED MEMORIES ==="
        $memories_text
    ] | str join "\n"
    
    print $"Calling google_ai to consolidate memories..."
    let output = $context | google_ai --select_system semantic_memory_curator --select_preprompt semantic_memory_curator
    if ($output | is-empty) {
        print "Error: AI command returned empty output."
        exit 1
    }
    
    # Parse the output
    let brain_match = $output | parse --regex '(?s)=== NEW BRAIN ===\s*\n(?P<content>.*?)(?:\n===|$)'
    let soul_match = $output | parse --regex '(?s)=== NEW SOUL ===\s*\n(?P<content>.*?)(?:\n===|$)'
    let log_match = $output | parse --regex '(?s)=== LOG ===\s*\n(?P<content>.*?)(?:\n===|$)'
    
    if ($brain_match | is-empty) or ($soul_match | is-empty) {
        print "Error: Failed to parse BRAIN or SOUL updates from response."
        print $"Raw Output:\n($output)"
        exit 1
    }
    
    let new_brain = $brain_match | get 0.content | clean-markdown-block
    let new_soul = $soul_match | get 0.content | clean-markdown-block
    let log_msg = if ($log_match | is-empty) { "Consolidated global memories" } else { $log_match | get 0.content | str trim }
    
    # Create backups
    let brain_bak = $"($brain_path).bak"
    let soul_bak = $"($soul_path).bak"

    try {
        cp $brain_path $brain_bak
        cp $soul_path $soul_bak

        # Write files
        $new_brain | save -f $brain_path
        $new_soul | save -f $soul_path
        
        # Remove backups on success
        rm $brain_bak
        rm $soul_bak
    } catch { |err|
        # Restore backups on failure
        if ($brain_bak | path exists) {
            mv -f $brain_bak $brain_path
        }
        if ($soul_bak | path exists) {
            mv -f $soul_bak $soul_path
        }
        error make { msg: $"Failed to save BRAIN/SOUL updates: ($err.msg)" }
    }
    
    # Write to log.log
    let timestamp = date now | format date "%Y-%m-%d %H:%M:%S"
    let log_entry = $"[($timestamp)] [BRAIN/SOUL] ($log_msg)\n"
    if ($log_path | path exists) {
        let current_log = open --raw $log_path
        $"($log_entry)($current_log)" | save -f $log_path
    } else {
        $log_entry | save -f $log_path
    }
    
    # Dynamically detect active project slug, fallback to default
    let project_slug = try {
        let meta = get-init-metadata (pwd) $vault
        $meta.slug
    } catch {
        "gemini_cli_expert_skill_library"
    }
    
    # Update current project daily episodic memory
    let today = date now | format date "%Y-%m-%d"
    let project_dir = [$vault "AGENTS_MEMORY" $project_slug] | path join
    mkdir $project_dir
    
    let daily_file = [$project_dir $"($today).md"] | path join
    let daily_entry = [
        "### Memory Self-Improvement"
        "Consolidated global memories (BRAIN.md/SOUL.md) and logged changes:"
        $"- ($log_msg)"
    ] | str join "\n"
    
    if ($daily_file | path exists) {
        let current_daily = open --raw $daily_file
        $"($current_daily)\n\n($daily_entry)" | save -f $daily_file
    } else {
        $daily_entry | save -f $daily_file
    }
    
    # Update last_updated in index
    let index_file = [$project_dir $"($project_slug).md"] | path join
    if ($index_file | path exists) {
        let index_content = open --raw $index_file
        # Fixed: Use double quotes and properly escaped backslashes for Nushell string regex
        let updated_content = $index_content | str replace --regex "last_updated:\\s*[\"']?\\d{4}-\\d{2}-\\d{2}[\"']?" $"last_updated: ($today)"
        $updated_content | save -f $index_file
    }
    
    # Update consolidation state (Only on full success)
    set-consolidation-state (date now) $vault
    
    print "Memory self-improvement completed successfully!"
}

export def agent-skill-developer [] {
    let vault = (get-vault)
    let draft_dir = [$vault "_draft_skills"] | path join
    if not ($draft_dir | path exists) { mkdir $draft_dir }
    
    # --- PHASE 1: ANALYZE AND CREATE DRAFT PLANS ---
    print "Running Phase 1: Analyzing aggregated CLI history..."
    let history_text = aggregate-history 100
    
    if ($history_text | is-empty) {
        print "No CLI history found across sources."
        return
    }
    
    let today = date now | format date "%Y-%m-%d"
    let draft_file = [$draft_dir $"($today).md"] | path join
    
    if not ($draft_file | path exists) {
        let context = [
            "=== AGGREGATED HISTORY ==="
            $history_text
            ""
            "=== METADATA ==="
            $"Today: ($today)"
        ] | str join "\n"
        
        print "Calling google_ai to generate skill proposal..."
        let proposal = $context | google_ai --select_system agent_skill_developer --select_preprompt agent_skill_developer_draft
        if ($proposal | is-not-empty) {
            $proposal | save -f $draft_file
            print $"Created skill plan at ($draft_file)"
            
            # Habitica Integration: Draft Notification
            try {
                let summary = $proposal | parse --regex 'summary: "(?P<text>.*?)"' | get 0.text? | default "New skill ideas detected"
                let todo_title = $"new skill draft: ($summary | str substring 0..50)..."
                habitica todos add $todo_title
            } catch {
                print "Warning: Failed to add Habitica todo for skill draft."
            }
        }
    } else {
        print $"Skill plan for ($today) already exists. Skipping drafting."
    }
    
    # --- PHASE 2: IMPLEMENT APPROVED PLANS ---
    print "Running Phase 2: Scanning for approved skill plans..."
    let drafts = glob ([$draft_dir "*.md"] | path join)
        | each { |f| $f | into string }
    
    for draft in $drafts {
        let content = open --raw $draft
        let fm = parse-frontmatter $content
        if $fm == null { continue }
        
        let status = try { $fm.status | str downcase } catch { "" }
        let implemented = try { $fm.implemented } catch { false }
        
        let is_approved = ($status == "approved" or $status == "partially approved" or ($content =~ '-\s*\[x\]\s*Approved' or $content =~ '-\s*\[x\]\s*Partially approved'))
        
        if $is_approved and not $implemented {
            print $"Found approved plan: ($draft). Implementing..."
            
            let context = [
                "=== APPROVED PLAN ==="
                $content
            ] | str join "\n"
            
            print "Calling google_ai to scaffold files..."
            let scaffold_out = $context | google_ai --select_system agent_skill_developer --select_preprompt agent_skill_developer_implement
            if ($scaffold_out | is-empty) {
                print "Error: Scaffold output was empty."
                continue
            }
            
            let files_data = $scaffold_out | parse --regex '(?s)=== FILE:\s*(?P<filepath>skills/.*?)\s*===\s*\n(?P<filecontent>.*?)(?:\n=== FILE:|$)'
            
            if ($files_data | is-empty) {
                print "Error: No files parsed from scaffold output."
                print $"Raw Output:\n($scaffold_out)"
                continue
            }
            
            mut created_skills = []
            let repo_root = try { $env.MY_ENV_VARS.llms_configs } catch { "~/Yandex.Disk/llms_configs" } | path expand
            for file in $files_data {
                let rel_path = $file.filepath | str trim
                let full_path = [$repo_root $rel_path] | path join
                let dir = $full_path | path dirname
                if not ($dir | path exists) { mkdir $dir }
                
                let file_content = $file.filecontent | str trim
                $file_content | save -f $full_path
                print $"Created file: ($rel_path)"
                
                let skill_name = $rel_path | split row "/" | get 1
                $created_skills = ($created_skills | append $skill_name)
            }
            $created_skills = ($created_skills | uniq)
            
            print "Linking new skills to Gemini CLI..."
            # Updated: Use link-skills (Nushell command) instead of gemini skills link
            try {
                link-skills
            } catch {
                print "Warning: link-skills command failed or not found."
            }
            
            # Habitica Integration: Skill Created Notification
            for skill in $created_skills {
                try {
                    # Try to find description and type in the plan
                    let pattern = ('(?s)## .*?' + $skill + '.*?\n(?P<section>.*?)(?:\n##|$)')
                    let matches = ($content | parse --regex $pattern)
                    let skill_section = if ($matches | is-not-empty) { $matches | get 0.section } else { "" }
                    let is_cron = ($skill | str starts-with "cron-")
                    let type_str = if $is_cron { "Cron" } else { "On-Demand" }
                    let regularity = if $is_cron { $skill_section | parse --regex 'Frequency: (?P<freq>.*)' | get 0.freq? | default "Not specified" } else { "N/A" }
                    let description = $skill_section | parse --regex 'Purpose: (?P<desc>.*)' | get 0.desc? | default "No description provided"
                    
                    let todo_title = $"new skill created: ($skill), use link-skills in deathnote and lenovo"
                    let todo_note = [
                        $"Type: ($type_str)"
                        $"Regularity: ($regularity)"
                        ""
                        "Description:"
                        $description
                    ] | str join "\n"
                    
                    habitica todos add $todo_title --notes $todo_note
                } catch {
                    print $"Warning: Failed to add Habitica todo for skill: ($skill)"
                }
            }
            
            let updated_content = $content
                | str replace --regex 'implemented:\s*false' 'implemented: true'
                | str replace --regex 'status:\s*".*?"' 'status: "Approved"'
            $updated_content | save -f $draft
            
            let log_path = [$vault "AGENTS_MEMORY" "log.log"] | path join
            let timestamp = date now | format date "%Y-%m-%d %H:%M:%S"
            let skill_list = $created_skills | str join ", "
            let log_msg = $"Implemented approved skills from plan: ($skill_list)"
            let log_entry = $"[($timestamp)] [SKILLS] ($log_msg)\n"
            if ($log_path | path exists) {
                let current_log = open --raw $log_path
                $"($log_entry)($current_log)" | save -f $log_path
            } else {
                $log_entry | save -f $log_path
            }
            
            let project_dir = [$vault "AGENTS_MEMORY" "gemini_cli_expert_skill_library"] | path join
            if not ($project_dir | path exists) { mkdir $project_dir }
            let today_file = [$project_dir $"($today).md"] | path join
            let daily_entry = [
                "### Skill Implementation"
                $"Implemented and linked approved skills: ($skill_list)"
                ("- Plan file: [" + ($draft | path basename) + "](file://" + ($draft | into string) + ")")
            ] | str join "\n"
            if ($today_file | path exists) {
                let current_daily = open --raw $today_file
                $"($current_daily)\n\n($daily_entry)" | save -f $today_file
            } else {
                $daily_entry | save -f $today_file
            }
            
            let index_file = [$project_dir "gemini_cli_expert_skill_library.md"] | path join
            if ($index_file | path exists) {
                let index_content = open --raw $index_file
                let updated_content_idx = $index_content | str replace --regex "last_updated:\\s*[\"']?\\d{4}-\\d{2}-\\d{2}[\"']?" $"last_updated: ($today)"
                $updated_content_idx | save -f $index_file
            }
            
            print $"Plan ($draft) successfully implemented!"
        }
    }
}
