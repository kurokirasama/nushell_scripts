#copy text to clipboard
export def copy [
] {
    if $env.XDG_CURRENT_DESKTOP == "gnome" {
        xsel --input --clipboard
    } else if $env.XDG_CURRENT_DESKTOP == "Hyprland" {
        wl-copy
    }
}

#copy pwd
export def cpwd [] {
  $env.PWD | copy
}

#check if drive is mounted
export def is-mounted [drive:string] {
  (ls ~/media | find $"($drive)" | length) > 0
}

#countdown alarm
export def countdown [
  n: int #time in seconds
] {
  let BEEP = [$env.MY_ENV_VARS.linux_backup "alarm-clock-elapsed.oga"] | path join

  let muted = if (which wpctl | is-not-empty) {
    # PipeWire/WirePlumber method
    let status = wpctl get-volume @DEFAULT_AUDIO_SINK@
    if ($status | str contains "[MUTED]") {
        "yes"
    } else {
        "no"
    }
  } else {
    # PulseAudio method
    pacmd list-sinks
    | lines
    | find muted
    | parse "{state}: {value}"
    | get value
    | get 0
  }

  if $muted == 'no' {
    termdown $n
    ^mpv --no-terminal $BEEP
    return
  }

  termdown $n
  unmute
  ^mpv --no-terminal $BEEP
  mute
}

#reset alpine authentification
export def reset-alpine-auth [] {
  rm ~/.pine-passfile
  touch ~/.pine-passfile
  alpine-notify -i
}

#enable ssh without password
export def ssh-sin-pass [
  user:string
  ip:string
  --port(-p):int = 22
  --sftp(-s) # enable passwordless authentication for SFTP-only servers
  --key(-k):string = "~/.ssh/id_rsa.pub" # public key to copy
] {
  let pub_key = ($key | path expand)
  if not ($pub_key | path exists) {
    ssh-keygen -t rsa
  }

  if $sftp {
    print (echo-g $"To install your key on an SFTP-only server, enter your password and run these commands in the sftp prompt:")
    print (echo-y "  mkdir .ssh")
    print (echo-y $"  put ($pub_key) .ssh/authorized_keys")
    print (echo-y "  chmod 600 .ssh/authorized_keys")
    print (echo-y "  bye\n")
    ^sftp -P $port $"($user)@($ip)"
  } else {
    ssh-copy-id -i $pub_key -p $port $"($user)@($ip)"
  }
}

#clean nerd-fonts repo
export def nerd-fonts-clean [] {
  let repo = ("~/software/nerd-fonts" | path expand)
  if ($repo | path exists) {
    cd $repo
    try { rm -rf patched-fonts } catch {}
    try { rm -f *.zip *.ttc *.ttf *.otf } catch {}
    try { ^git clean -fd } catch {}
    cd -
  }
}

# Performs logical operations on multiple predicates.
# User has to specify exactly one of the following flags: `--all`, `--any` or `--one-of`.
export def verify [
  clausules?
  --not(-n)  # Negate the test result
  --false(-f)  # The default behavior is to test truthiness of the predicates. Use this flag to test falsiness instead.
  --and(-a)  # All of the given predicates should test positive
  --or(-o)  # At least one of the given predicates should test positive
  --xor(-x)  # Exactly one of the given predicates should test positive
]: [
  list<bool> -> bool
  list<closure> -> bool
] {
  let inputs = if ($clausules | is-empty) {$in} else {$clausules}

  let test_value = not $false
  let op = {|item|
    match ($item | describe) {
      "bool" => $item
      "closure" => {do $item}
      $x => {error make {msg: $"inputs of type ($x) is not supported. Please check."}}
    }
  }

  let res = match [$and $or $xor] {
    [true false false] => { $inputs | all {|item| (do $op $item) == $test_value} }
    [false true false] => { $inputs | any {|item| (do $op $item) == $test_value} }
    [false false true] => {
      mut res = false
      mut first_true = false
      for $item in $inputs {
        match [((do $op $item) == $test_value) $first_true] {
          [false    _] => {}
          [true false] => {$first_true = true; $res = true;}
          [true  true] => {$res = false;}
        }
      }
      $res
    }
  }

  $not xor $res
}

