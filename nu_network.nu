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

  let current_network_name = (iwgetid -r)
  let current_network_strength = (
    nmcli -t -f ssid,signal,rate,in-use dev wifi list 
    | lines 
    | find "*" 
    | get 0 
    | split row : 
    | get 1
    | into int
  )

  echo-g $"current net: ($current_network_name), strength: ($current_network_strength)"

  let network_list = (
    nmcli -t -f ssid,signal,rate,in-use dev wifi list 
    | lines 
    | find -v $"($current_network_name):" 
    | parse "{name}:{signal}:{speed}" 
    | sort-by -r signal
    | str trim
  )

  let number_nets = ($network_list | length)

  echo-g "checking each network..."

  for i in 0..($number_nets - 1) {
    let net = ($network_list | get $i)
    echo $"net: ($net.name), strength: ($net.signal)"
    if ($net.name == "") {continue}

    if ($net.name) in ($known_networks_info | get known_networks) {
      if ($net.signal | into int) >= ($current_network_strength + $threshold) {
        let notification = $"Switching to network ($net.name) that has a better signal \(($net.signal) > (($current_network_strength) + ($threshold))\)"
        echo-g $notification
        notify-send $notification
        sudo nmcli device wifi connect $net.name
        return
      } else {
        let notification = $"Network ($net.name) is well known but its signal's strength is not worth switching"
        echo-g $notification
        notify-send $notification
      }
    }
  }
}

#wifi info
export def wifi-info [] {
  nmcli -t dev wifi 
  | lines 
  | str replace -a -s '\:' '|' 
  | str replace -a -s ':' '#' 
  | str replace -a -s '|' ':' 
  | str replace -s "*" "❱" 
  | split column '#' 
  | rename in-use mac ssid mode channel rate signal bars security
  | each {|row|
      if ($row | get in-use) == "❱" {
        $row 
        | update cells {|value| 
            [(ansi -e { fg: '#00ff00' attr: b }) $value] | str collect 
          }
      } else {
        $row
      }
    }
  | flatten
  | reject in-use
}

#list used network sockets
export def ls-ports [] {
  let input = (^lsof +c 0xFFFF -i -n -P)
  
  let header = (
    $input 
    | lines
    | take 1
    | each { 
        str downcase 
        | str replace ' name$' ' name state'
      }
  )

  let body = (
    $input 
    | lines
    | skip 1
    | each { 
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
  | rename -c ['name' 'connection']
  | reject 'command'
  | into df
  | join (ps -l | into df) 'pid' 'pid'
  | into df
  | into nu
}

#get ips
export def get-ips [
  device =  "wlo1"  #wlo1 for wifi (export default), eno1 for lan
] {
  let internal = (ip -json add 
    | from json 
    | where ifname =~ $"($device)" 
    | select addr_info 
    | flatten | find -v inet6 
    | flatten 
    | get local 
    | get 0
  )

  let external = (dig +short myip.opendns.com @resolver1.opendns.com)
  
  {internal: $internal, external: $external}
}

#get devices connected to network
export def get-devices [
  device = "wlo1" #wlo1 for wifi (export default), eno1 for lan
  #
  #It needs nmap2json, installable (ubuntu at least) via
  #
  #sudo gem install nmap2json
] {
  let ipinfo = (
    if (? | where name == pnet | length) > 0 {
      pnet 
      | where name == ($device) 
      | get 0 
      | get ips 
      | where type == v4 
      | get 0 
      | get addr
      | str replace '(?P<nums>\d+/)' '0/'
    } else {
      ip -json add 
      | from json 
      | where ifname =~ $"($device)" 
      | select addr_info 
      | flatten 
      | find -v inet6 
      | flatten 
      | get local prefixlen 
      | flatten 
      | str collect '/' 
      | str replace '(?P<nums>\d+/)' '0/'
    }
  )

  let nmap_output = (sudo nmap -oX nmap.xml -sn $ipinfo --max-parallelism 10)

  let nmap_output = (nmap2json convert nmap.xml | from json | get nmaprun | get host | get address)

  let this_ip = ($nmap_output | last | get addr)

  let ips = ($nmap_output 
    | drop 1 
    | flatten 
    | where addrtype =~ ipv4 
    | select addr 
    | rename ip
  )
  
  let macs_n_names = (
    $nmap_output 
    | flatten 
    | where addrtype =~ mac  
    | reject addrtype 
    | rename mac name 
  )

  let macs_n_names = (
    $macs_n_names
    | select mac
    | into df 
    | append (
        $macs_n_names 
        | get name 
        | wrap name 
        | into df 
      )
    | into nu
  )

  let devices = ( $ips | merge $macs_n_names )

  let known_devices = open ([$env.MY_ENV_VARS.linux_backup "known_devices.csv"] | path join)
  let known_macs = ($known_devices | get mac | str upcase)

  let known = ($devices | each {|it| $it.mac in $known_macs} | wrap known)

  let devices = ($devices | merge $known)

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