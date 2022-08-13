##variables 
let r_prompt = "short"

##dataframes

#get columns of a dataframe into a list
# def "df get-columns" [] {
#   $in | dtypes | into nu | get column
# }

##general scripts

#update nu config (after nu update)
def update-nu-config [] {
  ls (build-string $env.MY_ENV_VARS.nushell_dir "/**/*") 
  | find -i default_config 
  | update name {|n| 
      $n.name 
      | ansi strip
    }  
  | cp-pipe $nu.config-path

  open ([$env.MY_ENV_VARS.linux_backup "append_to_config.nu"] | path join) | save --append $nu.config-path
  nu -c $"source ($nu.config-path)"
}

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

#xls/ods 2 csv
def xls2csv [
  inputFile:string
  --outputFile:string
] {
  let output = (
    if ($outputFile | empty?) || (not $outputFile) {
      $"($inputFile | path parse | get stem).csv"
    } else {
      $outputFile
    }
  )
  libreoffice --headless --convert-to csv $inputFile
  # bash -c $"'cat \"($output)\" > test.csv'"
  # mv test.csv $output
}

#compress to 7z using max compression
def 7zmax [
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
  if ($rest | empty?) {
    echo-g "no files to compress specified"
  } else if ($delete | empty?) || (not $delete) {
    7z a -t7z -m0=lzma2 -mx=9 -ms=on -mmt=on $"($filename).7z" $rest
  } else {
    7z a -t7z -sdel -m0=lzma2 -mx=9 -ms=on -mmt=on $"($filename).7z" $rest
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
  let calendar = if ($calendar | empty?) {input (echo-g "calendar: ")} else {$calendar}
  let title = if ($title | empty?) {input (echo-g "title: ")} else {$title}
  let when = if ($when | empty?) {input (echo-g "when: ")} else {$when}
  let where = if ($where | empty?) {input (echo-g "where: ")} else {$where}
  let duration = if ($duration | empty?) {input (echo-g "duration: ")} else {$duration}
  
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
  let calendars = $env.MY_ENV_VARS.google_calendars
  let calendars_full = $env.MY_ENV_VARS.google_calendars_full

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
  let calendars = $env.MY_ENV_VARS.google_calendars
  let calendars_full = $env.MY_ENV_VARS.google_calendars_full
  
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
  let calendars = $env.MY_ENV_VARS.google_calendars
  let calendars_full = $env.MY_ENV_VARS.google_calendars_full
  
  if ($full | empty?) || ($full == 0) {
    gcalcli --calendar $"($calendars)" calm $rest --military --monday
  } else {
    gcalcli --calendar $"($calendars_full)" calm $rest --military --monday
  }
}

#get bitly short link
def mbitly [longurl] {
  if ($longurl | empty?) {
    echo-g "no url provided"
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
    echo-g "no search query provided"
  } else {
    let trans_credential = open ([$env.MY_ENV_VARS.credentials "mymemory_token.json"] | path join)
    let key = ($trans_credential | get token)
    let user = ($trans_credential | get username)

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
  (ls "~/media" | find $"($drive)" | length) > 0
}

#move manga folder to Seagate External Drive
def-env mvmanga [] {
  let from = $env.MY_ENV_VARS.local_manga
  let to = $env.MY_ENV_VARS.external_manga

  if (is-mounted "Seagate") {
    cd $from
    7zfolders
    mv *.7z $to
  } else {
    "Seageate drive isn't mounted"
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
  echo-g "updating..."
  sudo nala update
  echo-g "upgrading..."
  sudo nala upgrade -y
  echo-g "autoremoving..."
  sudo nala autoremove -y
  echo-g "updating rust..."
  rustup update
}

#green echo
def echo-g [string:string] {
  echo $"(ansi -e { fg: '#00ff00' attr: b })($string)(ansi reset)"
}

#open mcomix
def mcx [file?] {
  let file = if ($file | empty?) {$in} else {$file}

  bash -c $'mcomix "($file)" 2>/dev/null &'
}

#open file 
def openf [file?] {
  let file = if ($file | empty?) {$in | get name} else {$file}
   
  bash -c $'xdg-open "($file)" 2>/dev/null &'
}

#open google drive file 
def openg [file?] {
  let file = if ($file | empty?) {$in | get name} else {$file}
   
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
def printer [file?] {
  let file = if ($file | empty?) {$in | get name} else {$file}
  lp $file
}

#play first/last downloaded youtube video
def myt [file?, --reverse(-r)] {
  let inp = $in
  let video = (
    if not ($inp | empty?) {
      $inp | get name
    } else if not ($file | empty?) {
      $file
    } else if $reverse {
      lt -r | where type == file | last | get name
    } else {
      lt | where type == file | last | get name
    }
  )
  
  mpv --ontop --window-scale=0.4 --save-position-on-quit $video

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
def psn [name: string] {
  ps -l | find -i $name
}

#kill specified process in name
def killn [name: string] {
  ps -l
  | find -i $name 
  | par-each {
      kill -f $in.pid
    }
}

#jdownloader downloads info
def jd [
  --ubb(-b)#check ubb jdownloader
] {
  if ($ubb | empty?) || (not $ubb) {
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

#post to #announcements in discord
def ubb_announce [message] {
  let content = $"{\"content\": \"($message)\"}"

  let weburl = (open ([$env.MY_ENV_VARS.credentials "discord_webhooks.json"] | path join) | get cursos_ubb_announce)

  post $weburl $content --content-type "application/json"
}  

#upload weekly videos and post to discord
def up2ubb [year = 2022, sem = 01] {
  let sem = ([($year | into string) "-" ($sem | into string | str lpad -l 2 -c '0')] | str collect)

  let mounted = ("~/gdrive/VClasses/" | path expand | path exists)

  if not $mounted {
    echo-g "mounting gdrive..."
    mount-ubb
  }

  cd $env.MY_ENV_VARS.zoom

  ls **/* 
  | where name !~ done
  | where type == file 
  | where name =~ mp4 
  | get name 
  | par-each {|path| 
      $path 
      | parse "{date} {time} {course} {class}/{file}"
    } 
  | flatten 
  | each {|it| 
      let dir = ([$it.date $it.time $it.course $it.class] | str collect " ")
      let file_from = ([$dir $it.file] | path join)
      let file_to = ([$dir $"($it.class).mp4"] | path join)
      let gdrive_to = (["~" "gdrive" "VClasses" $sem $it.course $"($it.class).mp4"] 
        | path join 
        | path expand
      )
      
      if $file_from != $file_to {
        echo-g $"moving ($file_from) to ($file_to)..."
        mv $"($file_from)" $"($file_to)"
      }

      echo-g $"copying ($file_to) to ($gdrive_to)..."
      cp ($file_to) ($gdrive_to)    }
  
  let fecha = (date format %d/%m/%y)
  let message = $"Se han subido a drive los videos de clases al dia de hoy: ($fecha)."

  ubb_announce $message 

  mv 20*/ done/
}

#post to #medicos in discord
def med_discord [message] {
  let content = $"{\"content\": \"($message).\"}"

  let weburl = (open ([$env.MY_ENV_VARS.credentials "discord_webhooks.json"] | path join) | get medicos)

  post $weburl $content --content-type "application/json"
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

#delete non wanted media in mps (youtube download folder)
def delete-mps [] {
  if $env.MY_ENV_VARS.mps !~ $env.PWD {
    echo-g "wrong directory to run this"
  } else {
     ls 
     | where type == "file" && name !~ "mp4|mkv|webm" 
     | par-each {|it| 
         rm $"($it.name)" 
         | ignore
       }     
  }
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
  echo "fast --single-line --upload |  stdbuf -o0 awk '{print $2 \" \" $6}' | ttyplot -2 -t 'Download/Upload speed' -u Mbps" | bash 
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
  --no_backup:int  #wether to not backup $file or yes (default no:0, ie, it will backup)
  #
  #Examples
  #sub-sync file.srt "-4"
  #sub-sync file.srt "-4" --t1 00:02:33
  #sub-sync file.srt "-4" --no_backup 1
] {

  let file_exist = (($env.PWD) | path join $file | path exists)
  
  if $file_exist {
    if ($no_backup | empty?) || $no_backup == 0 {
      cp $file $"($file).backup"
    }

    let t1 = if ($t1 | empty?) {"@"} else {$t1}  
    let d2 = if ($d2 | empty?) {""} else {$d2}
    let t2 = if ($d2 | empty?) {""} else {if ($t2 | empty?) {"@"} else {$t2}}
  
    bash -c $"subsync -e latin1 ($t1)($d1) ($t2)($d2) < \"($file)\" > output.srt; cp output.srt \"($file)\""

    rm output.srt | ignore
  } else {
    echo-g $"subtitle file ($file) doesn't exist in (pwd-short)"
  }
}

#rm trough pipe
#
#Example
#ls *.txt | rm-pipe
def rm-pipe [] {
  get name 
  | ansi strip
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
      echo-g $"copying ($file)..." 
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
      echo-g $"moving ($file)..." 
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

  let known_devices = open ([$env.MY_ENV_VARS.linux_backup "known_devices.csv"] | path join)
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
  #Examples
  #t-removedelete 2 3 6 9
  #t-list | some filter | t-removedelete
] {
  if ($ids | empty?) {
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
def t-removedone [] {
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
def umall [user? = $env.USER] {
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
        echo-g $"audio conversion to ($to) done, but something might be wrong"
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
        echo-g $"video conversion to mp4 done, but something might be wrong"
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
  echo-g "merging videos..."
  myffmpeg -f concat -safe 0 -i $"($list)" -c copy $"($output)"
  
  echo-g "done!"
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

  echo-g "merging videos..."
  myffmpeg -f concat -safe 0 -i list.txt -c copy $"($output)"
      
  echo-g "done!"
  notify-send "video merging done!"
}

#join multiple pdfs
def join-pdfs [
  ...rest: #list of pdf files to concatenate
] {
  if ($rest | empty?) {
    echo-g "not enough pdfs provided"
  } else {
    pdftk $rest cat output output.pdf
    echo-g "pdf merged in output.pdf"
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
def screen-record [
  file = "video"  #output filename without extension (default: "video")
  --audio = true    #whether to record with audio or not (default: true)
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
  --from = $env.MY_ENV_VARS.mail    #email from, default: $MY_ENV_VARS.mail
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
    echo-g "body undefined!!"
  } else if not (($from | str contains "@") && ($to | str contains "@")) {
    echo-g "missing @ in email-from or email-to!!"
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
  earth-update
  yandex-update
  sejda-update
  nmap-update
  nyxt-update
  tasker-update
  ttyplot-update
  mpris-update
}

#update zoom
def zoom-update [] {
  cd $env.MY_ENV_VARS.debs

  if (ls *.deb | find zoom | length) > 0 {
    ls *.deb | find zoom | rm-pipe | ignore
  }
  
  echo-g "downloading zoom..."
  aria2c --download-result=hide https://zoom.us/client/latest/zoom_amd64.deb
  sudo gdebi -n (ls *.deb | find zoom | get 0 | get name | ansi strip)
}

#update chrome deb
def chrome-update [] {
  cd $env.MY_ENV_VARS.debs

  if (ls *.deb | find chrome | length) > 0 {
    ls *.deb | find chrome | rm-pipe | ignore
  }
  
  echo-g "downloading chrome..."
  aria2c --download-result=hide https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
  echo-g $"download finished: (ls *.deb | find chrome | get 0 | get name | ansi strip)"
}

#update google earth deb
def earth-update [] {
  cd $env.MY_ENV_VARS.debs

  if (ls *.deb | find earth | length) > 0 {
    ls *.deb | find earth | rm-pipe | ignore
  }
  
  echo-g "downloading google earth..."
  aria2c --download-result=hide https://dl.google.com/dl/earth/client/current/google-earth-pro-stable_current_amd64.deb
  echo-g $"download finished: (ls *.deb | find earth | get 0 | get name | ansi strip)"
}

#update yandex deb
def yandex-update [] {
  cd $env.MY_ENV_VARS.debs

  if (ls *.deb | find yandex | length) > 0 {
    ls *.deb | find yandex | rm-pipe | ignore
  }
  
  echo-g "downloading yandex..."
  aria2c --download-result=hide http://repo.yandex.ru/yandex-disk/yandex-disk_latest_amd64.deb
  echo-g $"download finished: (ls *.deb | find yandex | get 0 | get name | ansi strip)"
}

#update sejda
def sejda-update [] {
  cd $env.MY_ENV_VARS.debs

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
      echo-g "updating sedja..."
      rm sejda*.deb | ignore
      aria2c --download-result=hide $url
      sudo gdebi -n $new_file
    }

  } else {
    echo-g "downloading sedja..."
    aria2c --download-result=hide $url
    sudo gdebi -n $new_file
  }
}

#update tasker permissions
def tasker-update [] {
  cd $env.MY_ENV_VARS.debs

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
      echo-g "updating tasker permissions..."
      rm *tasker*.deb | ignore
      aria2c --download-result=hide $url
      sudo gdebi -n $new_file
    }

  } else {
    echo-g "downloading tasker..."
    aria2c --download-result=hide $url
    sudo gdebi -n $new_file
  }
}

#update nmap
def nmap-update [] {
  cd $env.MY_ENV_VARS.debs

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
      echo-g "updating nmap..."
      rm nmap*.deb | ignore

      aria2c --download-result=hide $url
      sudo alien -v -k $new_file

      let new_deb = (ls *.deb | find nmap | get 0 | get name | ansi strip)

      sudo gdebi -n $new_deb
      ls $new_file | rm-pipe | ignore
    }

  } else {
    echo-g "downloading nmap..."
    aria2c --download-result=hide $url
    sudo alien -v -k $new_file

    let new_deb = (ls *.deb | find nmap | get 0 | get name | ansi strip)

    sudo gdebi -n $new_deb
    ls $new_file | rm-pipe | ignore
  }
}

#update nyxt
def nyxt-update [] {
  cd $env.MY_ENV_VARS.debs

  let info = (
    fetch https://github.com/atlas-engineer/nyxt/releases
    | lines 
    | find .deb 
    | first 
    | split row "\"" 
    | get 1
  )

  let url = $"https://github.com($info)"

  let new_version = (
    $info 
    | split row /
    | last
    | split row _ 
    | get 1
  )
  
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
      echo-g "updating nyxt..."
      rm nyxt*.deb | ignore
      aria2c --download-result=hide $url

      let new_deb = (ls *.deb | find nyxt | get 0 | get name | ansi strip)
      sudo gdebi -n $new_deb
    }

  } else {
    echo-g "downloading nyxt..."
    aria2c --download-result=hide $url
    let new_deb = (ls *.deb | find nyxt | get 0 | get name | ansi strip)
    sudo gdebi -n $new_deb
  }
}

#update mpris
def mpris-update [] {
  cd ([$env.MY_ENV_VARS.linux_backup "scripts"] | path join)

  let info = (
    fetch https://github.com/hoyon/mpv-mpris/releases 
    | lines 
    | find -i mpris.so 
    | get 0 
    | split row "\""  
    | get 1
  )

  let url = $"https://github.com($info)"

  let new_version = (
    $info 
    | split row /
    | drop
    | last
  )
  
  let mpris = ((ls mpris.so | length) > 0)

  if $mpris {
    let current_version = (open mpris.json | get version)

    if $current_version != $new_version {
      echo-g "updating mpris..."
      rm mpris.so | ignore
      aria2c --download-result=hide $url -o mpris.so
    }

  } else {
    echo-g "downloading mpris..."
    aria2c --download-result=hide $url -o mpris.so
  }
}

#update ttyplot
def ttyplot-update [] {
  cd $env.MY_ENV_VARS.debs

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
      echo-g "updating ttyplot..."
      rm ttyplot*.deb | ignore
      aria2c --download-result=hide $url
      sudo gdebi -n $new_file
    }

  } else {
    echo-g "downloading ttyplot..."
    aria2c --download-result=hide $url
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
      echo-g $"registering ($file)..."
      nu -c $'register -e json ($file)'
    }
}

#stop network applications
def stop-net-apps [] {
  t-stop
  ydx-stop
  maestral stop
  killn jdown
}

#add a hidden column with the content of the # column
def indexify [
  column_name: string = 'index' #default: index
  ] { 
  each -n {|it| 
    $it.item 
    | upsert $column_name $it.index 
    | move $column_name --before ($it.item | columns).0 
  } 
}

#reset alpine authentification
def reset-alpine-auth [] {
  rm ~/.pine-passfile
  touch ~/.pine-passfile
  alpine-notify -i
}

#play youtube music from local database
def ytm [
  playlist? = "all_music" #playlist name (default: all_music)
  --list(-l)              #list available music playlists
  #
  #First run `yt-api download-music-playlists`
] {
  let mpv_input = ([$env.MY_ENV_VARS.linux_backup "scripts/mpv_input.conf"] | path join)
  let playlists = (ls $env.MY_ENV_VARS.youtube_database | get name)

  #--list|
  if not ($list | empty?) || (not $list) {
    $playlists | path parse | get stem
  } else {
    let to_play = ($playlists | find $playlist | ansi strip | get 0)

    if ($to_play | length) > 0 {
      let songs = open $to_play
      let len = ($songs | length)

      $songs 
      | shuffle 
      | each -n {|song|
          fetch $"($song.item.thumbnail)" | save /tmp/thumbnail.jpg
          convert -density 384 -scale 256 -background transparent /tmp/thumbnail.jpg /tmp/thumbnail.ico

          notify-send $"($song.item.title)" $"($song.item.artist)" -t 5000 --icon=/tmp/thumbnail.ico
          tiv /tmp/thumbnail.ico 
          echo-g $"now playing ($song.item.title) by ($song.item.artist) [($song.index)/($len)]..."

          bash -c $"mpv --msg-level=all=status --no-resume-playback --no-video --input-conf=($mpv_input) ($song.item.url)"
        }    
    } else {
      echo-g "playlist not found!"
    }
  }
}

#play youtube music from youtube
def "ytm online" [
  playlist? = "all_music" #playlist name, default: all_music
  --list(-l)              #list available music playlists
] {
  let mpv_input = ([$env.MY_ENV_VARS.linux_backup "scripts/mpv_input.conf"] | path join)
  let response = yt-api

  let playlists = (
    $response 
    | get items 
    | select id snippet 
    | upsert snippet {|sn| 
        $sn.snippet.title
      }
    | rename -c [snippet title]
  )

  #--list|
  if not ($list | empty?) || (not $list) {
    $playlists | find music
  } else {
    let to_play = ($playlists | where title =~ $playlist | first | get id)

    if ($to_play | length) > 0 {
      let songs = yt-api get-songs $to_play
      let len = ($songs | length)

      $songs 
      | shuffle 
      | each -n {|song|
          fetch $"($song.item.thumbnail)" | save /tmp/thumbnail.jpg
          convert -density 384 -scale 256 -background transparent /tmp/thumbnail.jpg /tmp/thumbnail.ico

          notify-send $"($song.item.title)" $"($song.item.artist)" -t 5000 --icon=/tmp/thumbnail.ico
          tiv /tmp/thumbnail.ico 
          echo-g $"now playing ($song.item.title) by ($song.item.artist) [($song.index)/($len)]..."

          bash -c $"mpv --msg-level=all=status --no-resume-playback --no-video --input-conf=($mpv_input) ($song.item.url)"
        }    
    } else {
      echo-g "playlist not found!"
    }
  }
}

#youtube api implementation to get playlists and songs info
def yt-api [
  type? = "snippet" #type of query: id, status, snippet (default)
  --pid:string      #playlist/song id
  --ptoken:string   #prev/next page token
] {
  #verify and update token
  yt-api verify-token

  let youtube_credential = open ([$env.MY_ENV_VARS.credentials "credentials.youtube.json"] | path join)
  let api_key = ($youtube_credential | get api_key)
  let token = ($youtube_credential | get token)

  #playlist|playlist nextPage|songs|songs nextPage
  let url = (
    if ($pid | empty?) && ($ptoken | empty?) {
      $"https://youtube.googleapis.com/youtube/v3/playlists?part=($type)&mine=true&key=($api_key)&maxResults=50"
    } else if ($pid | empty?) && (not ($ptoken | empty?)) {
      $"https://youtube.googleapis.com/youtube/v3/playlists?part=($type)&mine=true&key=($api_key)&maxResults=50&pageToken=($ptoken)"
    } else if not ($pid | empty?) {
      if ($ptoken | empty?) {
        $"https://youtube.googleapis.com/youtube/v3/playlistItems?part=($type)&maxResults=50&playlistId=($pid)&key=($api_key)&maxResults=50"
      } else {
        $"https://youtube.googleapis.com/youtube/v3/playlistItems?part=($type)&maxResults=50&pageToken=($ptoken)&playlistId=($pid)&key=($api_key)"
      }
    }
  )

  let response = fetch $"($url)" -H ["Authorization", $"Bearer ($token)"] -H ['Accept', 'application/json']
 
  $response
}

#get youtube songs of playlist by id
def "yt-api get-songs" [
  pid:string      #playlist id
  --ptoken:string #nextpage token
  #
  #Output table: 
  #inPlaylistID | id | title | artist | thumbnail | url
] {
  #verify and update token
  yt-api verify-token

  #songs|songs nextPage
  let response = (
    if ($ptoken | empty?) {
      yt-api --pid $pid
    } else {
      yt-api --pid $pid --ptoken $ptoken
    }
  )

  let nextpageToken = (
    if ($response | column? nextPageToken) {
        $response | get nextPageToken
    } else {
        false
    }
  )
  
  #first page
  let songs = (
    $response
    | get items 
    | select id snippet 
    | rename -c [id inPlaylistID]
    | upsert id {|item| 
        $item.snippet.resourceId.videoId
      }
    | upsert title {|item| 
        $item.snippet.title
      } 
    | upsert artist {|item| 
        $item.snippet.videoOwnerChannelTitle 
        | str replace ' - Topic' ''
      } 
    | upsert thumbnail {|item| 
        $item.snippet.thumbnails | transpose | last | get column1 | get url
      }
    | upsert url {|item|
        $item.snippet.resourceId.videoId | str prepend "https://www.youtube.com/watch?v="
      }
    | reject snippet
  )

  #next pages via recursion
  let songs = (
    if ($nextpageToken | typeof) == string {
        $songs | append (yt-api get-songs $pid --ptoken $nextpageToken)
    } else {
      $songs
    }
  )

  $songs
}

#download youtube music playlist to local database
def "yt-api download-music-playlists" [
  --downloadDir(-d) = $env.MY_ENV_VARS.youtube_database #download directory, default: $env.MY_ENV_VARS.youtube_database
] {
  let response = yt-api

  let playlists = (
    $response 
    | get items 
    | select id snippet 
    | upsert snippet {|sn| 
        $sn.snippet.title
      }
    | rename -c [snippet title]
    | find music
  )

  $playlists
  | each {|playlist|
      let filename = $"([$downloadDir ($playlist.title | ansi strip)] | path join).json"
      let songs = yt-api get-songs $playlist.id
      
      if ($songs | length) > 0 {
        echo-g $"downloading ($playlist.title | ansi strip) into ($filename)..."
        $songs | save $filename
      }
    }
}

#update playlist1 from playlist2
def "yt-api update-all" [
  --playlist1 = "all_music"
  --playlist2 = "new_likes"
] {
  let youtube_credential = open ([$env.MY_ENV_VARS.credentials "credentials.youtube.json"] | path join)
  let api_key = ($youtube_credential | get api_key)
  let token = ($youtube_credential | get token)
  let response = yt-api

  let playlists = (
    $response 
    | get items 
    | select id snippet 
    | upsert snippet {|sn| 
        $sn.snippet.title
      }
    | rename -c [snippet title]
  )

  let from = ($playlists | find $playlist2 | get id | get 0)
  let to = ($playlists | find $playlist1 | get id | get 0)

  let to_add = yt-api get-songs $from

  echo-g $"copying playlist items from ($playlist2) to ($playlist1)..."
  $to_add 
  | each {|song|
      let body = (
        {  "snippet": {
              "playlistId": $"($to)",
              "resourceId": {
                "kind": "youtube#video",
                "videoId": $"($song.id)"
              }
            }
        }
      )

      post "https://www.googleapis.com/youtube/v3/playlistItems?part=snippet&key=($api_key)" -t 'application/json' -H ["Authorization", $"Bearer ($token)"] $body | ignore
      sleep 10ms

    }   

  echo-g $"deleting playlist items from ($playlist2)..."
  let header2 = "Accept: application/json"

  $to_add 
  | each {|song|
      let url = $"https://youtube.googleapis.com/youtube/v3/playlistItems?id=($song.inPlaylistID)&key=($api_key)"
      let header1 = $"Authorization: Bearer ($token)"

      curl -s --request DELETE $url --header $header1 --header $header2 --compressed
      sleep 10ms
    }

  echo-g $"updating local database..."
  yt-api download-music-playlists
}

#verify if youtube api token has expired
def "yt-api verify-token" [] {
  let youtube_credential = open ([$env.MY_ENV_VARS.credentials "credentials.youtube.json"] | path join)
  let api_key = ($youtube_credential | get api_key)
  let token = ($youtube_credential | get token)

  let response = fetch $"https://youtube.googleapis.com/youtube/v3/playlists?part=snippet&mine=true&key=($api_key)" -H ["Authorization", $"Bearer ($token)"] -H ['Accept', 'application/json'] 

  if ($response | column? error) {
    yt-api get-token 
    #yt-api refresh-token
  }
}

#update youtube api token
def "yt-api get-token" [] {
  let youtube_credential = open ([$env.MY_ENV_VARS.credentials "credentials.youtube.json"] | path join)
  let client = ($youtube_credential | get client_id)

  let uri = (
    $youtube_credential 
    | get redirect_uris 
    | get 0 
    | str replace -a ":" "%3A" 
    | str replace -a "/" "%2F"
  )
  
  echo $"https://accounts.google.com/o/oauth2/auth?client_id=($client)&redirect_uri=($uri)&scope=https://www.googleapis.com/auth/youtube&response_type=token&approval_prompt=force" | copy

  echo-g "url copied to clipboard, now paste on browser..."

  let url = input (echo-g "Copy response url here: ")

  $youtube_credential  
  | upsert token {
      $url 
      | split row "#" 
      | get 1 
      | split row "=" 
      | get 1 
      | split row "&" 
      | get 0
    } 
  | save ([$env.MY_ENV_VARS.credentials "credentials.youtube.json"] | path join) 
}

#get youtube api refresh token
def "yt-api get-refresh-token" [] {
  let youtube_credential = open ([$env.MY_ENV_VARS.credentials "credentials.youtube.json"] | path join)
  let client = ($youtube_credential | get client_id)

  let uri = (
    $youtube_credential 
    | get redirect_uris 
    | get 0 
    | str replace -a ":" "%3A" 
    | str replace -a "/" "%2F"
  )
  
  echo $"https://accounts.google.com/o/oauth2/auth?client_id=($client)&redirect_uri=($uri)&scope=https://www.googleapis.com/auth/youtube&response_type=code&access_type=offline&prompt=consent" | copy

  echo-g "url copied to clipboard, now paste on browser..."

  let url = input (echo-g "Copy response url here: ")

  $youtube_credential  
  | upsert refresh_token {
      $url 
      | split row "=" 
      | get 1 
      | split row "&" 
      | get 0
    } 
  | save ([$env.MY_ENV_VARS.credentials "credentials.youtube.json"] | path join) 
}

#refres youtube api token via refresh token
def "yt-api refresh-token" [] {
  let youtube_credential = open ([$env.MY_ENV_VARS.credentials "credentials.youtube.json"] | path join)
  let client_id = ($youtube_credential | get client_id)
  let client_secret = ($youtube_credential | get client_secret)
  let refresh_token = ($youtube_credential | get refresh_token)
  let redirect_uri = (
    $youtube_credential 
    | get redirect_uris 
    | get 0 
    | str replace -a ":" "%3A" 
    | str replace -a "/" "%2F"
  )

  post "https://accounts.google.com/o/oauth2/token" $"client_id=($client_id)&client_secret=($client_secret)&refresh_token=($refresh_token)&grant_type=refresh_token" -t application/x-www-form-urlencoded

  # curl -X POST "https://accounts.google.com/o/oauth2/token" -d $"client_id=($client_id)&client_secret=($client_secret)&refresh_token=($refresh_token)&grant_type=refresh_token" -H "Content-Type: application/x-www-form-urlencoded"
}

#help info for yt-api
def "yt-api help" [] {
  echo "  CONFIGURE $env.MY_ENV_VARS.credentials\n
    Add the path to your directory with the credential file or replace manually.\n
  CREATE CREDENTIALS\n
    1) Create an api key from google developers console.\n
    2) Create oauth2 credentials. You should download a json file with at least the following fields:
      - client_id
      - client_secret
      - redirect_uris\n
    3) Add the api key to the previous file, from now on, the credentials file.\n
    4) Run `yt-api get-token`. The token is automatically added to the credentials file.\n
    5) Run `yt-api get-regresh-token`. The refresh token is automatically added to the credentials file.\n
    6) When the token expires, it will run `yt-api get-token` again.
    7) When `yt-api refresh-token` is finished, the refresh will be automatic.\n
  METHODS\n
    - `yt-api`
    - `yt-api get-songs`
    - `yt-api update-all`
    - `yt-api download-music-playlists`\n
  MORE HELP\n
    Run `? yt-api`\n
  RELATED\n
    `ytm`\n"
    | nu-highlight
}

