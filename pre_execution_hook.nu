#!/usr/bin/env nu

#checking existence of data file
if not ("~/.autolister.json" | path expand | path exists) {
    cp /home/kira/Yandex.Disk/Backups/linux/autolister.json ~/.autolister.json
}

#checking conditions
let interval = 24hr 
let now = (date now)
let update = ((open ~/.autolister.json | get updated | into datetime) + $interval < $now)
let autolister_file = open ~/.autolister.json

if $update {
    ## list mounted drives and download directory
    nu /home/kira/Yandex.Disk/Backups/linux/nu_scripts/autolister.nu 

    ## update ip
    print (echo $"(ansi -e { fg: '#00ff00' attr: b })getting device ips...(ansi reset)")
    let host = (sys host | get hostname)
    let ips_file = "/home/kira/Yandex.Disk/Android_Devices/Apps/Termux/ips.json"
    let ips_content = open $ips_file
    let ips = (nu /home/kira/Yandex.Disk/Backups/linux/nu_scripts/get-ips.nu (open ~/.host_work))

    $ips_content
    | upsert $host ($ips | from json)
    | save -f $ips_file

    $autolister_file
    | upsert updated $now
    | save -f ~/.autolister.json
}