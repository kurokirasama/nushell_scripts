#!/usr/bin/env nu

export def main [
  ...hosts #list of hosts
] {
    let host = sys host | get hostname
      
    let device = if ($host like $hosts.2) or ($host like $hosts.8) {
          sys net | where name =~ '^en' | get name.0
        } else {
          sys net | where name =~ '^wl' | get name.0
        }
    
    let internal = ip -json add 
      | from json 
      | where ifname like $device 
      | select addr_info 
      | flatten | find -v inet6 
      | flatten 
      | get local 
      | get 0

    let external = dig +short myip.opendns.com @resolver1.opendns.com
    
    return {internal: $internal, external: $external}
}
