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
    
    if not ($source | path exists) {
        error make {msg: $"Source skills directory not found: ($source)"}
    }
    
    # Ensure physical destination directories exist so we can link inside them
    mkdir $dest1 $dest2
    
    # Clean up any broken symlinks in the destinations
    for dest in [$dest1, $dest2] {
        let items = glob ($dest | path join "*")
        for item in $items {
            if ($item | path type) == "symlink" and (not ($item | path exists)) {
                rm $item
            }
        }
    }
    
    # Get all individual skills in the source directory
    let skills = glob ($source | path join "*")
    
    for skill in $skills {
        let name = $skill | path basename
        let target1 = $dest1 | path join $name
        let target2 = $dest2 | path join $name
        
        # Link to dest1 safely
        if ($target1 | path type) == "symlink" {
            rm $target1
        } else if ($target1 | path exists) {
            print $"Warning: A physical item already exists at ($target1). Skipping link to avoid overwriting."
            continue
        }
        ^ln -s $skill $target1
        
        # Link to dest2 safely
        if ($target2 | path type) == "symlink" {
            rm $target2
        } else if ($target2 | path exists) {
            print $"Warning: A physical item already exists at ($target2). Skipping link to avoid overwriting."
            continue
        }
        ^ln -s $skill $target2
    }
    print (echo-g "Skills linked successfully!")
}

#update global GEMINI.md
export def "update-gemini-md" [] {
    let source = $env.MY_ENV_VARS.llms_configs | path join "gemini-bak.md"
    cp $source ~/.gemini/GEMINI.md -f
    cp $source ~/.config/zed/AGENTS.md -f
}
