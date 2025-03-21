#help info for yt-api
export def "yt-api help" [] {
  print ([
    "CONFIGURE $env.MY_ENV_VARS.credentials"
    " Add the path to your directory with the credential file or replace manually."
    ""
    "CREATE CREDENTIALS"
    " 1) Create an api key from google developers console"
    " 2) Create oauth2 credentials. You should download a json file with at least the following fields:"
    "   - client_id"
    "   - client_secret"
    "   - redirect_uris"
    " 3) Add the api key to the previous file, from now on, the credentials file."
    " 4) Run `yt-api get-token`. The token is automatically added to the credentials file."
    " 5) Run `yt-api get-regresh-token`. The refresh token is automatically added to the credentials file."
    " 6) When the token expires, it will run `yt-api get-token` again."
    " 7) When `yt-api refresh-token` is finished, the refresh will be automatic."
    ""
    "METHODS:"
    " - yt-api"
    " - yt-api get-songs"
    " - yt-api update-all"
    " - yt-api download-music-playlists"
    ""
    "MORE HELP"
    " Run `? yt-api`"
    ""
    "RELATED"
    " ytm"
    ] | str join "\n"
  )
}

#play youtube music with playlist items pulled from local database
#
#First run `yt-api download-music-playlists`
export def ytm [
  playlist? = "all_likes" #playlist name (default: all_likes)
  --list(-l)              #list available music playlists for selection
  --artist(-a):string     #search by artist from all_likes
] {
  let mpv_input = [$env.MY_ENV_VARS.linux_backup "scripts/mpv_input.conf"] | path join
  let playlists = ls $env.MY_ENV_VARS.youtube_database | get name

  let to_play = if $list {
      $playlists | path parse | get stem | input list -f (echo-g "Select playlist:")
    } else {
      $playlists | find -n $playlist | get 0 | path parse | get stem
    }

  if ($to_play | is-empty) {
    return-error "playlist not found!"
  } 

  let songs = open ([$env.MY_ENV_VARS.youtube_database $"($to_play).json"] | path join)

  let songs = if not ($artist | is-empty) {
      $songs 
      | str downcase "artist"
      | where "artist" =~ ($artist | str downcase)
    } else {
      $songs 
    }
    
  if ($songs | is-empty) {
    return-error "artist not found!"
  }

  let len = $songs | length

  $songs 
  | shuffle 
  | enumerate
  | each {|song|
      http get $"($song.item.thumbnail)" | save -f /tmp/thumbnail.jpg
      convert -density 384 -scale 256 -background transparent /tmp/thumbnail.jpg /tmp/thumbnail.ico
      notify-send $"($song.item.title)" $"($song.item.artist)" -t 5000 --icon=/tmp/thumbnail.ico 
      tiv /tmp/thumbnail.ico        
      print (echo-g $"now playing ($song.item.title) by ($song.item.artist) [($song.index)/($len)]...")
      try {
        ^mpv --msg-level=all=no --no-resume-playback --no-video --input-conf=($mpv_input) $song.item.url
        sleep 1ns
      } catch {|e|
        print (echo-r $e.msg)
      }
    }
}

#play youtube music with playlist items pulled from youtube
export def "ytm online" [
  playlist? = "all_likes" #playlist name, export default: all_likes
  --list(-l)              #list available music playlists
  --artist(-a):string     #search by artist in all_likes
] {
  let mpv_input = [$env.MY_ENV_VARS.linux_backup "scripts/mpv_input.conf"] | path join
  let response = yt-api

  let playlists = (
    $response 
    | get items 
    | select id snippet 
    | upsert snippet {|sn| 
        $sn.snippet.title
      }
    | rename -c {snippet: title}
    | append {"id": "LM", "title": "all_likes"}
  )

  #--list|
  if not $list {
    $playlists | find -n music & likes
  } else {
    let to_play = $playlists | where title =~ $playlist | first | get id

    if ($to_play | length) > 0 {
      let songs = yt-api get-songs $to_play

      let songs = (
        if not ($artist | is-empty) {
          $songs 
          | str downcase "artist"
          | where "artist" =~ ($artist | str downcase)
        } else {
          $songs
        }
      )

      let len = $songs | length

      $songs 
      | shuffle 
      | enumerate
      | each {|song|
          http get $"($song.item.thumbnail)" | save -f /tmp/thumbnail.jpg
          convert -density 384 -scale 256 -background transparent /tmp/thumbnail.jpg /tmp/thumbnail.ico

          notify-send $"($song.item.title)" $"($song.item.artist)" -t 5000 --icon=/tmp/thumbnail.ico
          tiv /tmp/thumbnail.ico 
          print (echo-g $"now playing ($song.item.title) by ($song.item.artist) [($song.index)/($len)]...")

          ^mpv --msg-level=all=no --no-resume-playback --no-video --input-conf=($mpv_input) $song.item.url
        }    
    } else {
      return-error "playlist not found!"
    }
  }
}

