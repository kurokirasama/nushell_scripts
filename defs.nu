#grep for nu
#
#Examples;
#grep-nu search file.txt
#ls **/* | some_filter | grep-nu search 
#open file.txt | grep-nu search
export def grep-nu [
  search:string   #search term
  entrada?:string #file or pipe
] {
  let input = $in
  let entrada = if ($entrada | is-empty) {
    if ($input | is-column name) {
      $input | get name
    } else {
      $input
    }
  } else {
    $entrada
  }

  if ('*' in $entrada) {
      grep -ihHn $search ...(glob $entrada)
  } else {
      grep -ihHn $search $entrada
  }
  | lines 
  | parse "{file}:{line}:{match}"
  | str trim
  | update match {|f| 
      $f.match | nu-highlight
    }
  | update file {|f| 
      let info = $f.file | path parse
      $info.stem + "." + $info.extension
    }
  # | rename "source file" "line number"
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
  (ls ~/media | find $"($drive)" | length) > 0
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
  --desktop(-d) #check ubb desktop
] {
  match [$ubb,$desktop] {
    [true,false] => {jdown -b 1},
    [false,true] => {jdown -b 2},
    [false,false] => {jdown},
    [true,true] => {return-error "please specify only one option"}
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
  --log_file(-l):string = "log24" #log file in foreground mode
  --kill(-k)          #kill current matlab processes
] {
  if $kill {
    ps -l 
    | find -i matlab 
    | find local & MATLAB 
    | find -v 'MATLAB-language-server' & 'bin/nu'  & 'yandex-disk'
    | each {|row|
        kill -f $row.pid
      }
    
    return
  }

  if not $background {
    matlab -nosplash -nodesktop -softwareopengl -sd ($env.PWD) -logfile ([~/Dropbox/matlab $"($log_file).txt"] | path join | path expand) -r "setenv('SHELL', '/bin/bash');"
    return
  } 
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

  bash -c ($"matlab -nodisplay -nodesktop -nosplash -sd ($env.PWD)" + $" -r ($input) > ($output) &")
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

#pandoc md compiler
export def my-pandoc [
  file?
] {
  let file_name = if ($file | is-empty) {$in | get name} else {$file}
  let file_base_name = $file_name | path parse | get stem

  pandoc --quiet $file_name -o $"($file_base_name).pdf" --pdf-engine=xelatex -F mermaid-filter -F pandoc-crossref --number-sections --highlight-style $env.MY_ENV_VARS.pandoc_theme

  openf $"($file_base_name).pdf"
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
export def --wrapped "http server" [
  root:string =".", 
  ...rest
] {
  simple-http-server $root ...$rest
}


#export nushell.github documentation
export def export-nushell-docs [] {
  if ("~/software/nushell.github.io" | path expand | path exists) {
    cd ~/software/nushell.github.io;git pull
    rm -rf nushell
  } else {
    cd ~/software
    git clone https://github.com/nushell/nushell.github.io.git
    cd nushell.github.io
  }  

  mkdir nushell 
  cd blog;join-text-files md blog;mv blog.md ../nushell;cd ..
  cd book;join-text-files md book;mv book.md ../nushell;cd ..
  cd commands/categories;join-text-files md categories;mv categories.md ..;cd ..
  cd docs;join-text-files md docs;mv docs.md ..;cd ..
  join-text-files md commands;mv commands.md ../nushell;cd ..
  cd cookbook;join-text-files md cookbook;mv cookbook.md ../nushell;cd ..
  cd lang-guide;join-text-files md lang-guide;mv lang-guide.md ../nushell;cd ..

  rm -rf ([$env.MY_ENV_VARS.ai_database nushell] | path join)
  mv -f nushell/ $env.MY_ENV_VARS.ai_database

  cd ~/software/nushell
  cp README.md ([$env.MY_ENV_VARS.ai_database nushell] | path join)
  cd ([$env.MY_ENV_VARS.ai_database nushell] | path join)
  
  join-text-files md all_nushell
  let system_message = (open ([$env.MY_ENV_VARS.chatgpt_config system bash_nushell_programmer.md] | path join)) ++ "\n\nPlease consider the following nushell documentation to elaborate your answer.\n\n"

  $system_message ++ (open all_nushell.md) | save -f ([$env.MY_ENV_VARS.chatgpt_config system bash_nushell_programmer_with_nushell_docs.md] | path join)
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

## appimages

#open balena-etche
export def balena [] {
  bash -c $"([$env.MY_ENV_VARS.backup appimages 'balenaEtcher.AppImage'] | path join) 2>/dev/null &"
}