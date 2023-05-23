#zoxide completion
export def "nu-complete zoxide path" [line : string, pos: int] {
  let prefix = ( $line | str trim | split row ' ' | append ' ' | skip 1 | get 0)
  let data = (^zoxide query $prefix --list | lines)
  {
      completions : $data,
                  options: {
                   completion_algorithm: "fuzzy"
                  }
  }
}

#nushell banner
export def show_banner [] {
    let ellie = [
        "     __  ,"
        " .--()°'.'"
        "'|, . ,'  "
        ' !_-(_\   '
    ]
    let s = (sys)
    print $"(ansi reset)(ansi green)($ellie.0)"
    print $"(ansi green)($ellie.1)  (ansi yellow) (ansi yellow_bold)Nushell (ansi reset)(ansi yellow)v(version | get version)(ansi reset)"
    print $"(ansi green)($ellie.2)  (ansi light_blue) (ansi light_blue_bold)RAM (ansi reset)(ansi light_blue)($s.mem.used) / ($s.mem.total)(ansi reset)"
    print $"(ansi green)($ellie.3)  (ansi light_purple)ﮫ (ansi light_purple_bold)Uptime (ansi reset)(ansi light_purple)($s.host.uptime)(ansi reset)"
}

#neofetch but nu (in progress)
export def nufetch [--table(-t)] {
  if not $table {
    show_banner
  } else {
    let s  = sys
    let s2 = (
      hostnamectl 
      | lines 
      | parse "{headers}: {value}"
      | str trim
      | transpose -ird 
    )
    let os = (build-string ($s2 | get "Operating System") " " $nu.os-info.arch)
    let host = (open /sys/devices/virtual/dmi/id/product_name | lines | get 0)
    let shell = (build-string ($env.SHELL | path parse | get stem) " " (version | get version))
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
    let disk = (build-string  ($total_disk - $free_disk) " / " $total_disk)
    let mem = (build-string $s.mem.used " / " $s.mem.total)
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
    let terminal = (xdotool getactivewindow | xargs -I {} xprop -id {} WM_CLASS | split row = | get 1 | str trim | split row , | get 0 | str replace -a "\"" "")
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
    | upsert wmTheme (gsettings get org.gnome.shell.extensions.user-theme name | str replace -a "'" "")
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
}

#helper for displaying left prompt
export def left_prompt [] {
  if not ($env.MY_ENV_VARS | is-column l_prompt) {
      $env.PWD | path parse | get stem
  } else if ($env.MY_ENV_VARS.l_prompt | is-empty) or ($env.MY_ENV_VARS.l_prompt == 'short') {
      $env.PWD | path parse | get stem
  } else {
      $env.PWD | str replace $nu.home-path '~' -s
  }
}

#short help
export def ? [...search] {
  if ($search | is-empty) {
    help commands
  } else {
    if ($search | first) =~ "commands" {
      if ($search | first) =~ "my" {
        help commands | where command_type == custom
      } else {
        help commands 
      }
    } else if ($search | first | str contains "^") {
      tldr ($search | str join "-" | split row "^" | get 0) | nu-highlight
    } else if (which ($search | str join " ") | get path | get 0) =~ "Nushell" {
      if (which ($search | str join " ") | get path | get 0) =~ "alias" {
        get-aliases | find ($search | first) 
      } else {
        help ($search | str join " ") | nu-highlight
      }
    } else {
      tldr ($search | str join "-") | nu-highlight
    }
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

#wrapper for describe
export def typeof [--full(-f)] {
  describe 
  | if not $full { 
      split row '<' | get 0 
    } else { 
      $in 
    }
}

#grep for nu
export def grep-nu [
  search   #search term
  entrada?  #file or pipe
  #
  #Examples
  #grep-nu search file.txt
  #ls **/* | some_filter | grep-nu search 
  #open file.txt | grep-nu search
] {
  if ($entrada | is-empty) {
    if ($in | is-column name) {
      grep -ihHn $search ($in | get name)
    } else {
      ($in | into string) | grep -ihHn $search
    }
  } else {
      grep -ihHn $search $entrada
  }
  | lines 
  | parse "{file}:{line}:{match}"
  | str trim
  | update match {|f| 
      $f.match 
      | nu-highlight
    }
  | rename "source file" "line number"
}

#copy pwd
export def cpwd [] {
  $env.PWD | xclip -sel clip
}

#xls/ods 2 csv
export def xls2csv [
  inputFile:string
  --outputFile:string
] {
  let output = (
    if ($outputFile | is-empty) or (not $outputFile) {
      $"($inputFile | path parse | get stem).csv"
    } else {
      $outputFile
    }
  )
  libreoffice --headless --convert-to csv $inputFile
}

#check if drive is mounted
export def is-mounted [drive:string] {
  (ls "~/media" | find $"($drive)" | length) > 0
}

#get phone number from google contacts
export def get-phone-number [search:string] {
  goobook dquery $search 
  | from ssv 
  | rename results 
  | where results =~ '(?P<plus>\+)(?P<nums>\d+)'
  
}

#open mcomix
export def mcx [file?] {
  let file = if ($file | is-empty) {$in} else {$file}

  bash -c $'mcomix "($file)" 2>/dev/null &'
}

#open code
export def open2 [file?,--raw] {
  let file = if ($file | is-empty) {$in | get name | get 0} else {$file}
  let extension = ($file | path parse | get extension)

  if ($extension =~ "md|R|c|Rmd|m") or ($extension | is-empty) {
    bat $file
  } else if $extension =~ "nu" {
    open $file | nu-highlight
  } else {
    if $raw {
      open --raw $file
    } else {
      open $file
    }
  }
}

#open file 
export def openf [file?] {
  let file = if ($file | is-empty) {$in} else {$file}

  let file = (
    switch ($file | typeof) {
      "record": {|| 
        $file
        | get name
        | ansi strip
      },
      "table": {||
        $file
        | get name
        | get 0
        | ansi strip
      },
    } { 
        "otherwise": {||
          $file
        }
      }
  )
   
  bash -c $'xdg-open "($file)" 2>/dev/null &'
}

#open last file
export def openl [] {
  lt | last | openf
}

#open google drive file 
export def openg [file?] {
  let file = if ($file | is-empty) {$in | get name} else {$file}
   
  let url = (open $file 
    | lines 
    | drop nth 0 
    | parse "{field}={value}" 
    | table2record 
    | get url
  )

  $url | copy
  print (echo-g $"($url) copied to clipboard!")
}

#accumulate a list of files into the same table
export def openm [
  list? #list of files
  #Example
  #ls *.json | openm
  #let list = ls *.json; openm $list
] {
  let list = if ($list | is-empty) {$in} else {$list}
  
  $list 
  | get name
  | reduce -f [] {|it, acc| 
      $acc | append (open ($it | path expand))
    }
}

#send to printer
export def print-file [file?,--n_copies(-n):int] {
  let file = if ($file | is-empty) {$in | get name | ansi strip} else {$file}
  
  if ($n_copies | is-empty) {
    lp $file
  } else {
    lp -n $n_copies $file
  }
}


#search for specific process
export def psn [name?: string] {
  let name = if ($name | is-empty) {$in} else {$name}
  ps -l | find -i $name
}

#kill specified process in name
export def killn [name?] {
  if not ($name | is-empty) {
    ps -l
    | find -i $name 
    | par-each {||
        kill -f $in.pid
      }
  } else {
    $in
    | par-each {|row|
        kill -f $row.pid
      }
  }
}

#jdownloader downloads info
export def jd [
  --ubb(-b) #check ubb jdownloader
] {
  if ($ubb | is-empty) or (not $ubb) {
    jdown
  } else {
    jdown -b 1
  }
  | from json
}

#select column of a table (to table)
export def column [n] { 
  transpose 
  | select $n 
  | transpose 
  | select column1 
  | headers
}

#get column of a table (to list)
export def column2 [n] { 
  transpose 
  | get $n 
  | transpose 
  | get column1 
  | skip 1
}

#short pwd
export def pwd-short [] {
  $env.PWD 
  | str replace $nu.home-path '~' -s
}

#string repeat
export def "str repeat" [count: int] { 
  each {|it| 
    let str = $it; echo 1..$count 
    | each {||
        echo $str 
      } 
  } 
}

#join 2 lists
export def union [a: list, b: list] {
  $a 
  | append $b 
  | uniq
}

#nushell source files info
export def nu-sloc [] {
  let stats = (
    ls **/*.nu
    | select name
    | insert lines { |it| 
        open $it.name 
        | size 
        | get lines 
      }
    | insert blank {|s| 
        $s.lines - (open $s.name | lines | find --regex '\S' | length) 
      }
    | insert comments {|s| 
        open $s.name 
        | lines 
        | find --regex '^\s*#' 
        | length 
      }
    | sort-by lines -r
  )

  let lines = ($stats | reduce -f 0 {|it, acc| $it.lines + $acc })
  let blank = ($stats | reduce -f 0 {|it, acc| $it.blank + $acc })
  let comments = ($stats | reduce -f 0 {|it, acc| $it.comments + $acc })
  let total = ($stats | length)
  let avg = ($lines / $total | math round)

  $'(char nl)(ansi pr) SLOC Summary for Nushell (ansi reset)(char nl)'
  print { 'Total Lines': $lines, 'Blank Lines': $blank, Comments: $comments, 'Total Nu Scripts': $total, 'Avg Lines/Script': $avg }
  $'(char nl)Source file stat detail:'
  print $stats
}

#go to dir (via pipe)
export def-env cd-pipe [] {
  let input = $in
  cd (
      if ($input | path type -c [name] | get type) == file {
          ($input | path expand | path dirname)
      } else {
          $input | get name
      }
  )
}

#go to bash path (must be the last one in PATH)
export def-env cdto-bash [] {
  cd ($env.PATH | last)
}

#cd to the folder where a binary is located
export def-env which-cd [program] { 
  let dir = (which $program | get path | path dirname | str trim)
  cd $dir.0
}

#push to git, uses gptcommit if installed
# export def-env git-push [] {
#   git add -A
#   git status
#   git commit # -am $"($m)"
#   git push #origin main  
# }

#web search in terminal
export def gg [...search: string] {
  ddgr -n 5 ($search | str join ' ')
}

#habitipy dailies done all
export def hab-dailies-done [] {
  let to_do = (habitipy dailies 
    | grep ✖ 
    | detect columns -n 
    | select column0 
    | each {|row| 
        $row.column0 
        | str replace -s '.' ''
      }  
    | into int  
  )

  if not ($to_do | is-empty) {
    habitipy dailies done $to_do 
  }
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
  } else {
    termdown $n
    unmute
    ^mpv --no-terminal $BEEP
    mute
  }   
}

#get aliases
export def get-aliases [] {
  $nu
  | get scope 
  | get aliases
  | update expansion {|c|
      $c.expansion | nu-highlight
    }
}

#check validity of a link
export def check-link [link?,timeout?:int] {
  let link = if ($link | is-empty) {$in} else {$link}

  if ($timeout | is-empty) {
    try {
      http get $link | ignore;true
    } catch {
      false
    }
  } else {
    try {
      http get $link -m $timeout | ignore;true
    } catch {
      false
    }
  }
}

#send email via Gmail with signature files (posfix configuration required)
export def send-gmail [
  to:string       #email to
  subject:string  #email subject
  --body:string   #email body, use double quotes to use escape characters like \n
  --from:string   #email from, export default: $MY_ENV_VARS.mail
  ...attachments  #email attachments file names list (in current directory), separated by comma
  #
  #Examples:
  #-Body from cli:
  #  send-gmail test@gmail.com "the subject" --body "the body"
  #  echo "the body" | send-gmail test@gmail.com "the subject"
  #-Body from a file:
  #  open file.txt | send-gmail test@gmail.com "the subject"
  #-Attachments:
  # send-gmail test@gmail.com "the subject" --body "the body" this_file.txt
  # echo "the body" | send-gmail test@gmail.com "the subject" this_file.txt,other_file.pdf
  # open file.txt | send-gmail test@gmail.com "the subject" this_file.txt,other_file.pdf,other.srt
] {
  let inp = if ($in | is-empty) { "" } else { $in | into string }
  let from = if ($from | is-empty) {$env.MY_ENV_VARS.mail} else {$from}

  if ($body | is-empty) and ($inp | is-empty) {
    return-error "body unexport defined!!"
  } else if not (($from | str contains "@") and ($to | str contains "@")) {
    return-error "missing @ in email-from or email-to!!"
  } else {
    let signature_file = (
      switch $from {
        $env.MY_ENV_VARS.mail : {|| echo ([$env.MY_ENV_VARS.nu_scripts "send-gmail_kurokirasama_signature"] | path join)},
        $env.MY_ENV_VARS.mail_ubb : {|| echo ([$env.MY_ENV_VARS.nu_scripts "send-gmail_ubb_signature"] | path join)},
        $env.MY_ENV_VARS.mail_lmgg : {|| echo ([$env.MY_ENV_VARS.nu_scripts "send-gmail_lmgg_signature"] | path join)}
      } {otherwise : {|| echo ([$env.MY_ENV_VARS.nu_scripts "send-gmail_other_signature"] | path join)}}
    )

    let signature = (open $signature_file)

    let BODY = (
      if ($inp | is-empty) { 
        $signature 
        | str prepend $"($body)\n" 
      } else { 
        $signature 
        | str prepend $"($inp)\n" 
      } 
    )

    if ($attachments | is-empty) {
      echo $BODY | mail -r $from -s $subject $to
    } else {
      let ATTACHMENTS = ($attachments 
        | split row ","
        | par-each {|file| 
            [$env.PWD $file] 
            | path join
          } 
        | str join " --attach="
        | str prepend "--attach="
      )
      bash -c $"\'echo ($BODY) | mail ($ATTACHMENTS) -r ($from) -s \"($subject)\" ($to) --debug-level 10\'"
    }
  }
}

#get code of custom command
export def code [command,--raw] {
  if ($raw | is-empty) {
    view source $command | nu-highlight
  } else {
    view source $command
  }
}

#register nu plugins
export def reg-plugins [] {
  ls ~/.cargo/bin
  | where type == file 
  | sort-by -i name
  | get name 
  | find nu_plugin 
  | find -v example
  | each {|file|
      if (grep-nu $file $nu.plugin-path | length) == 0 {
        print (echo-g $"registering ($file)...")
        nu -c $'register ($file)'    
      } 
    }
}

#stop network applications
export def stop-net-apps [] {
  sudo service transmission-daemon stop
  yandex-disk stop
  maestral stop
  killn jdown
}

#add a hidden column with the content of the # column
export def indexify [
  column_name?: string = 'index' #export default: index
  ] { 
  enumerate 
  | upsert $column_name {|el| 
      $el.index
    } 
  | flatten
}

#reset alpine authentification
export def reset-alpine-auth [] {
  rm ~/.pine-passfile
  touch ~/.pine-passfile
  alpine-notify -i
}

#run matlab in cli
export def matlab-cli [--ubb(-b)] {
  if not $ubb {
    matlab19 -nosplash -nodesktop -sd $"\"($env.PWD)\"" -logfile "/home/kira/Dropbox/matlab/log19.txt" -r "setenv('SHELL', '/bin/bash');"
  } else {
    matlab19_ubb -nosplash -nodesktop -sd $"\"($env.PWD)\"" -logfile "/home/kira/Dropbox/matlab/log19.txt" -r "setenv('SHELL', '/bin/bash');"
  }
}

#create dir and cd into it
export def-env mkcd [name: path] {
  cd (mkdir $name -v | first)
}

#backup sublime settings
export def "sublime backup" [] {
  cd $env.MY_ENV_VARS.linux_backup

  let source_dir = "~/.config/sublime-text"
  
  7z max sublime-Packages.7z ([$source_dir "Packages"] | path join | path expand)
  7z max sublime-installedPackages.7z ([$source_dir "Installed Packages"] | path join | path expand)
}

#restore sublime settings
export def "sublime restore" [] {
  cd $env.MY_ENV_VARS.linux_backup
  
  7z x sublime-installedPackages.7z -o/home/kira/.config/sublime-text/
  7z x sublime-Packages.7z -o/home/kira/.config/sublime-text/
}

#second screen positioning (work)
export def set-screen [
  side: string = "right"  #which side, left or right (default)
  --home                  #for home pc
  --hdmi = "right"        #for home pc, which hdmi port: left or right (default)
] {
  if not $home {
    switch $side {
      "right": {|| xrandr --output HDMI-1-1 --auto --right-of eDP },
      "left": {|| xrandr --output HDMI-1-1 --auto --left-of eDP }
    } { 
      "otherwise": {|| return-error "Side argument should be either right or left" }
    }
  } else {
    switch $side {
      "right": {||
        if $hdmi == "right" {
          xrandr --output HDMI-1-1 --auto --right-of eDP-1-1
        } else {
          xrandr --output HDMI-0 --auto --right-of eDP-1-1
        } 
      },
      "left": {||
        if $hdmi == "right" {
          xrandr --output HDMI-1-1 --auto --left-of eDP-1-1 
        } else {
          xrandr --output HDMI-0 --auto --left-of eDP-1-1 
        }
      }
    } { 
      "otherwise": {|| return-error "Side argument should be either right or left" }
    }
  }

}

#get files all at once from webpage using wget
export def wget-all [
  webpage: string    #url to scrap
  ...extensions      #list of extensions separated by space
] {
  wget -A ($extensions | str join ",") -m -p -E -k -K -np --restrict-file-names=windows $webpage
}

#convert hh:mm:ss to duration
export def "into duration-from-hhmmss" [hhmmss?] {
  if ($hhmmss | is-empty) {
    $in
  } else {
    $hhmmss   
  }
  | split row :
  | enumerate
  | each {|row| 
      ($row.item | into int) * (60 ** (2 - $row.index))
    } 
  | math sum
  | into string 
  | str append sec
  | into duration
}

#convert duration to hh:mm:ss
export def "into hhmmss" [dur:duration] {
  let seconds = (
    $dur
    | into duration --convert sec
    | split row " "
    | get 0
    | into int
  )

  let h = (($seconds / 3600) | into int | into string | fill -a r -c "0" -w 2)
  let m = (($seconds / 60 ) | into int | into string | fill -a r -c "0" -w 2)
  let s = ($seconds mod 60 | into string | fill -a r -c "0" -w 2)

  $"($h):($m):($s)"
}

#returns a filtered table that has distinct values in the specified column
export def uniq-by [
  column: string  #the column to scan for duplicate values
] {
  reduce { |item, acc|
    if ($acc | any { |storedItem|
      ($storedItem | get $column) == ($item | get $column)
    }) {
      $acc
    } else {
      $acc | append $item
    }
  }
}

#get total sizes of ls output
export def sum-size [] {
  get size | math sum
}

#table to record
export def table2record [] {
  transpose -r -d 
}

#extract first link from text
export def open-link [] {
  lines 
  | find http
  | first 
  | get 0
  | openf
}

#umount all drives (duf)
export def umall [user?] {
  let user = if ($user | is-empty) {$env.USER} else {$user}

  try {
    duf -json 
    | from json 
    | find $"/media/($user)" 
    | get mount_point
    | each {|drive| 
        print (echo-g $"umounting ($drive  | ansi strip)...")
        umount ($drive | ansi strip)
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

#ansi strip table
export def "ansi strip-table" [] {
  update cells {|cell|
    if ($cell | describe) == string { 
      $cell | ansi strip
    } else {
      $cell
    }
  }
}

#my pdflatex
export def my-pdflatex [file?] {
  let tex = if ($file | is-empty) {$in | get name} else {$file}
  texfot pdflatex -interaction=nonstopmode -synctex=1 ($tex | path parse | get stem)
}

#generate error output
export def return-error [msg] {
  error make -u {msg: $"(echo-r $msg)"}
}

#find index of a search term
export def "find index" [name: string,default? = -1] {
  $in
  | upsert idx {|el,id| $id}
  | find $name
  | try {
      get idx
    } catch {
      -1
    }
}

#calculates elements that are in list a but not in list b
export def setdiff [a,b] {
  $a 
  | each {|n| 
    if $n not-in $b {$n} 
  }
}

#maestral status
export def "dpx status" [] {
  maestral status | lines | parse "{item}  {status}" | str trim | drop nth 0
}

#qr code generator
export def qrenc [url] {
  curl $"https://qrenco.de/($url)"
}

#date formatting
export def "date my-format" [
  date?: string #date in form 
  --extra = ""  #some text to append to the date (default empty)
  #
  #format date in the form Mmm ss, hh:mm
  #Example: "Apr 24, 15:08"
] {
  let date = if ($date | is-empty) {$in} else {$date}

  date now 
  | date format "%Y"
  | str append " " 
  | str append $date
  | str append "+00:00" 
  | into datetime 
  | date format "%Y.%m.%d_%H.%M"
  | str append $extra
}

#date renaming
export def rename-date [file,--extra = ""] {
  let extension = ($file | path parse | get extension)
  let new_name = (
    $file 
    | path parse
    | get stem 
    | date my-format --extra $extra
    | str append $".($extension)"
  )
}

#default a full table 
# export def "default table" [
#   table?                    #table to process
#   --default_value(-d) = null#default value to use, default = null
# ] {
#   mut tab = if ($table | is-empty) {$in} else {$table}
#   let cols = ($tab | columns) 
  
#   for col in $cols {
#       $tab = ($tab | default $default_value $col) 
#   }

#   $tab
# }


## appimages

#open balena-etche
export def balena [] {
  bash -c $"([$env.MY_ENV_VARS.appImages 'balenaEtcher.AppImage'] | path join) 2>/dev/null &"
}