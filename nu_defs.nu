#short help
def ? [...search] {
  if ($search | first) =~ "commands" {
    if ($search | first) =~ "my" {
      help commands | where is_custom == true
      } else {
        help commands 
      }
  } else if (which ($search | first) | get path | get 0) =~ "Nushell" {
    help ($search | str collect " ") | nu-highlight
  } else {
    tldr ($search | str collect "-") | nu-highlight
  }
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
  let calendar = if $calendar == null {echo $"calendar: ";input } else {$calendar}
  let title = if $title == null {echo $"\ntitle: ";input } else {$title}
  let when = if $when == null {echo $"\nwhen: ";input } else {$when}
  let where = if $where == null {echo $"\nwhere: ";input } else {$where}
  let duration = if $duration == null {echo $"\nduration: ";input } else {$duration}
  
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
  let calendars = "my_calendars"
  let calendars_full = "all_my_calendars"

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
  let calendars = "my_calendars"
  let calendars_full = "all_my_calendars"
  
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
  let calendars = "my_calendars"
  let calendars_full = "all_my_calendars"
  
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
    let Accesstoken = "bitlyToken"
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
    let key = "mymemoryApi"
    let user = "mymemoryUser"

    let from = if ($from | empty?) {"en-US"} else {$from}
    let to = if ($to | empty?) {"es-ES"} else {$to}

    let to_translate = ($search | str collect "%20")

    let url = $"https://api.mymemory.translated.net/get?q=($to_translate)&langpair=($from)%7C($to)&of=json&key=($key)&de=($user)"

    fetch $url | get responseData | get translatedText
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
  (goobook dquery $search 
    | from ssv 
    | rename results 
    | where results =~ '(?P<plus>\+)(?P<nums>\d+)'
  )
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
  ps | find $name | par-each {kill -f $in.pid}
}

#jdownloader downloads info
def nujd [] {
  (jdown 
    | lines 
    | each { |line| 
        $line | from nuon 
      } 
    | flatten 
    | flatten
  )
}

# Switch-case like instruction
def switch [
  var           #input var to test
  cases: record #record with all cases
  #
  # Example:
  # let x = 3
  # switch $x {
  #   1: { echo "you chose one" },
  #   2: { echo "you chose two" },
  #   3: { echo "you chose three" }
  # }
] {
    echo $cases | get $var | do $in
}

#post to #channel in discord
def to_discord [message] {
  let content = $"{\"content\": \"($message)\"}"

  let weburl = "discordURLwebhook"

  post $weburl $content --content-type "application/json"
}   

#select column of a table (to table)
def column [n] { 
  transpose | select $n | transpose | select column1 | headers
}

#get column of a table (to list)
def column2 [n] { 
  transpose | get $n | transpose | get column1 | skip 1
}

