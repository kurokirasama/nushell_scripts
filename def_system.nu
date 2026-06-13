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
    
    # Clean up any broken symlinks in the destinations
    for dest in [$dest1, $dest2, $dest3] {
        let items = glob ($dest | path join "*")
        for item in $items {
            if ($item | path type) == "symlink" and (not ($item | path exists)) {
                rm $item
            }
        }
    }

    # Special cleanup for Claude: Remove all files/symlinks in dest3 to avoid conflicts and start fresh
    let items3 = glob ($dest3 | path join "*")
    for item in $items3 {
        rm -rf $item
    }
    
    # 1. Map Standard Skills (from Yandex Disk)
    let base_skills = glob ($source | path join "*")
    let science_skills = glob ($source | path join "science-skills" "skills" "*")
    let gemini_skills = glob ($source | path join "gemini-api-skills" "gemini-skills" "skills" "*")
    let all_skills = ($base_skills | append $science_skills | append $gemini_skills)
    
    let repos_to_ignore = ["science-skills", "gemini-api-skills"]
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
        if ($target3 | path exists) {
            rm -rf $target3
        }
        
        if ($skill | path type) == "dir" {
            cp -r $skill $target3
        } else {
            mkdir $target3
            cp $skill ($target3 | path join "SKILL.md")
        }
    }

    # 2. Map Extension Skills (from antigravity-cli plugins)
    let plugins_dir = "~/.gemini/antigravity-cli/plugins" | path expand
    if ($plugins_dir | path exists) {
        # Pattern: .../plugins/<plugin_name>/skills/<skill_name>/SKILL.md
        let plugin_skills = glob ($plugins_dir | path join "*" "skills" "*" "SKILL.md")
        for skill in $plugin_skills {
            let parts = $skill | path split
            let plugin_name = $parts | get (($parts | length) - 4)
            let skill_name = $parts | get (($parts | length) - 2)
            
            # Create a prefixed name for Claude Code slash command support using a colon
            let target_name = $"($plugin_name):($skill_name)"
            let target = $dest3 | path join $target_name
            
            if ($target | path exists) {
                rm -rf $target
            }
            let source_dir = $skill | path dirname
            cp -r $source_dir $target
        }
    }

    print (echo-g "Skills and extension-based commands linked successfully!")
}

#update global GEMINI.md
export def "update-gemini-md" [] {
    let source = $env.MY_ENV_VARS.llms_configs | path join "gemini-bak.md"
    cp $source ~/.gemini/GEMINI.md -f
    cp $source ~/.config/zed/AGENTS.md -f
    cp $source ~/.claude/CLAUDE.md -f
}
