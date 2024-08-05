#!/usr/bin/env nu

#checking existence of data file
if not ("~/.autolister.json" | path expand | path exists) {
    cp ("~/Yandex.Disk/Backups/linux/autolister.json" | path expand) ~/.autolister.json
}

#checking conditions
let interval = 24hr 
let now = (date now)
let update = ((open ~/.autolister.json | get updated | into datetime) + $interval < $now)
let autolister_file = open ~/.autolister.json

if $update {
    if (sys host | get hostname) != "rayen" {
        ## list mounted drives and download directory
        nu ("~/Yandex.Disk/Backups/linux/my_scripts/nushell/autolister.nu" | path expand)
    }

    $autolister_file
    | upsert updated $now
    | save -f ~/.autolister.json

    ## update ip
    print (echo $"(ansi -e { fg: '#00ff00' attr: b })getting device ips...(ansi reset)")
    let host = (sys host | get hostname)
    let ips_file = "~/Yandex.Disk/Android_Devices/Apps/Termux/ips.json" | path expand
    let ips_content = open $ips_file
    let ips = (nu ("~/Yandex.Disk/Backups/linux/my_scripts/nushell/get-ips.nu" | path expand))

    $ips_content
    | upsert $host ($ips | from json)
    | save -f $ips_file
}