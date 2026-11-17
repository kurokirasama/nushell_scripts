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

# Update a directory size record without blocking the shell prompt.
export def update-pwd-size-async [pwd: path, pwd_sizes_path: path] {
    try {
        let size = (du $pwd --exclude *rclone* | get apparent | get 0 | into string | str replace " " "")
        let now = (date now)
        let rows = if ($pwd_sizes_path | path exists) {
            open $pwd_sizes_path | default []
        } else {
            []
        }
        let tmp = $"($pwd_sizes_path).tmp.(random uuid)"
        $rows
            | where directory != $pwd
            | append {directory: $pwd, size: $size, updated: $now}
            | to json
            | save -f $tmp
        mv -f $tmp $pwd_sizes_path
    } catch {}
}

def echo-g [text: string] { $"(ansi -e { fg: '#00ff00' attr: b })($text)(ansi reset)" }
def echo-r [text: string] { $"(ansi -e { fg: '#ff0000' attr: b })($text)(ansi reset)" }
def echo-y [text: string] { $"(ansi -e { fg: '#ffff00' attr: b })($text)(ansi reset)" }