# Rewrite the `name:` frontmatter field in a copied skill dir to exactly match the folder name
# (e.g. "conductor-newtrack"), satisfying Zed's convention and validation rules.
# Only touches the copy — the source SKILL.md is never modified.
def patch-skill-name [skill_dir: path, target_name: string] {
    let skill_md = $skill_dir | path join "SKILL.md"
    if not ($skill_md | path exists) { return }
    let content = open --raw $skill_md
    let patched = $content | lines | each { |line|
        if ($line | str starts-with "name:") { $"name: ($target_name)" } else { $line }
    } | str join "\n"
    if $patched != $content {
        $patched | save --force $skill_md
    }
}

#link skills from yandex disk to ~/.agents/skills
export def link-skills [] {
    let source = (try { $env.MY_ENV_VARS.llms_configs } catch { "~/Yandex.Disk/llms_configs" } | path expand | path join "skills")
    let conductor_backup = (try { $env.MY_ENV_VARS.llms_configs } catch { "~/Yandex.Disk/llms_configs" } | path expand | path join "conductor_skills_backup")
    let dest1 = "~/.agents/skills" | path expand
    let dest2 = "~/.gemini/antigravity-cli/skills" | path expand
    let dest3 = "~/.claude/skills" | path expand

    if not ($source | path exists) {
        error make {msg: $"Source skills directory not found: ($source)"}
    }

    # Ensure physical destination directories exist so we can link inside them
    mkdir $dest1 $dest2 $dest3

    # --- Pre-compute the full set of expected skill names (used for stale-link cleanup) ---
    let repos_to_ignore = ["science-skills", "gemini-api-skills"]
    let base_skills    = glob ($source | path join "*")
    let science_skills = glob ($source | path join "science-skills" "skills" "*")
    let gemini_skills  = glob ($source | path join "gemini-api-skills" "gemini-skills" "skills" "*")
    let all_skills     = ($base_skills | append $science_skills | append $gemini_skills)

    let standard_skill_names = $all_skills
        | each { |s| $s | path basename }
        | where { |n| $n not-in $repos_to_ignore }

    # Eagerly collect plugin skills across all potential plugin locations
    let candidate_plugin_dirs = [
        ("~/.gemini/antigravity-cli/plugins" | path expand),
        ("~/.gemini/config/plugins" | path expand),
        ("~/.gemini/plugins" | path expand)
    ]
    let plugin_skills = ($candidate_plugin_dirs 
        | where { |d| $d | path exists }
        | each { |d| glob ($d | path join "*" "skills" "*" "SKILL.md") }
        | flatten
        | uniq)

    let plugin_skill_names = $plugin_skills | each { |skill|
        let parts = $skill | path split
        let plugin_name = $parts | get (($parts | length) - 4)
        let skill_name  = $parts | get (($parts | length) - 2)
        $"($plugin_name)-($skill_name | str lowercase)"
    }

    let backup_others_skills = if (($conductor_backup | path join "others") | path exists) {
        glob (($conductor_backup | path join "others" "*") | into string)
    } else { [] }
    let backup_others_names = $backup_others_skills | each { |s| $s | path basename }

    let all_expected_names = ($standard_skill_names | append $plugin_skill_names | append $backup_others_names | uniq)

    # --- Intelligently clean dest1 and dest2 ---
    for dest in [$dest1, $dest2] {
        let items = glob ($dest | path join "*")
        for item in $items {
            if ($item | path type) == "symlink" {
                let name     = $item | path basename
                let is_broken = not ($item | path exists)
                let is_stale  = $name not-in $all_expected_names
                if $is_broken or $is_stale {
                    try { rm -rf $item } catch {}
                }
            }
        }
    }

    # --- Full wipe for dest3 (Claude Code blocks external symlinks; always copy fresh) ---
    let items3 = glob ($dest3 | path join "*")
    for item in $items3 {
        try { rm -rf $item } catch {}
    }

    # --- 1. Link/copy Standard Skills (from Yandex Disk) ---
    for skill in $all_skills {
        let name = $skill | path basename
        if ($name in $repos_to_ignore) { continue }

        let targets = [$dest1, $dest2] | each { |d| $d | path join $name }
        for target in $targets {
            try { rm -rf $target } catch {}
            try { ^ln -sfn $skill $target } catch {}
        }

        # Claude Code blocks external symlinks for security. We must copy the skills.
        let target3 = $dest3 | path join $name
        if ($target3 | path exists) { rm -rf $target3 }

        if ($skill | path type) == "dir" {
            cp -r $skill $target3
        } else {
            mkdir $target3
            cp $skill ($target3 | path join "SKILL.md")
        }
    }

    # --- 2. Restore / Deploy Conductor Skills from Backup (for other agents: Zed, OpenCode, Claude) ---
    for skill in $backup_others_skills {
        let name = $skill | path basename
        
        # Deploy to Zed ($dest1)
        let target_zed = $dest1 | path join $name
        try { rm -rf $target_zed } catch {}
        cp -r $skill $target_zed
        patch-skill-name $target_zed $name

        # Deploy to Claude Code ($dest3)
        let target3 = $dest3 | path join $name
        try { rm -rf $target3 } catch {}
        cp -r $skill $target3
        patch-skill-name $target3 $name
    }

    # --- 3. Link/copy Extension Skills (from antigravity-cli plugins) ---
    for skill in $plugin_skills {
        let parts = $skill | path split
        let plugin_name = $parts | get (($parts | length) - 4)
        let skill_name  = $parts | get (($parts | length) - 2)
        let source_dir  = $skill | path dirname

        let target_name = $"($plugin_name)-($skill_name | str lowercase)"

        # Copy to Zed ($dest1)
        let target_zed = $dest1 | path join $target_name
        try { rm -rf $target_zed } catch {}
        cp -r $source_dir $target_zed
        patch-skill-name $target_zed $target_name

        # Copy to Claude Code ($dest3)
        let target3 = $dest3 | path join $target_name
        try { rm -rf $target3 } catch {}
        cp -r $source_dir $target3
        patch-skill-name $target3 $target_name
    }

    # --- 4. Ensure AGY Conductor Plugins are present in ~/.gemini/config/plugins/conductor ---
    let agy_plugin_dest = "~/.gemini/config/plugins/conductor" | path expand
    let agy_backup_src = $conductor_backup | path join "agy"
    if ($agy_backup_src | path exists) and (not ($agy_plugin_dest | path join "skills" | path exists)) {
        mkdir ($agy_plugin_dest | path join "skills")
        cp -r ($agy_backup_src | path join "*") ($agy_plugin_dest | path join "skills")
        print (echo-g "✓ Restored AGY Conductor plugin skills to ~/.gemini/config/plugins/conductor")
    }

    print (echo-g "Skills and extension-based commands linked successfully!")
}

