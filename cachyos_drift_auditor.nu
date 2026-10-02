# /home/kira/Yandex.Disk/my_scripts/nushell/cachyos_drift_auditor.nu
# Autonomous CachyOS system package and config drift auditor
# Integrates with Obsidian AGENTS_MEMORY/_drafts_drifts, Backups/linux, and Habitica

def get-vault-path []: nothing -> string {
    let env_vault = try { $env.MY_ENV_VARS.OBSIDIAN_VAULT_ROOT } catch { null }
    let vault = $env_vault | default $env.OBSIDIAN_VAULT_ROOT? | default "~/Yandex.Disk/obsidian/vaults"
    $vault | path expand
}

def get-default-backups-dir []: nothing -> string {
    let env_backups = try { $env.MY_ENV_VARS.linux_backup } catch { null }
    let dir = $env_backups | default "~/Yandex.Disk/Backups/linux"
    $dir | path expand
}

def get-default-package-lists-path []: nothing -> string {
    [(get-default-backups-dir) "conductor" "package_lists.json"] | path join
}

def get-default-rejected-path []: nothing -> string {
    [(get-default-backups-dir) "conductor" "rejected_drift.json"] | path join
}

def get-default-drafts-dir []: nothing -> string {
    [(get-vault-path) "AGENTS_MEMORY" "_drafts_drifts"] | path join
}

def get-default-processed-dir []: nothing -> string {
    [(get-default-drafts-dir) "processed_drafts"] | path join
}

def get-default-log-path []: nothing -> string {
    [(get-vault-path) "AGENTS_MEMORY" "log.log"] | path join
}

# Helper to print rich rules with graceful fallback
def print-rule [title: string, --style: string = "bold cyan"] {
    try {
        rich rule $title --style $style
    } catch {
        print $"=== ($title) ==="
    }
}

# Helper to print rich markup lines with graceful fallback
def print-rich [text: string] {
    try {
        rich print $text
    } catch {
        print ($text | str replace -r '\[/?.*?\]' '')
    }
}

# 1. detect-host-name
# Summary: Dynamically detects the current host machine name without static assumptions.
# Returns: String representing the hostname.
# Example: detect-host-name # => "lgomez-hpnote"
export def detect-host-name []: nothing -> string {
    try {
        sys host | get hostname
    } catch {
        try {
            ^hostname | str trim
        } catch {
            "cachyos-host"
        }
    }
}

# 1.1 ensure-host-registered
# Summary: Ensures a host machine profile exists in package_lists.json under `hosts`.
# Parameters:
#   --host: Hostname to check and register (defaults to detect-host-name)
#   --package-lists-path: Override path to package_lists.json
#   --dry-run: Preview without modifying package_lists.json
# Returns: Record with `registered`, `is_new`, `dry_run`, and `host`.
export def ensure-host-registered [
    --host: string
    --package-lists-path: string
    --dry-run
]: nothing -> record {
    let pkg_file = if ($package_lists_path != null) { $package_lists_path } else { get-default-package-lists-path }
    let target_host = if ($host != null) { $host } else { (detect-host-name) }
    if not ($pkg_file | path exists) {
        return { registered: false, is_new: false, dry_run: ($dry_run | default false), host: $target_host }
    }
    let data = (open $pkg_file)
    if not ("shared" in $data) {
        return { registered: false, is_new: false, dry_run: ($dry_run | default false), host: $target_host }
    }
    let hosts_map = ($data.hosts? | default {})
    if ($target_host in ($hosts_map | columns)) {
        return { registered: false, is_new: false, dry_run: ($dry_run | default false), host: $target_host }
    }

    if $dry_run {
        return { registered: true, is_new: true, dry_run: true, host: $target_host }
    }

    let updated_hosts = ($hosts_map | insert $target_host { official: [], aur: [] })
    let updated_data = ($data | update hosts $updated_hosts)
    $updated_data | to json --indent 2 | save -f $pkg_file
    { registered: true, is_new: true, dry_run: false, host: $target_host }
}

# 2. get-local-packages
# Summary: Probes installed official and AUR packages on the local CachyOS host via pacman.
# Returns: Record with `official` and `aur` lists.
# Example: get-local-packages # => { official: [...], aur: [...] }
export def get-local-packages []: nothing -> record<official: list<string>, aur: list<string>> {
    let all_explicit = (try {
        ^pacman -Qqe | lines | each { |l| $l | str trim } | where { |l| ($l | str length) > 0 }
    } catch {
        []
    })

    let aur_explicit = (try {
        ^pacman -Qqm | lines | each { |l| $l | str trim } | where { |l| ($l | str length) > 0 }
    } catch {
        []
    })

    let official_explicit = ($all_explicit | where not ($it in $aur_explicit))

    {
        official: $official_explicit,
        aur: $aur_explicit
    }
}

