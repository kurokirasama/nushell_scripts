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
] {
  if not ("~/.ssh/id_rsa.pub" | path expand | path exists) {
    ssh-keygen -t rsa
  }

  ssh-copy-id -i ~/.ssh/id_rsa.pub -p $port $"($user)@($ip)"
}

#clean nerd-fonts repo
export def nerd-fonts-clean [] {
  cd ~/software/nerd-fonts/
  rm -rf .git
  rm -rf patched-fonts
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
    let source = ($env.MY_ENV_VARS.llms_configs | path join "skills")
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

    # Eagerly collect plugin skills so the list is reused in both cleanup and linking
    let plugins_dir = "~/.gemini/antigravity-cli/plugins" | path expand
    let plugin_skills = if ($plugins_dir | path exists) {
        glob ($plugins_dir | path join "*" "skills" "*" "SKILL.md")
    } else { [] }

    let plugin_skill_names = $plugin_skills | each { |skill|
        let parts = $skill | path split
        let plugin_name = $parts | get (($parts | length) - 4)
        let skill_name  = $parts | get (($parts | length) - 2)
        $"($plugin_name)-($skill_name | str downcase)"
    }

    let all_expected_names = ($standard_skill_names | append $plugin_skill_names)

    # --- Intelligently clean dest1 and dest2 ---
    # Remove any symlink that is either broken or no longer in the current skill batch.
    # Non-symlink entries (manually placed real dirs) are intentionally left untouched.
    for dest in [$dest1, $dest2] {
        let items = glob ($dest | path join "*")
        for item in $items {
            if ($item | path type) == "symlink" {
                let name     = $item | path basename
                let is_broken = not ($item | path exists)
                let is_stale  = $name not-in $all_expected_names
                if $is_broken or $is_stale {
                    rm $item
                }
            }
        }
    }

    # --- Full wipe for dest3 (Claude Code blocks external symlinks; always copy fresh) ---
    let items3 = glob ($dest3 | path join "*")
    for item in $items3 {
        rm -rf $item
    }

    # --- 1. Link/copy Standard Skills (from Yandex Disk) ---
    for skill in $all_skills {
        let name = $skill | path basename
        if ($name in $repos_to_ignore) { continue }

        let targets = [$dest1, $dest2] | each { |d| $d | path join $name }
        for target in $targets {
            if ($target | path type) == "symlink" {
                rm $target
            } else if ($target | path exists) {
                continue
            }
            ^ln -s $skill $target
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

    # --- 2. Link/copy Extension Skills (from antigravity-cli plugins) ---
    # NOTE: $dest2 (agy) intentionally excluded — agy resolves plugin skills natively from its plugins/ dir.
    for skill in $plugin_skills {
        let parts = $skill | path split
        let plugin_name = $parts | get (($parts | length) - 4)
        let skill_name  = $parts | get (($parts | length) - 2)
        let source_dir  = $skill | path dirname

        # Lowercase the skill name so the folder and SKILL.md `name:` field both satisfy Zed's
        # validation (only lowercase letters, numbers, and hyphens allowed).
        let target_name = $"($plugin_name)-($skill_name | str downcase)"

        # Copy to Zed ($dest1) — we copy (not symlink) so we can patch the SKILL.md name field
        # without modifying the source plugin files.
        let target_zed = $dest1 | path join $target_name
        if ($target_zed | path type) == "symlink" {
            rm $target_zed
        } else if ($target_zed | path exists) {
            rm -rf $target_zed
        }
        cp -r $source_dir $target_zed
        patch-skill-name $target_zed $target_name

        # Copy to Claude Code ($dest3) — Claude Code blocks external symlinks
        let target3 = $dest3 | path join $target_name
        if ($target3 | path exists) { rm -rf $target3 }
        cp -r $source_dir $target3
        patch-skill-name $target3 $target_name
    }

    print (echo-g "Skills and extension-based commands linked successfully!")
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