#link agents from yandex disk to user CLI folders
export def link-agents [] {
    let base    = (try { $env.MY_ENV_VARS.llms_configs } catch { "~/Yandex.Disk/llms_configs" } | path expand | path join "agents")
    let src_ag  = ($base | path join "antigravity")
    let src_oc  = ($base | path join "opencode")
    let src_cl  = ($base | path join "claude")

    let dest_gemini   = ($env.HOME | path join ".gemini" "agents")
    let dest_opencode = ($env.HOME | path join ".config" "opencode" "agents")
    let dest_claude   = ($env.HOME | path join ".claude" "agents")

    for src in [$src_ag, $src_oc, $src_cl] {
        if not ($src | path exists) {
            error make {msg: $"Source agents subfolder not found: ($src). Run the migration first."}
        }
    }

    mkdir $dest_gemini $dest_opencode $dest_claude

    # Helper: validate OpenCode frontmatter (tools must be object, not array)
    def validate-opencode-agent [file: string] {
        let content = open --raw $file
        let lines = $content | lines
        let tools_line = $lines | enumerate | where { |r| ($r.item | str trim) == "tools:" } | first
        if ($tools_line | is-empty) { return true }
        let next_idx = $tools_line.index + 1
        if $next_idx >= ($lines | length) { return true }
        let next_line = $lines | get $next_idx
        if ($next_line | str starts-with "  - ") or ($next_line | str starts-with "- ") {
            return false
        }
        return true
    }

    # ── Antigravity (Gemini CLI) ── symlink
    let ag_files = glob ($src_ag | path join "*.md")
    let ag_names = $ag_files | each { |f| $f | path basename }
    for item in (glob ($dest_gemini | path join "*")) {
        if ($item | path type) == "symlink" {
            let name = $item | path basename
            if (not ($item | path exists)) or ($name not-in $ag_names) { try { rm -rf $item } catch {} }
        }
    }
    for agent in $ag_files {
        let target = $dest_gemini | path join ($agent | path basename)
        try { rm -rf $target } catch {}
        try { ^ln -sfn $agent $target } catch {}
    }

    # ── OpenCode ── symlink (with validation guard)
    let oc_files = glob ($src_oc | path join "*.md")
    let oc_names = $oc_files | each { |f| $f | path basename }
    for item in (glob ($dest_opencode | path join "*")) {
        if ($item | path type) == "symlink" {
            let name = $item | path basename
            if (not ($item | path exists)) or ($name not-in $oc_names) { try { rm -rf $item } catch {} }
        }
    }
    for agent in $oc_files {
        if not (validate-opencode-agent $agent) {
            print $"(ansi yellow)WARNING(ansi reset): Skipping ($agent | path basename) — tools: field is an array, invalid for OpenCode"
            continue
        }
        let target = $dest_opencode | path join ($agent | path basename)
        try { rm -rf $target } catch {}
        try { ^ln -sfn $agent $target } catch {}
    }

    # ── Claude Code ── copy (blocks external symlinks)
    for item in (glob ($dest_claude | path join "*")) { try { rm -rf $item } catch {} }
    for agent in (glob ($src_cl | path join "*.md")) {
        let target = $dest_claude | path join ($agent | path basename)
        try { cp -f $agent $target } catch {}
    }

    print (echo-g "Agent definition files linked successfully!")
}

#update global GEMINI.md, AGENTS.md, and CLAUDE.md rules
export def "update-gemini-md" [] {
    let llms = try { $env.MY_ENV_VARS.llms_configs } catch { "~/Yandex.Disk/llms_configs" } | path expand
    let source = [$llms "gemini-bak.md"] | path join
    cp $source ~/.gemini/GEMINI.md -f
    cp $source ~/.config/zed/AGENTS.md -f
    cp $source ~/.claude/CLAUDE.md -f
    
    # OpenCode global rules path
    let opencode_dir = "~/.config/opencode" | path expand
    if not ($opencode_dir | path exists) {
        mkdir $opencode_dir
    }
    cp $source ($opencode_dir | path join "AGENTS.md") -f
}

def echo-g [text: string] { $"(ansi -e { fg: '#00ff00' attr: b })($text)(ansi reset)" }
def echo-r [text: string] { $"(ansi -e { fg: '#ff0000' attr: b })($text)(ansi reset)" }
def echo-y [text: string] { $"(ansi -e { fg: '#ffff00' attr: b })($text)(ansi reset)" }

