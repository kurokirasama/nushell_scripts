##variables 
let r_prompt = "short"

#short help
def ? [...search] {
  if ($search | empty?) {
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
def h [howmany = 100] {
  history
  | last $howmany
  | update command {|f|
      $f.command 
      | nu-highlight
    }
}

#wrapper for describe
def typeof [--full(-f)] {
  describe 
  | if not $full { 
      split row '<' | get 0 
    } else { 
      $in 
    }
}

#copy pwd
def cpwd [] {
  $env.PWD | xclip -sel clip
}

#compress every subfolder into separate files and delete them
def 7zfolders [] {
  ^find . -maxdepth 1 -mindepth 1 -type d -print0 
  | parallel -0 --eta 7z a -t7z -sdel -bso0 -bsp0 -m0=lzma2 -mx=9 -ms=on -mmt=on {}.7z {}
}

#compress to 7z using max compression
def 7zmax [
  filename: string  #filename without extension
  ...rest:  string  #files to compress and extra flags for 7z (add flags between quotes)
  #
  # Example:
  # compress all files in current directory and delete them
  # 7zmax filename * "-sdel"
  # compress all files in current directory and split into pieces of 3Gb (b|k|m|g)
  # 7zmax filename * "-v3g"
  # both
  # 7zmax filename * "-v3g -sdel"
] {
  if ($rest | empty?) {
    echo "no files to compress specified"
  } else {
     7z a -t7z -m0=lzma2 -mx=9 -ms=on -mmt=on $"($filename).7z" $rest
  }
}

#add event to google calendar, also usable without arguments
def addtogcal [
  calendar?   #to which calendar add event
  title?      #event title
  when?       #date: yyyy.MM.dd hh:mm
  where?      #location
  duration?   #duration in minutes
] {
  let calendar = if ($calendar | empty?) {echo $"calendar: ";input } else {$calendar}
  let title = if ($title | empty?) {echo $"\ntitle: ";input } else {$title}
  let when = if ($when | empty?) {echo $"\nwhen: ";input } else {$when}
  let where = if ($where | empty?) {echo $"\nwhere: ";input } else {$where}
  let duration = if ($duration | empty?) {echo $"\nduration: ";input } else {$duration}
  
  gcalcli --calendar $"($calendar)" add --title $"($title)" --when $"($when)" --where $"($where)" --duration $"($duration)" --default-reminders
}

#show gcal agenda in selected calendars
def agenda [
  --full: int  #show all calendars (default: 0)
  ...rest      #extra flags for gcalcli between quotes (specified full needed)
  #
  # Examples
  # agenda 
  # agenda --full true
  # agenda "--details=all"
  # agenda --full true "--details=all"
] {
  let calendars = "calendar1|calendar2"
  let calendars_full = "calendar1|calendar2|calendar3"

  if ($full | empty?) || ($full == 0) {
    gcalcli --calendar $"($calendars)" agenda --military $rest
  } else {
    gcalcli --calendar $"($calendars_full)" agenda --military $rest
  }
}

#show gcal week in selected calendards
def semana [
  --full: int  #show all calendars (default: 0)
  ...rest      #extra flags for gcalcli between quotes (specified full needed)
  #
  # Examples
  # semana 
  # semana --full true
  # semana "--details=all"
  # semana --full true "--details=all"
] {
  let calendars = "calendar1|calendar2"
  let calendars_full = "calendar1|calendar2|calendar3"
  
  if ($full | empty?) || ($full == 0) {
    gcalcli --calendar $"($calendars)" calw $rest --military --monday
  } else {
    gcalcli --calendar $"($calendars_full)" calw $rest --military --monday
  }
}

#show gcal month in selected calendards
def mes [
  --full: int  #show all calendars (default: 0)
  ...rest      #extra flags for gcalcli between quotes (specified full needed)
  #
  # Examples
  # mes 
  # mes --full true
  # mes "--details=all"
  # mes --full true "--details=all"
] {
  let calendars = "calendar1|calendar2"
  let calendars_full = "calendar1|calendar2|calendar3"

  if ($full | empty?) || ($full == 0) {
    gcalcli --calendar $"($calendars)" calm $rest --military --monday
  } else {
    gcalcli --calendar $"($calendars_full)" calm $rest --military --monday
  }
}

#get bitly short link
def mbitly [longurl] {
  if ($longurl | empty?) {
    echo "no url provided"
  } else {
    let Accesstoken = "API_KEY"
    let username = "user"
    let url = $"https://api-ssl.bitly.com/v3/shorten?access_token=($Accesstoken)&login=($username)&longUrl=($longurl)"

    let shorturl = (fetch $url | get data | get url)

    $shorturl
    $shorturl | copy
  }
}

#translate text using mymemmory api
def trans [
  ...search:string  #search query
  --from:string     #from which language you are translating (default english)
  --to:string       #to which language you are translating (default spanish)
  #
  #Use ISO standar names for the languages, for example:
  #english: en-US
  #spanish: es-ES
  #italian: it-IT
  #swedish: sv-SV
  #
  #More in: https://en.wikipedia.org/wiki/List_of_ISO_639-1_codes
] {
  if ($search | empty?) {
    echo "no search query provided"
  } else {
    let key = "API_KEY"
    let user = "user_email"

    let from = if ($from | empty?) {"en-US"} else {$from}
    let to = if ($to | empty?) {"es-ES"} else {$to}

    let to_translate = ($search | str collect "%20")

    let url = $"https://api.mymemory.translated.net/get?q=($to_translate)&langpair=($from)%7C($to)&of=json&key=($key)&de=($user)"

    fetch $url 
    | get responseData 
    | get translatedText
  }
}

#check if drive is mounted
def is-mounted [drive:string] {
  let count = (ls "~/media" | find $"($drive)" | length)

  if $count == 0 {
    false
  } else {
    true
  }
}

#get phone number from google contacts
def get-phone-number [search:string] {
  goobook dquery $search 
  | from ssv 
  | rename results 
  | where results =~ '(?P<plus>\+)(?P<nums>\d+)'
  
}

#update-upgrade system
def supgrade [] {
  echo "updating..."
  sudo aptitude update -y
  echo "upgrading..."
  sudo aptitude safe-upgrade -y
  echo "autoremoving..."
  sudo apt autoremove -y
}

#open mcomix
def mcx [file] {
  bash -c $'mcomix "($file)"" 2>/dev/null &'
}

#open file 
def openf [file?] {
  let file = if ($file | empty?) {$in} else {$file}
   
  bash -c $'xdg-open "($file)" 2>/dev/null &'
}

#search for specific process
def psn [name: string] {
  ps | find $name
}

#kill specified process in name
def killn [name: string] {
  ps 
  | find $name 
  | par-each {
      kill -f $in.pid
    }
}

#jdownloader downloads info
def jd [] {
  jdown 
  | lines 
  | each { |line| 
      $line 
      | from nuon 
    } 
  | flatten 
  | flatten
}

# Switch-case like instruction
def switch [
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
  if ($cases | column? $var) {
    $cases 
    | get $var 
    | do $in
  } else if not ($otherwise | empty?) {
    $otherwise 
    | get otherwise 
    | do $in
  }
}

#select column of a table (to table)
def column [n] { 
  transpose 
  | select $n 
  | transpose 
  | select column1 
  | headers
}

#get column of a table (to list)
def column2 [n] { 
  transpose 
  | get $n 
  | transpose 
  | get column1 
  | skip 1
}

#short pwd
def pwd-short [] {
  $env.PWD 
  | str replace $nu.home-path '~' -s
}

#string repeat
def "str repeat" [count: int] { 
  each {|it| 
    let str = $it; echo 1..$count 
    | each { 
        echo $str 
      } 
  } 
}

#string prepend
def "str prepend" [toprepend] { 
  build-string $toprepend $in
}

#string append
def "str append" [toappend] { 
  build-string $in $toappend
}

#join 2 lists
def union [a: list, b: list] {
  $a 
  | append $b 
  | uniq
}

#nushell source files info
def 'nu-sloc' [] {
  let stats = (
    ls **/*.nu
    | select name
    | insert lines { |it| open $it.name | size | get lines }
    | insert blank {|s| $s.lines - (open $s.name | lines | find --regex '\S' | length) }
    | insert comments {|s| open $s.name | lines | find --regex '^\s*#' | length }
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
def-env goto [] {
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
def-env goto-bash [] {
  cd ($env.PATH | last)
}

#cd to the folder where a binary is located
def-env which-cd [program] { 
  let dir = (which $program | get path | path dirname | str trim)
  cd $dir.0
}

#push to git
def git-push [m: string] {
  git add -A
  git status
  git commit -am $"($m)"
  git push #origin main  
}

#web search in terminal
def gg [...search: string] {
  ddgr -n 5 ($search | str collect ' ')
}

#habitipy dailies done all
def hab-dailies-done [] {
  let to_do = (habitipy dailies 
    | grep ✖ 
    | awk {print $1} 
    | tr '.\n' ' ' 
    | split row ' ' 
    | into int
  )

  habitipy dailies done $to_do 
}

#countdown alarm 
def countdown [
  n: int #time in seconds
] {
  let BEEP = "/path/to/beep/sound/file"
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
def get-aliases [] {
  $nu
  | get scope 
  | get aliases
  | update expansion {|c|
      $c.expansion | nu-highlight
    }
}

#ping with plot
def png-plot [ip?] {
  let ip = if ($ip | empty?) {"1.1.1.1"} else {$ip}

  bash -c $"ping ($ip) | sed -u 's/^.*time=//g; s/ ms//g' | ttyplot -t \'ping to ($ip)\' -u ms"
}

#plot download-upload speed
def speedtest-plot [] {
  bash -c "fast --single-line --upload |  stdbuf -o0 awk '{print $2 \" \" $6}' | ttyplot -2 -t 'Download/Upload speed' -u Mbps" 
}

#plot data table using gnuplot
def gnu-plot [
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
  let x = if ($data | empty?) {$in} else {$data}
  let n_cols = ($x | transpose | length)
  let name_cols = ($x | transpose | column2 0)

  let ylabel = if $n_cols == 1 {$name_cols | get 0} else {$name_cols | get 1}
  let xlabel = if $n_cols == 1 {""} else {$name_cols | get 0}

  let title = if ($title | empty?) {
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
def check-link [link?,timeout?:int] {
  let link = if ($link | empty?) {$in} else {$link}

  if ($timeout | empty?) {
    not (do -i { fetch $link } | empty?)
  } else {
    not (do -i { fetch $link -t $timeout} | empty?)
  }
}

#sync subtitles
def sub-sync [
  file:string      #subtitle file name to process
  d1:string        #delay at the beginning or at time specified by t1 (<0 adelantar, >0 retrasar)
  --t1:string      #time position of delay d1 (hh:mm:ss)
  --d2:string      #delay at the end or at time specified by t2
  --t2:string      #time position of delay d2 (hh:mm:ss)t
  --no-backup:int  #wether to not backup $file or yes (default no:0, ie, it will backup)
  #
  #Examples
  #sub-sync file.srt "-4"
  #sub-sync file.srt "-4" --t1 00:02:33
  #sub-sync file.srt "-4" --no-backup 1
] {

  let file_exist = (($env.PWD) | path join $file | path exists)
  
  if $file_exist {
    if ($no-backup | empty?) || $no-backup == 0 {
      cp $file $"($file).backup"
    }

    let t1 = if ($t1 | empty?) {"@"} else {$t1}  
    let d2 = if ($d2 | empty?) {""} else {$d2}
    let t2 = if ($d2 | empty?) {""} else {if ($t2 | empty?) {"@"} else {$t2}}
  
    bash -c $"subsync -e latin1 ($t1)($d1) ($t2)($d2) < \"($file)\" > output.srt; cp output.srt \"($file)\""

    rm output.srt | ignore
  } else {
    echo $"subtitle file ($file) doesn't exist in (pwd-short)"
  }
}

#rm trough pipe
#
#Example
#ls *.txt | rm-pipe
def rm-pipe [] {
  get name 
  | par-each {|file| 
      rm -rf $file
    } 
  | flatten
}

#cp trough pipe to same dir
def cp-pipe [
  to: string#target directory
  #
  #Example
  #ls *.txt | first 5 | cp-pipe ~/temp
] {
  get name 
  | each {|file| 
      echo $"copying ($file)..." 
      cp $file ($to | path expand)
    } 
  | flatten
}

#mv trough pipe to same dir
def mv-pipe [
  to: string#target directory
  #
  #Example
  #ls *.txt | mv-pipe ~/temp
] {
  get name 
  | each {|file|
      echo $"moving ($file)..." 
      mv $file ($to | path expand)
    }
  | flatten
}

#ls by date (newer last)
def lt [
  --reverse(-r) #reverse order
] {
  if ($reverse | empty?) || (not $reverse) {
    ls --du | sort-by modified  
  } else {
    ls --du | sort-by modified -r
  } 
}

#ls in text grid
def lg [
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

#get devices connected to network
def get-devices [
  device = "wlo1" #wlo1 for wifi (default), eno1 for lan
] {
  let ipinfo = (ip -json add 
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
        if ($f.name | empty?) {
          "Unknown"
        } else {
          $f.name
        }
      }
  )

  let devices = ( $ips | merge { $macs_n_names} )

  let known_devices = (open '/path/to/known_devices.csv')
  let known_macs = ($known_devices | get mac | str upcase)

  let known = ($devices | each {any? $it.mac in $known_macs} | wrap known)

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

#ls sorted by name
def ln [] {
  ls --du | sort-by -i type name 
}

#ls only name
def lo [] {
  ls 
  | sort-by -i type name 
  | reject type size modified 
}

#ls sorted by extension
def le [] {
  ls --du 
  | sort-by -i type name 
  | insert "ext" { 
      $in.name 
      | path parse 
      | get extension 
    } 
  | sort-by ext
}

#get list of files recursively
def get-files [] {
  ls **/* 
  | where type == file 
  | sort-by -i name
}

#get list of directories in current path
def get-dirs [] {
  ls 
  | where type == dir 
  | sort-by -i name
}

#verify if a column exist within a table
def column? [name] { 
  $name in ($in | columns) 
}

#zoxide completion
def "nu-complete zoxide path" [line : string, pos: int] {
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
def grep-nu [
  search   #search term
  entrada?  #file or pipe
  #
  #Examples
  #grep-nu search file.txt
  #ls **/* | some_filter | grep-nu search 
  #open file.txt | grep-nu search
] {
  if ($entrada | empty?) {
    if ($in | column? name) {
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
def get-ips [
  device =  "wlo1"  #wlo1 for wifi (default), eno1 for lan
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
def geek-find [
  search:string  #search term in title
  ...rest:string #extra flags for geeknote
  #
  #Example
  #geek-find ssh
  #geek-find ssh "--tag linux"
] {
  let result = if ($rest | empty?) {
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
def geek-show [
  item:int       #search term in title
  ...rest:string #extra flags for geeknote show (--raw)
  #
  #Example (after a geek-find)
  #geek-show 1
  #geek-show 1 "--raw"
] {
  let result = if ($rest | empty?) {
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
def geek-edit [
  item:int       #search term in title
  ...rest:string #extra flags for geeknote show (--raw)
  #
  #Example (after a geek-find)
  #geek-edit 1
  #geek-edit 1 "--tag new_tag"
] {
  if ($rest | empty?) {
    geeknote edit $item
  } else {
    let command = (build-string "geeknote edit " ($item | into string) " " ($rest | str collect ' '))
    nu -c $command
  }
}

#geeknote create
def geek-create [
  commands:string #list of commands to create a note
  #
  #Example 
  #geek-create "--title 'a note'"
  #geek-create "--title 'a note' --tag linux --content 'the content'"
] {
  nu -c (build-string "geeknote create" " " $commands)
}

#add file to transmission download queue
def t-add [
  down  #magnetic link or torrent file
] {
  transmission-remote -n 'transmission:transmission' -a $down
}

#add magnetic links from file to transmission download queue
def t-addfromfile [
  file  #text file with 1 magnetic link per line
] {
  open $file 
  | lines 
  | each {|link|
      t-add $link
    }
}

#get info of a torrent download 
def t-info [
  id:int  #id of the torrent to fetch
] {
  transmission-remote -t $id -n 'transmission:transmission' -i
}

#delete torrent from download queue without deleting files
def t-remove [
  ...ids    #list of ids
] {
  $ids 
  | each {|id| 
      transmission-remote -t $id -n 'transmission:transmission' --remove
    }
}

#delete torrent from download queue deleting files
def t-removedelete [
  ...ids    #list of ids
] {
  $ids 
  | each {|id| 
      transmission-remote -t $id -n 'transmission:transmission' -rad
    }
}

#delete finished torrent from download queue without deleting files
def t-removedone [
  ...ids    #list of ids
] {
  t-list 
  | drop 1 
  | where ETA =~ Done 
  | get ID 
  | each {|id|
      transmission-remote  -t $id -n 'transmission:transmission' --remove
    } 
}

#delete torrent from download queue that match a search without deleting files
def t-removename [
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
def t-starttorrent [
  id:int  #torrent id
] {
  transmission-remote -t $id -n 'transmission:transmission' -s
}

#start all torrents
def t-starttorrents [] {
  t-list 
  | drop 1 
  | get ID 
  | each {|id|
      transmission-remote -t $id -n 'transmission:transmission' -s
    }
}

#stop a torrent from download queue
def t-stoptorrent [
  id:int  #torrent id
] {
  transmission-remote -t $id -n 'transmission:transmission' -S
}

#stop all torrents
def t-stoptorrents [] {
  t-list 
  | drop 1 
  | get ID 
  | each {|id|
      transmission-remote -t $id -n 'transmission:transmission' -S
    }
}

#umount all drives (duf)
def umall [user? = "your_user"] {
  duf -json 
  | from json 
  | find $"/media/($user)" 
  | get mount_point
  | each {|drive| 
      echo $"umounting ($drive)..."
      umount $drive
    }
}

#convert media files recursively to specified format
def media-to [
  to:string #destination format (aac, mp3 or mp4)
  #
  #Examples (make sure there are only compatible files in all subdirectories)
  #media-to mp4 (avi to mp4)
  #media-to aac (audio files to aac)
  #media-to mp3 (audio files to mp3)
] {
  if $to =~ "aac" || $to =~ "mp3" {
    let n_files = (bash -c $'find . -type f -not -name "*.part" -not -name "*.srt" -not -name "*.mkv" -not -name "*.mp4" -not -name "*.txt" -not -name "*.url" -not -name "*.jpg" -not -name "*.png" -not -name "*.($to)"'
        | lines 
        | length
    )

    echo $"($n_files) audio files found..."

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
        echo $"audio conversion to ($to) done"
      } else {
        echo $"audio conversion to ($to) done, but something might be wrong"
      }
    }
  } else if $to =~ "mp4" {
    let n_files = (ls **/*
        | insert "ext" { 
            $in.name | path parse | get extension
          }  
        | where ext =~ "avi"
        | length
    )

    echo $"($n_files) avi files found..."

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
        echo $"video conversion to mp4 done"
      } else {
        echo $"video conversion to mp4 done, but something might be wrong"
      }
    }
  }
}

#cut audio
def cut-audio [
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
def merge-subs [
  filename  #name (without extencion) of both subtitle and mkv file
] {
  mkvmerge -o myoutput.mkv  $"($filename).mkv" --language "0:spa" --track-name $"0:($filename)" $"($filename).srt"
  mv myoutput.mkv $"($filename).mkv"
  rm $"($filename).srt" | ignore
}

#merge videos
def merge-videos [
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
  echo "merging videos..."
  myffmpeg -f concat -safe 0 -i $"($list)" -c copy $"($output)"
  
  echo "done!"
  notify-send "video merging done!"
}

#auto merge all videos in dir
def merge-videos-auto [
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

  echo "merging videos..."
  myffmpeg -f concat -safe 0 -i list.txt -c copy $"($output)"
      
  echo "done!"
  notify-send "video merging done!"
}

#join multiple pdfs
def join-pdfs [
  ...rest: #list of pdf files to concatenate
] {
  if ($rest | empty?) {
    echo "not enough pdfs provided"
  } else {
    pdftk $rest cat output output.pdf
    echo "pdf merged in output.pdf"
  }
}

#video info
def video-info [file] {
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
def remove-video-noise [
  file      #video file name with extension
  start     #start (hh:mm:ss) of audio noise (no speaker)
  end       #end (hh:mm:ss) of audio noise (no speaker)
  noiseLevel#level reduction adjustment (0.2-0.3)
  output    #output file name with extension (same extension as $file)
] {
  if (ls ([$env.PWD tmp*] | path join) | length) > 0 {
    rm tmp*
  }

  echo "extracting video..."
  myffmpeg -loglevel 1 -i $"($file)" -vcodec copy -an tmpvid.mp4

  echo "extracting audio..."
  myffmpeg -loglevel 1 -i $"($file)" -acodec pcm_s16le -ar 128k -vn tmpaud.wav

  echo "extracting noise..."
  myffmpeg -loglevel 1 -i $"($file)" -acodec pcm_s16le -ar 128k -vn -ss $start -t $end tmpnoiseaud.wav

  echo "creating noise profile..."
  sox tmpnoiseaud.wav -n noiseprof tmpnoise.prof

  echo "cleaning noise from audio file..."
  sox tmpaud.wav tmpaud-clean.wav noisered tmpnoise.prof $noiseLevel

  echo "merging clean audio with video file..."
  myffmpeg -loglevel 1 -i tmpvid.mp4 -i tmpaud-clean.wav -map 0:v -map 1:a -c:v copy -c:a aac -b:a 128k $output

  echo "done!"
  notify-send "noise removal done!"

  echo "don't forget to remove tmp* files"
}

#screen record to mp4
def screen-record [
  file = "video"  #output filename without extension (default: "video")
  audio = true    #whether to record with audio or not (default: true)
] {
  if $audio {
    ffmpeg -video_size 1920x1080 -framerate 24 -f x11grab -i :0.0+0,0 -f alsa -ac 2 -i pulse -acodec aac -strict experimental $"($file).mp4"
  } else {
    ffmpeg -video_size 1920x1080 -framerate 24 -f x11grab -i :0.0+0,0 $"($file).mp4"
  }
}

#send email via Gmail with signature files (posfix configuration required)
def send-gmail [
  to:string                         #email to
  subject:string                    #email subject
  --body:string                     #email body, use double quotes to use escape characters like \n
  --from = "your_mail@gmail.com"    #email from, default: your_mail@gmail.com
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
  let inp = if ($in | empty?) { "" } else { $in | into string }

  if ($body | empty?) && ($inp | empty?) {
    echo "body undefined!!"
  } else if not (($from | str contains "@") && ($to | str contains "@")) {
    echo "missing @ in email-from or email-to!!"
  } else {
    let signature_file = (
      switch $from {
        "your_mail@gmail.com" : {echo /path/to/send-gmail_your_email_signature},
        "your_email2@something.com" : {echo /path/to/send-gmail_your_email2_signature},
        "your_email3@something.com" : {echo /path/to/send-gmail_your_email3_signature}
      } {otherwise : {echo /path/to/send-gmail_other_signature}}
    )

    let signature = (open $signature_file)

    let BODY = (
      if ($inp | empty?) { 
        $signature 
        | str prepend $"($body)\n" 
      } else { 
        $signature 
        | str prepend $"($inp)\n" 
      } 
    )

    if ($attachments | empty?) {
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
def code [command] {
  view-source $command | nu-highlight
}

#update deb apps
#zoom, chrome, yandex, sejda, nmap, nyxt, tasker, ttyplot
def deb-update [] {
  zoom-update
  chrome-update
  yandex-update
  sejda-update
  nmap-update
  nyxt-update
  tasker-update
  ttyplot-update
}

#update zoom
def zoom-update [] {
  cd /path/to/debs

  if (ls *.deb | find zoom | length) > 0 {
    ls *.deb | find zoom | rm-pipe | ignore
  }
  
  echo "downloading zoom..."
  wget -q --show-progress https://zoom.us/client/latest/zoom_amd64.deb
  sudo gdebi -n (ls *.deb | find zoom | get 0 | get name)
}

#update chrome deb
def chrome-update [] {
  cd /path/to/debs

  if (ls *.deb | find chrome | length) > 0 {
    ls *.deb | find chrome | rm-pipe | ignore
  }
  
  echo "downloading chrome..."
  wget -q --show-progress https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
  echo $"download finished: (ls *.deb | find chrome | get 0 | get name)"
}

#update yandex deb
def yandex-update [] {
  cd /path/to/debs

  if (ls *.deb | find yandex | length) > 0 {
    ls *.deb | find yandex | rm-pipe | ignore
  }
  
  echo "downloading yandex..."
  wget -q --show-progress http://repo.yandex.ru/yandex-disk/yandex-disk_latest_amd64.deb
  echo $"download finished: (ls *.deb | find yandex | get 0 | get name)"
}

#update sejda
def sejda-update [] {
  cd /path/to/debs

  let new_file = (
    fetch https://www.sejda.com/es/desktop 
    | lines 
    | find linux 
    | find deb 
    | str trim 
    | str replace -a "\'" "" 
    | split row ': ' 
    | get 1
  )

  let new_version = ($new_file | split row _ | get 1)

  let url = $"https://sejda-cdn.com/downloads/($new_file)"

  let sedja = ((ls *.deb | find sejda | length) > 0)

  if $sedja {
    let current_version = (
      ls *.deb 
      | find sejda 
      | get 0 
      | get name 
      | split row _ 
      | get 1
    )

    if $current_version != $new_version {
      echo "updating sedja..."
      rm sejda*.deb | ignore
      wget -q --show-progress $url
      sudo gdebi -n $new_file
    }

  } else {
    echo "downloading sedja..."
    wget -q --show-progress $url
    sudo gdebi -n $new_file
  }
}

#update tasker permissions
def tasker-update [] {
  cd /path/to/debs

  let url = (
    fetch https://github.com/joaomgcd/Tasker-Permissions/releases/ 
    | lines 
    | find deb 
    | find href 
    | get 0 
    | split row "href=" 
    | get 2 
    | split row "<" 
    | get 0 
    | split row "\"" 
    | get 0
  )

  let new_file = ($url | split row / | last)

  let new_version = ($url | split row _ | get 1)

  let tasker = ((ls *.deb | find tasker | length) > 0)

  if $tasker {
    let current_version = (
      ls *.deb 
      | find tasker 
      | get 0 
      | get name 
      | split row _ 
      | get 1
    )

    if $current_version != $new_version {
      echo "updating tasker permissions..."
      rm *tasker*.deb | ignore
      wget -q --show-progress $url
      sudo gdebi -n $new_file
    }

  } else {
    echo "downloading tasker..."
    wget -q --show-progress $url
    sudo gdebi -n $new_file
  }
}

#update nmap
def nmap-update [] {
  cd /path/to/debs

  let new_file = (
    fetch https://nmap.org/dist 
    | lines 
    | find "href=\"nmap"  
    | find rpm 
    | find x86_64 
    | get 0 
    | split row "href=" 
    | get 1 
    | split row > 
    | get 0 
    | str replace -a "\"" "" 
  )

  let url = $"https://nmap.org/dist/($new_file)"

  let new_version = ($new_file  | split row .x | get 0 | str replace nmap- "")

  let nmap_list = ((ls *.deb | find nmap | length) > 0)

  if $nmap_list {
    let current_version = (
      ls *.deb 
      | find nmap 
      | get 0 
      | get name 
      | split row _ 
      | get 1
    )

    if $current_version != $new_version {
      echo "updating nmap..."
      rm nmap*.deb | ignore

      wget -q --show-progress $url
      sudo alien -v -k $new_file

      let new_deb = (ls *.deb | find nmap | get 0 | get name)

      sudo gdebi -n $new_deb
      ls $new_file | rm-pipe | ignore
    }

  } else {
    echo "downloading nmap..."
    wget -q --show-progress $url
    sudo alien -v -k $new_file

    let new_deb = (ls *.deb | find nmap | get 0 | get name)

    sudo gdebi -n $new_deb
    ls $new_file | rm-pipe | ignore
  }
}

#update nyxt
def nyxt-update [] {
  cd /path/to/debs

  let new_file = (
    fetch https://github.com/atlas-engineer/nyxt/releases
    | lines 
    | find .deb 
    | get 0 
    | split row / 
    | last 
    | split row "\"" 
    | first
  )

  let new_version = ($new_file | split row _ | get 1)
  
  let url = $"https://github.com/atlas-engineer/nyxt/releases/download/($new_version)/($new_file)"

  let nyxt = ((ls *.deb | find nyxt | length) > 0)

  if $nyxt {
    let current_version = (
      ls *.deb 
      | find nyxt 
      | get 0 
      | get name 
      | split row _ 
      | get 1
    )

    if $current_version != $new_version {
      echo "updating nyxt..."
      rm nyxt*.deb | ignore
      wget -q --show-progress $url
      sudo gdebi -n $new_file
    }

  } else {
    echo "downloading nyxt..."
    wget -q --show-progress $url
    sudo gdebi -n $new_file
  }
}

#update ttyplot
def ttyplot-update [] {
  cd /path/to/debs

  let info = (
    fetch https://github.com/tenox7/ttyplot/releases 
    | lines 
    | find .deb 
    | get 0 
    | split row /
  )

  let main_version = ($info | get 5)
  let new_file = ($info 
    | get 6 
    | split row "\"" 
    | get 0
  )

  let new_version = (
    $new_file 
    | split row _ 
    | get 1 
    | split row .deb 
    | get 0
  )

  let url = $"https://github.com/tenox7/ttyplot/releases/download/($main_version)/($new_file)"

  let tty = ((ls *.deb | find ttyplot | length) > 0)

  if $tty {
    let current_version = (
      ls *.deb 
      | find ttyplot 
      | get 0 
      | get name 
      | split row _ 
      | get 1 
      | split row .deb 
      | get 0
    )

    if $current_version != $new_version {
      echo "updating ttyplot..."
      rm ttyplot*.deb | ignore
      wget -q --show-progress $url
      sudo gdebi -n $new_file
    }

  } else {
    echo "downloading ttyplot..."
    wget -q --show-progress $url
    sudo gdebi -n $new_file
  }
}

#register nu plugins
def reg-plugins [] {
  ls ~/.cargo/bin
  | where type == file 
  | sort-by -i name
  | get name 
  | find nu_plugin 
  | each {|file|
      echo $"registering ($file)..."
      nu -c $'register -e json ($file)'
    }
}

## appimages

#open balena-etcher
def balena [] {
  bash -c $'/path/to/appimages/balenaEtcher.AppImage 2>/dev/null &'
}