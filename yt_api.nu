#help info for yt-api
export def "yt-api help" [] {
  echo "  CONFIGURE $env.MY_ENV_VARS.credentials\n
    Add the path to your directory with the credential file or replace manually.\n
  CREATE CREDENTIALS\n
    1) Create an api key from google developers console.\n
    2) Create oauth2 credentials. You should download a json file with at least the following fields:
      - client_id
      - client_secret
      - redirect_uris\n
    3) Add the api key to the previous file, from now on, the credentials file.\n
    4) Run `yt-api get-token`. The token is automatically added to the credentials file.\n
    5) Run `yt-api get-regresh-token`. The refresh token is automatically added to the credentials file.\n
    6) When the token expires, it will run `yt-api get-token` again.
    7) When `yt-api refresh-token` is finished, the refresh will be automatic.\n
  METHODS\n
    - `yt-api`
    - `yt-api get-songs`
    - `yt-api update-all`
    - `yt-api download-music-playlists`\n
  MORE HELP\n
    Run `? yt-api`\n
  RELATED\n
    `ytm`\n"
    | nu-highlight
}

#play youtube music with playlist items pulled from local database
export def ytm [
  playlist? = "all_likes" #playlist name (default: all_likes)
  --list(-l)              #list available music playlists
  --artist(-a):string     #search by artist from all:likes
  #
  #First run `yt-api download-music-playlists`
] {
  let mpv_input = ([$env.MY_ENV_VARS.linux_backup "scripts/mpv_input.conf"] | path join)
  let playlists = (ls $env.MY_ENV_VARS.youtube_database | get name)

  #--list|
  if not ($list | is-empty) or (not $list) {
    $playlists | path parse | get stem
  } else {
    let to_play = ($playlists | find $playlist | ansi strip | get 0)

    if ($to_play | length) > 0 {
      let songs = (
        open $to_play 
        | into df 
        | drop-duplicates [id] 
        | into nu
      )

      let songs = (
        if not ($artist | is-empty) {
          $songs 
          | str downcase "artist"
          | where "artist" =~ ($artist | str downcase)
        } else {
          $songs 
        }
      )
      
      let len = ($songs | length)

      if ($len > 0) {
        $songs 
        | shuffle 
        | each -n {|song|
            fetch $"($song.item.thumbnail)" | save -f /tmp/thumbnail.jpg
            convert -density 384 -scale 256 -background transparent /tmp/thumbnail.jpg /tmp/thumbnail.ico

            notify-send $"($song.item.title)" $"($song.item.artist)" -t 5000 --icon=/tmp/thumbnail.ico
            tiv /tmp/thumbnail.ico 
            echo-g $"now playing ($song.item.title) by ($song.item.artist) [($song.index)/($len)]..."

            bash -c $"mpv --msg-level=all=status --no-resume-playback --no-video --input-conf=($mpv_input) ($song.item.url)"

          }
      } else {
        return-error "artist not found!"
      }    
    } else {
      return-error "playlist not found!"
    }
  }
}

