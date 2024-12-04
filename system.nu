#short help
export def ? [...search,--find(-f)] {
  let search = $search | str join " "
  if ($search | is-empty) {
    return (help commands)
  } 

  if $find {
    help ...(help -f $search | ansi-strip-table | get name | input list -f (echo-g "Select command:"))
    return
  }

  if $search =~ "commands" {
   if $search =~ "my" {
     help commands | where category == default
   } else {
     help commands 
   }
  } else if (which $search | get type | get 0) =~ "external" {
    usage (which $search | get command | get 0)
  } else {
    help (which $search | get command | get 0)
  }
}

# get the examples from tldr as a table
export def usage [ cmd: string, --no-ansi(-A), --update(-u) ] {
    if $update {
        ^tldr -u --markdown $cmd
    } else {
        ^tldr --markdown $cmd
    } | lines | compact -e
    | skip until { str starts-with '- ' }
    | chunks 2 | each { str join ' ' }
    | parse '- {desc}: `{example}`'
    | update example {
        str replace -ra '{{(.+?)}}' $'(ansi u)$1(ansi reset)' # Underline shown for user input
        | str replace -r '^(\w\S*)' $'(ansi bo)$1(ansi reset)' # Make first word (usually command) bold
        | str replace -ar ' (-{1,2}\S+)' $' (ansi d)$1(ansi reset)' # Make cli flags dim
    } | if $no_ansi { update example { ansi strip } } else {}
    | move desc --after example
    | collect
}

# get the version information formatting the plugins
export def ver [] { 
    let plugin_modified = plugin list | insert last_modified { |plug| ls $plug.filename | get 0?.modified? } | select name last_modified

    let ver = version | upsert installed_plugins {|v| $v | 
        get installed_plugins | 
        split row ', ' |
        parse '{name} {version}' | 
        join $plugin_modified name
    }

    $ver | table -e
}

#nushell banner
export def show_banner [] {
    let ellie = [
        "     __  ,"
        " .--()°'.'"
        "'|, . ,'  "
        ' !_-(_\   '
    ]
    let s = {mem: (sys mem), host: (sys host)}
    print $"(ansi reset)(ansi green)($ellie.0)"
    print $"(ansi green)($ellie.1)  (ansi yellow) (ansi yellow_bold)Nushell (ansi reset)(ansi yellow)v(version | get version)(ansi reset)"
    print $"(ansi green)($ellie.2)  (ansi light_blue) (ansi light_blue_bold)RAM (ansi reset)(ansi light_blue)($s.mem.used) / ($s.mem.total)(ansi reset)"
    print $"(ansi green)($ellie.3)  (ansi light_purple)ﮫ (ansi light_purple_bold)Uptime (ansi reset)(ansi light_purple)($s.host.uptime)(ansi reset)"
}