## appimages

#open balena-etche
def balena [] {
  bash -c $"([$env.MY_ENV_VARS.appImages 'balenaEtcher.AppImage'] | path join) 2>/dev/null &"
}

## testing

# def "yt-api verify-token" [url,token] {
#   let response = fetch $"($url)" -H ["Authorization", $"Bearer ($token)"] -H ['Accept', 'application/json']

#   if ($response | column? error) {
#     let client = (open ~/Yandex.Disk/Backups/linux/credentials/credentials.youtube.json | get client_id)
#     let refresh_token = (open ~/Yandex.Disk/Backups/linux/credentials/credentials.youtube.json | get refresh_token)
#     let secret = (open ~/Yandex.Disk/Backups/linux/credentials/credentials.youtube.json | get client_secret)

#     let response = (post "https://www.googleapis.com/oauth2/v4/token" -t 'application/json' {
#         "client_id": ($client),
#         "client_secret": ($secret),
#         "refresh_token": ($refresh_token),
#         "grant_type": "authorization_code",
#         "access_type": "offline",
#         "prompt": "consent",
#         "scope": "https://www.googleapis.com/auth/youtube"
#       }
#     )

#     $response | save test.json
#   }
# }


def test-api [] {
  let youtube_credential = open ([$env.MY_ENV_VARS.credentials "credentials.youtube.json"] | path join)
  let api_key = ($youtube_credential | get api_key)
  let token = ($youtube_credential | get token)
  let client = ($youtube_credential | get client_id)
  let refresh_token = ($youtube_credential | get refresh_token)
  let secret = ($youtube_credential | get client_secret)

  let response = (post "https://www.googleapis.com/oauth2/v4/token" -t 'application/json' {
     "client_id": ($client),
     "client_secret": ($secret),
     "refresh_token": ($refresh_token),
     "grant_type": "refresh_token"
   }
  )

  $response | save test.json 
}

 # let response = (post "https://accounts.google.com/o/oauth2/token/" $"client_id=($client)&client_secret=($secret)&refresh_token=($refresh_token)&grant_type=refresh_token&access_type=offline&prompt=consent&scope=https://www.googleapis.com/auth/youtube"2 -t "text/html"
  # )
