#!/usr/bin/env nu

export def main [tags?:string = "ai,ai_notes,bard"] {
  use /home/kira/Yandex.Disk/Backups/linux/nu_scripts/string_manipulation.nu *

  let files = ls ~/Dropbox/Aplicaciones/Gmail/* | find joplin
  
  if ($files | length) == 0 {return}

  $files
  | each {|file|
      let json = open ($file.name | ansi strip)
      let title = $json.title
      let content = $json.body

      obs create $title "AI/AI_GeminiVoiceChat" $content

      # $tags
      # | split row ","
      # | each {|tag|
      #     joplin tag add $tag $title
      #     sleep 0.1sec
      #   }

      rm -f $file.name
    }
}

#check obsidian server
export def "obs check" [] {
  let apikey = "cf32804c5e2066aafdecfa16b3bc39456d84e12d88671f97b5ee8a38f2cc0964"
  let host = "127.0.0.1"
  let port = 27124
  let certificate = "/home/kira/Yandex.Disk/obsidian/obsidian-local-rest-api.crt"

  let url = {
              "scheme": "https",
              "host": $host,
              "port": $port
            } | url join

  let status = curl -s -X 'GET' $url -H 'accept: application/json' -H $'Authorization: Bearer ($apikey)' --cacert $certificate | from json | get status 

  return {status: $status, apikey: $apikey, host: $host, port: $port, certificate: $certificate}
}

#check obsidian path
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
              "scheme": "https",
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
                "scheme": "https",
                "host": $host,
                "port": $port ,
                "path": "search/simple",
                "query": ("query=" + ($query | url encode) + "&contextLength=100"),
              } | url join

    let response = curl -sX 'POST' $url -H 'accept: application/json' -H $auth_header --cacert $certificate -d '' | from json

    $note = ($response | get filename | input list -f (echo-g "Select note:"))
  }

  if not $edit {
    # show
    let note_url = {
                "scheme": "https",
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
export def "obs create" [
  name:string   # name of the note
  v_path:string # path for the note in vault
  content:string   # content of the note
] {
  let check = obs check

  if $check.status != "OK" {
    return-error "something went wrong with the server!"
  }

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
              "scheme": "https",
              "host": $host,
              "port": $port ,
              "path": (["vault" $v_path $"($name | url encode).md"] | path join)
            } | url join

  let response = curl -sX 'PUT' $url -H 'accept: text/markdown' -H $auth_header --cacert $certificate -d $content | from json

  if ($response.message? | is-not-empty) {
    return ($response.message)
  }
}