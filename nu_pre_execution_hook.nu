#!/usr/bin/env nu

#checking existence of data file
if not ("~/.autolister.json" | path expand | path exists) {
    cp /home/kira/Yandex.Disk/Backups/linux/autolister.json ~/.autolister.json
}

#checking conditions
let interval = 24hr 
let now = date now
let update = ((open ~/.autolister.json | get updated | into datetime) + $interval < $now)

if $update {
    nu /home/kira/Yandex.Disk/Backups/linux/nu_scripts/autolister.nu 
    open ~/.autolister.json
    | upsert updated $now
    | save -f ~/.autolister.json
}