# 3. audit-system-drift
# Summary: Calculates package drift between local system installations and declarative definitions.
# Parameters:
#   --package-lists-path: Path to package_lists.json (defaults to /home/kira/Yandex.Disk/Backups/linux/conductor/package_lists.json)
#   --rejected-drift-path: Path to rejected_drift.json (defaults to Backups/linux/conductor/rejected_drift.json)
#   --mock-system: Optional mock system record for testing
# Example: audit-system-drift --package-lists-path "custom.json"
export def audit-system-drift [
    --package-lists-path: string
    --rejected-drift-path: string
    --mock-system: record
]: nothing -> record {
    let pkg_file = if ($package_lists_path != null) { $package_lists_path } else { get-default-package-lists-path }
    let rej_file = if ($rejected_drift_path != null) { $rejected_drift_path } else { get-default-rejected-path }
    let current_host = (detect-host-name)

    let repo_data = if ($pkg_file | path exists) {
        open $pkg_file
    } else {
        { shared: { official: [], aur: [] }, hosts: {} }
    }

    let is_hierarchical = ("shared" in $repo_data)
    let hosts_map = if $is_hierarchical { ($repo_data.hosts? | default {}) } else { {} }
    let is_new_host = ($is_hierarchical and not ($current_host in ($hosts_map | columns)))

    let shared_off = if $is_hierarchical { ($repo_data.shared.official? | default []) } else { ($repo_data.official? | default []) }
    let shared_aur = if $is_hierarchical { ($repo_data.shared.aur? | default []) } else { ($repo_data.aur? | default []) }

    let host_profile = if ($current_host in ($hosts_map | columns)) {
        $hosts_map | get $current_host
    } else {
        { official: [], aur: [] }
    }
    let host_off = ($host_profile.official? | default [])
    let host_aur = ($host_profile.aur? | default [])

    let expected_official = ($shared_off | append $host_off | sort | uniq)
    let expected_aur = ($shared_aur | append $host_aur | sort | uniq)

    let rejected_data = if ($rej_file | path exists) {
        open $rej_file
    } else {
        { official: [], aur: [], files: [] }
    }

    let rej_official = ($rejected_data.official? | default [])
    let rej_aur = ($rejected_data.aur? | default [])

    let sys_packages = if ($mock_system != null) {
        $mock_system
    } else {
        get-local-packages
    }

    let sys_official = ($sys_packages.official? | default [])
    let sys_aur = ($sys_packages.aur? | default [])

    # All installed packages on system (including dependencies) to prevent false-positive "missing" alerts
    let all_installed_sys = if ($mock_system != null) {
        ($sys_official | append $sys_aur | uniq)
    } else {
        try {
            ^pacman -Qq | lines | each { |l| $l | str trim } | where { |l| ($l | str length) > 0 }
        } catch {
            ($sys_official | append $sys_aur | uniq)
        }
    }

    # Filter out items present in rejected_drift.json
    let unrejected_sys_off = ($sys_official | where not ($it in $rej_official))
    let unrejected_sys_aur = ($sys_aur | where not ($it in $rej_aur))

    # Calculate differences against expected (shared + current host)
    let new_official = ($unrejected_sys_off | where not ($it in $expected_official) | sort | uniq)
    let new_aur = ($unrejected_sys_aur | where not ($it in $expected_aur) | sort | uniq)

    let missing_official = ($expected_official | where not ($it in $all_installed_sys) | sort | uniq)
    let missing_aur = ($expected_aur | where not ($it in $all_installed_sys) | sort | uniq)

    let suppressed_official = ($sys_official | where ($it in $rej_official) and not ($it in $expected_official) | sort | uniq)
    let suppressed_aur = ($sys_aur | where ($it in $rej_aur) and not ($it in $expected_aur) | sort | uniq)

    let suppressed_count = (($suppressed_official | length) + ($suppressed_aur | length))
    let total_drift = (($new_official | length) + ($new_aur | length) + ($missing_official | length) + ($missing_aur | length))

    {
        target_host: $current_host,
        is_new_host: $is_new_host,
        mode: "local",
        package_lists_path: $pkg_file,
        rejected_drift_path: $rej_file,
        counts: {
            new_official: ($new_official | length),
            new_aur: ($new_aur | length),
            missing_official: ($missing_official | length),
            missing_aur: ($missing_aur | length),
            suppressed: $suppressed_count,
            total_drift: $total_drift
        },
        drift: {
            new_official: $new_official,
            new_aur: $new_aur,
            missing_official: $missing_official,
            missing_aur: $missing_aur,
            suppressed_official: $suppressed_official,
            suppressed_aur: $suppressed_aur
        }
    }
}

