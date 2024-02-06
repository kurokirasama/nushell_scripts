#grep for nu
#
#Examples;
#grep-nu search file.txt
#ls **/* | some_filter | grep-nu search 
#open file.txt | grep-nu search
export def grep-nu [
  search   #search term
  entrada? #file or pipe
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

export alias grp = grep-nu

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

#jdownloader downloads info
export def jd [
  --ubb(-b) #check ubb jdownloader
] {
  if (not $ubb) {
    jdown
  } else {
    jdown -b 1
  }
  | from json
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

#web search in terminal
export def gg [...search: string] {
  ddgr -n 5 ($search | str join ' ')
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
export def send-gmail [
  to:string       #email to
  subject:string  #email subject
  --body:string   #email body, use double quotes to use escape characters like \n
  --from:string   #email from, export default: $MY_ENV_VARS.mail
  ...attachments  #email attachments file names list (in current directory), separated by comma
] {
  let inp = if ($in | is-empty) { "" } else { $in | into string }
  let from = if ($from | is-empty) {$env.MY_ENV_VARS.mail} else {$from}

  if ($body | is-empty) and ($inp | is-empty) {
    return-error "body unexport defined!!"
  } 
  if not (($from | str contains "@") and ($to | str contains "@")) {
    return-error "missing @ in email-from or email-to!!"
  } 

  let signature_file = (
    match $from {
      ($env.MY_ENV_VARS.mail) => {
        [$env.MY_ENV_VARS.nu_scripts "send-gmail_kurokirasama_signature"] | path join
      },
      ($env.MY_ENV_VARS.mail_ubb) => {
        [$env.MY_ENV_VARS.nu_scripts "send-gmail_ubb_signature"] | path join
      },
      ($env.MY_ENV_VARS.mail_lmgg) => {
        [$env.MY_ENV_VARS.nu_scripts "send-gmail_lmgg_signature"] | path join
      },
      _ => {
        [$env.MY_ENV_VARS.nu_scripts "send-gmail_other_signature"] | path join
      }
    }
  )

  let signature = (open $signature_file)

  let BODY = (
    if ($inp | is-empty) { 
      $"($body)\n" + $signature 
    } else { 
      $"($inp)\n" + $signature 
    } 
  )

  if ($attachments | is-empty) {
    echo $BODY | mail -r $from -s $subject $to
  } else {
    let ATTACHMENTS = ($attachments 
      | split row ","
      | each {|file| 
          [$env.PWD $file] | path join
        } 
      | str join " --attach="
    )
    bash -c $"\'echo ($BODY) | mail --attach=($ATTACHMENTS) -r ($from) -s \"($subject)\" ($to) --debug-level 10\'"
  }
}

#reset alpine authentification
export def reset-alpine-auth [] {
  rm ~/.pine-passfile
  touch ~/.pine-passfile
  alpine-notify -i
}

#run matlab in cli
export def matlab-cli [
  --background(-b)    #send process to the background
  --input(-i):string  #input m-file to run
  --output(-o):string #output file for log without extension
  --kill(-k)          #kill current matlab processes
] {
  if $kill {
    ps -l 
    | find -i matlab 
    | find local & MATLAB 
    | find -v MATLAB-language-server & 'bin/nu' 
    | each {|row|
        kill -f $row.pid
      }
    
    return
  }

  if not $background {
    matlab -nosplash -nodesktop -softwareopengl -sd $"\"($env.PWD)\"" -logfile "/home/kira/Dropbox/matlab/log23.txt" -r "setenv('SHELL', '/bin/bash');"
    return
  } else {
    let log = (date now | format date "%Y.%m.%d_%H.%M.%S") + "_log.txt"

    let input = (
      if ($input | is-empty) {
        ls *.m 
        | get name 
        | path parse 
        | get stem 
        | input list -f (echo-g "m-file to run: ")
      } else {
        $input
      }
    )
  
    let output = if ($output | is-empty) {$log} else {$output + ".txt"}

    bash -c $"matlab -nodisplay -nodesktop -nosplash -sd ($env.PWD) -r ($input) > ($output) &"
  }
}

#get files all at once from webpage using wget
export def wget-all [
  webpage: string    #url to scrap
  ...extensions      #list of extensions separated by space
] {
  wget -A ($extensions | str join ",") -m -p -E -k -K -np --restrict-file-names=windows $webpage
}

#my pdflatex
export def my-pdflatex [file?] {
  let tex = if ($file | is-empty) {$in | get name} else {$file}
  texfot pdflatex -interaction=nonstopmode -synctex=1 ($tex | path parse | get stem)
}

#maestral status
export def "dpx status" [] {
  maestral status | lines | parse "{item}  {status}" | str trim | drop nth 0
}

#qr code generator
export def qrenc [url] {
  curl $"https://qrenco.de/($url)"
}

#compact with empty strings and nulls
export def scompact [
    ...columns: string # the columns to compactify
    --invert(-i) # select the opposite
] {
  mut out = $in
  for column in $columns {
    if $invert {
      $out = ($out | upsert $column {|row| if not ($row | get $column | is-empty) {null} else {$row | get $column}} | compact $column  )
      } else {
        $out = ($out | upsert $column {|row| if ($row | get $column | is-empty) {null} else {$row | get $column}} | compact $column  )
      }
  }
  return $out 
}

#local http server
export def "http server" [root:string ="."] {
  simple-http-server $root
}

## appimages

#open balena-etche
export def balena [] {
  bash -c $"([$env.MY_ENV_VARS.appImages 'balenaEtcher.AppImage'] | path join) 2>/dev/null &"
}