#!/usr/bin/env nu

export def main [] {
  let mounted = sys disks | get mount | find -n rclone
  
  if ($mounted | length) == 0 {
    return "no mounted storages!"
  }

  $mounted
  | each {|drive|
      fusermount -u $drive
      sleep 1sec
    }
}