# 4. format-drift-markdown
# Summary: Formats an audit result into reviewable Markdown text with YAML frontmatter and decision checkboxes.
# Parameters:
#   audit_res: Record returned by audit-system-drift
#   --date: Optional override date (YYYY-MM-DD)
# Example: format-drift-markdown $res --date "2026-10-01"
export def format-drift-markdown [
    audit_res: record
    --date: string
]: nothing -> string {
    let d = if ($date != null) { $date } else { date now | format date "%Y-%m-%d" }
    let host = $audit_res.target_host
    let counts = $audit_res.counts
    let drift = $audit_res.drift
    let pkg_path = (get-default-package-lists-path)

    let actionable_total = (($counts.new_official) + ($counts.new_aur) + ($counts.missing_official) + ($counts.missing_aur))
    let missing_total = (($counts.missing_official) + ($counts.missing_aur))

    mut draft_lines = [
        "---",
        $"date: \"($d)\"",
        $"target_host: \"($host)\"",
        "implemented: false",
        "---",
        "",
        $"# CachyOS System Drift Audit: ($d)",
        "",
        "## Summary",
        $"- Target Host: `($host)`",
        "- Execution Mode: `local`",
        $"- New Official Packages: ($counts.new_official)",
        $"- New AUR Packages: ($counts.new_aur)",
        $"- Missing / Uninstalled Packages: ($missing_total)",
        ("- Suppressed [Rejected] Packages: " + ($counts.suppressed | into string)),
        $"- Total Actionable Items: ($actionable_total)",
        ""
    ]

    if ($counts.new_official > 0) {
        $draft_lines = ($draft_lines | append [
            "## 1. Proposed New Official Packages",
            "Choose whether to share across all machines, keep host-specific, or reject.",
            ""
        ])

        for pkg in $drift.new_official {
            $draft_lines = ($draft_lines | append [
                $"### Package: `($pkg)`",
                "- **Category**: Official Repository Package",
                $"- **Status**: Installed on CachyOS \(`($host)`\), missing from declarative manifest",
                "- **Proposed Action**: Add to shared manifest or host profile",
                "- **Decision**:",
                "  - [ ] Add to Shared",
                $"  - [ ] Add to ($host) only",
                "  - [ ] Not Approved",
                ""
            ])
        }
    }

    if ($counts.new_aur > 0) {
        $draft_lines = ($draft_lines | append [
            "## 2. Proposed New AUR Packages",
            "Choose whether to share across all machines, keep host-specific, or reject.",
            ""
        ])

        for pkg in $drift.new_aur {
            $draft_lines = ($draft_lines | append [
                $"### Package: `($pkg)`",
                "- **Category**: AUR Foreign Package",
                $"- **Status**: Installed via paru/AUR on CachyOS \(`($host)`\), missing from declarative manifest",
                "- **Proposed Action**: Add to shared manifest or host profile",
                "- **Decision**:",
                "  - [ ] Add to Shared",
                $"  - [ ] Add to ($host) only",
                "  - [ ] Not Approved",
                ""
            ])
        }
    }

    if ($missing_total > 0) {
        $draft_lines = ($draft_lines | append [
            "## 3. Missing Packages (Declared in Manifest, Absent Locally)",
            $"These packages are declared in `package_lists.json` but are not installed on `($host)`.",
            "Mark `- [x] Install on this machine` to achieve parity.",
            "Mark `- [x] Exclude from host` if this package is not needed on this hardware.",
            "Mark `- [x] Remove from Shared everywhere` to purge globally.",
            ""
        ])

        let missing_off = if ("missing_official" in $drift) { $drift.missing_official } else { [] }
        for pkg in $missing_off {
            $draft_lines = ($draft_lines | append [
                $"### Package: `($pkg)`",
                "- **Category**: Official Repo (Missing locally)",
                $"- **Status**: Declared in manifest, but absent on `($host)`",
                "- **Proposed Action**: Install locally or exclude from host",
                "- **Decision**:",
                "  - [ ] Install on this machine",
                $"  - [ ] Exclude from ($host)",
                "  - [ ] Remove from Shared everywhere",
                ""
            ])
        }

        let missing_a = if ("missing_aur" in $drift) { $drift.missing_aur } else { [] }
        for pkg in $missing_a {
            $draft_lines = ($draft_lines | append [
                $"### Package: `($pkg)`",
                "- **Category**: AUR (Missing locally)",
                $"- **Status**: Declared in manifest, but absent on `($host)`",
                "- **Proposed Action**: Install locally or exclude from host",
                "- **Decision**:",
                "  - [ ] Install on this machine",
                $"  - [ ] Exclude from ($host)",
                "  - [ ] Remove from Shared everywhere",
                ""
            ])
        }
    }

    $draft_lines | str join (char nl)
}

# 5. write-drift-draft
# Summary: Generates a dated review draft atomically in Obsidian AGENTS_MEMORY/_drafts_drifts.
# Parameters:
#   audit_res: Record returned by audit-system-drift
#   --drafts-dir: Target directory (defaults to AGENTS_MEMORY/_drafts_drifts)
#   --date: Optional date string
#   --force: Overwrite today's draft even if existing
#   --dry-run: Simulate without writing to disk
# Example: write-drift-draft $res --dry-run
export def write-drift-draft [
    audit_res: record
    --drafts-dir: string
    --date: string
    --force
    --dry-run
]: nothing -> record {
    let d = if ($date != null) { $date } else { date now | format date "%Y-%m-%d" }
    let target_dir = if ($drafts_dir != null) { $drafts_dir } else { get-default-drafts-dir }

    if not ($target_dir | path exists) {
        mkdir $target_dir
    }

    let actionable_drift = (($audit_res.counts.new_official) + ($audit_res.counts.new_aur) + ($audit_res.counts.missing_official) + ($audit_res.counts.missing_aur))
    if ($actionable_drift == 0) {
        return {
            created: false,
            path: null,
            reason: "zero_drift",
            message: "No package drift detected against repository. No review draft needed."
        }
    }

    let draft_filename = $"($d).md"
    let draft_path = $"($target_dir)/($draft_filename)"

    if $dry_run {
        return {
            created: true,
            dry_run: true,
            path: $draft_path,
            date: $d,
            counts: $audit_res.counts,
            message: ("(DRY-RUN) Draft would be written to " + $draft_path)
        }
    }

    if ($draft_path | path exists) and (not $force) {
        let existing_content = (open --raw $draft_path)
        if ($existing_content =~ "implemented: true") {
            let timestamp_suffix = (date now | format date "%H%M%S")
            let suffixed_path = $"($target_dir)/($d)_($timestamp_suffix).md"
            let content = (format-drift-markdown $audit_res --date $d)
            $content | save -f $suffixed_path
            return {
                created: true,
                path: $suffixed_path,
                date: $d,
                counts: $audit_res.counts,
                message: $"Draft created at ($suffixed_path)"
            }
        }
    }

    let content = (format-drift-markdown $audit_res --date $d)
    let tmp_path = $"($target_dir)/.tmp_($draft_filename)"
    $content | save -f $tmp_path
    mv -f $tmp_path $draft_path

    {
        created: true,
        path: $draft_path,
        date: $d,
        counts: $audit_res.counts,
        message: $"Draft successfully written to ($draft_path)"
    }
}

