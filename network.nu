#network switcher 
export def network-switcher [] {
  let threshold = 10

  try {nmcli -t -f ssid,signal,rate,in-use dev wifi rescan}

  let known_networks_info = (
    nmcli -m tabular -f name connection show 
    | lines 
    | str trim 
    | find -v NAME 
    | wrap known_networks
  )

  let current_network_name = wifi-info -w
  let current_network_strength = (
    nmcli -t -f ssid,signal,rate,in-use dev wifi list 
    | lines 
    | find "*" 
    | get 0 
    | split row : 
    | get 1
    | into int
  )

  print (echo-g $"current net: ($current_network_name), strength: ($current_network_strength)")

  let network_list = (
    nmcli -t -f ssid,signal,rate,in-use dev wifi list 
    | lines 
    | find -v $"($current_network_name):" 
    | parse "{name}:{signal}:{speed}" 
    | sort-by -r signal
    | str trim
  )

  let number_nets = $network_list | length

  print (echo-g "checking each network...")

  for i in 0..($number_nets - 1) {
    let net = $network_list | get $i
    print (echo $"net: ($net.name), strength: ($net.signal)")
    if $net.name == "" {continue}

    if $net.name in ($known_networks_info | get known_networks) {
      if ($net.signal | into int) >= ($current_network_strength + $threshold) {
        let notification = $"Switching to network ($net.name) that has a better signal \(($net.signal) > (($current_network_strength) + ($threshold))\)"
        print (echo-g $notification)
        notify-send $notification
        sudo nmcli device wifi connect $net.name
        return
      } 
      let notification = $"Network ($net.name) is well known but its signal's strength is not worth switching"
      print (echo-g $notification)
      notify-send $notification
    }
  }
}

#wifi info
export def wifi-info [
  --wifi_id(-w)
] {
  let info = (
    nmcli -t dev wifi 
    | lines 
    | str replace -a '\:' '|' 
    | str replace -a ':' '#' 
    | str replace -a '|' ':' 
    | str replace "*" "❱" 
    | split column '#' 
    | rename in-use mac ssid mode channel rate signal bars security
    | indexify
  )

  if ($info | is-empty) {
    return "no wifi connected!"
  }

  let the_row = $info | where in-use == "❱"
  let the_row_index = $the_row | get index.0
  let the_row = $the_row | update cells {|value| 
              [(ansi -e { fg: '#00ff00' attr: b }) $value] | str join 
            }

  if $wifi_id {
    return ($the_row | get ssid.0? | ansi strip)
  } 
  return ($info | reject $the_row_index | append $the_row | sort-by rate | reject in-use)
}

#list used network sockets
export def ls-ports [] {
  let input = ^lsof +c 0xFFFF -i -n -P
  
  let header = (
    $input 
    | lines
    | take 1
    | each {||
        str downcase 
        | str replace ' name$' ' name state'
      }
  )

  let body = (
    $input 
    | lines
    | skip 1
    | each {|| 
        str replace '([^)])$' '$1 (NONE)' 
        | str replace ' \((.+)\)$' ' $1'
      }
  )
  
  [$header] 
  | append $body
  | to text
  | detect columns
  | upsert 'pid' { |r| 
      $r.pid 
      | into int 
    }
  | rename -c {name: connection}
  | reject 'command'
  | polars into-df
  | polars join (ps -l | polars into-df) 'pid' 'pid'
  | polars into-nu
}

#get ips
export def get-ips [
  device?: string  #wlo1 for wifi (export default), eno1 for lan
] {
  let host = sys host | get hostname
  
  let device = (
    if ($device | is-empty) {
      if $host like $env.MY_ENV_VARS.hosts.2 {
        "eno1"
      } else {
        "wlo1"
      }
    } else {
      $device
    }
  )

  let internal = (ip -json add 
    | from json 
    | where ifname like $device 
    | select addr_info 
    | flatten | find -v inet6 
    | flatten 
    | get local 
    | get 0
  )

  let external = dig +short myip.opendns.com @resolver1.opendns.com
  
  return {internal: $internal, external: $external}
}

#get devices connected to network
#
#It needs nmap2json, installable (ubuntu at least) via:
#`sudo gem install nmap2json`
#
export def get-devices [] {
  let device = ip -json route get 1.1.1.1  | from json | get dev.0

  let ipinfo = ip -json add 
      | from json 
      | where ifname like $"($device)" 
      | select addr_info 
      | flatten 
      | find -v inet6 
      | flatten 
      | get local prefixlen 
      | flatten 
      | str join '/' 
      | str replace -r '(?P<nums>\d+/)' '0/'

  let nmap_output = sudo nmap -oX nmap.xml -sn $ipinfo --max-parallelism 10

  let nmap_output = nmap2json convert nmap.xml | from json | get nmaprun | get host | get address

  let this_ip = $nmap_output | last | get addr

  let ips = ($nmap_output 
    | drop 1 
    | flatten 
    | where addrtype like ipv4 
    | select addr 
    | rename ip
  )
  
  let macs_n_names = (
    $nmap_output 
    | flatten 
    | where addrtype like mac  
    | reject addrtype 
    | rename mac name 
    | default null name
  )

  let devices = $ips | merge $macs_n_names

  let known_devices = open ($env.MY_ENV_VARS.linux_backup | path join known_devices.csv)
  let known_macs = $known_devices | get mac | str upcase

  let known = $devices | each {|it| $it.mac in $known_macs} | wrap known

  let devices = $devices | merge $known

  let aliases = (
    $devices 
    | each {|row| 
        if $row.known {
          $known_devices | find $row.mac | get alias
        } else {
          " "
        }
      } 
    | flatten 
    | wrap alias
  )
   
  rm nmap.xml | ignore 

  $devices | merge $aliases
}

#get wifi pass
export def wifi-pass [] {
  sudo grep "^psk=" /etc/NetworkManager/system-connections/* 
  | lines 
  | split column system-connections/ 
  | get column2 
  | each {|row| 
      $row 
      | parse "{net}.nmconnection:psk={password}"
    } 
  | flatten
}

#show stored ips
export def show-ips [] {
  open $env.MY_ENV_VARS.ips | table -e
}

#web search in terminal
export def --wrapped gg [...search: string] {
  ddgr -n 5 ...$search
}

#check validity of a link
export def check-link [link?,timeout?:duration] {
  let link = get-input $in $link

  if ($timeout | is-empty) {
    let response = try {
      http get $link | ignore;true
    } catch {
      false
    }
    return $response
  }

  try {
    http get $link -m $timeout | ignore;true
  } catch {
    false
  }
}

#get files all at once from webpage using wget
export def wget-all [
  webpage: string    #url to scrap
  ...extensions      #list of extensions separated by space
] {
  wget -A ($extensions | str join ",") -m -p -E -k -K -np --restrict-file-names=windows $webpage
}

#qr code generator
export def qrenc [url] {
  curl $"https://qrenco.de/($url)"
}

#local http server
export def --wrapped "http server" [
  root:string =".",
  ...rest
] {
  simple-http-server $root ...$rest
}

#download file with filename
def "http download" [url:string] {
  let attachmentName  = http head $url
    | transpose -dr
    | get -o content-disposition
    | parse "attachment; filename={filename}"
    | get filename?.0?

  let filename = if ($attachmentName | is-empty) {
      # use the end of the URL path
      ($url | url parse | get path | path parse | do {$"($in.stem).($in.extension)"})
    } else {
      $attachmentName
    }

  http get --raw $url | save $filename
}
