#!/usr/bin/env nu

export def main [
  input_host:string
  device?  #wlo1 for wifi (export default), eno1 for lan
] {
  let host = (sys host | get hostname)
  
  let device = (
    if ($device | is-empty) {
      if $host in ["lgomez-desktop" "lgomez-server"] {
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
    | where ifname =~ $"($device)" 
    | select addr_info 
    | flatten 
    | find -v inet6 
    | flatten 
    | get local 
    | get 0
  )

  let external = (dig +short myip.opendns.com @resolver1.opendns.com)
  
  return ({internal: $internal, external: $external} | to json)
}