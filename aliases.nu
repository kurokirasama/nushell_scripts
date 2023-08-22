export alias ncdu = ncdu --color dark
export alias tree = tree -h
export alias grp = grep-nu
export alias cal = cal --week-start monday
export alias bat = bat --paging=never --theme=ansi
export alias dsitcl = bash -c 'docker run --rm -it -v "/home/kira/Dropbox/Documentos/Clases/UBB/DataScienceAtTheCommandLine/Files/data":/data datasciencetoolbox/dsatcl2e'
export alias s = subl
export alias install-nu-plugin = cargo install --path .
export alias nu-clean = cargo clean
export alias open-config = subl $nu.config-path
export alias gmail = cmdg -shell "/home/kira/.cargo/bin/nu"
export alias wsp = whatscli
export alias ssh-amara = ssh -X amara@192.168.0.31 -p 5699
export alias ssh-ies = ssh -X ing_estadistica@146.83.193.197 -p 22
export alias mount-ubb = google-drive-ocamlfuse ~/gdrive/
export alias mount-kira = google-drive-ocamlfuse -label kurokirasama ~/gdrive/
export alias mount-lmgg = google-drive-ocamlfuse -label lmgg ~/gdrive/
export alias mount-amara = google-drive-ocamlfuse -label amara ~/gdrive/
export alias mount-onedrive = onedrive-fuse mount ~/onedrive -o permission.readonly=false -o vfs.file.disk_cache.max_total_size=2000000000 -o vfs.file.disk_cache.max_cached_file_size=1500000000 -o vfs.file.upload.max_size=1000000000
export alias um-gdrive = fusermount -u ~/gdrive
export alias um-odrive = fusermount -u ~/onedrive
export alias png = ping -c 4 -w 4 -q 1.1.1.1
export alias netspeed = nload -u H -U H wlp2s0
export alias cputemp = tlp-stat -t
export alias copy = xclip -sel clip
export alias takephoto = ffmpeg -y -f video4linux2 -s 1280x720 -i /dev/video0 -ss 0:0:2 -frames 1 /home/kira/photo.jpg
export alias print-list = lpstat -R
export alias cable-ubb = nmcli con up "Cable UBB"
export alias mpydf = pydf /media/kira/*
export alias apagar = systemctl poweroff -i
export alias reiniciar = systemctl reboot -i
export alias get-mac = open /sys/class/net/wlo1/address
export alias get-wg = xdotool selectwindow getwindowgeometry
export alias btop = btm --battery --hide_avg_cpu --group
export alias mute = amixer -q -D pulse sset Master mute
export alias unmute = amixer -q -D pulse sset Master unmute
export alias max-vol = amixer -D pulse sset Master Playback 65536
export alias "math mean" = math avg
export alias "math std" = math stddev

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