#neofetch but nu
export def nufetch [--table(-t)] {
  if not $table {
    show_banner
    return 
  } 

  let s = {mem: (sys mem), host: (sys host), disks: (sys disks), cpu: (sys cpu)}
  let s2 = (
    hostnamectl 
    | lines 
    | parse "{headers}: {value}"
    | str trim
    | transpose -ird 
  )
  let os = ($s2 | get "Operating System") + " " + $nu.os-info.arch
  let host = (open /sys/devices/virtual/dmi/id/product_name | lines | get 0)
  let shell = ($env.SHELL | path parse | get stem) + " " + (version | get version)
  let screen_res = (
    xrandr 
    | lines 
    | find "*+" 
    | parse "   {resolution} {rest}" 
    | get resolution 
    | str join ", "
  )
  let theme = (
    gsettings get org.gnome.desktop.interface gtk-theme 
    | lines 
    | get 0 
    | str replace -a "'" ""
  )
  let icons = (
    gsettings get org.gnome.desktop.interface icon-theme 
    | lines 
    | get 0
    | str replace -a "'" ""
  )
  let free_disk = ($s.disks | where mount == / | get free | get 0)
  let total_disk = ($s.disks | where mount == / | get total | get 0)
  let disk = (($total_disk - $free_disk) | into string) + " / " + ($total_disk | into string)
  let mem = ($s.mem.used | into string) + " / " + ($s.mem.total | into string)
  let gpus = (
    lspci 
    | lines 
    | find -i vga 
    | parse "{col2} VGA compatible controller: {col1}" 
    | each {|row| 
        [$row.col1 $row.col2] 
        | str join " "
      }
    )
  let wm = (
    if $env.XDG_CURRENT_DESKTOP == "ubuntu:GNOME" {
      "Mutter"
    } else {
      wmctrl -m | lines | first | split row ": " | last
    }
  )
  let terminal = (
    xdotool getactivewindow | xargs -I {} xprop -id {} WM_CLASS 
    | split row '='
    | get 1 
    | str trim 
    | split row , 
    | get 0 
    | str replace -a "\"" ""
  )
  let wmtheme = gsettings get org.gnome.shell.extensions.user-theme name | str replace -a "'" ""
  let info = {} 

  $info
  | upsert user $env.USERNAME
  | upsert hostname $s.host.hostname
  | upsert os $os
  | upsert host $host
  | upsert kernel $s.host.kernel_version
  | upsert uptime $s.host.uptime
  | upsert dpkgPackages (dpkg --get-selections | lines | length)
  | upsert snapPackages ((snap list  | lines | length) - 1)
  | upsert shell $shell
  | upsert resolution $screen_res
  | upsert de $env.XDG_CURRENT_DESKTOP
  | upsert wm $wm
  | upsert wmTheme $wmtheme
  | upsert theme $theme
  | upsert icons $icons
  | upsert terminal $terminal
  | upsert cpu ($s.cpu | get brand | uniq | get 0)
  | upsert cores (($s.cpu | length) / 2)
  | upsert gpu $gpus
  | upsert disk $disk
  | upsert memory $mem
  | table -e
}

#helper for displaying left prompt
export def left_prompt [] {
  if not ($env.MY_ENV_VARS | is-column l_prompt) {
      $env.PWD | path parse | get stem
  } else if ($env.MY_ENV_VARS.l_prompt | is-empty) or ($env.MY_ENV_VARS.l_prompt == 'short') {
      $env.PWD | path parse | get stem
  } else {
      $env.PWD | str replace $nu.home-path '~'
  }
}

#last 100 elements in history with highlight
export def h [howmany = 100] {
  history
  | last $howmany
  | update command {|f|
      $f.command 
      | nu-highlight
    }
}

#search for specific process
export def psn [name?: string] {
  let name = get-input $in $name
  ps -l | find -i $name
}

#kill specified process
#
#Receives a name or a list of processes
export def killn [name?:string] {
  if not ($name | is-empty) {
    ps -l
    | find -i $name 
    | each {|p|
        kill -f $p.pid
      }
  } else {
    $in
    | each {|row|
        kill -f $row.pid
      }
  }
}

#short pwd
export def pwd-short [] {
  $env.PWD | str replace $nu.home-path '~'
}

#go to dir (via pipe)
export def --env cd-pipe [] {
  let input = $in
  cd (
      if ($input |  get name | path type) == file {
          ($input | path expand | path dirname)
      } else {
          $input | get name
      }
  )
}

#cd to the folder where a binary is located
export def --env which-cd [program] { 
  let dir = (which $program | get path | path dirname | str trim)
  cd $dir.0
}

#get aliases
export def get-aliases [] {
  scope aliases
  | update expansion {|c|
      $c.expansion | nu-highlight
    }
}

#get code of custom command
export def code [...command,--raw(-r)] {
  let command = $command | str join " "
  if not $raw {
    view source $command | nu-highlight
  } else {
    view source $command
  }
}

#stop network applications
export def stop-net-apps [] {
  sudo service transmission-daemon stop
  yandex-disk stop
  maestral stop
  killn jdown
  killn math
  sudo systemctl stop mysql
}

#create dir and cd into it
export def --env mkcd [name: path] {
  mkdir $name
  cd $name
}

#second screen positioning
export def set-screen [
  side: string = "right"  #which side, left or right (default)
  --home                  #for home pc
  --hdmi = "right"        #for home pc, which hdmi port: left or right (default)
] {
  if not $home {
    match $side {
      "right" => {xrandr --output HDMI-1-1 --auto --right-of eDP},
      "left" => {xrandr --output HDMI-1-1 --auto --left-of eDP},
      _ => {return-error "Side argument should be either right or left"}
    }
    return
  } 

  match $side {
    "right" => {
      if $hdmi == "right" {
        xrandr --output HDMI-1-1 --auto --right-of eDP-1-1
      } else {
        xrandr --output HDMI-0 --auto --right-of eDP-1-1
      } 
    },
    "left" => {
      if $hdmi == "right" {
        xrandr --output HDMI-1-1 --auto --left-of eDP-1-1 
      } else {
        xrandr --output HDMI-0 --auto --left-of eDP-1-1 
      }
    },
    _ => {return-error "Side argument should be either right or left"}
  }
}