# https://accounts.google.com/o/oauth2/auth?client_id=676765289577-ek34fcbppprtcvtt7sd98ioodvapojci.apps.googleusercontent.com&redirect_uri=http%3A%2F%2Flocalhost%2Foauth2callback&scope=https://www.googleapis.com/auth/youtube&response_type=token

# http://localhost/oauth2callback
# http://localhost:8080 

# http://localhost/oauth2callback#access_token=&token_type=Bearer&expires_in=3599&scope=https://www.googleapis.com/auth/youtube

# def get-yt-playlist [
#   pid         #playlist id
#   nos? = 500  #number of song to fetch
#   --all       #fetch all songs
# ] {
#   ls
# # $playlists | flatten | where title == jp  | get id
# }


# auth_code
# https://accounts.google.com/o/oauth2/v2/auth?redirect_uri=https%3A%2F%2Fdevelopers.google.com%2Foauthplayground&prompt=consent&response_type=code&client_id=407408718192.apps.googleusercontent.com&scope=https%3A%2F%2Fwww.googleapis.com%2Fauth%2Fyoutube&access_type=offline
# https://accounts.google.com/o/oauth2/v2/auth?redirect_uri=https%3A%2F%2Fdevelopers.google.com%2Foauthplayground&prompt=consent&response_type=code&client_id=407408718192.apps.googleusercontent.com&scope=https%3A%2F%2Fwww.googleapis.com%2Fauth%2Fyoutube&access_type=offline

# 4/0AdQt8qiNECGYvH98mxe0xnd7dHhGahZb2Na9w2-Q0YTv3KvjCg7ULN6T4Z5jGrLvEfLtnw

# refresh_token
# 1//04fRaM1rCDgifCgYIARAAGAQSNwF-L9IrQQDg2DCQypNrG44ML4QwcMsEGI0X5i4n43B5E4ZmdLvTcaeDltC0aQDjeUjlCE89BcU