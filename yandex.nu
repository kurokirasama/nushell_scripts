#yandex-disk wrappers
export def ydx [] {
  print ([
    "yandex-disk wrapper."
      "METHODS:"
      "- ydx status"
      "- ydx start"
      "- ydx stop"
      "- ydx help"
      "- ydx last"
    ]
    | str join "\n"
  )
}

#yandex-disk status
export def "ydx status" [] {
	yandex-disk status 
	| grep -E "Sync|Total|Used|Trash" 
	| lines 
	| split column ':' 
	| str trim 
	| rename item status
}

#yandex-disk start
export def "ydx start" [] {
	yandex-disk start
}

#yandex-disk stop
export def "ydx stop" [] {
	yandex-disk stop
}

#yandex-disk help
export def "ydx help" [] {
	yandex-disk --help
}

#yandex disk last synchronized items
export def "ydx last" [] {
  yandex-disk status 
  | split row "Last synchronized items:" 
  | last 
  | str trim 
  | lines 
  | str trim 
  | each {|it| 
      $it 
      | split row "file: " 
      | last 
      | str replace -a "'" ""
    }
}