#umount all drives 
export def umall [user?] {
  let user = get-input $env.USER $user

  try {
    sys disks 
    | find $"/media/($user)" 
    | get mount
    | ansi strip
    | each {|drive| 
        print (echo-g $"umounting ($drive)...")
        try {
          umount -q $drive
        } catch {
          sudo umount -q $drive
        }
      }
  } catch {
    return-error "device is busy!"
  }
}

#fix docker run error
export def fix-docker [] {
  sudo usermod -aG docker $env.USER
  newgrp docker
}

#generate error output
export def return-error [msg] {
  error make -u {msg: $"(echo-r $msg)"}
}

#get monitors
export def get-monitors [] {
  xrandr | lines | range 1..5 | parse -r '(\S+)\s+(\S+).*'
}

# Show some history stats similar to how atuin does it
export def history-stats [
  --summary (-s): int = 10
  --last-cmds (-l): int
] {
  let top_commands = (
    history
    | if ($last_cmds != null) { last $last_cmds } else { $in }
    | get command
    | split column ' ' command
    | uniq -c
    | flatten
    | sort-by --reverse count
    | first $summary
  )

  let total_cmds = (history | length)
  let unique_cmds = (history | get command | uniq | length)

  print $"Top (ansi green)($summary)(ansi reset) most used commands:"
  let max = ($top_commands | get count | math max)
  $top_commands | each {|cmd|
    let in_ten = 10 * ($cmd.count / $max)
    print -n "["
    print -n (ansi red)
    for i in 0..<$in_ten {
      if $i == 2 {
        print -n (ansi yellow)
      } else if $i == 5 {
        print -n (ansi green)
      }
      if $i != 10 {
        print -n "▮"
      }
    }
    for x in $in_ten..<10 {
      if $x < 9 {
        print -n " "
      }
    }
    print $"(ansi reset)] (ansi xterm_grey)($cmd.count  | fill -a r -c ' ' -w 4)(ansi reset) (ansi default_bold)($cmd.command)(ansi reset)"
  }

  print $"(ansi green)Total commands:(ansi reset)   ($total_cmds)"
  print $"(ansi green)Unique commands:(ansi reset)  ($unique_cmds)"
}

#umount fuse drive
#
#possible drives:
#- box
#- gdrive
#- onedrive
#- yandex
#- photos
export def um [
  drive?:string
  --all(-a)
  --list(-l)
] {
  let mounted = sys disks | find rclone | get mount | ansi strip
  if ($mounted | length) == 0 {
    return-error "no mounted storages!"
  }

  if $list {
    return ($mounted | path parse | get stem)
  }

  if $all {
    $mounted | each {|drive|
        print (echo-g $"unmounting ($drive | path parse | get stem)...")
        fusermount -u $drive
      }
    return
  }

  let drive = (
    if ($drive | is-empty) {
      $mounted
      | path parse
      | get stem
      | input list -f (echo-g "Select drive to umount: ")
      | str prepend "~/rclone/"
      | path expand
    } else {
      ("~/rclone/" + $drive) | path expand
    }
  )
  fusermount -u $drive
}

#mount fuse drive via rclone
#
#possible drives:
#- box
#- gdrive
#- onedrive
#- yandex
#- mega
export def rmount [drive?:string] {
  let drive = (
    if ($drive | is-empty) {
      rclone listremotes 
      | lines 
      | str replace ":" "" 
      | str trim 
      | input list -f (echo-g "Select drive to umount: ")
      | str prepend "~/rclone/"
    } else {
      "~/rclone/" + $drive
    }
    | path expand
  )

  let remote = $drive | path parse | get stem
  let option = "--vfs-cache-mode full"
  bash -c ('rclone mount ' + $remote + ': ' + $drive + ' ' +  $option + ' &')
}