#youtube api implementation to get playlists and songs info
export def yt-api [
  type? = "snippet" #type of query: id, status, snippet (export default)
  --pid:string      #playlist/song id
  --ptoken:string   #prev/next page token
] {
  #verify and update token
  yt-api verify-token

  let youtube_credential = $env.MY_ENV_VARS.api_keys.youtube
  let api_key = $youtube_credential | get api_key
  let token = $youtube_credential | get token

  #playlist|playlist nextPage|songs|songs nextPage
  let url = (
    if ($pid | is-empty) and ($ptoken | is-empty) {
      $"https://youtube.googleapis.com/youtube/v3/playlists?part=($type)&mine=true&key=($api_key)&maxResults=50"
    } else if ($pid | is-empty) and (not ($ptoken | is-empty)) {
      $"https://youtube.googleapis.com/youtube/v3/playlists?part=($type)&mine=true&key=($api_key)&maxResults=50&pageToken=($ptoken)"
    } else if not ($pid | is-empty) {
      if ($ptoken | is-empty) {
        $"https://youtube.googleapis.com/youtube/v3/playlistItems?part=($type)&maxResults=50&playlistId=($pid)&key=($api_key)&maxResults=50"
      } else {
        $"https://youtube.googleapis.com/youtube/v3/playlistItems?part=($type)&maxResults=50&pageToken=($ptoken)&playlistId=($pid)&key=($api_key)"
      }
    }
  )

  let response = http get $"($url)" -H ["Authorization", $"Bearer ($token)"] -H ['Accept', 'application/json']
 
  return $response
}

#get youtube songs of playlist by id
#
#Output table: 
#inPlaylistID | id | title | artist | thumbnail | url
export def "yt-api get-songs" [
  pid:string      #playlist id
  --ptoken:string #nextpage token
] {
  #verify and update token
  yt-api verify-token

  #songs|songs nextPage
  let response = if ($ptoken | is-empty) {
      yt-api --pid $pid
    } else {
      yt-api --pid $pid --ptoken $ptoken
    }

  let nextpageToken = (
    if ($response | is-column nextPageToken) {
        $response | get nextPageToken
    } else {
        false
    }
  )
  
  #first page
  let songs = (
    $response
    | get items 
    | select id snippet 
    | rename -c {id: inPlaylistID}
    | upsert id {|item| 
        $item.snippet.resourceId.videoId
      }
    | upsert title {|item| 
        $item.snippet.title
      }
    | where title !~ "Deleted video|Private video"
    | upsert artist {|item| 
        $item.snippet.videoOwnerChannelTitle 
        | str replace ' - Topic' ''
      } 
    | upsert thumbnail {|item| 
        $item.snippet.thumbnails | transpose | last | get column1 | get url
      }
    | upsert url {|item|
        $item.snippet.resourceId.videoId | str prepend "https://www.youtube.com/watch?v="
      }
    | reject snippet
  )

  #next pages via recursion
  let songs = if ($nextpageToken | typeof) == string {
      print -n (echo $"\rgetting page ($nextpageToken)...")
      $songs | append (yt-api get-songs $pid --ptoken $nextpageToken)
    } else {
      $songs
    }

  return $songs
}

#download youtube music playlist to local database
export def "yt-api download-music-playlists" [
  --downloadDir(-d):string #download directory, export default: $env.MY_ENV_VARS.youtube_database
] {
  let downloadDir = get-input $env.MY_ENV_VARS.youtube_database $downloadDir
  let response = yt-api

  let playlists = (
    $response 
    | get items 
    | select id snippet 
    | upsert snippet {|sn| 
        $sn.snippet.title
      }
    | rename -c {snippet: title}
    | find -n music
    | append {"id": "LM", "title": "all_likes"}
  )

  $playlists
  | each {|playlist|
      print (echo-g $"getting ($playlist.title)'s songs...")
      let filename = $"([($downloadDir) ($playlist.title)] | path join).json"
      let songs = yt-api get-songs $playlist.id
      
      if ($songs | length) > 0 {
        print (echo-g $"\nsaving into ($filename)...")
        $songs | sort-by artist | save -f $filename
      }
    }
}

