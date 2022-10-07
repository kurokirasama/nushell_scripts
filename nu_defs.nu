#helper for displaying left prompt
export def left_prompt [] {
  if not ($env.MY_ENV_VARS | is-column l_prompt) {
      $env.PWD | path parse | get stem
  } else if ($env.MY_ENV_VARS.l_prompt | is-empty) || ($env.MY_ENV_VARS.l_prompt == 'short') {
      $env.PWD | path parse | get stem
  } else {
      $env.PWD | str replace $nu.home-path '~' -s
  }
}

#update nu config (after nu update)
export def update-nu-config [] {
  ls (build-string $env.MY_ENV_VARS.nushell_dir "/**/*") 
  | find -i default_config 
  | update name {|n| 
      $n.name 
      | ansi strip
    }  
  | cp-pipe $nu.config-path

  open ([$env.MY_ENV_VARS.linux_backup "append_to_config.nu"] | path join) | save --append $nu.config-path
  nu -c $"source-env ($nu.config-path)"
}

#short help
export def ? [...search] {
  if ($search | is-empty) {
    help commands
  } else {
    if ($search | first) =~ "commands" {
      if ($search | first) =~ "my" {
        help commands | where is_custom == true
      } else {
        help commands 
      }
    } else if ($search | first | str contains "^") {
      tldr ($search | str collect "-" | split row "^" | get 0) | nu-highlight
    } else if (which ($search | first) | get path | get 0) =~ "Nushell" {
      if (which ($search | first) | get path | get 0) =~ "alias" {
        get-aliases | find ($search | first)
      } else {
        help ($search | str collect " ") | nu-highlight
      }
    } else {
      tldr ($search | str collect "-") | nu-highlight
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
    if ($outputFile | is-empty) || (not $outputFile) {
      $"($inputFile | path parse | get stem).csv"
    } else {
      $outputFile
    }
  )
  libreoffice --headless --convert-to csv $inputFile
}

#compress to 7z using max compression
export def 7zmax [
  filename: string  #filename without extension
  ...rest:  string  #files to compress and extra flags for 7z (add flags between quotes)
  --delete(-d)      #delete files after compression
  #
  # Example:
  # compress all files in current directory and delete them
  # 7zmax filename * "-sdel"
  # compress all files in current directory and split into pieces of 3Gb (b|k|m|g)
  # 7zmax filename * "-v3g"
  # both
  # 7zmax filename * "-v3g -sdel"
] {
  if ($rest | is-empty) {
    echo-r "no files to compress specified"
  } else if ($delete | is-empty) || (not $delete) {
    7z a -t7z -m0=lzma2 -mx=9 -ms=on -mmt=on $"($filename).7z" $rest
  } else {
    7z a -t7z -sdel -m0=lzma2 -mx=9 -ms=on -mmt=on $"($filename).7z" $rest
  }
}

#add event to google calendar, also usable without arguments
export def addtogcal [
  calendar?   #to which calendar add event
  title?      #event title
  when?       #date: yyyy.MM.dd hh:mm
  where?      #location
  duration?   #duration in minutes
] {
  let calendar = if ($calendar | is-empty) {input (echo-g "calendar: ")} else {$calendar}
  let title = if ($title | is-empty) {input (echo-g "title: ")} else {$title}
  let when = if ($when | is-empty) {input (echo-g "when: ")} else {$when}
  let where = if ($where | is-empty) {input (echo-g "where: ")} else {$where}
  let duration = if ($duration | is-empty) {input (echo-g "duration: ")} else {$duration}
  
  gcalcli --calendar $"($calendar)" add --title $"($title)" --when $"($when)" --where $"($where)" --duration $"($duration)" --default-reminders
}

#show gcal agenda in selected calendars
export def agenda [
  --full: int  #show all calendars (export default: 0)
  ...rest      #extra flags for gcalcli between quotes (specified full needed)
  #
  # Examples
  # agenda 
  # agenda --full true
  # agenda "--details=all"
  # agenda --full true "--details=all"
] {
  let calendars = $env.MY_ENV_VARS.google_calendars
  let calendars_full = $env.MY_ENV_VARS.google_calendars_full

  if ($full | is-empty) || ($full == 0) {
    gcalcli --calendar $"($calendars)" agenda --military $rest
  } else {
    gcalcli --calendar $"($calendars_full)" agenda --military $rest
  }
}

#show gcal week in selected calendards
export def semana [
  --full: int  #show all calendars (export default: 0)
  ...rest      #extra flags for gcalcli between quotes (specified full needed)
  #
  # Examples
  # semana 
  # semana --full true
  # semana "--details=all"
  # semana --full true "--details=all"
] {
  let calendars = $env.MY_ENV_VARS.google_calendars
  let calendars_full = $env.MY_ENV_VARS.google_calendars_full
  
  if ($full | is-empty) || ($full == 0) {
    gcalcli --calendar $"($calendars)" calw $rest --military --monday
  } else {
    gcalcli --calendar $"($calendars_full)" calw $rest --military --monday
  }
}

#show gcal month in selected calendards
export def mes [
  --full: int  #show all calendars (export default: 0)
  ...rest      #extra flags for gcalcli between quotes (specified full needed)
  #
  # Examples
  # mes 
  # mes --full true
  # mes "--details=all"
  # mes --full true "--details=all"
] {
  let calendars = $env.MY_ENV_VARS.google_calendars
  let calendars_full = $env.MY_ENV_VARS.google_calendars_full
  
  if ($full | is-empty) || ($full == 0) {
    gcalcli --calendar $"($calendars)" calm $rest --military --monday
  } else {
    gcalcli --calendar $"($calendars_full)" calm $rest --military --monday
  }
}

#get bitly short link
export def mbitly [longurl] {
  if ($longurl | is-empty) {
    echo-r "no url provided"
  } else {
    let bitly_credential = open ([$env.MY_ENV_VARS.credentials "bitly_token.json"] | path join)
    let Accesstoken = ($bitly_credential | get token)
    let username = ($bitly_credential | get username)
    
    let url = $"https://api-ssl.bitly.com/v3/shorten?access_token=($Accesstoken)&login=($username)&longUrl=($longurl)"
    let shorturl = (fetch $url | get data | get url)

    $shorturl | copy
    echo-g $"($shorturl) copied to clipboard!"
  }
}

#translate text using mymemmory api
export def trans [
  ...search:string  #search query
  --from:string     #from which language you are translating (export default english)
  --to:string       #to which language you are translating (export default spanish)
  #
  #Use ISO standar names for the languages, for example:
  #english: en-US
  #spanish: es-ES
  #italian: it-IT
  #swedish: sv-SV
  #
  #More in: https://en.wikipedia.org/wiki/List_of_ISO_639-1_codes
] {
  if ($search | is-empty) {
    echo-r "no search query provided"
  } else {
    let trans_credential = open ([$env.MY_ENV_VARS.credentials "mymemory_token.json"] | path join)
    let key = ($trans_credential | get token)
    let user = ($trans_credential | get username)

    let from = if ($from | is-empty) {"en-US"} else {$from}
    let to = if ($to | is-empty) {"es-ES"} else {$to}

    let to_translate = ($search | str collect "%20")

    let url = $"https://api.mymemory.translated.net/get?q=($to_translate)&langpair=($from)%7C($to)&of=json&key=($key)&de=($user)"

    fetch $url 
    | get responseData 
    | get translatedText
  }
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

#update-upgrade system
export def supgrade [--old(-o)] {
  if not $old {
    echo-g "updating and upgrading..."
    sudo nala upgrade -y

    echo-g "autoremoving..."
    sudo nala autoremove -y
  } else {
    echo-g "updating..."
    sudo apt update -y

    echo-g "upgrading..."
    sudo apt upgrade -y

    echo-g "autoremoving..."
    sudo apt autoremove -y
  }

  echo-g "updating rust..."
  rustup update

  echo-g "upgrading pip3 packages..."
  pip3-upgrade
}

#upgrade pip3 packages
export def pip3-upgrade [] {
  pip3 list --outdated --format=freeze 
  | lines 
  | split column "==" 
  | each {|pkg| 
      echo-g $"upgrading ($pkg.column1)..."
      pip3 install --upgrade $pkg.column1
    }
}

#green echo
export def echo-g [string:string] {
  echo $"(ansi -e { fg: '#00ff00' attr: b })($string)(ansi reset)"
}

#red echo
export def echo-r [string:string] {
  echo $"(ansi -e { fg: '#ff0000' attr: b })($string)(ansi reset)"
}

#open mcomix
export def mcx [file?] {
  let file = if ($file | is-empty) {$in} else {$file}

  bash -c $'mcomix "($file)" 2>/dev/null &'
}

#open file 
export def openf [file?] {
  let file = if ($file | is-empty) {$in} else {$file}

  let file = (
    switch ($file | typeof) {
      "record": { 
        $file
        | get name
        | ansi strip
      },
      "table": { 
        $file
        | get name
        | get 0
        | ansi strip
      },
    } { 
        "otherwise": { 
          $file
        }
      }
  )
   
  bash -c $'xdg-open "($file)" 2>/dev/null &'
}

#open google drive file 
export def openg [file?] {
  let file = if ($file | is-empty) {$in | get name} else {$file}
   
  let url = (open $file 
    | lines 
    | find -i url 
    | split row "URL=" 
    | get 0
  )

  $url | copy
  echo-g $"($url) copied to clipboard!"
}

#send to printer
export def print-file [file?] {
  let file = if ($file | is-empty) {$in | get name} else {$file}
  lp $file
}

#play first/last downloaded youtube video
export def myt [file?, --reverse(-r)] {
  let inp = $in
  let video = (
    if not ($inp | is-empty) {
      $inp | get name
    } else if not ($file | is-empty) {
      $file
    } else if $reverse {
      ls | sort-by modified -r | where type == "file" | last | get name
    } else {
      ls | sort-by modified | where type == "file" | last | get name
    }
  )
  
  mpv --ontop --window-scale=0.4 --save-position-on-quit --no-border $video

  let delete = (input "delete file? (y/n): ")
  if $delete == "y" {
    rm $video
  } else {
    let move = (input "move file to pending? (y/n): ")
    if $move == "y" {
      mv $video pending
    }
  } 
}

#search for specific process
export def psn [name: string] {
  ps -l | find -i $name
}

#kill specified process in name
export def killn [name?] {
  if not ($name | is-empty) {
    ps -l
    | find -i $name 
    | par-each {
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
  --ubb(-b)#check ubb jdownloader
] {
  if ($ubb | is-empty) || (not $ubb) {
    jdown
  } else {
    jdown -b 1
  }
  | lines 
  | each { |line| 
      $line 
      | from nuon 
    } 
  | flatten 
  | flatten
}

# Switch-case like instruction
export def switch [
  var                #input var to test
  cases: record      #record with all cases
  otherwise?: record #record code for otherwise
  #
  # Example:
  # let x = "3"
  # switch $x {
  #   1: { echo "you chose one" },
  #   2: { echo "you chose two" },
  #   3: { echo "you chose three" }
  # }
  #
  # let x = "4"
  # switch $x {
  #   1: { echo "you chose one" },
  #   2: { echo "you chose two" },
  #   3: { echo "you chose three" }
  # } { otherwise: { echo "otherwise" }}
  #
] {
  if ($cases | is-column $var) {
    $cases 
    | get $var 
    | do $in
  } else if not ($otherwise | is-empty) {
    $otherwise 
    | get "otherwise" 
    | do $in
  }
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
    | each { 
        echo $str 
      } 
  } 
}

#string prepend
export def "str prepend" [toprepend] { 
  build-string $toprepend $in
}

#string append
export def "str append" [toappend] { 
  build-string $in $toappend
}

#join 2 lists
export def union [a: list, b: list] {
  $a 
  | append $b 
  | uniq
}

#nushell source files info
export def 'nu-sloc' [] {
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
      if ($input | path type) == file {
          ($input | path dirname)
      } else {
          $input
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

#delete non wanted media in mps (youtube download folder)
export def delete-mps [] {
  if $env.MY_ENV_VARS.mps !~ $env.PWD {
    echo-r "wrong directory to run this"
  } else {
     le
     | where type == "file" && ext !~ "mp4|mkv|webm|part" 
     | par-each {|it| 
         rm $"($it.name)" 
         | ignore
       }     
  }
}

#push to git
export def git-push [m: string] {
  git add -A
  git status
  git commit -am $"($m)"
  git push #origin main  
}

#web search in terminal
export def gg [...search: string] {
  ddgr -n 5 ($search | str collect ' ')
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

  habitipy dailies done $to_do 
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
    mpv --no-terminal $BEEP  
  } else {
    termdown $n
    unmute
    mpv --no-terminal $BEEP
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

#ping with plot
export def png-plot [ip?] {
  let ip = if ($ip | is-empty) {"1.1.1.1"} else {$ip}

  bash -c $"ping ($ip) | sed -u 's/^.*time=//g; s/ ms//g' | ttyplot -t \'ping to ($ip)\' -u ms"
}

#plot download-upload speed
export def speedtest-plot [] {
  echo "fast --single-line --upload |  stdbuf -o0 awk '{print $2 \" \" $6}' | ttyplot -2 -t 'Download/Upload speed' -u Mbps" | bash 
}

#plot data table using gnuplot
export def gnu-plot [
  data?           #1 or 2 column table
  --title:string  #title
  #
  #Example: If $x is a table with 2 columns
  #$x | gnu-plot
  #($x | column 0) | gnu-plot
  #($x | column 1) | gnu-plot
  #($x | column 0) | gnu-plot --title "My Title"
  #gnu-plot $x --title "My Title"
] {
  let x = if ($data | is-empty) {$in} else {$data}
  let n_cols = ($x | transpose | length)
  let name_cols = ($x | transpose | column2 0)

  let ylabel = if $n_cols == 1 {$name_cols | get 0} else {$name_cols | get 1}
  let xlabel = if $n_cols == 1 {""} else {$name_cols | get 0}

  let title = if ($title | is-empty) {
    if $n_cols == 1 {
      $ylabel | str upcase
    } else {
      $"($ylabel) vs ($xlabel)"
    }
  } else {
    $title
  }

  $x | to tsv | save data0.txt 
  sed 1d data0.txt | save data.txt
  
  gnuplot -e $"set terminal dumb; unset key;set title '($title)';plot 'data.txt' w l lt 0;"

  rm data*.txt | ignore
} 

#check validity of a link
export def check-link [link?,timeout?:int] {
  let link = if ($link | is-empty) {$in} else {$link}

  if ($timeout | is-empty) {
    not (do -i { fetch $link } | is-empty)
  } else {
    not (do -i { fetch $link -t $timeout} | is-empty)
  }
}

#sync subtitles
export def sub-sync [
  file:string      #subtitle file name to process
  d1:string        #delay at the beginning or at time specified by t1 (<0 adelantar, >0 retrasar)
  --t1:string      #time position of delay d1 (hh:mm:ss)
  --d2:string      #delay at the end or at time specified by t2
  --t2:string      #time position of delay d2 (hh:mm:ss)t
  --no_backup:int  #wether to not backup $file or yes (export default no:0, ie, it will backup)
  #
  #Examples
  #sub-sync file.srt "-4"
  #sub-sync file.srt "-4" --t1 00:02:33
  #sub-sync file.srt "-4" --no_backup 1
] {

  let file_exist = (($env.PWD) | path join $file | path exists)
  
  if $file_exist {
    if ($no_backup | is-empty) || $no_backup == 0 {
      cp $file $"($file).backup"
    }

    let t1 = if ($t1 | is-empty) {"@"} else {$t1}  
    let d2 = if ($d2 | is-empty) {""} else {$d2}
    let t2 = if ($d2 | is-empty) {""} else {if ($t2 | is-empty) {"@"} else {$t2}}
  
    bash -c $"subsync -e latin1 ($t1)($d1) ($t2)($d2) < \"($file)\" > output.srt; cp output.srt \"($file)\""

    rm output.srt | ignore
  } else {
    echo-r $"subtitle file ($file) doesn't exist in (pwd-short)"
  }
}

#rm trough pipe
#
#Example
#ls *.txt | first 5 | rm-pipe
export def rm-pipe [] {
  if not ($in | is-empty) {
    get name 
    | ansi strip
    | par-each {|file| 
        rm -rf $file
      } 
    | flatten
  }
}

#cp trough pipe to same dir
export def cp-pipe [
  to: string#target directory
  #
  #Example
  #ls *.txt | first 5 | cp-pipe ~/temp
] {
  get name 
  | each {|file| 
      echo-g $"copying ($file)..." 
      cp -r $file ($to | path expand)
    } 
  | flatten
}

#mv trough pipe to same dir
export def mv-pipe [
  to: string#target directory
  #
  #Example
  #ls *.txt | first 5 | mv-pipe ~/temp
] {
  get name 
  | each {|file|
      echo-g $"moving ($file)..." 
      mv $file ($to | path expand)
    }
  | flatten
}

#ls by date (newer last)
export def lt [
  --reverse(-r) #reverse order
] {
  if ($reverse | is-empty) || (not $reverse) {
    ls | sort-by modified  
  } else {
    ls | sort-by modified -r
  } 
}

#ls in text grid
export def lg [
  --date(-t)    #sort by date
  --reverse(-r) #reverse order
] {
  let t = if $date {"true"} else {"false"}
  let r = if $reverse {"true"} else {"false"}

  switch $t {
    "true": { 
      switch $r {
        "true": { 
          ls | sort-by -r modified | grid -c
        },
        "false": { 
          ls | sort-by modified | grid -c
        }
      }
    },
    "false": { 
      switch $r {
        "true": { 
          ls | sort-by -i -r type name | grid -c
        },
        "false": { 
          ls | sort-by -i type name | grid -c
        }
      }
    }
  }
}

#ls sorted by name
export def ln [--du(-d)] {
  if $du {
    ls --du | sort-by -i type name 
  } else {
    ls | sort-by -i type name 
  }
}

#ls only name
export def lo [] {
  ls 
  | sort-by -i type name 
  | reject type size modified 
}

#ls sorted by extension
export def le [] {
  ls
  | sort-by -i type name 
  | insert "ext" { 
      $in.name 
      | path parse 
      | get extension 
    } 
  | sort-by ext
}

#get list of files recursively
export def get-files [] {
  ls **/* 
  | where type == file 
  | sort-by -i name
}


#find file in dir recursively
export def find-file [search] {
  get-files 
  | where name =~ $search
}

#get list of directories in current path
export def get-dirs [dir?] {
  if ($dir | is-empty) {
    ls 
    | where type == dir 
    | sort-by -i name
  } else {
    ls $dir
    | where type == dir 
    | sort-by -i name
  }
}

#get devices connected to network
export def get-devices [
  device = "wlo1" #wlo1 for wifi (export default), eno1 for lan
  #
  #It needs nmap2json, installable (ubuntu at least) via
  #
  #sudo gem install nmap2json
] {
  let ipinfo = (
    if (? | where name == net | length) > 0 {
      net 
      | where name == ($device) 
      | get 0 
      | get ips 
      | where type == v4 
      | get 0 
      | get addr
      | str replace '(?P<nums>\d+/)' '0/'
    } else {
      ip -json add 
      | from json 
      | where ifname =~ $"($device)" 
      | select addr_info 
      | flatten 
      | find -v inet6 
      | flatten 
      | get local prefixlen 
      | flatten 
      | str collect '/' 
      | str replace '(?P<nums>\d+/)' '0/'
    }
  )

  let nmap_output = (sudo nmap -oX nmap.xml -sn $ipinfo --max-parallelism 10)

  let nmap_output = (nmap2json convert nmap.xml | from json | get nmaprun | get host | get address)

  let this_ip = ($nmap_output | last | get addr)

  let ips = ($nmap_output 
    | drop 1 
    | flatten 
    | where addrtype =~ ipv4 
    | select addr 
    | rename ip
  )
  
  let macs_n_names = ($nmap_output 
    | drop 1 
    | flatten 
    | where addrtype =~ mac 
    | select addr vendor 
    | rename mac name
    | update name {|f|
        if ($f.name | is-empty) {
          "Unknown"
        } else {
          $f.name
        }
      }
  )

  let devices = ( $ips | merge { $macs_n_names} )

  let known_devices = open ([$env.MY_ENV_VARS.linux_backup "known_devices.csv"] | path join)
  let known_macs = ($known_devices | get mac | str upcase)

  let known = ($devices | each {any it.mac in $known_macs} | wrap known)

  let devices = ($devices | merge {$known})

  let aliases = (
    $devices 
    | each {|row| 
        if $row.known {
          $known_devices | find $row.mac | get alias
        } else {
          " "
        }
      } 
    | flatten 
    | wrap alias
  )
   
  rm nmap.xml | ignore 

  $devices | merge {$aliases}
}

#verify if a column exist within a table
export def is-column [name] { 
  $name in ($in | columns) 
}

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

#get ips
export def get-ips [
  device =  "wlo1"  #wlo1 for wifi (export default), eno1 for lan
] {
  let internal = (ip -json add 
    | from json 
    | where ifname =~ $"($device)" 
    | select addr_info 
    | flatten | find -v inet6 
    | flatten 
    | get local 
    | get 0
  )

  let external = (dig +short myip.opendns.com @resolver1.opendns.com)
  
  {internal: $internal, external: $external}
}

#geeknote find
export def geek-find [
  search:string  #search term in title
  ...rest:string #extra flags for geeknote
  #
  #Example
  #geek-find ssh
  #geek-find ssh "--tag linux"
] {
  let result = if ($rest | is-empty) {
      do -i {geeknote find --search $search} 
      | complete 
      | get stdout
    } else {
      let command = (build-string "geeknote find --search " $search " " ($rest | str collect ' '))
      do -i {nu -c $command} 
      | complete 
      | get stdout
    }

  $result
  | lines 
  | drop nth 1 
  | str replace ': 2' '¬ 2' 
  | each {|it| 
      $it | split row '¬' | last
    }
}

#geeknote show
export def geek-show [
  item:int       #search term in title
  ...rest:string #extra flags for geeknote show (--raw)
  #
  #Example (after a geek-find)
  #geek-show 1
  #geek-show 1 "--raw"
] {
  let result = if ($rest | is-empty) {
      do -i {geeknote show $item} 
      | complete 
      | get stdout
    } else {
      let command = (build-string "geeknote show " ($item | into string) " " ($rest | str collect ' '))
      do -i {nu -c $command} 
      | complete 
      | get stdout
    }

  $result 
  | nu-highlight 
  | lines 
}

#geeknote edit
export def geek-edit [
  item:int       #search term in title
  ...rest:string #extra flags for geeknote show (--raw)
  #
  #Example (after a geek-find)
  #geek-edit 1
  #geek-edit 1 "--tag new_tag"
] {
  if ($rest | is-empty) {
    geeknote edit $item
  } else {
    let command = (build-string "geeknote edit " ($item | into string) " " ($rest | str collect ' '))
    nu -c $command
  }
}

#geeknote create
export def geek-create [
  commands:string #list of commands to create a note
  #
  #Example 
  #geek-create "--title 'a note'"
  #geek-create "--title 'a note' --tag linux --content 'the content'"
] {
  nu -c (build-string "geeknote create" " " $commands)
}

#open transmission tui
export def t-ui [] {
  let ip = (get-ips | get internal)
  tremc -c $"transmission:transmission@($ip):9091"
}

#add file to transmission download queue
export def t-add [
  down  #magnetic link or torrent file
] {
  transmission-remote -n 'transmission:transmission' -a $down
}

#add magnetic links from file to transmission download queue
export def t-addfromfile [
  file  #text file with 1 magnetic link per line
] {
  open $file 
  | lines 
  | each {|link|
      t-add $link
    }
}

#get info of a torrent download 
export def t-info [
  id:int  #id of the torrent to fetch
] {
  transmission-remote -t $id -n 'transmission:transmission' -i
}

#delete torrent from download queue without deleting files
export def t-remove [
  ...ids    #list of ids
] {
  $ids 
  | each {|id| 
      transmission-remote -t $id -n 'transmission:transmission' --remove
    }
}

#delete torrent from download queue deleting files
export def t-removedelete [
  ...ids    #list of ids
  #Examples
  #t-removedelete 2 3 6 9
  #t-list | some filter | t-removedelete
] {
  if ($ids | is-empty) {
    $in
    | find -v "Sum:"
    | get ID 
    | each {|id| 
        transmission-remote -t $id -n 'transmission:transmission' -rad
      }
  } else {
    $ids 
    | each {|id| 
        transmission-remote -t $id -n 'transmission:transmission' -rad
      }
  }
}

#delete finished torrent from download queue without deleting files
export def t-removedone [] {
  t-list 
  | drop 1 
  | where ETA =~ Done 
  | get ID 
  | each {|id|
      transmission-remote  -t $id -n 'transmission:transmission' --remove
    } 
}

#delete torrent from download queue that match a search without deleting files
export def t-removename [
  search  #search term
] {
  t-list 
  | drop 1 
  | find -i $search 
  | get ID 
  | each {|id|
      transmission-remote  -t $id -n 'transmission:transmission' --remove
    } 
}

#start a torrent from download queue
export def t-starttorrent [
  id:int  #torrent id
] {
  transmission-remote -t $id -n 'transmission:transmission' -s
}

#start all torrents
export def t-starttorrents [] {
  t-list 
  | drop 1 
  | get ID 
  | each {|id|
      transmission-remote -t $id -n 'transmission:transmission' -s
    }
}

#stop a torrent from download queue
export def t-stoptorrent [
  id:int  #torrent id
] {
  transmission-remote -t $id -n 'transmission:transmission' -S
}

#stop all torrents
export def t-stoptorrents [] {
  t-list 
  | drop 1 
  | get ID 
  | each {|id|
      transmission-remote -t $id -n 'transmission:transmission' -S
    }
}

#umount all drives (duf)
export def umall [user? = $env.USER] {
  duf -json 
  | from json 
  | find $"/media/($user)" 
  | get mount_point
  | each {|drive| 
      echo-g $"umounting ($drive)..."
      umount $drive
    }
}

#convert media files recursively to specified format
export def media-to [
  to:string #destination format (aac, mp3 or mp4)
  #
  #Examples (make sure there are only compatible files in all subdirectories)
  #media-to mp4 (avi to mp4)
  #media-to aac (audio files to aac)
  #media-to mp3 (audio files to mp3)
] {
  #to aac or mp3
  if $to =~ "aac" || $to =~ "mp3" {
    let n_files = (bash -c $'find . -type f -not -name "*.part" -not -name "*.srt" -not -name "*.mkv" -not -name "*.mp4" -not -name "*.txt" -not -name "*.url" -not -name "*.jpg" -not -name "*.png" -not -name "*.($to)"'
        | lines 
        | length
    )

    echo-g $"($n_files) audio files found..."

    if $n_files > 0 {
      bash -c $'find . -type f -not -name "*.part" -not -name "*.srt" -not -name "*.mkv" -not -name "*.mp4" -not -name "*.txt" -not -name "*.url" -not -name "*.jpg" -not -name "*.png" -not -name "*.($to)" -print0 | parallel -0 --eta myffmpeg -n -loglevel 0 -i {} -c:a ($to) -b:a 64k {.}.($to)'

      let aacs = (ls **/* 
        | insert "ext" { 
            $in.name | path parse | get extension
          }  
        | where ext =~ $to 
        | length
      )

      if $n_files == $aacs {
        echo-g $"audio conversion to ($to) done"
      } else {
        echo-r $"audio conversion to ($to) done, but something might be wrong"
      }
    }
  #to mp4
  } else if $to =~ "mp4" {
    let n_files = (ls **/*
        | insert "ext" { 
            $in.name | path parse | get extension
          }  
        | where ext =~ "avi"
        | length
    )

    echo-g $"($n_files) avi files found..."

    if $n_files > 0 {
      bash -c 'find . -type f -name "*.avi" -print0 | parallel -0 --eta myffmpeg -n -loglevel 0 -i {} -b:a 64k {.}.mp4'

      let aacs = (ls **/* 
        | insert "ext" { 
            $in.name | path parse | get extension
          }  
        | where ext =~ "mp4"
        | length
      )

      if $n_files == $aacs {
        echo-g $"video conversion to mp4 done"
      } else {
        echo-r $"video conversion to mp4 done, but something might be wrong"
      }
    }
  }
}

#cut audio
export def cut-audio [
  infile:string   #input audio file
  outfile:string  #output audio file
  start:int       #start of the piece to extract (s) 
  duration:int    #duration of the piece to extract (s)
  #
  #Example: cut 10s starting at second 60 
  #cut_audio input.ext output.ext 60 10
] {  
  myffmpeg -ss $start -i $"($infile)" -t $duration -c copy $"($outfile)"
}

#merge subs to mkv video
export def merge-subs [
  filename  #name (without extencion) of both subtitle and mkv file
] {
  mkvmerge -o myoutput.mkv  $"($filename).mkv" --language "0:spa" --track-name $"0:($filename)" $"($filename).srt"
  mv myoutput.mkv $"($filename).mkv"
  rm $"($filename).srt" | ignore
}

#merge videos
export def merge-videos [
  list  #text file with list of videos to merge
  output#output file
  #
  #To get a functional output, all audio sample rate must be the same
  #check with video-info video_file
  #
  #The file with the list must have the following structure:
  #
  #~~~
  #file '/path/to/file/file1'"
  #.
  #.
  #.
  #file '/path/to/file/fileN'"
  #~~~
] {
  echo-g "merging videos..."
  myffmpeg -f concat -safe 0 -i $"($list)" -c copy $"($output)"
  
  echo-g "done!"
  notify-send "video merging done!"
}

#auto merge all videos in dir
export def merge-videos-auto [
  ext   #unique extension of all videos to merge
  output#output file
  #
  #To get a functional output, all audio sample rate must be the same
  #check with video-info video_file
] {
  let list = (($env.PWD) | path join "list.txt")

  if not ($list | path exists) {
    touch $"($list)"
  } else {
    "" | save $list
  }
  
  ls $"*.($ext)" 
  | where type == file 
  | get name
  | each {|file|
      echo (build-string "file \'" (($env.PWD) | path join $file) "\'\n") | save --append list.txt
    }

  echo-g "merging videos..."
  myffmpeg -f concat -safe 0 -i list.txt -c copy $"($output)"
      
  echo-g "done!"
  notify-send "video merging done!"
}

#join multiple pdfs
export def join-pdfs [
  ...rest: #list of pdf files to concatenate
] {
  if ($rest | is-empty) {
    echo-r "not enough pdfs provided"
  } else {
    pdftk $rest cat output output.pdf
    echo-g "pdf merged in output.pdf"
  }
}

#video info
export def video-info [file] {
  mpv -ao null -frames 0 $"($file)" 
  | detect columns -n 
  | first 2 
  | reject column0 
  | rename track id extra codec
  | update cells {|f|
      $f 
      | str replace -a -s "(" "" 
      | str replace -a -s ")" ""
    }
}

#remove audio noise from video
export def remove-video-noise [
  file      #video file name with extension
  start     #start (hh:mm:ss) of audio noise (no speaker)
  end       #end (hh:mm:ss) of audio noise (no speaker)
  noiseLevel#level reduction adjustment (0.2-0.3)
  output    #output file name with extension (same extension as $file)
] {
  if (ls ([$env.PWD tmp*] | path join) | length) > 0 {
    rm tmp*
  }

  echo-g "extracting video..."
  myffmpeg -loglevel 1 -i $"($file)" -vcodec copy -an tmpvid.mp4

  echo-g "extracting audio..."
  myffmpeg -loglevel 1 -i $"($file)" -acodec pcm_s16le -ar 128k -vn tmpaud.wav

  echo-g "extracting noise..."
  myffmpeg -loglevel 1 -i $"($file)" -acodec pcm_s16le -ar 128k -vn -ss $start -t $end tmpnoiseaud.wav

  echo-g "creating noise profile..."
  sox tmpnoiseaud.wav -n noiseprof tmpnoise.prof

  echo-g "cleaning noise from audio file..."
  sox tmpaud.wav tmpaud-clean.wav noisered tmpnoise.prof $noiseLevel

  echo-g "merging clean audio with video file..."
  myffmpeg -loglevel 1 -i tmpvid.mp4 -i tmpaud-clean.wav -map 0:v -map 1:a -c:v copy -c:a aac -b:a 128k $output

  echo-g "done!"
  notify-send "noise removal done!"

  echo-g "don't forget to remove tmp* files"
}

#screen record to mp4
export def screen-record [
  file = "video"  #output filename without extension (export default: "video")
  --audio = true    #whether to record with audio or not (export default: true)
] {
  if $audio {
    ffmpeg -video_size 1920x1080 -framerate 24 -f x11grab -i :0.0+0,0 -f alsa -ac 2 -i pulse -acodec aac -strict experimental $"($file).mp4"
  } else {
    ffmpeg -video_size 1920x1080 -framerate 24 -f x11grab -i :0.0+0,0 $"($file).mp4"
  }
}

#send email via Gmail with signature files (posfix configuration required)
export def send-gmail [
  to:string                         #email to
  subject:string                    #email subject
  --body:string                     #email body, use double quotes to use escape characters like \n
  --from = $env.MY_ENV_VARS.mail    #email from, export default: $MY_ENV_VARS.mail
  ...attachments                    #email attachments file names list (in current directory), separated by comma
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

  if ($body | is-empty) && ($inp | is-empty) {
    echo-r "body unexport defined!!"
  } else if not (($from | str contains "@") && ($to | str contains "@")) {
    echo-r "missing @ in email-from or email-to!!"
  } else {
    let signature_file = (
      switch $from {
        $env.MY_ENV_VARS.mail : {echo ([$env.MY_ENV_VARS.nu_scripts "send-gmail_kurokirasama_signature"] | path join)},
        $env.MY_ENV_VARS.mail_ubb : {echo ([$env.MY_ENV_VARS.nu_scripts "send-gmail_ubb_signature"] | path join)},
        $env.MY_ENV_VARS.mail_lmgg : {echo ([$env.MY_ENV_VARS.nu_scripts "send-gmail_lmgg_signature"] | path join)}
      } {otherwise : {echo ([$env.MY_ENV_VARS.nu_scripts "send-gmail_other_signature"] | path join)}}
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
        | str collect " --attach="
        | str prepend "--attach="
      )
      bash -c $"\'echo ($BODY) | mail ($ATTACHMENTS) -r ($from) -s \"($subject)\" ($to) --debug-level 10\'"
    }
  }
}

#get code of custom command
export def code [command] {
  view-source $command | nu-highlight
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
      if (grp $file $nu.plugin-path | length) == 0 {
        echo-g $"registering ($file)..."
        nu -c $'register ($file)'    
      } 
    }
}