#play youtube music with playlist items pulled from youtube
export def "ytm online" [
  playlist? = "all_likes" #playlist name, export default: all_likes
  --list(-l)              #list available music playlists
  --artist(-a):string     #search by artist in all_likes
] {
  let mpv_input = ([$env.MY_ENV_VARS.linux_backup "scripts/mpv_input.conf"] | path join)
  let response = yt-api

  let playlists = (
    $response 
    | get items 
    | select id snippet 
    | upsert snippet {|sn| 
        $sn.snippet.title
      }
    | rename -c [snippet title]
    | append {"id": "LM", "title": "all_likes"}
  )

  #--list|
  if not ($list | is-empty) or (not $list) {
    $playlists | find music & likes
  } else {
    let to_play = ($playlists | where title =~ $playlist | first | get id)

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

      let len = ($songs | length)

      $songs 
      | shuffle 
      | each -n {|song|
          fetch $"($song.item.thumbnail)" | save -f /tmp/thumbnail.jpg
          convert -density 384 -scale 256 -background transparent /tmp/thumbnail.jpg /tmp/thumbnail.ico

          notify-send $"($song.item.title)" $"($song.item.artist)" -t 5000 --icon=/tmp/thumbnail.ico
          tiv /tmp/thumbnail.ico 
          echo-g $"now playing ($song.item.title) by ($song.item.artist) [($song.index)/($len)]..."

          bash -c $"mpv --msg-level=all=status --no-resume-playback --no-video --input-conf=($mpv_input) ($song.item.url)"
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

  let youtube_credential = open-credential ([$env.MY_ENV_VARS.credentials "credentials.youtube.json.asc"] | path join)
  let api_key = ($youtube_credential | get api_key)
  let token = ($youtube_credential | get token)

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

  let response = fetch $"($url)" -H ["Authorization", $"Bearer ($token)"] -H ['Accept', 'application/json']
 
  $response
}

#get youtube songs of playlist by id
export def "yt-api get-songs" [
  pid:string      #playlist id
  --ptoken:string #nextpage token
  #
  #Output table: 
  #inPlaylistID | id | title | artist | thumbnail | url
] {
  #verify and update token
  yt-api verify-token

  #songs|songs nextPage
  let response = (
    if ($ptoken | is-empty) {
      yt-api --pid $pid
    } else {
      yt-api --pid $pid --ptoken $ptoken
    }
  )

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
    | rename -c [id inPlaylistID]
    | upsert id {|item| 
        $item.snippet.resourceId.videoId
      }
    | upsert title {|item| 
        $item.snippet.title
      } 
    | find -v "Deleted video"
    | find -v "Private video"
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
  let songs = (
    if ($nextpageToken | typeof) == string {
      print -n (echo-g $"\rgetting page ($nextpageToken)...")
      $songs | append (yt-api get-songs $pid --ptoken $nextpageToken)
    } else {
      $songs
    }
  )

  $songs
}

#download youtube music playlist to local database
export def "yt-api download-music-playlists" [
  --downloadDir(-d) = $env.MY_ENV_VARS.youtube_database #download directory, export default: $env.MY_ENV_VARS.youtube_database
] {
  let response = yt-api

  let playlists = (
    $response 
    | get items 
    | select id snippet 
    | upsert snippet {|sn| 
        $sn.snippet.title
      }
    | rename -c [snippet title]
    | find music
    | update title {|item|
        $item.title 
        | ansi strip
      }
    | append {"id": "LM", "title": "all_likes"}
  )

  $playlists
  | each {|playlist|
      let filename = $"([($downloadDir) ($playlist.title)] | path join).json"
      let songs = yt-api get-songs $playlist.id
      
      if ($songs | length) > 0 {
        echo-g $"\nsaving ($playlist.title) into ($filename)..."
        $songs | sort-by artist | save -f $filename
      }
    }
}

#update playlist1 from playlist2
export def "yt-api update-all" [
  --playlist1 = "all_music"
  --playlist2 = "new_likes"
] {
  let youtube_credential = open-credential ([$env.MY_ENV_VARS.credentials "credentials.youtube.json.asc"] | path join)
  let api_key = ($youtube_credential | get api_key)
  let token = ($youtube_credential | get token)
  let response = yt-api

  let playlists = (
    $response 
    | get items 
    | select id snippet 
    | upsert snippet {|sn| 
        $sn.snippet.title
      }
    | rename -c [snippet title]
  )

  let from = ($playlists | find $playlist2 | get id | get 0)
  let to = ($playlists | find $playlist1 | get id | get 0)

  let to_add = yt-api get-songs $from

  echo-g $"copying playlist items from ($playlist2) to ($playlist1)..."
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

      post "https://www.googleapis.com/youtube/v3/playlistItems?part=snippet&key=($api_key)" -t 'application/json' -H ["Authorization", $"Bearer ($token)"] $body | ignore
      sleep 10ms

    }   

  echo-g $"deleting playlist items from ($playlist2)..."
  let header2 = "Accept: application/json"

  $to_add 
  | each {|song|
      let url = $"https://youtube.googleapis.com/youtube/v3/playlistItems?id=($song.inPlaylistID)&key=($api_key)"
      let header1 = $"Authorization: Bearer ($token)"

      curl -s --request DELETE $url --header $header1 --header $header2 --compressed
      sleep 10ms
    }

  echo-g $"updating local database..."
  yt-api download-music-playlists
}

#delete all songs of a playlist
export def "yt-api empty-playlist" [playlist?:string] {
  let response = yt-api

  echo-g "listing playlists..."
  let youtube_credential = open-credential ([$env.MY_ENV_VARS.credentials "credentials.youtube.json.asc"] | path join)
  let api_key = ($youtube_credential | get api_key)
  let token = ($youtube_credential | get token)

  let playlists = (
    $response 
    | get items 
    | select id snippet 
    | upsert snippet {|sn| 
        $sn.snippet.title
      }
    | rename -c [snippet title]
  )

  echo-g "selecting playlist to process..."
  let the_playlist = (
    if ($playlist | is-empty) {
      $playlists
      let index = (input (echo-g "from which playlist you want to delete songs (index)?: ") | into int)
      $playlists | get $index
    } else {
      $playlists | find -i $playlist
    }
  )

  echo-g "geting songs..."
  let songs = yt-api get-songs $the_playlist.id

  echo-g $"removing songs from ($the_playlist.title)..."
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
export def "yt-api remove-duplicated-songs" [
  playlist?:string #playlist id
  #
  #Does not work if there are more than 50 duplicates, due to youtube api quota
] {
  let response = yt-api

  echo-g "listing playlists..."
  let youtube_credential = open-credential ([$env.MY_ENV_VARS.credentials "credentials.youtube.json.asc"] | path join)
  let api_key = ($youtube_credential | get api_key)
  let token = ($youtube_credential | get token)

  let playlists = (
    $response 
    | get items 
    | select id snippet 
    | upsert snippet {|sn| 
        $sn.snippet.title
      }
    | rename -c [snippet title]
  )

  echo-g "selecting playlist to process..."
  let the_playlist = (
    if ($playlist | is-empty) {
      $playlists
      let index = (input (echo-g "from which playlist you want to remove duplicates (index)?: ") | into int)
      $playlists | get $index
    } else {
      $playlists | find -i $playlist
    }
  )

  echo-g "geting songs and droping duplicates..."
  let songs = yt-api get-songs $the_playlist.id

  let unique_songs = (
    $songs
    | into df 
    | drop-duplicates [id] 
    | into nu
  )

  echo-g $"removing songs from ($the_playlist.title)..."
  let header2 = "Accept: application/json"

  $songs
  | each {|song|
      let url = $"https://youtube.googleapis.com/youtube/v3/playlistItems?id=($song.inPlaylistID)&key=($api_key)"
      let header1 = $"Authorization: Bearer ($token)"

      curl -s --request DELETE $url --header $header1 --header $header2 --compressed
      sleep 10ms
    }

  echo-g $"adding non duplicated songs to ($the_playlist.title)..."
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

      post "https://www.googleapis.com/youtube/v3/playlistItems?part=snippet&key=($api_key)" -t 'application/json' -H ["Authorization", $"Bearer ($token)"] $body | ignore
      sleep 10ms

    } 

  echo-g "updating local database..."
  yt-api download-music-playlists
}

#verify if youtube api token has expired
export def "yt-api verify-token" [] {
  let youtube_credential = open-credential ([$env.MY_ENV_VARS.credentials "credentials.youtube.json.asc"] | path join)
  let api_key = ($youtube_credential | get api_key)
  let token = ($youtube_credential | get token)

  let response = try {
      fetch $"https://youtube.googleapis.com/youtube/v3/playlists?part=snippet&mine=true&key=($api_key)" -H ["Authorization", $"Bearer ($token)"] -H ['Accept', 'application/json'] 
    } catch {
      {error: {code: 401}}
  }

  if ($response | is-column error) and ($response | get error  | get code) != 403 {
    yt-api get-token 
    #yt-api refresh-token
  } else if ($response | is-column error) and ($response | get error  | get code) == 403 {
    return-error "youtube api quota excedeed!"
  }
}

#update youtube api token
export def "yt-api get-token" [] {
  let youtube_credential = open-credential ([$env.MY_ENV_VARS.credentials "credentials.youtube.json.asc"] | path join)
  let client = ($youtube_credential | get client_id)

  let uri = (
    $youtube_credential 
    | get redirect_uris 
    | get 0 
    | str replace -a ":" "%3A" 
    | str replace -a "/" "%2F"
  )
  
  echo $"https://accounts.google.com/o/oauth2/auth?client_id=($client)&redirect_uri=($uri)&scope=https://www.googleapis.com/auth/youtube&response_type=token&approval_prompt=force" | copy

  echo-g "url copied to clipboard, now paste on browser..."

  let url = input (echo-g "Copy response url here: ")

  let content = (
    $youtube_credential  
    | upsert token {
        $url 
        | split row "#" 
        | get 1 
        | split row "=" 
        | get 1 
        | split row "&" 
        | get 0
      }
  ) 
  save-credential $content ([$env.MY_ENV_VARS.credentials "credentials.youtube.json"] | path join) 
}


##In progress

#get youtube api refresh token
export def "yt-api get-refresh-token" [] {
  let youtube_credential = open-credential ([$env.MY_ENV_VARS.credentials "credentials.youtube.json.asc"] | path join)
  let client = ($youtube_credential | get client_id)

  let uri = (
    $youtube_credential 
    | get redirect_uris 
    | get 0 
    | str replace -a ":" "%3A" 
    | str replace -a "/" "%2F"
  )
  
  echo $"https://accounts.google.com/o/oauth2/auth?client_id=($client)&redirect_uri=($uri)&scope=https://www.googleapis.com/auth/youtube&response_type=code&access_type=offline&prompt=consent" | copy

  echo-g "url copied to clipboard, now paste on browser..."

  let url = input (echo-g "Copy response url here: ")

  let content = (
    $youtube_credential  
    | upsert refresh_token {
        $url 
        | split row "=" 
        | get 1 
        | split row "&" 
        | get 0
      }
  ) 
  save-credential $content ([$env.MY_ENV_VARS.credentials "credentials.youtube.json"] | path join) 
}

#refresh youtube api token via refresh token (in progress)
export def "yt-api refresh-token" [] {
  let youtube_credential = open-credential ([$env.MY_ENV_VARS.credentials "credentials.youtube.json.asc"] | path join)
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

  post "https://accounts.google.com/o/oauth2/token" $"client_id=($client_id)&client_secret=($client_secret)&refresh_token=($refresh_token)&grant_type=refresh_token" -t application/x-www-form-urlencoded

  # curl -X POST "https://accounts.google.com/o/oauth2/token" -d $"client_id=($client_id)&client_secret=($client_secret)&refresh_token=($refresh_token)&grant_type=refresh_token" -H "Content-Type: application/x-www-form-urlencoded"
}



## testing

# export def "yt-api verify-token" [url,token] {
#   let response = fetch $"($url)" -H ["Authorization", $"Bearer ($token)"] -H ['Accept', 'application/json']

#   if ($response | is-column error) {
#     let client = (open ~/Yandex.Disk/Backups/linux/credentials/credentials.youtube.json | get client_id)
#     let refresh_token = (open ~/Yandex.Disk/Backups/linux/credentials/credentials.youtube.json | get refresh_token)
#     let secret = (open ~/Yandex.Disk/Backups/linux/credentials/credentials.youtube.json | get client_secret)

#     let response = (post "https://www.googleapis.com/oauth2/v4/token" -t 'application/json' {
#         "client_id": ($client),
#         "client_secret": ($secret),
#         "refresh_token": ($refresh_token),
#         "grant_type": "authorization_code",
#         "access_type": "offline",
#         "prompt": "consent",
#         "scope": "https://www.googleapis.com/auth/youtube"
#       }
#     )

#     $response | save test.json
#   }
# }


export def test-api [] {
  let youtube_credential = open-credential ([$env.MY_ENV_VARS.credentials "credentials.youtube.json.asc"] | path join)
  let api_key = ($youtube_credential | get api_key)
  let token = ($youtube_credential | get token)
  let client = ($youtube_credential | get client_id)
  let refresh_token = ($youtube_credential | get refresh_token)
  let secret = ($youtube_credential | get client_secret)

  let response = (post "https://www.googleapis.com/oauth2/v4/token" -t 'application/json' {
     "client_id": ($client),
     "client_secret": ($secret),
     "refresh_token": ($refresh_token),
     "grant_type": "refresh_token"
   }
  )

  $response | save -f test.json 
}

 # let response = (post "https://accounts.google.com/o/oauth2/token/" $"client_id=($client)&client_secret=($secret)&refresh_token=($refresh_token)&grant_type=refresh_token&access_type=offline&prompt=consent&scope=https://www.googleapis.com/auth/youtube"2 -t "text/html"
  # )
# https://accounts.google.com/o/oauth2/auth?client_id=676765289577-ek34fcbppprtcvtt7sd98ioodvapojci.apps.googleusercontent.com&redirect_uri=http%3A%2F%2Flocalhost%2Foauth2callback&scope=https://www.googleapis.com/auth/youtube&response_type=token

# http://localhost/oauth2callback
# http://localhost:8080 

# http://localhost/oauth2callback#access_token=&token_type=Bearer&expires_in=3599&scope=https://www.googleapis.com/auth/youtube

# export def get-yt-playlist [
#   pid         #playlist id
#   nos? = 500  #number of song to fetch
#   --all       #fetch all songs
# ] {
#   ls
# # $playlists | flatten | where title == jp  | get id
# }


# auth_code
# https://accounts.google.com/o/oauth2/v2/auth?redirect_uri=https%3A%2F%2Fdevelopers.google.com%2Foauthplayground&prompt=consent&response_type=code&client_id=407408718192.apps.googleusercontent.com&scope=https%3A%2F%2Fwww.googleapis.com%2Fauth%2Fyoutube&access_type=offline
# https://accounts.google.com/o/oauth2/v2/auth?redirect_uri=https%3A%2F%2Fdevelopers.google.com%2Foauthplayground&prompt=consent&response_type=code&client_id=407408718192.apps.googleusercontent.com&scope=https%3A%2F%2Fwww.googleapis.com%2Fauth%2Fyoutube&access_type=offline

# 4/0AdQt8qiNECGYvH98mxe0xnd7dHhGahZb2Na9w2-Q0YTv3KvjCg7ULN6T4Z5jGrLvEfLtnw

# refresh_token
# 1//04fRaM1rCDgifCgYIARAAGAQSNwF-L9IrQQDg2DCQypNrG44ML4QwcMsEGI0X5i4n43B5E4ZmdLvTcaeDltC0aQDjeUjlCE89BcU