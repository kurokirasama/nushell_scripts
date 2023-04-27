#tokei wrapper
export def tokei [] {
  ^tokei | grep -v = | from tsv
}

#keybindings
export def get-keybindings [] {
  $env.config.keybindings
}

#go to nu config dir
export def-env goto-nuconfigdir [] {
  $nu.config-path | goto
} 

#cores temp
export def coretemp [] {
  sensors | grep Core
}

#battery stats
export def batstat [] {
  upower -i /org/freedesktop/UPower/devices/battery_BAT0 | grep -E "state|time|percentage"
}

#listen ports
export def listen-ports [] {
  sudo netstat -tunlp | detect columns
}

#connect bluetooth headset
export def cblue [] {
  echo "connect 34:82:C5:47:E3:3B" | bluetoothctl
}

#ram info
export def ram [] {
  free -h  | from ssv | rename type total used free | select type used free total
}