# 6. notify-drift-habitica
# Summary: Dispatches Habitica todo notification with tag `software-updates-(host)` and checklist.
# Parameters:
#   draft_result: Record returned by write-drift-draft
#   audit_res: Record returned by audit-system-drift
#   --dry-run: Simulate without executing external API calls
# Example: notify-drift-habitica $draft_res $audit_res --dry-run
export def notify-drift-habitica [
    draft_result: record
    audit_res: record
    --dry-run
]: nothing -> record {
    if not ($draft_result.created? | default false) {
        return {
            success: true,
            notified: false,
            message: "No draft created, skipping Habitica notification."
        }
    }

    let d = $draft_result.date
    let counts = $draft_result.counts
    let host = $audit_res.target_host
    let drift = (if ("drift" in $audit_res) { $audit_res.drift } else { {} })

    let new_off = (if ("new_official" in $drift) { $drift.new_official } else { [] })
    let new_a = (if ("new_aur" in $drift) { $drift.new_aur } else { [] })
    let missing_off = (if ("missing_official" in $drift) { $drift.missing_official } else { [] })
    let missing_a = (if ("missing_aur" in $drift) { $drift.missing_aur } else { [] })

    mut items = []
    for pkg in $new_off { $items = ($items | append $"official: ($pkg)") }
    for pkg in $new_a { $items = ($items | append $"aur: ($pkg)") }
    for pkg in $missing_off { $items = ($items | append $"missing [official]: ($pkg)") }
    for pkg in $missing_a { $items = ($items | append $"missing [aur]: ($pkg)") }

    let checklist = if ($items | length) > 25 {
        let first_24 = ($items | first 24)
        let remaining = (($items | length) - 24)
        $first_24 | append $"... and ($remaining) more items in draft"
    } else {
        $items
    }

    let todo_text = ("Review CachyOS Drift Draft " + $d + " (" + $host + ")")
    let draft_path = if ("path" in $draft_result) { $draft_result.path } else { "" }
    let missing_sum = (($counts.missing_official) + ($counts.missing_aur))
    let notes = $"Review draft at ($draft_path)\nHost: ($host)\nOfficial: ($counts.new_official), AUR: ($counts.new_aur), Missing: ($missing_sum)"
    let habitica_tag = $"software-updates-($host)"

    if $dry_run {
        return {
            success: true,
            notified: true,
            dry_run: true,
            todo_text: $todo_text,
            tag: $habitica_tag,
            checklist: $checklist,
            message: ("(DRY-RUN) Habitica todo would be created for '" + $todo_text + "' with tag " + $habitica_tag + " and " + ($checklist | length | into string) + " items.")
        }
    }

    let call_res = (try {
        h add todos --text $todo_text --notes $notes --priority 1 --due '' --checklist $checklist --tag-name [$habitica_tag]
        { exit_code: 0, stdout: "Habitica task created", stderr: "" }
    } catch { |err|
        { exit_code: 1, stdout: "", stderr: ($err | into string) }
    })

    {
        success: ($call_res.exit_code == 0),
        notified: ($call_res.exit_code == 0),
        todo_text: $todo_text,
        tag: $habitica_tag,
        checklist_count: ($checklist | length),
        output: ($call_res.stdout | str trim),
        error: ($call_res.stderr | str trim)
    }
}

# 7. parse-drift-draft
# Summary: Parses a review draft Markdown file into individual structured package decisions.
# Parameters:
#   draft_path: Path to the .md draft file
# Returns: Record with `path`, `date`, and `items` table.
# Example: parse-drift-draft "/path/to/2026-10-01.md"
export def parse-drift-draft [draft_path: string]: nothing -> record {
    if not ($draft_path | path exists) {
        error make { msg: $"Draft file not found: ($draft_path)" }
    }

    let raw_text = (open --raw $draft_path)
    let sections = ($raw_text | split row "### Package: `")

    let date_lines = ($raw_text | lines | where {|l| $l =~ '^date:\s*'})
    let date_match = if ($date_lines | is-not-empty) { $date_lines | first } else { "" }
    let draft_date = if ($date_match | is-not-empty) {
        $date_match | str replace -r '^date:\s*"?([^"]*)"?.*$' '$1' | str trim
    } else {
        $draft_path | path parse | get stem
    }

    let host_lines = ($raw_text | lines | where {|l| $l =~ '^target_host:\s*'})
    let host_match = if ($host_lines | is-not-empty) { $host_lines | first } else { "" }
    let draft_host = if ($host_match | is-not-empty) {
        $host_match | str replace -r '^target_host:\s*"?([^"]*)"?.*$' '$1' | str trim
    } else {
        (detect-host-name)
    }

    let items = ($sections | skip 1 | each {|sec|
        let name = ($sec | split row "`" | first | str trim)
        let is_add_shared = ($sec =~ '-\s+\[[xX]\]\s+(?:Approved|Add to Shared)')
        let is_add_host = ($sec =~ '-\s+\[[xX]\]\s+Add to \S+ only')
        let is_install_local = ($sec =~ '-\s+\[[xX]\]\s+Install on this machine')
        let is_exclude_host = ($sec =~ '-\s+\[[xX]\]\s+Exclude from')
        let is_remove_shared = ($sec =~ '-\s+\[[xX]\]\s+(?:Remove from Shared everywhere|Remove from package_lists|Remove from)')
        let is_rejected = ($sec =~ '-\s+\[[xX]\]\s+Not Approved')

        let is_official = ($sec =~ 'Official Repo') or ($sec =~ 'package_lists\.json\.official')
        let is_aur = ($sec =~ 'AUR') or ($sec =~ 'package_lists\.json\.aur')

        mut decision = "unresolved"
        mut action = "unresolved"

        if $is_add_host {
            $decision = "approved"
            $action = "add_host"
        } else if $is_install_local {
            $decision = "approved"
            $action = "install_local"
        } else if $is_remove_shared {
            $decision = "approved"
            $action = "remove_shared"
        } else if $is_add_shared {
            $decision = "approved"
            $action = "add_shared"
        } else if $is_exclude_host {
            $decision = "rejected"
            $action = "exclude_host"
        } else if $is_rejected {
            $decision = "rejected"
            $action = "reject"
        }

        let target = if $is_aur { "aur" } else { "official" }
        let op = if ($action in ["remove_shared", "exclude_host"]) { "remove" } else if ($action == "install_local") { "install" } else { "add" }

        {
            name: $name,
            target: $target,
            op: $op,
            decision: $decision,
            action: $action
        }
    })

    {
        path: $draft_path,
        date: $draft_date,
        target_host: $draft_host,
        items: $items
    }
}

