# Manga & Torrent Automation Toolkit Module for Nushell
# Replaces legacy bash monitor scripts with structured, modern data pipelines.

# Parse and normalize manga URLs from text, fixing protocol quirks and trimming.
export def "manga parse-urls" [raw_input?: any] {
    let input = if ($raw_input | is-empty) { $in | default "" } else { $raw_input }
    if ($input | is-empty) {
        return []
    }

    let url_regex = '(?i)(?P<url>https?://[^\s"''\>]+)'
    let raw_lines = if ($input | describe | str starts-with "list") {
        ($input | each { |l| $l | into string | str trim } | where { |l| ($l | is-not-empty) })
    } else {
        ($input | into string | lines | each { |l| $l | str trim } | where { |l| ($l | is-not-empty) })
    }
    
    mut extracted = []
    for line in $raw_lines {
        # Check for malformed double-protocol: http://https:// or https://https://
        let sanitized = ($line 
            | str replace -r '(?i)^https?://https?://' 'https://'
            | str replace -r '(?i)^https?://http://' 'http://'
            | str trim
        )
        
        let matches = ($sanitized | parse -r $url_regex)
        if ($matches | is-not-empty) {
            for m in $matches {
                let u = ($m.url 
                    | str replace -r '(?i)^https?://https?://' 'https://'
                    | str replace -r '(?i)^https?://http://' 'http://'
                    | str trim
                )
                if ($u | is-not-empty) {
                    $extracted = ($extracted | append $u)
                }
            }
        }
    }

    return ($extracted | uniq)
}

# Resolve Dropbox sync conflict files (e.g. `mangaPendiente (1).txt`) by consolidating unique lines and cleaning duplicates.
export def "manga clean-duplicates" [
    prefix: string = "mangaPendiente"
    --dir: path = "/home/kira/Dropbox/Aplicaciones/Gmail"
] {
    if ($dir | path exists) == false {
        return { prefix: $prefix, consolidated_lines: 0, removed_files: [] }
    }

    let base_file = ($dir | path join $"($prefix).txt")
    let all_files = (try { ls -a -f $dir } catch { [] })
    let matching_files = ($all_files | where type == file and (($it.name | path basename) | str starts-with $prefix) and (($it.name | path basename) | str ends-with ".txt"))

    if ($matching_files | is-empty) {
        return { prefix: $prefix, consolidated_lines: 0, removed_files: [] }
    }

    # Gather all lines across base and conflict files
    mut all_lines = []
    mut conflict_files = []

    for f in $matching_files {
        let f_path = $f.name
        let f_name = ($f_path | path basename)
        if ($f_name == $"($prefix).txt") {
            # Base file
            let content = (try { open -r $f_path | lines | each { |l| $l | str trim } | where { |l| ($l | is-not-empty) } } catch { [] })
            $all_lines = ($all_lines | append $content)
        } else if ($f_name =~ ($"^" + $prefix + '\s*\(\d+\)\.txt$')) {
            # Conflict copy
            let content = (try { open -r $f_path | lines | each { |l| $l | str trim } | where { |l| ($l | is-not-empty) } } catch { [] })
            $all_lines = ($all_lines | append $content)
            $conflict_files = ($conflict_files | append $f_path)
        }
    }

    let unique_lines = ($all_lines | uniq)
    
    # Save back to base file
    if ($unique_lines | is-not-empty) {
        ($unique_lines | str join "\n" | $in + "\n") | save -f $base_file
    }

    # Remove conflict files
    for cf in $conflict_files {
        try { rm -f $cf } catch { }
    }

    return {
        prefix: $prefix,
        consolidated_lines: ($unique_lines | length),
        removed_files: $conflict_files
    }
}

