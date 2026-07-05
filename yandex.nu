#yandex-disk wrappers
export def ydx [] {
  print ([
    "yandex-disk wrapper."
      "METHODS:"
      "- ydx status"
      "- ydx start"
      "- ydx stop"
      "- ydx restart"
      "- ydx help"
      "- ydx last"
      "- ydx trash list"
      "- ydx trash empty"
      "- ydx trash restore"
      "- ydx trash delete"
      "- ydx get-link"
    ]
    | str join "\n"
  )
}

#yandex-disk status
export def "ydx status" [] {
    let result = yandex-disk status | complete
    
    if $result.exit_code != 0 {
        # Daemon is not running or unreachable
        let clean_stderr = $result.stderr | str trim
        return [[item status]; ["Daemon status" $clean_stderr]]
    }
    
    $result.stdout
        | lines
        | where ($it | str contains "Sync") or ($it | str contains "Total") or ($it | str contains "Used") or ($it | str contains "Trash")
        | split column ':'
        | str trim
        | rename item status
}

#yandex-disk start with OOM protection
export def "ydx start" [] {
    let result = ^~/Yandex.Disk/my_scripts/bash_for_nushell/start-yandex-disk | complete

    if $result.exit_code != 0 {
        return-error $"ydx start failed: ($result.stderr | str trim)"
    }

    if "Already running" in $result.stdout {
        return $result.stdout | str trim
    }

    $result.stdout
        | lines
        | skip while {|x| not ($x | str contains "─── Status")}
        | skip 1
        | take while {|x| not ($x | str contains "───")}
        | each {|x| $x | str replace -r '^\[start-yandex-disk\]\s+' '' | str trim}
        | parse "{item} : {status}"
}

#yandex-disk stop
export def "ydx stop" [] {
	yandex-disk stop
}

#yandex-disk restart (stop, wait 1s, then start with OOM protection)
export def "ydx restart" [] {
    # Attempt to stop, ignore errors and suppress output
    ydx stop o+e>| ignore
    sleep 1sec
    ydx start
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
  | each {|item| 
      $item 
      | split row "file: " 
      | last 
      | str replace -a "'" ""
    }
}

# List contents of Yandex.Disk Trash
export def "ydx trash list" [
    path: string = "/" # Path in trash (root by default)
    --limit: int = 20 # Max items to return
] {
    let response = _ydx-api-request GET "/trash/resources" {
        path: $path
        limit: $limit
    }
    
    if ($response | get -o _embedded | is-empty) {
        return []
    }
    
    $response._embedded.items
    | select name type path created modified size?
}

# Empty Yandex.Disk Trash
export def "ydx trash empty" [] {
    _ydx-api-request DELETE "/trash/resources"
    print (echo-g "Trash emptied successfully.")
}

# Restore a resource from Trash
export def "ydx trash restore" [
    path?: any # Path to the resource in Trash (can be passed via pipeline)
    --name: string # New name for the restored resource
    --overwrite # Whether to overwrite if the destination path already exists
] {
    let input = get-input $in $path
    let items = if ($input | describe | str starts-with "list") { $input } else { [$input] }

    for item in $items {
        if ($item | is-empty) { continue }
        
        let resource_path = if ($item | describe | str starts-with "record") { $item.path } else { $item }
        let cloud_path = _ydx-resolve-path $resource_path
        
        mut params = {
            path: $cloud_path
            overwrite: $overwrite
        }
        
        if ($name | is-not-empty) { $params = ($params | insert name $name) }
        
        _ydx-api-request POST "/trash/resources/restore" $params
        print (echo-g $"Resource '($cloud_path)' restored successfully.")
    }
}

# Delete a resource permanently from Trash
export def "ydx trash delete" [
    path?: any # Path to the resource in Trash (can be passed via pipeline)
] {
    let input = get-input $in $path
    let items = if ($input | describe | str starts-with "list") { $input } else { [$input] }

    for item in $items {
        if ($item | is-empty) { continue }
        
        let resource_path = if ($item | describe | str starts-with "record") { $item.path } else { $item }
        let cloud_path = _ydx-resolve-path $resource_path
        
        _ydx-api-request DELETE "/trash/resources" {
            path: $cloud_path
        }
        print (echo-g $"Resource '($cloud_path)' permanently deleted.")
    }
}

# Get a temporary direct download link for a file
export def "ydx get-link" [
    path?: any # Path to the file on Yandex.Disk (can be passed via pipeline)
    --copy(-c) # Copy the link to the system clipboard
    --open(-o) # Open the link in the default web browser
] {
    let input = get-input $in $path
    let items = if ($input | describe | str starts-with "list") { $input } else { [$input] }

    mut results = []

    for item in $items {
        if ($item | is-empty) { continue }
        
        let resource_path = if ($item | describe | str starts-with "record") { $item.path } else { $item }
        let cloud_path = _ydx-resolve-path $resource_path
        
        let response = _ydx-api-request GET "/resources/download" {
            path: $cloud_path
        }
        
        let link = $response | get -o href
        
        if ($link | is-not-empty) {
            $results = ($results | append $link)
            
            if $copy { $link | copy }
            if $open { open $link }
        } else {
            print (echo-r $"Failed to get link for '($resource_path)'.")
        }
    }

    if ($results | length) == 1 {
        $results | first
    } else {
        $results
    }
}

# Private helper for Yandex.Disk API requests
def _ydx-api-request [
    method: string
    path: string
    params: record = {}
    body: any = null
] {
    let token = get-api-key "yandex_disk"
    
    let url = {
        scheme: "https"
        host: "cloud-api.yandex.net"
        path: $"/v1/disk($path)"
        params: $params
    } | url join
    
    let headers = {
        Authorization: $"OAuth ($token)"
        Accept: "application/json"
    }
    
    match ($method | str uppercase) {
        "GET" => { http get $url -H $headers }
        "POST" => { http post $url "{}" -H $headers }
        "DELETE" => { http delete $url -H $headers }
        _ => { return-error $"Unsupported method: ($method)" }
    }
}

# Resolve a local absolute path to a Yandex.Disk cloud-relative path
def _ydx-resolve-path [path: string] {
    if ($path | str starts-with "disk:/") or ($path | str starts-with "trash:/") {
        return $path
    }

    let expanded = $path | path expand
    let root = $env.MY_ENV_VARS.base_yandex
    
    let resolved = (try {
        let relative = $expanded | path relative-to $root
        $"(/$relative)"
    } catch {
        $path
    })
    
    # print (echo-y $"[ydx] Resolved '($path)' to cloud path '($resolved)'")
    $resolved
}

#resume yandex service
export def "ydx resume" [] {
    systemctl --user restart yandex-disk
}