#stop network applications
export def stop-net-apps [] {
  t-stop
  ydx-stop
  maestral stop
  killn jdown
}

#add a hidden column with the content of the # column
export def indexify [
  column_name: string = 'index' #export default: index
  ] { 
  each -n {|it| 
    $it.item 
    | upsert $column_name $it.index 
    | move $column_name --before ($it.item | columns).0 
  } 
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
    matlab19 -nosplash -nodesktop -sd $"\"($env.PWD)\"" -logfile "/home/kira/Dropbox/matlab/log19.txt"
  } else {
    matlab19_ubb -nosplash -nodesktop -sd $"\"($env.PWD)\"" -logfile "/home/kira/Dropbox/matlab/log19.txt"
  }
}

#create dir and cd into it
export def-env mkcd [name: path] {
  cd (mkdir $name -s | first)
}

#backup sublime settings
export def backup-sublime [] {
  cd $env.MY_ENV_VARS.linux_backup
  let source_dir = "~/.config/sublime-text"
  
  7zmax sublime-installedPackages ([$source_dir "Installed Packages"] | path join)
  7zmax sublime-Packages ([$source_dir "Packages"] | path join)
}

#second screen positioning (work)
export def set-screen [
  side: string = "right"  #which side, left or right (default)
  --home                  #for home pc
  --hdmi = "right"        #for home pc, which hdmi port: left or right (default)
] {
  if not $home {
    switch $side {
      "right": { xrandr --output HDMI-1-1 --auto --right-of eDP },
      "left": { xrandr --output HDMI-1-1 --auto --left-of eDP }
    } { 
      "otherwise": { echo-r "Side argument should be either right or left" }
    }
  } else {
    switch $side {
      "right": { 
        if $hdmi == "right" {
          xrandr --output HDMI-1-1 --auto --right-of eDP-1-1
        } else {
          xrandr --output HDMI-0 --auto --right-of eDP-1-1
        } 
      },
      "left": { 
        if $hdmi == "right" {
          xrandr --output HDMI-1-1 --auto --left-of eDP-1-1 
        } else {
          xrandr --output HDMI-0 --auto --left-of eDP-1-1 
        }
      }
    } { 
      "otherwise": { echo-r "Side argument should be either right or left" }
    }
  }

}