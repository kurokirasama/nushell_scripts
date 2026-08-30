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

#run matlab in cli or gui
export def matlab-cli [
  --background(-b)    #send process to the background, select input m-file from list
  --input(-i):string  #input m-file to run in background mode, must be in the same directory
  --output(-o):string #output file for log without extension
  --log_file(-l):string = "log24" #log file in foreground mode
  --kill(-k)          #kill current matlab processes
  --login(-L)         #verify or perform interactive matlab license activation
  --nodisplay(-n)     #manually disable DISPLAY / force headless mode
  --gui(-g)           #launch full MATLAB Desktop GUI with robust Wayland/NVIDIA wrappers
] {
  let is_ssh = (($env | transpose name value | where name in ["SSH_CLIENT" "SSH_TTY" "SSH_CONNECTION"] | length) > 0)
  
  let is_arch = (try {
    if ("/etc/arch-release" | path exists) or ("/etc/cachyos-release" | path exists) {
      true
    } else if ("/etc/os-release" | path exists) {
      let os_info = (open /etc/os-release | lines)
      ($os_info | any { |l| $l =~ "(?i)ID(=|_LIKE=).*(arch|cachyos)" })
    } else {
      false
    }
  } catch { false })

  let lib_dir = (if $is_arch { "/usr/lib" } else { "/usr/lib/x86_64-linux-gnu" })
  let target_libs = ["libstdc++.so.6" "libX11.so.6" "libX11-xcb.so.1" "libfreetype.so.6"]
  let preload_lib = ($target_libs | each { |f| $lib_dir | path join $f } | where { $in | path exists } | str join ":")


  let env_vars = (if ($nodisplay or $is_ssh) {
      { DISPLAY: "" }
  } else {
      mut vars = {
        QT_QPA_PLATFORM: "xcb"
        GDK_BACKEND: "x11"
        _JAVA_AWT_WM_NONREPARENTING: "1"
        AWT_TOOLKIT: "XToolkit"
      }
      if not $is_arch {
        $vars = ($vars | insert MW_CEF_STARTUP_OPTIONS "--no-sandbox --disable-gpu --disable-gpu-compositing --ozone-platform=x11")
      }
      if ($preload_lib | is-not-empty) {
        let cur_preload = ($env.LD_PRELOAD? | default "")
        let full_preload = (if ($cur_preload | is-not-empty) { $"($preload_lib):($cur_preload)" } else { $preload_lib })
        $vars = ($vars | insert LD_PRELOAD $full_preload)
      }
      $vars
  })

  with-env $env_vars {
    if $login {
      matlab -nodisplay -batch "disp('MATLAB Version & Licensing Check:'); disp(version)"
      return
    }

    if $kill {
      ps | where name =~ "(?i)matlab|mathworks" | where name !~ "(?i)MATLAB-language-server" | each {|row|
        try { kill -f $row.pid }
      }
      return
    }

    if $gui {
      job spawn {
        matlab -desktop
      } | ignore
      return
    }

    if not $background {
      matlab -nosplash -nodesktop -sd ($env.PWD) -logfile ("~/Dropbox/matlab" | path join $"($log_file).txt" | path expand) -r "setenv('SHELL', '/bin/bash');"
      return
    }

    let log = (date now | format date "%Y.%m.%d_%H.%M.%S") + "_log.txt"

    let input = if ($input | is-empty) {
        ls *.m
        | get name
        | path parse
        | get stem
        | input list -f (echo-g "m-file to run: ")
      } else {
        $input | path parse | get stem
      }
    

    let output = if ($output | is-empty) {$log} else {$output + ".txt"}

    job spawn {
      matlab -batch ("setenv('SHELL', '/bin/bash'); " + $input) 
      | save -f $output
    } | ignore
    sleep 2sec
  }
}

# Return the flag emoji for a given two-digit country code
export def country-flag [
  country_code: string # The two-digit country code (e.g., "US", "de")
] {
  let base_offset = 127397

  $country_code
  | str uppercase
  | split chars
  | each {|c|
    ($c | into binary | into int) + $base_offset
    | char --integer $in
  }
  | str join
}

# Run Sober (Roblox player on Linux via Flatpak)
export def sober [
  --foreground(-f) # Run in foreground to stream Roblox/Sober logs
] {
  if $foreground {
    flatpak run org.vinegarhq.Sober
  } else {
    job spawn { flatpak run org.vinegarhq.Sober } | ignore
  }
}

# Alias for sober (Roblox)
export alias roblox = sober