# 8. apply-drift-draft
# Summary: Applies approved decisions to package_lists.json (shared/hosts), executes local installations, and updates rejected_drift.json, pushing via ai git-push -G.
# Parameters:
#   draft_path: Path to the draft file
#   --package-lists-path: Override path to package_lists.json
#   --rejected-drift-path: Override path to rejected_drift.json
#   --processed-dir: Override path to processed_drafts directory
#   --dry-run: Preview without modifying files or installing packages
#   --no-push: Skip executing ai git-push -G
# Example: apply-drift-draft "/path/to/draft.md"
export def apply-drift-draft [
    draft_path: string
    --package-lists-path: string
    --rejected-drift-path: string
    --processed-dir: string
    --dry-run
    --no-push
    --skip-install
]: nothing -> record {
    let pkg_file = if ($package_lists_path != null) { $package_lists_path } else { get-default-package-lists-path }
    let rej_file = if ($rejected_drift_path != null) { $rejected_drift_path } else { get-default-rejected-path }
    let proc_dir = if ($processed_dir != null) { $processed_dir } else { get-default-processed-dir }

    if not ($pkg_file | path exists) {
        error make { msg: $"package_lists.json not found: ($pkg_file)" }
    }

    let parsed = (parse-drift-draft $draft_path)
    let draft_host = $parsed.target_host
    let items = $parsed.items

    let approved_items = ($items | where decision == "approved")
    let rejected_items = ($items | where decision == "rejected")
    let unresolved_items = ($items | where decision == "unresolved")

    if (($approved_items | length) == 0) and (($rejected_items | length) == 0) {
        return {
            processed: false,
            draft_path: $draft_path,
            approved_count: 0,
            rejected_count: 0,
            unresolved_count: ($unresolved_items | length),
            archived: false,
            message: "No approved or rejected items found. Draft remains in _drafts_drifts/."
        }
    }

    let add_shared_off = ($items | where action == "add_shared" and target == "official" | get name)
    let add_shared_aur = ($items | where action == "add_shared" and target == "aur" | get name)

    let add_host_off = ($items | where action == "add_host" and target == "official" | get name)
    let add_host_aur = ($items | where action == "add_host" and target == "aur" | get name)

    let remove_shared_off = ($items | where action == "remove_shared" and target == "official" | get name)
    let remove_shared_aur = ($items | where action == "remove_shared" and target == "aur" | get name)

    let exclude_host_off = ($items | where action == "exclude_host" and target == "official" | get name)
    let exclude_host_aur = ($items | where action == "exclude_host" and target == "aur" | get name)

    let install_local_off = ($items | where action == "install_local" and target == "official" | get name)
    let install_local_aur = ($items | where action == "install_local" and target == "aur" | get name)
    let all_to_install = ($install_local_off | append $install_local_aur | uniq)

    let reject_off = ($items | where action == "reject" and target == "official" | get name)
    let reject_aur = ($items | where action == "reject" and target == "aur" | get name)

    # 1. Update package_lists.json
    let repo_data = (open $pkg_file)
    let is_hierarchical = ("shared" in $repo_data)

    let updated_pkg_data = if $is_hierarchical {
        mut shared_off = ($repo_data.shared.official? | default [])
        mut shared_aur = ($repo_data.shared.aur? | default [])
        mut hosts_map = ($repo_data.hosts? | default {})

        if not ($draft_host in ($hosts_map | columns)) {
            $hosts_map = ($hosts_map | insert $draft_host { official: [], aur: [] })
        }

        # 1. add_shared
        if ($add_shared_off | is-not-empty) {
            $shared_off = ($shared_off | append $add_shared_off)
            for h in ($hosts_map | columns) {
                let h_val = ($hosts_map | get $h)
                let h_off = ($h_val.official? | default [] | where not ($it in $add_shared_off))
                let h_aur = ($h_val.aur? | default [])
                $hosts_map = ($hosts_map | upsert $h { official: ($h_off | sort | uniq), aur: ($h_aur | sort | uniq) })
            }
        }
        if ($add_shared_aur | is-not-empty) {
            $shared_aur = ($shared_aur | append $add_shared_aur)
            for h in ($hosts_map | columns) {
                let h_val = ($hosts_map | get $h)
                let h_off = ($h_val.official? | default [])
                let h_aur = ($h_val.aur? | default [] | where not ($it in $add_shared_aur))
                $hosts_map = ($hosts_map | upsert $h { official: ($h_off | sort | uniq), aur: ($h_aur | sort | uniq) })
            }
        }

        # 2. add_host
        if ($add_host_off | is-not-empty) {
            let curr_h_val = ($hosts_map | get $draft_host)
            let updated_h_off = ($curr_h_val.official? | default [] | append $add_host_off | sort | uniq)
            $hosts_map = ($hosts_map | upsert $draft_host { official: $updated_h_off, aur: ($curr_h_val.aur? | default []) })
        }
        if ($add_host_aur | is-not-empty) {
            let curr_h_val = ($hosts_map | get $draft_host)
            let updated_h_aur = ($curr_h_val.aur? | default [] | append $add_host_aur | sort | uniq)
            $hosts_map = ($hosts_map | upsert $draft_host { official: ($curr_h_val.official? | default []), aur: $updated_h_aur })
        }

        # 3. remove_shared
        if ($remove_shared_off | is-not-empty) {
            $shared_off = ($shared_off | where not ($it in $remove_shared_off))
            for h in ($hosts_map | columns) {
                let h_val = ($hosts_map | get $h)
                let h_off = ($h_val.official? | default [] | where not ($it in $remove_shared_off))
                let h_aur = ($h_val.aur? | default [])
                $hosts_map = ($hosts_map | upsert $h { official: ($h_off | sort | uniq), aur: ($h_aur | sort | uniq) })
            }
        }
        if ($remove_shared_aur | is-not-empty) {
            $shared_aur = ($shared_aur | where not ($it in $remove_shared_aur))
            for h in ($hosts_map | columns) {
                let h_val = ($hosts_map | get $h)
                let h_off = ($h_val.official? | default [])
                let h_aur = ($h_val.aur? | default [] | where not ($it in $remove_shared_aur))
                $hosts_map = ($hosts_map | upsert $h { official: ($h_off | sort | uniq), aur: ($h_aur | sort | uniq) })
            }
        }

        # 4. exclude_host
        if ($exclude_host_off | is-not-empty) {
            $shared_off = ($shared_off | where not ($it in $exclude_host_off))
            for h in ($hosts_map | columns) {
                let h_val = ($hosts_map | get $h)
                mut h_off = ($h_val.official? | default [])
                let h_aur = ($h_val.aur? | default [])
                if $h == $draft_host {
                    $h_off = ($h_off | where not ($it in $exclude_host_off))
                } else {
                    $h_off = ($h_off | append $exclude_host_off)
                }
                $hosts_map = ($hosts_map | upsert $h { official: ($h_off | sort | uniq), aur: ($h_aur | sort | uniq) })
            }
        }
        if ($exclude_host_aur | is-not-empty) {
            $shared_aur = ($shared_aur | where not ($it in $exclude_host_aur))
            for h in ($hosts_map | columns) {
                let h_val = ($hosts_map | get $h)
                let h_off = ($h_val.official? | default [])
                mut h_aur = ($h_val.aur? | default [])
                if $h == $draft_host {
                    $h_aur = ($h_aur | where not ($it in $exclude_host_aur))
                } else {
                    $h_aur = ($h_aur | append $exclude_host_aur)
                }
                $hosts_map = ($hosts_map | upsert $h { official: ($h_off | sort | uniq), aur: ($h_aur | sort | uniq) })
            }
        }

        {
            shared: {
                official: ($shared_off | sort | uniq),
                aur: ($shared_aur | sort | uniq)
            },
            hosts: $hosts_map
        }
    } else {
        # Legacy flat schema fallback
        mut curr_off = ($repo_data.official? | default [])
        mut curr_aur = ($repo_data.aur? | default [])

        let all_off_adds = ($add_shared_off | append $add_host_off)
        let all_aur_adds = ($add_shared_aur | append $add_host_aur)
        let all_off_removes = ($remove_shared_off | append $exclude_host_off)
        let all_aur_removes = ($remove_shared_aur | append $exclude_host_aur)

        if ($all_off_adds | is-not-empty) { $curr_off = ($curr_off | append $all_off_adds) }
        if ($all_off_removes | is-not-empty) { $curr_off = ($curr_off | where not ($it in $all_off_removes)) }
        if ($all_aur_adds | is-not-empty) { $curr_aur = ($curr_aur | append $all_aur_adds) }
        if ($all_aur_removes | is-not-empty) { $curr_aur = ($curr_aur | where not ($it in $all_aur_removes)) }

        {
            official: ($curr_off | sort | uniq),
            aur: ($curr_aur | sort | uniq)
        }
    }

    # 2. Update rejected_drift.json
    let rej_data = if ($rej_file | path exists) {
        open $rej_file
    } else {
        { official: [], aur: [], files: [] }
    }
    mut r_off = ($rej_data.official? | default [])
    mut r_aur = ($rej_data.aur? | default [])
    let r_files = ($rej_data.files? | default [])

    if ($reject_off | is-not-empty) {
        $r_off = ($r_off | append $reject_off)
    }
    if ($reject_aur | is-not-empty) {
        $r_aur = ($r_aur | append $reject_aur)
    }

    let updated_rej_data = {
        official: ($r_off | sort | uniq),
        aur: ($r_aur | sort | uniq),
        files: $r_files
    }

    # 3. Local package installation for install_local
    if ($all_to_install | is-not-empty) and (not $dry_run) and (not $skip_install) {
        try {
            print $"Installing ($all_to_install | length) missing packages locally via paru..."
            ^paru -S --needed --noconfirm ...$all_to_install
        } catch { |err|
            print $"Warning: Failed to install packages via paru: ($err)"
        }
    }

    if $dry_run {
        return {
            processed: true,
            dry_run: true,
            draft_path: $draft_path,
            target_host: $draft_host,
            approved_count: ($approved_items | length),
            rejected_count: ($rejected_items | length),
            unresolved_count: ($unresolved_items | length),
            added_official: ($add_shared_off | append $add_host_off | sort | uniq),
            removed_official: ($remove_shared_off | append $exclude_host_off | sort | uniq),
            added_aur: ($add_shared_aur | append $add_host_aur | sort | uniq),
            removed_aur: ($remove_shared_aur | append $exclude_host_aur | sort | uniq),
            added_shared_official: $add_shared_off,
            added_shared_aur: $add_shared_aur,
            added_host_official: $add_host_off,
            added_host_aur: $add_host_aur,
            installed_local: $all_to_install,
            rejected_official: $reject_off,
            rejected_aur: $reject_aur,
            archived: (($unresolved_items | length) == 0)
        }
    }

    # Write files
    $updated_pkg_data | to json --indent 2 | save -f $pkg_file
    $updated_rej_data | to json --indent 2 | save -f $rej_file

    # If all items resolved, archive draft
    mut archived = false
    if ($unresolved_items | length) == 0 {
        if not ($proc_dir | path exists) {
            mkdir $proc_dir
        }
        let raw_content = (open --raw $draft_path)
        let updated_content = ($raw_content | str replace "implemented: false" "implemented: true")
        let filename = ($draft_path | path basename)
        let target_proc_path = $"($proc_dir)/($filename)"

        $updated_content | save -f $target_proc_path
        rm -f $draft_path
        $archived = true
    }

    # Commit and push package_lists.json using ai git-push -G by default
    mut commit_hash: any = null
    if (not $no_push) {
        let repo_dir = get-default-backups-dir
        if ($pkg_file | str starts-with $repo_dir) and ([$repo_dir ".git"] | path join | path exists) {
            try {
                do {
                    cd $repo_dir
                    ai git-push -G
                }
                $commit_hash = (try { ^git -C $repo_dir log -1 --format="%h" | str trim } catch { null })
            } catch { |err|
                print $"Warning: ai git-push -G failed: ($err)"
            }
        }
    }

    {
        processed: true,
        dry_run: false,
        draft_path: $draft_path,
        target_host: $draft_host,
        approved_count: ($approved_items | length),
        rejected_count: ($rejected_items | length),
        unresolved_count: ($unresolved_items | length),
        added_official: ($add_shared_off | append $add_host_off | sort | uniq),
        removed_official: ($remove_shared_off | append $exclude_host_off | sort | uniq),
        added_aur: ($add_shared_aur | append $add_host_aur | sort | uniq),
        removed_aur: ($remove_shared_aur | append $exclude_host_aur | sort | uniq),
        added_shared_official: $add_shared_off,
        added_shared_aur: $add_shared_aur,
        added_host_official: $add_host_off,
        added_host_aur: $add_host_aur,
        installed_local: $all_to_install,
        rejected_official: $reject_off,
        rejected_aur: $reject_aur,
        archived: $archived,
        commit_hash: $commit_hash
    }
}