#short pwd
def pwd-short [] {
  $env.PWD | str replace $nu.home-path '~' -s
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

#join 2 lists
def union [a: list, b: list] {
    $a | append $b | uniq
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

#go to bash path
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

#update aliases file from config.nu
def update-aliases [] {
  let nlines = (open $nu.config-path | lines | length)
 
  let from = ((grep "## aliases" $nu.config-path -n | split row ':') | get 0 | into int)
  
  (open $nu.config-path 
    | lines 
    | last ($nlines - $from + 1) 
    | save /path/to/aliases_backup.nu
  )
}

#update config.nu from aliases backup
def update-config [] {
  let from = ((grep "## aliases" $nu.config-path -n | split row ':') | get 0 | into int)
  let aliases = "/path/to/aliases_backup.nu"

  (open $nu.config-path 
    | lines 
    | first ($from - 1) 
    | append (open $aliases | lines) 
    | save temp.nu
  )
  
  mv temp.nu $nu.config-path
}

#countdown alarm 
def countdown [
  n: int # time in seconds
] {
    let BEEP = "/path/to/beep/sound.ext"
    let muted = (pacmd list-sinks 
      | awk '/muted/ { print $2 }' 
      | tr '\n' ' ' 
      | split row ' ' 
      | last
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
  (open $nu.config-path 
    | lines 
    | find "alias " 
    | find -v "$" 
    | find -v "#"
    | split column ' = ' 
    | select column1 column2 
    | rename Alias Command 
    | update Alias {|f| 
        $f.Alias | split row ' ' | last
      } 
    | sort-by Alias
    | update Command {|c|
        $c.Command | nu-highlight
    }
  )
}

#ping with plot
def png-plot [ip?] {
  let ip = if ($ip | empty?) {"1.1.1.1"} else {$ip}

  bash -c $"ping ($ip) | sed -u 's/^.*time=//g; s/ ms//g' | ttyplot -t \'ping to ($ip)\' -u ms"
}

#speedtest with plot
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
def check-link [link?] {
  let link = if ($link | empty?) {$in} else {$link}

  not (do -i { fetch $link } | empty?)
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
  } else {
    echo $"subtitle file ($file) doesn't exist in ($pwd-short)"
  }
}

#rm trough pipe
#
#Example
#ls *.txt | rm-pipe
def rm-pipe [] {
  get name | par-each {|file| rm $file} | flatten
}

#cp trough pipe to same dir
def cp-pipe [
  to: string#target directory
  #
  #Example
  #ls *.txt | cp-pipe ~/temp
] {
  get name | each {|file| 
    echo $"copying ($file)..." 
    cp $file ($to | path expand)
  } | flatten
}

#mv trough pipe to same dir
def mv-pipe [
  to: string#target directory
  #
  #Example
  #ls *.txt | mv-pipe ~/temp
] {
  get name | each {|file|
    echo $"moving ($file)..." 
    mv $file ($to | path expand)
  } | flatten
}

#ls by date (newer last)
def lt [
  --reverse(-r) #reverse order
] {
  if ($reverse | empty?) || $reverse == false {
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
def get-devices [] {
  let ipinfo = (ip add 
    | lines 
    | find inet 
    | find "/" 
    | find dynamic 
    | find -v inet6 
    | get 0 
    | detect columns -n 
    | get column1 
    | get 0
    | str replace '(?P<nums>\d+/)' '0/'
  )

  let nmap_output = (sudo nmap -sn $ipinfo --max-parallelism 10)

  let ips = ($nmap_output 
    | lines 
    | find report 
    | split row ' ' 
    | find --regex '(?P<nums>\d+)' 
    | drop 
    | str replace -s '(' '' 
    | str replace -s ')' '' 
    | wrap ip
  )
  
  let macs_n_names = ($nmap_output | lines | find MAC | split row ': ' | find '(')
  let macs = ($macs_n_names | split row '('  | find -v ')' | str replace ' ' '' | wrap mac)
  let names = ($macs_n_names | split row '(' | find ')' | str replace -s ')' '' | wrap name)

  let devices = ( [$ips $macs $names] 
    | reduce {|it, acc| 
        $acc | merge { $it }
      }
    )

  let known_devices = (open '/path/to/known_devices.csv')
  let known_macs = ($known_devices | get mac | str upcase)

  let known = ($devices | each {any? $it.mac in $known_macs} | wrap known)

  let devices = ($devices | merge {$known})

  let aliases = ($devices | each {|row| 
    if $row.known {
      $known_devices | find $row.mac | get alias
    } else {
      " "
    }
  } | flatten | wrap alias
  )
   
  $devices | merge {$aliases}
}

#remove last file argument
def rv [
  ...rest #last executed command with a file
  #
  #Example
  #mpv video.mp4
  #(arrow up or !!)
  #rv mpv video.mp4
] {
  rm ($rest | last)
}

## to aliases if coloring is fixed

#ls by name
def ln [] {
  ls --du | sort-by -i type name 
}

#get list of files recursively
def get-files [] {
  ls **/* | where type == file | sort-by -i name
}

#get list of directories in current path
def get-dirs [] {
  ls | where type == dir | sort-by -i name
}

##

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
  $search   #search term
  entrada?  #file or pipe
  #
  #Examples
  #grep-nu search file.txt
  #ls **/* | some_filter | grep-nu search 
] {
  let inp = if ($entrada | empty?) {$in | get name} else {$entrada}

  grep -ihHn $search $inp 
  | lines 
  | split column -c ':'
  | rename file "line number" match 
  | update match {|f| 
      $f.match | nu-highlight
    }
}

#get ips
def get-ips [] {
  let internal = (ifconfig | lines | find netmask | find broadcast | str trim | split column ' ' | get column2 | get 1)
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
      do -i {geeknote find --search $search} | complete | get stdout
    } else {
      let command = (build-string "geeknote find --search " $search " " ($rest | str collect ' '))
      do -i {nu -c $command} | complete | get stdout
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
      do -i {geeknote show $item} | complete | get stdout
    } else {
      let command = (build-string "geeknote show " ($item | into string) " " ($rest | str collect ' '))
      do -i {nu -c $command} | complete | get stdout
    }

  $result | nu-highlight | lines 
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