# Monitor the output of a command
export def monitor [
    cmd: closure, # command to execute
    until?: closure, # condition to stop monitoring
    --time(-t): duration = 5sec # time interval
] {
    let cnd = if ($until == null) {{$in | true}} else {$until}
    loop {
        let $res = do $cmd
        clear
        print $res
        sleep $time
        if not ($res | do $cnd) {
            break
        }
    }
}

# select files and dirs
export def fuzzy-select-fs [type: string = "file"] {
    let candidates = (
        ls **/*
        | where type == $type
        | get name
        | sort --ignore-case
    )
    if ($candidates | is-empty) {
        return ""
    }
    let choice = $candidates | input list --fuzzy '?'
    if ($choice | is-empty) {
        return ""
    }
    if $type == "dir" {
        $"`($choice)(char path_sep)`"
    } else {
        $"`($choice)`"
    }
}

export def fuzzy-dispatcher [] {
    match (input --numchar 1 --suppress-output) {
        f => (fuzzy-select-fs file)
        d => (fuzzy-select-fs dir)
        _ => ''
    }
}

#generate autouse file
export def autouse-file [] {
  ls -f nu_modules/*.nu
  | get name
  | each {|file|
      "use " + $file + " *"
    }
  | save -f .autouse.nu
}

#list bluetooth devices and connect
export def cblue [] {
  let os_version = sys host | get os_version
  let devices = if $os_version == "20.04" {
    ^bluetoothctl paired-devices
  } else {
    ^bluetoothctl devices
  } | parse "Device {mac} {name}"

  let connected = ^bluetoothctl info | lines | first | parse "{Device} {mac} {public}" | get mac.0
  let chosen_name = $devices | get name | input list -f (echo-g "Select device: ")
  let chosen = $devices | where name == $chosen_name | get mac.0
  
  if $chosen == $connected {
    ^bluetoothctl disconnect $chosen
  } else {
    ^bluetoothctl connect $chosen
  }
}

#sys disks 2
export def "sys disks2" [] {
  let fields = [id path uuid partuuid]

  $fields
  | par-each {|field|
      ls $"/dev/disk/by-($field)"
      | insert device {|x| $x.name|path expand}
      | update name {path basename}
      | select name device
      | rename $field
  }
  | reduce --fold (sys disks) {|it acc|
      $acc
      | join $it device
  }
}

# Creates a tree of processes from the ps command.
#
# Any table can be piped in, so long as every row has a `pid` and `ppid` column.
# If there is no input, then the standard `ps` is invoked.
export def "ps tree" [
  --root-pids (-p): list<int> # root of process tree
]: [
  table -> table,
] {
  mut procs = $in

  # get a snapshot to use to build the whole tree as it was at the time of this call
  if $procs == null {
    $procs = ps
  }

  let procs = $procs

  let roots = if $root_pids == null {
    $procs | where ppid? == null or ppid not-in $procs.pid
  } else {
    $procs | where pid in $root_pids
  }

  $roots
  | insert children {|proc|
    $procs
    | where ppid == $proc.pid
    | each {|child|
      $procs
      | ps tree -p [$child.pid]
      | get 0
    }
  }
}

#get only parents processes
export def "ps parents" [pid?: int] {
  let pid = $pid | default $nu.pid

  let all_processes = (ps)
  let current_process = ($all_processes | where pid == $pid)
  
  def get-parents [ processes, parents ] {
    let next_parent_pid = ($parents | first | get ppid)
    let next_parent_process = ($processes | where pid == $next_parent_pid)
    
    match $next_parent_process {
      [] => { return $parents}
      
      # Found a parent - Recurse
      _ => {
        let parents = [
          ...$next_parent_process
          ...$parents
        ]
        get-parents $processes $parents
      }
    }
  }

  get-parents $all_processes $current_process
}

#current used keybindinds
export def get-used-keybindings [] {
  let $keybindings = $env.config.keybindings | update modifier {split row '_' | sort | str join '_'}

  let $modifiers = $keybindings |  get modifier | uniq --count | sort-by count -r | update count null | transpose -idr

  $keybindings 
  | select keycode modifier 
  | group-by keycode --to-table 
  | update items {|i| 
      $i.items.modifier 
      | reduce -f $modifiers {|value acc| 
          update $value '✅'
        }
    } 
  | flatten 
  | sort-by group 
  | table --abbreviated 1000
}