# Purge obsolete legacy bash scratch and snapshot files from Dropbox Gmail and folderwatched.
export def "manga clean-legacy-files" [
    --dir: path = "/home/kira/Dropbox/Aplicaciones/Gmail"
    --folderwatched: path = "/home/kira/Dropbox/Aplicaciones/Gmail/folderwatched"
] {
    mut removed = []

    if ($dir | path exists) {
        let legacy_gmail_names = [
            "oldManga.txt", "oldMangaLatest.txt", "oldAnimePendiente.txt",
            "newManga.txt", "newMangaLatest.txt", "newAnimePendiente.txt"
        ]
        for name in $legacy_gmail_names {
            let target = ($dir | path join $name)
            if ($target | path exists) {
                try {
                    rm -f $target
                    $removed = ($removed | append $target)
                } catch { }
            }
        }
    }

    if ($folderwatched | path exists) {
        let legacy_folderwatched_names = [
            "temp", "temp2", "file1", "file2", "manga", "manga1",
            "mangaPendienteNew.txt", "mangaPendiente.txt"
        ]
        for name in $legacy_folderwatched_names {
            let target = ($folderwatched | path join $name)
            if ($target | path exists) {
                try {
                    rm -f $target
                    $removed = ($removed | append $target)
                } catch { }
            }
        }
    }

    return {
        removed_count: ($removed | length),
        removed_files: $removed
    }
}

# Extract all existing URLs from active and completed JDownloader crawljob files
def get-existing-crawljob-urls [folderwatched: path] {
    mut existing_urls = []
    let regex = '(?i)(?P<url>https?://[^\s,\]\n\r]+)'

    # Active crawljobs
    let active_files = (try { ls -a -f $folderwatched | where type == file and ($it.name =~ '(?i)\.crawljob$') } catch { [] })
    # Completed/added crawljobs
    let added_dir = ($folderwatched | path join "added")
    let added_files = (if ($added_dir | path exists) { try { ls -a -f $added_dir | where type == file and ($it.name =~ '(?i)\.crawljob$') } catch { [] } } else { [] })

    let all_jobs = ($active_files | append $added_files)
    for j in $all_jobs {
        try {
            let content = (open -r $j.name)
            let matches = ($content | parse -r $regex)
            if ($matches | is-not-empty) {
                let urls = ($matches | get url | each { |u| $u | str trim | str replace -r ',$' '' })
                $existing_urls = ($existing_urls | append $urls)
            }
        } catch {
            # Ignore read errors on corrupt/transient files
        }
    }

    return ($existing_urls | uniq)
}

# Generate a JDownloader crawljob file containing non-duplicate missing chapter URLs.
export def "manga crawljob generate" [
    urls: list<string>
    --folderwatched: path = "/home/kira/Dropbox/Aplicaciones/Gmail/folderwatched"
] {
    let clean_urls = ($urls | manga parse-urls)
    if ($clean_urls | is-empty) {
        return null
    }

    if ($folderwatched | path exists) == false {
        mkdir $folderwatched
    }

    let existing = (get-existing-crawljob-urls $folderwatched)
    let new_urls = ($clean_urls | where { |u| not ($u in $existing) })

    if ($new_urls | is-empty) {
        return null
    }

    let date_str = (date now | format date "%Y%m%d_%H%M%S")
    let filename = $"manga_crawljob_($date_str).crawljob"
    let filepath = ($folderwatched | path join $filename)

    mut lines = [
        "# Auto-generated by Nushell Manga Monitor"
        "enabled=true"
        "overwritePackagizerEnabled = false"
        "text = ["
    ]
    for u in $new_urls {
        $lines = ($lines | append $"  ($u),")
    }
    $lines = ($lines | append "]" "")
    let content = ($lines | str join "\n")

    $content | save -f $filepath
    return $filepath
}

