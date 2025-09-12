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
      | where "artist" like ($artist | str downcase)
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
      sleep 0.1sec
      # notify-send $"($song.item.title)" $"($song.item.artist)" -t 5000 --icon=/tmp/thumbnail.ico | complete | ignore
      print ("")
      timg /tmp/thumbnail.jpg
      print -n (echo-g $"($song.item.title) | ($song.item.artist)\n[($song.index)/($len)]")
      
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

  let playlists = $response 
    | get items 
    | select id snippet 
    | upsert snippet {|sn| 
        $sn.snippet.title
      }
    | rename -c {snippet: title}
    | append {"id": "LM", "title": "all_likes"}

  #--list|
  if not $list {
    $playlists | find -n music & likes
  } else {
    let to_play = $playlists | where title like $playlist | first | get id

    if ($to_play | length) > 0 {
      let songs = yt-api get-songs $to_play

      let songs = if not ($artist | is-empty) {
          $songs 
          | str downcase "artist"
          | where "artist" like ($artist | str downcase)
        } else {
          $songs
        }

      let len = $songs | length

      $songs 
      | shuffle 
      | enumerate
      | each {|song|
          http get $"($song.item.thumbnail)" | save -f /tmp/thumbnail.jpg
          convert -density 384 -scale 256 -background transparent /tmp/thumbnail.jpg /tmp/thumbnail.ico

          notify-send $"($song.item.title)" $"($song.item.artist)" -t 5000 --icon=/tmp/thumbnail.ico
          timg /tmp/thumbnail.ico 
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
  # Automatically fetch a valid token
  let token = yt-get-access-token
  let youtube_credential = $env.MY_ENV_VARS.api_keys.youtube
  let api_key = $youtube_credential | get api_key

  #playlist|playlist nextPage|songs|songs nextPage
  let url = if ($pid | is-empty) and ($ptoken | is-empty) {
      $"https://youtube.googleapis.com/youtube/v3/playlists?part=($type)&mine=true&maxResults=50"
    } else if ($pid | is-empty) and (not ($ptoken | is-empty)) {
      $"https://youtube.googleapis.com/youtube/v3/playlists?part=($type)&mine=true&maxResults=50&pageToken=($ptoken)"
    } else if not ($pid | is-empty) {
      if ($ptoken | is-empty) {
        $"https://youtube.googleapis.com/youtube/v3/playlistItems?part=($type)&maxResults=50&playlistId=($pid)"
      } else {
        $"https://youtube.googleapis.com/youtube/v3/playlistItems?part=($type)&maxResults=50&pageToken=($ptoken)&playlistId=($pid)"
      }
    }

  let response = http get $url -H ["Authorization", $"Bearer ($token)"] -H ['Accept', 'application/json']
 
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
  # Automatically fetch a valid token
  let token = yt-get-access-token

  #songs|songs nextPage
  let response = if ($ptoken | is-empty) {
      yt-api --pid $pid
    } else {
      yt-api --pid $pid --ptoken $ptoken
    }

  let nextpageToken = if ($response | is-column nextPageToken) {
        $response | get nextPageToken
    } else {
        false
    }
  
  #first page
  let songs = $response
    | get items 
    | select id snippet 
    | rename -c {id: inPlaylistID}
    | upsert id {|item| 
        $item.snippet.resourceId.videoId
      }
    | upsert title {|item| 
        $item.snippet.title
      }
    | where title not-like "Deleted video|Private video"
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

  let playlists = $response 
    | get items 
    | select id snippet 
    | upsert snippet {|sn| 
        $sn.snippet.title
      }
    | rename -c {snippet: title}
    | find -n music
    | append {"id": "LM", "title": "all_likes"}

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

  let playlists = $response 
    | get items 
    | select id snippet 
    | upsert snippet {|sn| 
        $sn.snippet.title
      }
    | rename -c {snippet: title}

  let from = $playlists | find $playlist2 | get id | get 0
  let to = $playlists | find $playlist1 | get id | get 0

  let to_add = yt-api get-songs $from

  print (echo-g $"copying playlist items from ($playlist2) to ($playlist1)...")
  $to_add 
  | each {|song|
      let body = {  "snippet": {
              "playlistId": $"($to)",
              "resourceId": {
                "kind": "youtube#video",
                "videoId": $"($song.id)"
              }
            }
        }

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

  let playlists = $response 
    | get items 
    | select id snippet 
    | upsert snippet {|sn| 
        $sn.snippet.title
      }
    | rename -c {snippet: title}

  print (echo-g "selecting playlist to process...")
  let the_playlist = if ($playlist | is-empty) {
      $playlists
      let index = input (echo-g "from which playlist you want to delete songs (index)?: ") | into int
      $playlists | get $index
    } else {
      $playlists | find -i $playlist
    }

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

  let playlists = $response 
    | get items 
    | select id snippet 
    | upsert snippet {|sn| 
        $sn.snippet.title
      }
    | rename -c {snippet: title}

  print (echo-g "selecting playlist to process...")
  let the_playlist = if ($playlist | is-empty) {
      $playlists
      let index = input (echo-g "from which playlist you want to remove duplicates (index)?: ") | into int
      $playlists | get $index
    } else {
      $playlists | find -i $playlist
    }

  print (echo-g "geting songs and droping duplicates...")
  let songs = yt-api get-songs $the_playlist.id

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
      let body = {  "snippet": {
              "playlistId": $"($the_playlist)",
              "resourceId": {
                "kind": "youtube#video",
                "videoId": $"($song.id)"
              }
            }
        }

      http post "https://www.googleapis.com/youtube/v3/playlistItems?part=snippet&key=($api_key)" -t 'application/json' -H ["Authorization", $"Bearer ($token)"] $body | ignore
      sleep 10ms
    } 

  print (echo-g "updating local database...")
  yt-api download-music-playlists
}

#verify if youtube api token has expired
export def "yt-api verify-token" [] {
  # Automatically fetch a valid token (refreshes if expired)
  let token = yt-get-access-token
  # Update the env with the new token
  $env.MY_ENV_VARS = $env.MY_ENV_VARS | upsert api_keys.youtube.token $token
}

## OAuth2 flow ##

# Function to save tokens to a file
def save-tokens [tokens: record] {
    $tokens | to json | save -f $env.TOKEN_FILE
    print "Tokens saved to ($env.TOKEN_FILE)"
}

# Function to load tokens from a file
def load-tokens [] {
    if ($env.TOKEN_FILE | path exists) {
        open $env.TOKEN_FILE
    } else {
        # Return an empty record if file doesn't exist
        {}
    }
}

# Function to check if token is expired (basic check, assumes 'expires_in' is seconds)
def is-token-expired [token_data?: record] {
    let token_data = if ($token_data | is-empty) {$in} else {$token_data}
    if ("expires_at" in $token_data) {
        let current_time = date now
        let expires_at = $token_data.expires_at | into datetime
        $current_time >= $expires_at
    } else {
        # If expires_at is not recorded, assume it's expired or needs refresh
        true
    }
}

# --- Main OAuth2 Functions ---

# Custom command to initiate the OAuth2 authorization flow
def yt-oauth-authorize [] {
    let client_id = $env.MY_ENV_VARS.api_keys.google.zed_mcp_server.client_id
    let redirect_uri = $env.MY_ENV_VARS.api_keys.google.zed_mcp_server.redirect_uris.0
    let GOOGLE_AUTH_URL = $env.MY_ENV_VARS.api_keys.google.zed_mcp_server.auth_uri
    let scope = "https://www.googleapis.com/auth/youtube.force-ssl https://www.googleapis.com/auth/youtube.upload https://www.googleapis.com/auth/userinfo.profile" # Adjust scopes as needed
    let state = random uuid

    let auth_url = $"($GOOGLE_AUTH_URL)?client_id=($client_id)&redirect_uri=($redirect_uri)&response_type=code&scope=($scope | url encode)&access_type=offline&prompt=consent&state=($state)"

    print $"Please open this URL in your browser to authorize:"
    print (echo-g $auth_url)
    # Await user to manually copy the URL and paste the redirect URL after authorization
    print "After authorizing, you will be redirected to a URL like 'http://localhost:8080/?code=YOUR_CODE&state=YOUR_STATE'."
    print (echo-g "Copy the entire URL from your browser's address bar and paste it here:")

    let redirect_response = input "Paste the redirect URL:"

    # Extract authorization code and state more robustly
    let parsed_url_components = $redirect_response | url parse
    let query_params_record = $parsed_url_components.query | from url

    let auth_code = $query_params_record.code
    let state_param = $query_params_record.state

    if ($state_param != $state) {
        return-error "CSRF state mismatch. Potential security risk. Aborting."
    }

    $auth_code
}

# Custom command to exchange authorization code for access and refresh tokens
def yt-oauth-exchange-code [auth_code: string] {
let client_id = $env.MY_ENV_VARS.api_keys.google.zed_mcp_server.client_id
let client_secret = $env.MY_ENV_VARS.api_keys.google.zed_mcp_server.client_secret
let redirect_uri = $env.MY_ENV_VARS.api_keys.google.zed_mcp_server.redirect_uris.0
let GOOGLE_TOKEN_URL = $env.MY_ENV_VARS.api_keys.google.zed_mcp_server.token_uri

    let body = {
        client_id: $client_id,
        client_secret: $client_secret,
        code: $auth_code,
        redirect_uri: $redirect_uri,
        grant_type: "authorization_code"
    }

    print "Exchanging authorization code for tokens..."
    let response = http post $GOOGLE_TOKEN_URL --headers { Content-Type: "application/json" } ($body | to json)
    
    let tokens = $response
    # Calculate expiration time
    let expires_at = (date now) + ($tokens.expires_in * 1sec)
    let full_tokens = $tokens | merge { expires_at: $expires_at }
    save-tokens $full_tokens
    print "Successfully obtained and saved new tokens."
    $full_tokens
}

# Custom command to refresh the access token using the refresh token
def yt-oauth-refresh-token [refresh_token: string] {
    let client_id = $env.MY_ENV_VARS.api_keys.google.zed_mcp_server.client_id
    let client_secret = $env.MY_ENV_VARS.api_keys.google.zed_mcp_server.client_secret
    let GOOGLE_TOKEN_URL = $env.MY_ENV_VARS.api_keys.google.zed_mcp_server.token_uri

    let body = {
        client_id: $client_id,
        client_secret: $client_secret,
        refresh_token: $refresh_token,
        grant_type: "refresh_token"
    }

    print "Refreshing access token..."
    let response = http post $GOOGLE_TOKEN_URL --headers { Content-Type: "application/json" } ($body | to json)

    if ($response.status_code == 200) {
        let new_tokens = $response.body | from json
        # Load existing tokens to preserve refresh_token if not returned in refresh response
        let existing_tokens = load-tokens
        let refresh_token_to_keep = if ("refresh_token" in $new_tokens) { $new_tokens.refresh_token } else { $existing_tokens.refresh_token }

        # Calculate expiration time for new access token
        let expires_at = (date now | format date "%s") + $new_tokens.expires_in
        let full_tokens = {
            access_token: $new_tokens.access_token,
            token_type: $new_tokens.token_type,
            expires_in: $new_tokens.expires_in,
            refresh_token: $refresh_token_to_keep,
            expires_at: $expires_at
        }
        save-tokens $full_tokens
        print "Successfully refreshed and saved new access token."
        $full_tokens
    } else {
        return-error $"Failed to refresh token: ($response.status_code) - ($response.body)"
    }
}

# Main function to get a valid access token, handling refresh automatically
export def yt-get-access-token [] {
    let tokens = load-tokens

    if ($tokens | is-empty) or ($tokens | is-token-expired) {
        print "No valid tokens found or token expired. Initiating authorization flow."
        let auth_code = yt-oauth-authorize
        let new_tokens = yt-oauth-exchange-code $auth_code
        $new_tokens.access_token
    } else {
        # print "Valid tokens found. Checking for refresh..."
        # Google access tokens typically last 1 hour, but refresh tokens can last indefinitely.
        # We check expiration on every call to be safe and refresh if needed.
        if ("refresh_token" in $tokens) and ($tokens | is-token-expired) {
            let refreshed_tokens = yt-oauth-refresh-token $tokens.refresh_token
            $refreshed_tokens.access_token
        } else if ("access_token" in $tokens) {
            # print "Using existing valid access token."
            $tokens.access_token
        } else {
            return-error "Something went wrong with token management. Please re-authorize."
        }
    }
}
