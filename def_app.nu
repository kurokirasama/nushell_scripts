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

#maestral status
export def "dpx status" [] {
  maestral status | lines | parse "{item}  {status}" | str trim | drop nth 0
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
    matlab -nosplash -nodesktop -sd ($env.PWD) -logfile ("~/Dropbox/matlab" | path join $"($log_file).txt" | path expand) -r "setenv('SHELL', '/bin/bash');"
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

# Return the flag emoji for a given two-digit country code
export def country-flag [
  country_code: string # The two-digit country code (e.g., "US", "de")
] {
  let base_offset = 127397

  $country_code
  | str upcase
  | split chars
  | each {|c|
    ($c | into binary | into int) + $base_offset
    | char --integer $in
  }
  | str join
}