# Scan Dropbox Gmail folder for new manga/anime chapters, clean duplicates, and generate crawljobs.
export def "manga sync" [
    --dir: path = "/home/kira/Dropbox/Aplicaciones/Gmail"
    --folderwatched: path = "/home/kira/Dropbox/Aplicaciones/Gmail/folderwatched"
    --state-file: path = "/home/kira/Dropbox/Aplicaciones/Gmail/.manga_monitor_state.json"
    --dry-run
] {
    if ($dir | path exists) == false {
        return { status: "skipped", reason: $"Directory ($dir) not found" }
    }

    # Step 1: Clean duplicate conflict files and legacy scratch files
    let cleaned_mp = (manga clean-duplicates "mangaPendiente" --dir $dir)
    let cleaned_ml = (manga clean-duplicates "mangaLatest" --dir $dir)
    let cleaned_ap = (manga clean-duplicates "animependiente" --dir $dir)
    let cleaned_legacy = (manga clean-legacy-files --dir $dir --folderwatched $folderwatched)

    # Step 2: Read URLs
    mut all_urls = []
    let target_files = ["mangaPendiente.txt", "mangaLatest.txt", "animependiente.txt"]
    for tf in $target_files {
        let full_path = ($dir | path join $tf)
        if ($full_path | path exists) {
            let content = (open -r $full_path)
            let urls = ($content | manga parse-urls)
            $all_urls = ($all_urls | append $urls)
        }
    }
    let unique_urls = ($all_urls | uniq)

    # Step 3: Check persistent state & existing crawljobs
    let state_path = ($state_file | path expand)
    let state_exists = ($state_path | path exists)
    let state_urls = if $state_exists {
        try { open $state_path } catch { [] }
    } else {
        []
    }

    let existing_crawljob_urls = (get-existing-crawljob-urls $folderwatched)

    # If state file does not exist, auto-seed with all existing URLs to prevent downloading historical chapters
    if (not $state_exists) {
        let initial_seed = ($unique_urls | append $existing_crawljob_urls | uniq)
        if (not $dry_run) {
            $initial_seed | save -f $state_path
        }
        return {
            status: "ok",
            total_source_urls: ($unique_urls | length),
            new_urls_found: 0,
            crawljob_created: null
        }
    }

    let all_known_urls = ($state_urls | append $existing_crawljob_urls | uniq)
    let pending_urls = ($unique_urls | where { |u| not ($u in $all_known_urls) })

    if ($pending_urls | is-empty) {
        return {
            status: "ok",
            total_source_urls: ($unique_urls | length),
            new_urls_found: 0,
            crawljob_created: null
        }
    }

    # Step 4: Generate crawljob
    let job_file = if $dry_run {
        $"[DRY RUN] Would create crawljob with ($pending_urls | length) URLs"
    } else {
        let created = (manga crawljob generate $pending_urls --folderwatched $folderwatched)
        if ($created != null) {
            # Update state file
            let updated_state = ($state_urls | append $pending_urls | uniq)
            $updated_state | save -f $state_path

            # Send Discord alert
            try {
                let msg = $"📚 **Nushell Manga Monitor**: Created new crawljob with ($pending_urls | length) (if ($pending_urls | length) == 1 { "chapter" } else { "chapters" }).\n($pending_urls | first 5 | str join "\n")"
                to-discord $msg --channel gemini_cli_cron -p
            } catch { }
        }
        $created
    }

    return {
        status: "ok",
        total_source_urls: ($unique_urls | length),
        new_urls_found: ($pending_urls | length),
        crawljob_created: $job_file
    }
}

# Scan Dropbox Gmail folder for new .torrent files and dispatch notifications.
export def "torrent sync" [
    --dir: path = "/home/kira/Dropbox/Aplicaciones/Gmail"
    --state-file: path = "~/.torrent_monitor_state.json"
    --dry-run
] {
    if ($dir | path exists) == false {
        return []
    }

    let all_files = (try { ls -a -f $dir } catch { [] })
    let torrent_files = ($all_files | where { |f| $f.type == "file" and ($f.name =~ '(?i)\.torrent') })

    if ($torrent_files | is-empty) {
        return []
    }

    let state_path = ($state_file | path expand)
    let state = if ($state_path | path exists) {
        try { open $state_path } catch { [] }
    } else {
        []
    }

    let new_torrents = ($torrent_files | where { |tf|
        let name = ($tf.name | path basename | str trim)
        not ($name in $state)
    })

    if ($new_torrents | is-empty) {
        return []
    }

    let torrent_names = ($new_torrents | each { |tf| $tf.name | path basename | str trim })

    if (not $dry_run) {
        let count = ($new_torrents | length)

        # Discord notification
        try {
            let msg = $"🧲 **Nushell Torrent Monitor**: Found ($count) new torrent (if $count == 1 { "file" } else { "files" }):\n($torrent_names | str join "\n")"
            to-discord $msg --channel gemini_cli_cron -p
        } catch { }

        # Update state file
        let updated_state = ($state | append $torrent_names | uniq)
        $updated_state | save -f $state_path
    }

    return ($new_torrents | each { |tf|
        {
            name: ($tf.name | path basename | str trim),
            path: $tf.name,
            size: $tf.size
        }
    })
}
