#transmission wrapper
export def "t help" [] {
  try { rich rule "Transmission CLI Commands" --style "bold cyan" } catch { print "transmission-daemon wrapper\n" }
  let commands = [
    { name: "t start", description: "Start transmission daemon service" },
    { name: "t stop", description: "Stop transmission daemon service" },
    { name: "t reload", description: "Reload transmission daemon service" },
    { name: "t list", description: "List all active/idle torrents with status" },
    { name: "t basic-stats", description: "Show basic transmission statistics in panel" },
    { name: "t full-stats", description: "Show comprehensive transmission statistics" },
    { name: "t ui", description: "Open tremc TUI client" },
    { name: "t add", description: "Add magnet URL or torrent file to queue" },
    { name: "t add-from-file", description: "Add torrent file directly" },
    { name: "t info", description: "Show detailed info for a specific torrent" },
    { name: "t remove", description: "Remove a torrent from transmission" },
    { name: "t remove-delete", description: "Remove a torrent and delete downloaded data" },
    { name: "t remove-done", description: "Remove all finished torrents" },
    { name: "t start-all-torrents", description: "Start all torrent transfers" },
    { name: "t stop-all-torrents", description: "Stop all torrent transfers" },
  ]
  for cmd in $commands {
      let padded = $cmd.name | fill -w 22 -a left
      try {
          rich print $"  [bold cyan]($padded)[/] [dim]#[/] ($cmd.description)"
      } catch {
          print $"  ($padded)  # ($cmd.description)"
      }
  }
}

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
  transmission-remote -n 'transmission:transmission' -l 
  | from ssv 
  | default-table 
  | drop
  | reject Ratio
  | update Have {|c| try {$c.Have | into filesize} catch {$c.Have}}
  | update Status {|c|
  		match $c.Status {
  			"Stopped" => {$"(ansi red)($c.Status)(ansi reset)"},
  			"Downloading" => {$"(ansi green)($c.Status)(ansi reset)"},
  			"Seeding" => {$"(ansi cyan)($c.Status)(ansi reset)"},
  			"Paused" => {$"(ansi orange)($c.Status)(ansi reset)"},
  			"Queued" => {$"(ansi yellow)($c.Status)(ansi reset)"},
  			"Idle" => {$"(ansi blue)($c.Status)(ansi reset)"},
  			_ => {$c.Status},
  		}
    }
  | update Up {|c| $c.Up | into float}
  | update Down {|c| $c.Down | into float}
  | update Up {|c|
  		if $c.Up > 0 {
 			$"(ansi cyan)($c.Up)(ansi reset)"
  		} else {
  			$c.Up | into string --decimals 1
  		}
    }
  | update Down {|c|
 		if $c.Down > 0 {
 			$"(ansi green)($c.Down)(ansi reset)"
 		} else {
 			$c.Down | into string --decimals 1
 		}
    }
  | update Name {|c| 
  		if ($c.Name | path parse | get extension | is-empty) {
  			$"(ansi blue_bold)($c.Name)(ansi reset)"
  		} else if ($c.Name | path parse | get extension) in ["mp4", "mkv", "mp3", "avi", "mov", "webm", "flv", "png", "jpg", "jpeg", "gif"] {
  			$"(ansi purple_bold)($c.Name)(ansi reset)"
  		} else {
  			$"(ansi white_bold)($c.Name)(ansi reset)"
  		}
    }
}

#transmission basic stats
export def "t basic-stats" [] {
  let stats_text = (do { transmission-remote -n 'transmission:transmission' -st } | complete).stdout
  try {
    $stats_text | str trim | rich panel --title "Transmission Basic Stats" --box rounded --border-style cyan
  } catch {
    transmission-remote -n 'transmission:transmission' -st
  }
}

#transmission full stats
export def "t full-stats" [] {
  let stats_text = (do { transmission-remote -n 'transmission:transmission' -si } | complete).stdout
  try {
    $stats_text | str trim | rich panel --title "Transmission Full Stats" --box rounded --border-style cyan
  } catch {
    transmission-remote -n 'transmission:transmission' -si
  }
}

#open transmission tui
export def "t ui" [] {
  let ip = get-ips | get internal
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
  id:int  #id of the torrent to http get
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
#Examples
#t-removedelete 2 3 6 9
#t list | some filter | t-removedelete
export def "t remove-delete" [
  ...ids    #list of ids or table
] {
  let t = $in
  if ($ids | is-empty) {
    $t
    | each {|id| 
        transmission-remote -t ($id.ID | str replace "*" "") -n 'transmission:transmission' -rad
      }
  } else {
    $ids 
    | each {|id| 
        transmission-remote -t ($id | str replace "*" "") -n 'transmission:transmission' -rad
      }
  }
}

#delete finished torrent from download queue without deleting files
export def "t remove-done" [] {
  t list 
  | drop 1 
  | where ETA like Done 
  | where Done == "100%"
  | get ID 
  | each {|id|
      transmission-remote  -t ($id | str replace "*" "") -n 'transmission:transmission' --remove
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