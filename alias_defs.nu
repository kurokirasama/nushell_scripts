#rm last
export def rml [] {
  ls | sort-by modified | last | rm-pipe
}

#tokei wrapper
export def tokei [] {
  ^tokei | grep -v '=' | from tsv
}

#keybindings
export def get-keybindings [] {
  $env.config.keybindings
}

#go to nu config dir
export def --env goto-nuconfigdir [] {
  $nu.config-path | goto
} 

#cores temp
export def coretemp [] {
  sensors 
  | grep Core
  | detect columns --no-headers  
  | reject column0 column3 
  | rename core temp
}

#battery stats
export def batstat [] {
  upower -i /org/freedesktop/UPower/devices/battery_BAT0 
  | lines 
  | find state & time & percentage 
  | str trim
  | split column ":" 
  | transpose -r -d 
  | str trim
}

#listen ports
export def listen-ports [] {
  sudo netstat -tunlp | detect columns
}

#ram info
export def ram [] {
  free -h
  | str replace ":" "" -a
  | from ssv 
  | rename type total used free 
  | select type used free total
}

#yewtube
export def ytcli [] {
  yt set show_video True, set fullscreen False, set search_music False, set player mpv, set notifier notify-send, set order date, set user_order date, set playerargs default, set video_format webm, set ddir /home/kira/Yandex.Disk/mps, userpl kurokirasama
}

#adbtasker
export def adbtasker [] {
  adb -s ojprnfson7izpjkv tcpip 5555
  # adb shell pm grant com.fb.fluid android.permission.WRITE_SECURE_SETTINGS
}

#open gmail client (cmdg)
export def --env gmail [] {
  cd $env.MY_ENV_VARS.download_dir
  cmdg -shell "/home/kira/.cargo/bin/nu"
}

#wrapper for mermaid diagrams
#
#Usage:
#   m -i file.mmd --other_mmcd_options -o pdf/png/svg
export def --wrapped m [
  ...rest #arguments for mmcd
  --output_format(-o):string = "pdf" #png, svg or pdf
] {
  let output = ($rest | str join "::" | split row '-i::' | get 1 | split row '::' | first | path parse | get stem) + "." + $output_format

  let pdfit = if $output_format == "pdf" {"--pdfFit"} else {[]}
  let rest = $rest ++ $pdfit
  mmdc -p $env.MY_ENV_VARS.mermaid_puppetter_config ...$rest -o $output -b transparent
}