#update playlist1 from playlist2
export def "yt-api update-all" [
  --playlist1 = "all_music"
  --playlist2 = "new_likes"
] {
  let youtube_credential = $env.MY_ENV_VARS.api_keys.youtube
  let api_key = $youtube_credential | get api_key
  let token = $youtube_credential | get token
  let response = yt-api

  let playlists = (
    $response 
    | get items 
    | select id snippet 
    | upsert snippet {|sn| 
        $sn.snippet.title
      }
    | rename -c {snippet: title}
  )

  let from = $playlists | find $playlist2 | get id | get 0
  let to = $playlists | find $playlist1 | get id | get 0

  let to_add = yt-api get-songs $from

  print (echo-g $"copying playlist items from ($playlist2) to ($playlist1)...")
  $to_add 
  | each {|song|
      let body = (
        {  "snippet": {
              "playlistId": $"($to)",
              "resourceId": {
                "kind": "youtube#video",
                "videoId": $"($song.id)"
              }
            }
        }
      )

      http post "https://www.googleapis.com/youtube/v3/playlistItems?part=snippet&key=($api_key)" -t 'application/json' -H ["Authorization", $"Bearer ($token)"] $body | ignore
      sleep 10ms
    }   

  print (echo-g $"deleting playlist items from ($playlist2)...")
  let header2 = "Accept: application/json"

  $to_add 
  | each {|song|
      let url = $"https://youtube.googleapis.com/youtube/v3/playlistItems?id=($song.inPlaylistID)&key=($api_key)"
      let header1 = $"Authorization: Bearer ($token)"

      curl -s --request DELETE $url --header $header1 --header $header2 --compressed
      sleep 10ms
    }

  print (echo-g $"updating local database...")
  yt-api download-music-playlists
}

#delete all songs of a playlist
export def "yt-api empty-playlist" [playlist?:string] {
  let response = yt-api

  print (echo-g "listing playlists...")
  let youtube_credential = $env.MY_ENV_VARS.api_keys.youtube
  let api_key = $youtube_credential | get api_key
  let token = $youtube_credential | get token

  let playlists = (
    $response 
    | get items 
    | select id snippet 
    | upsert snippet {|sn| 
        $sn.snippet.title
      }
    | rename -c {snippet: title}
  )

  print (echo-g "selecting playlist to process...")
  let the_playlist = (
    if ($playlist | is-empty) {
      $playlists
      let index = (input (echo-g "from which playlist you want to delete songs (index)?: ") | into int)
      $playlists | get $index
    } else {
      $playlists | find -i $playlist
    }
  )

  print (echo-g "geting songs...")
  let songs = yt-api get-songs $the_playlist.id

  print (echo-g $"removing songs from ($the_playlist.title)...")
  let header2 = "Accept: application/json"

  $songs
  | each {|song|
      let url = $"https://youtube.googleapis.com/youtube/v3/playlistItems?id=($song.inPlaylistID)&key=($api_key)"
      let header1 = $"Authorization: Bearer ($token)"

      curl -s --request DELETE $url --header $header1 --header $header2 --compressed
      sleep 10ms
    }
}

#remove duplicated songs from a playlist
#
#Does not work if there are more than 50 duplicates, due to youtube api quota
export def "yt-api remove-duplicated-songs" [
  playlist?:string #playlist id
] {
  let response = yt-api

  print (echo-g "listing playlists...")
  let youtube_credential = $env.MY_ENV_VARS.api_keys.youtube
  let api_key = $youtube_credential | get api_key
  let token = $youtube_credential | get token

  let playlists = (
    $response 
    | get items 
    | select id snippet 
    | upsert snippet {|sn| 
        $sn.snippet.title
      }
    | rename -c {snippet: title}
  )

  print (echo-g "selecting playlist to process...")
  let the_playlist = (
    if ($playlist | is-empty) {
      $playlists
      let index = (input (echo-g "from which playlist you want to remove duplicates (index)?: ") | into int)
      $playlists | get $index
    } else {
      $playlists | find -i $playlist
    }
  )

  print (echo-g "geting songs and droping duplicates...")
  let songs = (yt-api get-songs $the_playlist.id)

  let unique_songs = $songs

  print (echo-g $"removing songs from ($the_playlist.title)...")
  let header2 = "Accept: application/json"

  $songs
  | each {|song|
      let url = $"https://youtube.googleapis.com/youtube/v3/playlistItems?id=($song.inPlaylistID)&key=($api_key)"
      let header1 = $"Authorization: Bearer ($token)"

      curl -s --request DELETE $url --header $header1 --header $header2 --compressed
      sleep 10ms
    }

  print (echo-g $"adding non duplicated songs to ($the_playlist.title)...")
  $unique_songs 
  | each {|song|
      let body = (
        {  "snippet": {
              "playlistId": $"($the_playlist)",
              "resourceId": {
                "kind": "youtube#video",
                "videoId": $"($song.id)"
              }
            }
        }
      )

      http post "https://www.googleapis.com/youtube/v3/playlistItems?part=snippet&key=($api_key)" -t 'application/json' -H ["Authorization", $"Bearer ($token)"] $body | ignore
      sleep 10ms
    } 

  print (echo-g "updating local database...")
  yt-api download-music-playlists
}

