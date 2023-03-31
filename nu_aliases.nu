export alias dsitcl = bash -c 'docker run --rm -it -v "/home/kira/Dropbox/Documentos/Clases/UBB/DataScienceAtTheCommandLine/Files/data":/data datasciencetoolbox/dsatcl2e'
export alias s = subl
export alias install-nu-plugin = cargo install --path .
export alias nu-clean = cargo clean
export alias get-keybindings = $env.config.keybindings
export alias goto-nuconfigdir = ($nu.config-path | goto)
export alias open-config = subl $nu.config-path
export old-alias tree = tree -h
export old-alias grp = grep-nu
export old-alias cal = cal --week-start monday
export alias adbtasker = adb -s 9cdd570d tcpip 5555
export alias gmail = cmdg -shell "/home/kira/.cargo/bin/nu"
export alias wsp = whatscli
export alias ssh-amara = ssh -X amara@192.168.0.31 -p 5699
export alias ssh-ies = ssh -X ing_estadistica@146.83.193.197 -p 22
export alias mount-ubb = google-drive-ocamlfuse ~/gdrive/
export alias mount-kira = google-drive-ocamlfuse -label kurokirasama ~/gdrive/
export alias mount-lmgg = google-drive-ocamlfuse -label lmgg ~/gdrive/
export alias mount-amara = google-drive-ocamlfuse -label amara ~/gdrive/
export alias mount-onedrive = onedrive-fuse mount ~/onedrive
export alias um-gdrive = fusermount -u ~/gdrive
export alias um-odrive = fusermount -u ~/onedrive
export alias png = ping -c 4 -w 4 -q 1.1.1.1
export alias netspeed = nload -u H -U H wlp2s0
export alias cputemp = tlp-stat -t
export alias coretemp = (sensors | grep Core)
export alias batstat = (upower -i /org/freedesktop/UPower/devices/battery_BAT0 | grep -E "state|time|percentage")
export alias copy = xclip -sel clip
export alias takephoto = ffmpeg -y -f video4linux2 -s 1280x720 -i /dev/video0 -ss 0:0:2 -frames 1 /home/kira/photo.jpg
export alias print-list = lpstat -R
export alias listen-ports = (sudo netstat -tunlp | detect columns)
export alias cable-ubb = nmcli con up "Cable UBB"
export alias mpydf = pydf /media/kira/*
export old-alias bat = bat --paging never --theme=ansi
export old-alias tokei = (tokei . | grep -v = | from tsv)
export alias apagar = systemctl poweroff -i
export alias reiniciar = systemctl reboot -i
export alias get-mac = open /sys/class/net/wlo1/address
export alias cblue = (echo "connect 34:82:C5:47:E3:3B" | bluetoothctl)
export alias ram = (free -h  | from ssv | rename type total used free | select type used free total)
export alias get-wg = xdotool selectwindow getwindowgeometry
export old-alias ncdu = ncdu --color dark
export alias ytcli = yt set show_video True, set fullscreen False, set search_music False, set player mpv, set notifier notify-send, set order date, set user_order date, set playerargs "default"
export alias btop = btm --battery --hide_avg_cpu --group
export alias mute = amixer -q -D pulse sset Master mute
export alias unmute = amixer -q -D pulse sset Master unmute
export alias max-vol = amixer -D pulse sset Master Playback 65536
export alias "math mean" = math avg
export alias "math std" = math stddev
export alias pi = (math pi )
export alias e = (math e)
export alias tau = (math tau)
export alias gamma = 0.5772156649015328
export alias phi = 1.6180339887498948 

# export alias hangouts = hangups --col-scheme solarized-dark
# export alias myoctave = (octave --no-gui -q 2>/dev/null)
# export alias ln = (ls --du | sort-by -i name)
# export alias lt = (ln | sort-by modified)
# export alias lx = (ln | sort-by type)
# export alias getlist = (ls **/*| where type == file)
# export alias getdirs = (ls | where type == dir)
# export alias grp-a = grep-anime
# export alias grp-s = grep-series
# export alias grp-m = grep-manga

#get max value with amixer -D pulse sget Master