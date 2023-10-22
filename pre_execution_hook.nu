#!/usr/bin/env nu

## list mounted drives and download directory
#checking existence of data file
if not ("~/.autolister.json" | path expand | path exists) {
    cp /home/kira/Yandex.Disk/Backups/linux/autolister.json ~/.autolister.json
}

#checking conditions
let interval = 24hr 
let now = (date now)
let update = ((open ~/.autolister.json | get updated | into datetime) + $interval < $now)

if $update {
    nu /home/kira/Yandex.Disk/Backups/linux/nu_scripts/autolister.nu 
    open ~/.autolister.json
    | upsert updated $now
    | save -f ~/.autolister.json
}

## update ip
if $update {
    print (echo $"(ansi -e { fg: '#00ff00' attr: b })getting device ips...(ansi reset)")
    let host = (sys | get host | get hostname)
    let ips_file = "/home/kira/Yandex.Disk/Android Devices/Apps/Termux/ips.json"
    let ips = (nu /home/kira/Yandex.Disk/Backups/linux/nu_scripts/get-ips.nu)

    open $ips_file
    | upsert $host ($ips | from json)
    | save -f $ips_file
}