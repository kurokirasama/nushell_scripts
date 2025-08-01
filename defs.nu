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
  #add in2csv
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
  | where results like '(?P<plus>\+)(?P<nums>\d+)'

}

#open mcomix
export def mcx [file?] {
  let file = get-input $in $file

  job spawn {mcomix $file} | ignore
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
export def --wrapped gg [...search: string] {
  ddgr -n 5 ...$search
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
export def check-link [link?,timeout?:duration] {
  let link = get-input $in $link

  if ($timeout | is-empty) {
    let response = try {
      http get $link | ignore;true
    } catch {
      false
    }
    return $response
  }

  try {
    http get $link -m $timeout | ignore;true
  } catch {
    false
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
  --background(-b)    #send process to the background, select input m-file from list
  --input(-i):string  #input m-file to run in background mode, must be in the same directory
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
    matlab -nosplash -nodesktop -softwareopengl -sd ($env.PWD) -logfile ("~/Dropbox/matlab" | path join $"($log_file).txt" | path expand) -r "setenv('SHELL', '/bin/bash');"
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
      $input | path parse | get stem
    }
  )

  let output = if ($output | is-empty) {$log} else {$output + ".txt"}

  job spawn {matlab -batch ("setenv('SHELL', '/bin/bash'); " + $input) | save -f $output} | ignore
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
  let tex = get-input $in $file -n
  let file_base_name = $tex | path parse | get stem
  texfot pdflatex -interaction=nonstopmode -synctex=1 $file_base_name
  bibtex $file
  sleep 0.1sec
  texfot pdflatex --shell-escape -interaction=nonstopmode -synctex=1 $file_base_name
  texfot pdflatex --shell-escape -interaction=nonstopmode -synctex=1 $file_base_name
}

#pandoc md compiler
export def my-pandoc [
  file?
] {
  let file_name = get-input $in $file -n
  let file_base_name = $file_name | path parse | get stem

  pandoc --quiet $file_name -o $"($file_base_name).pdf" --pdf-engine=/usr/bin/xelatex -F mermaid-filter -F pandoc-crossref --number-sections --highlight-style $env.MY_ENV_VARS.pandoc_theme

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

#flatten a record keys
#
#Example:
# flatten-keys $env.config '$env.config'
def flatten-keys [rec: record, root: string] {
  $rec | columns | each {|key|
    let is_record = (
      $rec | get $key | describe --detailed | get type | $in == record
    )

    # Recusively return each key plus its subkeys
    [$'($root).($key)'] ++  match $is_record {
      true  => (flatten-keys ($rec | get $key) $'($root).($key)')
      false => []
    }
   } | flatten
}

#generates nushell document for llm (gemini and claude)
export def generate-nushell-doc [] {
  cd ~/software/nushell.github.io
  git pull
  cd book/
  get-files | cp-pipe ~/temp

  cd ~/temp
  ["3rdpartyprompts.md" "installation.md" "design_notes.md" "background_task.md"] | each {|f|
    rm -f $f
  }

  cd ~/temp
  join-text-files md nushell_book

  let doc = open nushell_book.md

  cd ([$env.MY_ENV_VARS.chatgpt_config system] | path join)

  let index = open bash_nushell_programmer_with_nushell_docs.md | lines | find-index "NUSHELL DOCUMENTATION" | get 1 | into int

  let system_message = open bash_nushell_programmer_with_nushell_docs.md | lines | first ($index + 2) | to text

  $system_message + $doc | save -f bash_nushell_programmer_with_nushell_docs.md

  cd ~/temp
  rm *
}

#generate an unique md from all files in current directory recursively
export def generate-md-from-dir [output_file = "output.md"] {
  # Initialize output file
  "" | save $output_file

  ls **/*
  | where type == file
  | where name not-like "png|jpg"
  | where name != $output_file
  | each { |it|
    let filepath = $it.name
    let file_content = open $filepath

    # Create the section header
    let section_header = $"\n# ($filepath)\n"
    $section_header | save -a $output_file

    # Create the code block
    let code_block_start = "\n```\n"
    $code_block_start | save -a $output_file

    $file_content | save -a $output_file

    let code_block_end = "\n```\n"
    $code_block_end | save -a $output_file

    print $"Generated section for ($filepath)"
  }
  print $"All file contents copied to ($output_file)"
}

#Calculates a past datetime by subtracting a duration from the current time.
export def ago []: [ duration -> datetime ] {
  (date now) - $in
}

#download file with filename
def "http download" [url:string] {
  let attachmentName  = http head $url
    | transpose -dr
    | get -o content-disposition
    | parse "attachment; filename={filename}"
    | get filename?.0?

  let filename = if ($attachmentName | is-empty) {
      # use the end of the URL path
      ($url | url parse | get path | path parse | do {$"($in.stem).($in.extension)"})
    } else {
      $attachmentName
    }

  http get --raw $url | save $filename
}

#################################################################################################
## appimages
#################################################################################################

#open balena-etche
export def balena [] {
  bash -c $"([$env.MY_ENV_VARS.backup appimages 'balenaEtcher.AppImage'] | path join) 2>/dev/null &"
}
