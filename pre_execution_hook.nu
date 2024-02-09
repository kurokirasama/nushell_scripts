#!/usr/bin/env nu

#checking existence of data file
if not ("~/.autolister.json" | path expand | path exists) {
    cp /home/kira/Yandex.Disk/Backups/linux/autolister.json ~/.autolister.json
}

#checking conditions
let interval = 24hr 
let now = (date now)
let update = ((open ~/.autolister.json | get updated | into datetime) + $interval < $now)

if $update {
    ## list mounted drives and download directory
    nu /home/kira/Yandex.Disk/Backups/linux/nu_scripts/autolister.nu 

    ## update ip
    print (echo $"(ansi -e { fg: '#00ff00' attr: b })getting device ips...(ansi reset)")
    let host = (sys | get host | get hostname)
    let ips_file = "/home/kira/Yandex.Disk/Android_Devices/Apps/Termux/ips.json"
    let ips = (nu /home/kira/Yandex.Disk/Backups/linux/nu_scripts/get-ips.nu (open ~/.host_work))

    open $ips_file
    | upsert $host ($ips | from json)
    | save -f $ips_file

    open ~/.autolister.json
    | upsert updated $now
    | save -f ~/.autolister.json
}