#verify if youtube api token has expired
export def "yt-api verify-token" [] {
  let youtube_credential = $env.MY_ENV_VARS.api_keys.youtube
  let api_key = $youtube_credential | get api_key
  let token = $youtube_credential | get token

  let response = (try {
        http get $"https://youtube.googleapis.com/youtube/v3/playlists?part=snippet&mine=true&key=($api_key)" -H ["Authorization", $"Bearer ($token)"] -H ['Accept', 'application/json'] 
      } catch {
        {error: {code: 401}}
    })

  if ($response | is-column error) and ($response | get error  | get code) != 403 {
    yt-api get-token 
    #yt-api refresh-token
  } else if ($response | is-column error) and ($response | get error  | get code) == 403 {
    return-error "youtube api quota excedeed!"
  }
}

#update youtube api token
export def --env "yt-api get-token" [] {
  let youtube_credential = $env.MY_ENV_VARS.api_keys.youtube
  let client = $youtube_credential | get client_id

  let uri = (
    $youtube_credential 
    | get redirect_uris 
    | get 0 
    | str replace -a ":" "%3A" 
    | str replace -a "/" "%2F"
  )
  
  print (echo-g "click on this url:")
  print ($"https://accounts.google.com/o/oauth2/auth?client_id=($client)&redirect_uri=($uri)&scope=https://www.googleapis.com/auth/youtube&response_type=token&approval_prompt=force")

  let url = (input (echo-g "Copy response url here: "))

  let token = (
    $url 
    | split row "#" 
    | get 1 
    | split row "=" 
    | get 1 
    | split row "&" 
    | get 0
 )

  let content = $youtube_credential  | upsert token $token
  
  save-credential $content youtube  
  
  $env.MY_ENV_VARS = $env.MY_ENV_VARS | upsert api_keys.youtube.token $token
}

##In progress

#get youtube api refresh token
export def --env "yt-api get-refresh-token" [] {
  let youtube_credential = $env.MY_ENV_VARS.api_keys.youtube
  let client = ($youtube_credential | get client_id)

  let uri = (
    $youtube_credential 
    | get redirect_uris 
    | get 0 
    | str replace -a ":" "%3A" 
    | str replace -a "/" "%2F"
  )
  
  let url = $"https://accounts.google.com/o/oauth2/auth?client_id=($client)&redirect_uri=($uri)&scope=https://www.googleapis.com/auth/youtube&response_type=code&access_type=offline&prompt=consent"

  $url | copy

  print (echo $url)
  print (echo-g "url copied to clipboard, now paste on browser")

  let url = (input (echo-g "Copy response url here: "))

  let refresh_token = (
    $url 
    | split row "=" 
    | get 1 
    | split row "&" 
    | get 0
 )

  let content = ($youtube_credential | upsert refresh_token $refresh_token)

  save-credential $content youtube 

  $env.MY_ENV_VARS = (
    $env.MY_ENV_VARS
    | upsert api_keys.youtube.refresh_token $refresh_token
  )
}

#refresh youtube api token via refresh token (in progress)
export def "yt-api refresh-token" [] {
  let youtube_credential = $env.MY_ENV_VARS.api_keys.youtube
  let client_id = ($youtube_credential | get client_id)
  let client_secret = ($youtube_credential | get client_secret)
  let refresh_token = ($youtube_credential | get refresh_token)
  let redirect_uri = (
    $youtube_credential 
    | get redirect_uris 
    | get 0 
    | str replace -a ":" "%3A" 
    | str replace -a "/" "%2F"
  )

  http post "https://accounts.google.com/o/oauth2/token" $"client_id=($client_id)&client_secret=($client_secret)&refresh_token=($refresh_token)&grant_type=refresh_token" -t application/x-www-form-urlencoded
}