# 9. process-all-drift-drafts
# Summary: Scans and processes all pending review drafts present in _drafts_drifts/.
# Parameters:
#   --drafts-dir: Override path to _drafts_drifts directory
#   --dry-run: Simulate without file modifications
#   --no-push: Skip executing ai git-push -G
# Example: process-all-drift-drafts
export def process-all-drift-drafts [
    --drafts-dir: string
    --package-lists-path: string
    --rejected-drift-path: string
    --processed-dir: string
    --dry-run
    --no-push
    --skip-install
]: nothing -> list {
    let d_dir = if ($drafts_dir != null) { $drafts_dir } else { get-default-drafts-dir }
    if not ($d_dir | path exists) {
        return []
    }

    let draft_files = (glob $"($d_dir)/*.md")
    if ($draft_files | is-empty) {
        return []
    }

    mut results = []
    for f in $draft_files {
        let r = (apply-drift-draft $f
            --package-lists-path $package_lists_path
            --rejected-drift-path $rejected_drift_path
            --processed-dir $processed_dir
            --dry-run=($dry_run)
            --no-push=($no_push)
            --skip-install=($skip_install)
        )
        $results = ($results | append $r)
    }

    $results
}

# 10. log-drift-to-memory
# Summary: Prepends a single-sentence entry to Obsidian AGENTS_MEMORY/log.log.
# Parameters:
#   log_text: Raw message to record
#   --log-path: Override path to log.log
# Example: log-drift-to-memory "Audited host: zero drift."
export def log-drift-to-memory [
    log_text: string
    --log-path: string
]: nothing -> nothing {
    let target_log = if ($log_path != null) { $log_path } else { get-default-log-path }
    if not ($target_log | path parse | get parent | path exists) {
        return
    }

    let timestamp = (date now | format date "%Y-%m-%d %H:%M:%S")
    let entry = $"[($timestamp)] [CACHYOS-DRIFT] ($log_text)\n"

    if ($target_log | path exists) {
        let current_log = (open --raw $target_log)
        $"($entry)($current_log)" | save -f $target_log
    } else {
        $entry | save -f $target_log
    }
}

