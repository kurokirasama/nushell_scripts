# export alias hangouts = hangups --col-scheme solarized-dark
# export alias myoctave = (octave --no-gui -q 2>/dev/null)
# export alias ln = (ls --du | sort-by -i name)
# export alias lt = (ln | sort-by modified)
# export alias lx = (ln | sort-by type)
# export alias getlist = (ls **/*| where type == file)
# export alias getdirs = (ls | where type == dir)
# export alias mount-ubb = google-drive-ocamlfuse ~/gdrive/
# export alias mount-kira = google-drive-ocamlfuse -label kurokirasama ~/gdrive/
# export alias mount-lmgg = google-drive-ocamlfuse -label lmgg ~/gdrive/
# export alias mount-amara = google-drive-ocamlfuse -label amara ~/gdrive/
# export alias mount-onedrive = onedrive-fuse mount ~/onedrive -o permission.readonly=false -o vfs.file.disk_cache.max_total_size=2000000000 -o vfs.file.disk_cache.max_cached_file_size=1500000000 -o vfs.file.upload.max_size=1000000000
# export alias um-gdrive = fusermount -u ~/gdrive
# export alias um-odrive = fusermount -u ~/onedrive
# export alias mount-kira = bash -c "rclone mount gkira: ~/rclone/gdrive &"
# export alias mount-ubb = bash -c "rclone mount gubb: ~/rclone/gdrive &"
# export alias mount-lmgg = bash -c "rclone mount glmgg: ~/rclone/gdrive &"
# export alias mount-hime = bash -c "rclone mount ghime: ~/rclone/gdrive &"
# export alias mount-onedrive = bash -c "rclone mount onedrive: ~/rclone/onedrive &"
# export alias mount-box = bash -c "rclone mount box: ~/rclone/box &"
# export alias mount-yandex = bash -c "rclone mount yandex: ~/rclone/yandex &"
# get max value with amixer -D pulse sget Master
