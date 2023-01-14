#transmission wrapper
export def t [] {}

#transmission start
export def "t start" [] {
  sudo service transmission-daemon start
}

#transmission stop
export def "t stop" [] {
  sudo service transmission-daemon stop
}

#transmission reload
export def "t reload" [] {
  sudo service transmission-daemon reload
}

#transmission list
export def "t list" [] {
  transmission-remote -n 'transmission:transmission' -l | from ssv | default table
}

#transmission basic stats
export def "t basic-stats" [] {
  transmission-remote -n 'transmission:transmission' -st
}

#transmission full stats
export def "t full-stats" [] {
  transmission-remote -n 'transmission:transmission' -si
}

#open transmission tui
export def "t ui" [] {
  let ip = (get-ips | get internal)
  tremc -c $"transmission:transmission@($ip):9091"
}

#add file to transmission download queue
export def "t add" [
  down  #magnetic link or torrent file
] {
  transmission-remote -n 'transmission:transmission' -a $down
}

#add magnetic links from file to transmission download queue
export def "t add-from-file" [
  file  #text file with 1 magnetic link per line
] {
  open $file 
  | lines 
  | each {|link|
      transmission-remote -n 'transmission:transmission' -a $link
    }
}

#get info of a torrent download 
export def "t info" [
  id:int  #id of the torrent to fetch
] {
  transmission-remote -t $id -n 'transmission:transmission' -i
}

#delete torrent from download queue without deleting files
export def "t remove" [
  ...ids    #list of ids
] {
  $ids 
  | each {|id| 
      transmission-remote -t $id -n 'transmission:transmission' --remove
    }
}

#delete torrent from download queue deleting files
export def "t remove-delete" [
  ...ids    #list of ids
  #Examples
  #t-removedelete 2 3 6 9
  #t list | some filter | t-removedelete
] {
  if ($ids | is-empty) {
    $in
    | find -v "Sum:"
    | get ID 
    | each {|id| 
        transmission-remote -t $id -n 'transmission:transmission' -rad
      }
  } else {
    $ids 
    | each {|id| 
        transmission-remote -t $id -n 'transmission:transmission' -rad
      }
  }
}

#delete finished torrent from download queue without deleting files
export def "t remove-done" [] {
  t list 
  | drop 1 
  | where ETA =~ Done 
  | where Done == "100%"
  | get ID 
  | each {|id|
      transmission-remote  -t $id -n 'transmission:transmission' --remove
    } 
}

#delete torrent from download queue that match a search without deleting files
export def "t remove-name" [
  search  #search term
] {
  t list 
  | drop 1 
  | find -i $search 
  | get ID 
  | each {|id|
      transmission-remote  -t $id -n 'transmission:transmission' --remove
    } 
}

#start a torrent from download queue
export def "t start-torrent" [
  id:int  #torrent id
] {
  transmission-remote -t $id -n 'transmission:transmission' -s
}

#start all torrents
export def "t start-all-torrents" [] {
  t list 
  | drop 1 
  | get ID 
  | each {|id|
      transmission-remote -t $id -n 'transmission:transmission' -s
    }
}

#stop a torrent from download queue
export def "t stop-torrent" [
  id:int  #torrent id
] {
  transmission-remote -t $id -n 'transmission:transmission' -S
}

#stop all torrents
export def "t stop-all-torrents" [] {
  t list 
  | drop 1 
  | get ID 
  | each {|id|
      transmission-remote -t $id -n 'transmission:transmission' -S
    }
}