# 11. cachyos-drift-auditor
# Summary: Main orchestrator for CachyOS package drift auditing and draft reconciliation.
# Parameters:
#   --dry-run(-d): Preview operations without modifying disk, git, or Habitica
#   --date: Override audit date (defaults to today YYYY-MM-DD)
#   --force(-f): Force regenerate draft even if one exists for the current day
#   --no-push: Skip git push via ai git-push -G after applying approved drafts
#   --skip-apply: Skip processing existing drafts before auditing
#   --skip-notify: Skip Habitica notification dispatch
#   --skip-log: Skip updating AGENTS_MEMORY/log.log
# Example: cachyos-drift-auditor --dry-run
export def cachyos-drift-auditor [
    --dry-run(-d)                          # Run audit and draft without persisting files or modifying external services
    --date: string                         # Override audit date (defaults to today YYYY-MM-DD)
    --package-lists-path: string           # Path to package_lists.json (defaults to $env.MY_ENV_VARS.linux_backup)
    --rejected-drift-path: string          # Path to rejected_drift.json
    --drafts-dir: string                   # Path to _drafts_drifts directory
    --processed-dir: string                # Path to processed_drafts directory
    --force(-f)                            # Force regenerate draft even if one exists for the current date
    --no-push                              # Skip git push via ai git-push -G after applying approved drafts
    --skip-apply                           # Skip processing existing drafts before auditing
    --skip-notify                          # Skip Habitica notification dispatch
    --skip-log                             # Skip updating AGENTS_MEMORY/log.log
    --skip-install                         # Skip local package installation via paru for install_local decisions
]: nothing -> record {
    let d = if ($date != null) { $date } else { date now | format date "%Y-%m-%d" }
    let host = (detect-host-name)

    print-rule $"CachyOS Drift Auditor: ($d) [($host)]" --style "bold cyan"

    # Step 1: Process any pending review drafts in _drafts_drifts/
    mut applied_drafts = []
    if not $skip_apply {
        print-rich "[cyan]── Step 1: Checking for approved drafts in Obsidian AGENTS_MEMORY/_drafts_drifts ──[/]"
        $applied_drafts = (process-all-drift-drafts
            --drafts-dir $drafts_dir
            --package-lists-path $package_lists_path
            --rejected-drift-path $rejected_drift_path
            --processed-dir $processed_dir
            --dry-run=($dry_run)
            --no-push=($no_push)
            --skip-install=($skip_install)
        )
        let resolved_count = ($applied_drafts | where processed and (($it.approved_count > 0) or ($it.rejected_count > 0)) | length)
        print-rich $"  [green]✓[/] Processed [bold]($applied_drafts | length)[/] existing draft files [bold]\(($resolved_count) resolved\)[/]."

        if ($resolved_count > 0) and (not $dry_run) and (not $skip_log) {
            let total_app = ($applied_drafts | get approved_count | math sum)
            let total_rej = ($applied_drafts | get rejected_count | math sum)
            log-drift-to-memory $"Applied approved package drift on ($host): ($total_app) approved packages merged into Backups/linux, ($total_rej) rejected packages suppressed."
        }
    }

    # Step 2: Audit local system drift against package_lists.json
    print-rich $"[cyan]── Step 2: Probing ($host) local package drift ──[/]"
    let audit_res = (audit-system-drift
        --package-lists-path $package_lists_path
        --rejected-drift-path $rejected_drift_path
    )

    if ($audit_res.is_new_host? | default false) {
        let reg_res = (ensure-host-registered
            --host $audit_res.target_host
            --package-lists-path $package_lists_path
            --dry-run=($dry_run)
        )
        if ($reg_res.registered? | default false) {
            if $dry_run {
                print-rich $"  [yellow]![/] (DRY-RUN) Would auto-register new host profile: [bold]($audit_res.target_host)[/] in package_lists.json"
            } else {
                print-rich $"  [green]✓[/] Auto-registered new host profile: [bold]($audit_res.target_host)[/] in package_lists.json"
            }
        }
    }

    let counts = $audit_res.counts
    let missing_sum = (($counts.missing_official) + ($counts.missing_aur))
    print-rich $"  [bold]Target Host:[/] [green]($audit_res.target_host)[/]"
    print-rich $"  [bold]New Official:[/] ($counts.new_official), [bold]New AUR:[/] ($counts.new_aur)"
    print-rich $"  [bold]Missing:[/] ($missing_sum), [bold]Suppressed:[/] ($counts.suppressed)"
    print-rich $"  [bold yellow]Total Actionable Drift:[/] ($counts.total_drift)"

    # Step 3: If drift detected, generate review draft and dispatch Habitica todo
    mut draft_res: any = { created: false, path: null, counts: $counts, message: "No draft created" }
    mut notif_res: any = { notified: false, success: true, message: "No notification needed" }

    if $counts.total_drift > 0 {
        print-rich "[cyan]── Step 3: Generating review draft in Obsidian AGENTS_MEMORY/_drafts_drifts ──[/]"
        $draft_res = (write-drift-draft $audit_res
            --drafts-dir $drafts_dir
            --date $d
            --force=($force)
            --dry-run=($dry_run)
        )
        print-rich $"  [green]✓[/] ($draft_res.message)"

        if not $skip_notify {
            print-rich "[cyan]── Step 4: Dispatching Habitica notification ──[/]"
            $notif_res = (notify-drift-habitica $draft_res $audit_res --dry-run=($dry_run))
            print-rich $"  [green]✓[/] ($notif_res.message)"
        }

        if (not $dry_run) and (not $skip_log) {
            log-drift-to-memory $"Audited ($host): ($counts.total_drift) drifted packages detected; review draft created at ($draft_res.path)."
        }
    } else {
        print-rich "  [bold green]✓ Zero drift detected. System is in 100% parity with Backups/linux declarative packages![/]"
        if (not $dry_run) and (not $skip_log) {
            log-drift-to-memory $"Audited ($host): verified 100% parity with declarative packages in Backups/linux."
        }
    }

    print-rule $"Audit Completed: ($d)" --style "bold green"

    {
        date: $d,
        target_host: $audit_res.target_host,
        counts: $counts,
        draft: $draft_res,
        notification: $notif_res,
        applied_drafts: $applied_drafts
    }
}

# Alias for backwards compatibility
export alias audit-cachyos-drift = cachyos-drift-auditor
