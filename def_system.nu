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
  let BEEP = ([$env.MY_ENV_VARS.linux_backup "alarm-clock-elapsed.oga"] | path join)
  let muted = (pacmd list-sinks
    | lines
    | find muted
    | parse "{state}: {value}"
    | get value
    | get 0
  )

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
  let op = {|it|
    match ($it | describe) {
      "bool" => $it
      "closure" => {do $it}
      $x => {error make {msg: $"inputs of type ($x) is not supported. Please check."}}
    }
  }

  let res = match [$and $or $xor] {
    [true false false] => { $inputs | all {|it| (do $op $it) == $test_value} }
    [false true false] => { $inputs | any {|it| (do $op $it) == $test_value} }
    [false false true] => {
      mut res = false
      mut first_true = false
      for $it in $inputs {
        match [((do $op $it) == $test_value) $first_true] {
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

#Calculates a past datetime by subtracting a duration from the current time.
export def ago []: [ duration -> datetime ] {
  (date now) - $in
}
