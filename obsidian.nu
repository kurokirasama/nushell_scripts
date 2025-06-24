#check obsidian server
@category apis
@search-terms obsidian
export def "obs check" [] {
  let apikey = $env.MY_ENV_VARS.api_keys.obsidian.local_rest_apikey
  let host = $env.MY_ENV_VARS.api_keys.obsidian.host
  let port = $env.MY_ENV_VARS.api_keys.obsidian.port
  let certificate = $env.MY_ENV_VARS.api_keys.obsidian.certificate

  let url = {
              "scheme": "http",
              "host": $host,
              "port": $port
            } | url join

  let status = curl -s -X 'GET' $url -H 'accept: application/json' -H $'Authorization: Bearer ($apikey)' --cacert $certificate | from json | get status 

  return {status: $status, apikey: $apikey, host: $host, port: $port, certificate: $certificate}
}

#check obsidian path
@category apis
@search-terms obsidian
export def "obs check-path" [
  v_path:string # path in vault
] {
  let check = obs check

  if $check.status != "OK" {
    return-error "something went wrong with the server!"
  }

  let apikey = $check.apikey
  let host = $check.host
  let port = $check.port
  let certificate = $check.certificate
  let auth_header = $'Authorization: Bearer ($apikey)'

  let url = {
              "scheme": "http",
              "host": $host,
              "port": $port ,
              "path": (["vault" $v_path] | path join)
            } | url join

  let response = curl -sX 'GET' $"($url)/" -H 'accept: application/json' -H $auth_header --cacert $certificate | from json 
  return ($response)
}

#obsidian search on body of notes
#
# mv to http get/post when ready
# let response = https post $url {} --content-type "application/json" -H ["Authorization:", $"Bearer ($apikey)"] --certificate
@category apis
@search-terms obsidiam
export def "obs search" [
  ...query    #search query (in title and body)
  --tag(-t):string   #search in tag (use search, in progress)
  --edit(-e)  #edit selected note (??)
  --raw(-r)   #don't use syntax highlight
] {
  if ($query | is-empty) {
    return-error "empty search query!"
  }

  let check = obs check

  if $check.status != "OK" {
    return-error "something went wrong with the server!"
  }

  let apikey = $check.apikey
  let host = $check.host
  let port = $check.port
  let certificate = $check.certificate
  let auth_header = $'Authorization: Bearer ($apikey)'
  let query = $query | str join " "
  mut note = ""

  # search
  if ($tag | is-not-empty) {
    return-error "work in progress!"
  } else {
    let url = {
                "scheme": "http",
                "host": $host,
                "port": $port ,
                "path": "search/simple",
                "query": ("query=" + ($query | url encode) + "&contextLength=100"),
              } | url join

    let response = curl -sX 'POST' $url -H 'accept: application/json' -H $auth_header --cacert $certificate -d '' | from json

    # ^http POST $url "Accept:application/json" $auth_header --verify=$certificate --verbose | save a.txt -f 
    
    $note = $response | get filename | input list -f (echo-g "Select note:")
  }

  if not $edit {
    # show
    let note_url = {
                "scheme": "http",
                "host": $host,
                "port": $port ,
                "path": ("vault/" + ($note | url encode)),
              } | url join
  
    let content = curl -sX 'GET' $note_url -H 'accept: text/markdown' -H $auth_header --cacert $certificate
  
    if $raw {$content} else {$content | glow}
  } else {
    # edit
    return-error "work in progress!"
  }
}

#obsidian create new note
@category apis
@search-terms obsidian
export def "obs create" [
  name:string   # name of the note
  content?:string # content of the note
  --v_path(-v):string # path for the note in vault, otherwise select from list
  --sub_path(-s) # select subpath
] {
  let content = get-input $in $content
  if ($content | is-empty) {return-error "empty content!"}

  let v_path = if ($v_path | is-empty) {
    ls $env.MY_ENV_VARS.api_keys.obsidian.vault 
    | get name 
    | find -v "_resources"
    | path parse
    | get stem
    | sort
    | input list -f (echo-g "Select path for the note: ")
    } else {
      $v_path
    }

  let sub_path = if $sub_path {
    ls ($env.MY_ENV_VARS.api_keys.obsidian.vault | path join $v_path)
    | where type == "dir"
    | get name
    | path parse
    | get stem
    | sort
    | input list -f (echo-g "Select sub_path for the note: ")
    } else {
      ""
    }

  let check = obs check

  if $check.status != "OK" {
    return-error "something went wrong with the server!"
  }
 
  let v_path = if ($sub_path | is-empty) {$v_path} else {$v_path + "/" + $sub_path}

  let check_path = obs check-path $v_path

  if ($check_path | get errorCode? | is-not-empty) {
    return-error "path doesn't exists!"
  }

  let apikey = $check.apikey
  let host = $check.host
  let port = $check.port
  let certificate = $check.certificate
  let auth_header = $'Authorization: Bearer ($apikey)'

  let url = {
              "scheme": "http",
              "host": $host,
              "port": $port ,
              "path": (["vault" $v_path $"($name | url encode).md"] | path join)
            } | url join

  let response = curl -sX 'PUT' $url -H 'accept: text/markdown' -H $auth_header --cacert $certificate -d $content | from json

  if ($response.message? | is-not-empty) {
    return ($response.message)
  }
}
