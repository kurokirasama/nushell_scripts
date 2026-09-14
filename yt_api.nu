#help info for yt-api
export def "yt-api help" [] {
  try { rich rule "YouTube Music & API Toolkit" --style "bold cyan" } catch { }
  let setup_info = [
    "[bold]1. Credentials Setup:[/]"
    "   - Ensure OAuth2 credentials exist in $env.MY_ENV_VARS.credentials"
    "   - Run `yt-api get-token` to authenticate"
    ""
    "[bold]2. Common Commands:[/]"
    "   - [bold cyan]yt-api[/]                     # Fetch raw YouTube API endpoints"
    "   - [bold cyan]yt-api get-songs[/]           # Download song metadata from playlist"
    "   - [bold cyan]yt-api update-all[/]          # Synchronize all local music databases"
    "   - [bold cyan]ytm[/]                        # Play tracks with terminal artwork"
    "   - [bold cyan]ytm --list[/]                 # Select a local playlist to stream"
  ]
  try {
    $setup_info | str join "\n" | rich panel --title "YouTube API Guide" --box rounded --border-style cyan
  } catch {
    print ($setup_info | str join "\n")
  }
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
      | str lowercase "artist"
      | where "artist" like ($artist | str lowercase)
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
      let card = try {
        $"Track: [bold cyan]($song.item.title)[/]\nArtist: [bold magenta]($song.item.artist)[/]\nProgress: [yellow](($song.index) + 1)/($len)[/]"
          | rich panel --title "Now Playing" --box rounded --border-style green
      } catch {
        (echo-g $"($song.item.title) | ($song.item.artist)\n[($song.index)/($len)]")
      }
      print $card
      
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
          | str lowercase "artist"
          | where "artist" like ($artist | str lowercase)
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
          let card = try {
            $"Track: [bold cyan]($song.item.title)[/]\nArtist: [bold magenta]($song.item.artist)[/]\nProgress: [yellow](($song.index) + 1)/($len)[/]"
              | rich panel --title "Now Playing (Online)" --box rounded --border-style green
          } catch {
            (echo-g $"now playing ($song.item.title) by ($song.item.artist) [($song.index)/($len)]...")
          }
          print $card

          ^mpv --msg-level=all=no --no-resume-playback --no-video --input-conf=($mpv_input) $song.item.url
        }    
    } else {
      return-error "playlist not found!"
    }
  }
}

const types = ["snippet", "status", "id"]
#youtube api implementation to get playlists and songs info
export def yt-api [
  type?:string@$types = "snippet" #type of query: id, status, snippet (export default)
  --pid:string      #playlist/song id
  --ptoken:string   #prev/next page token
] {
  # Automatically fetch a valid token
  let token = yt-get-access-token
  let youtube_credential = get-api-key "youtube"
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
        $"https://www.youtube.com/watch?v=($item.snippet.resourceId.videoId)"
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
  let youtube_credential = get-api-key "youtube"
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
  let youtube_credential = get-api-key "youtube"
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
  let youtube_credential = get-api-key "youtube"
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

# Verify if YouTube API token has expired and update environment
export def "yt-api verify-token" [account: string = "default"] {
  # Automatically fetch a valid token (refreshes if expired)
  let token = (yt-get-access-token $account)
  # Update the env with the new token
  $env.MY_ENV_VARS = ($env.MY_ENV_VARS | upsert api_keys.youtube.token $token)
}

## OAuth2 flow ##

# Resolves the token storage file path for the specified account.
def get-token-file [account: string = "default"] {
    if ($account == "default" or $account == "kurokirasama" or ($account | is-empty)) {
        $env.TOKEN_FILE? | default ($env.HOME | path join ".youtube_oauth_token.json")
    } else {
        $env.HOME | path join $".youtube_oauth_token_($account).json"
    }
}

# Function to save tokens to a file for a specific account
def save-tokens [tokens: record, account: string = "default"] {
    let file = (get-token-file $account)
    $tokens | to json | save -f $file
    print $"Tokens saved to ($file)"
}

# Function to load tokens from a file for a specific account
def load-tokens [account: string = "default"] {
    let file = (get-token-file $account)
    if ($file | path exists) {
        try { open $file } catch { {} }
    } else {
        {}
    }
}

# Function to check if token is expired
def is-token-expired [token_data?: record] {
    let token_data = if ($token_data | is-empty) { $in } else { $token_data }
    if ($token_data == null or ($token_data | is-empty)) {
        return true
    }
    if ("expires_at" in $token_data) {
        let current_time = (date now)
        let expires_at = try { $token_data.expires_at | into datetime } catch { return true }
        $current_time >= $expires_at
    } else {
        true
    }
}

# --- Main OAuth2 Functions ---

# Custom command to initiate the OAuth2 authorization flow
def yt-oauth-authorize [] {
    let client_id = (get-api-key "google.zed_mcp_server.client_id")
    let redirect_uri = (get-api-key "google.zed_mcp_server.redirect_uris.0")
    let GOOGLE_AUTH_URL = (get-api-key "google.zed_mcp_server.auth_uri")
    let scope = "https://www.googleapis.com/auth/youtube.force-ssl https://www.googleapis.com/auth/youtube.upload https://www.googleapis.com/auth/userinfo.profile"
    let state = (random uuid)

    let auth_url = $"($GOOGLE_AUTH_URL)?client_id=($client_id)&redirect_uri=($redirect_uri)&response_type=code&scope=($scope | url encode)&access_type=offline&prompt=consent&state=($state)"

    print "Please open this URL in your browser to authorize:"
    print (echo-g $auth_url)
    print "After authorizing, you will be redirected to a URL like 'http://localhost:8080/?code=YOUR_CODE&state=YOUR_STATE'."
    print (echo-g "Copy the entire URL from your browser's address bar and paste it here:")

    let redirect_response = (input "Paste the redirect URL:")

    let parsed_url_components = ($redirect_response | url parse)
    let query_params_record = ($parsed_url_components.query | from url)

    let auth_code = $query_params_record.code
    let state_param = $query_params_record.state

    if ($state_param != $state) {
        return-error "CSRF state mismatch. Potential security risk. Aborting."
    }

    $auth_code
}

# Custom command to exchange authorization code for access and refresh tokens
def yt-oauth-exchange-code [auth_code: string, account: string = "default"] {
    let client_id = (get-api-key "google.zed_mcp_server.client_id")
    let client_secret = (get-api-key "google.zed_mcp_server.client_secret")
    let redirect_uri = (get-api-key "google.zed_mcp_server.redirect_uris.0")
    let GOOGLE_TOKEN_URL = (get-api-key "google.zed_mcp_server.token_uri")

    let body = {
        client_id: $client_id,
        client_secret: $client_secret,
        code: $auth_code,
        redirect_uri: $redirect_uri,
        grant_type: "authorization_code"
    }

    print "Exchanging authorization code for tokens..."
    let response = try {
        http post $GOOGLE_TOKEN_URL --headers { Content-Type: "application/json" } ($body | to json)
    } catch { |err|
        return-error $"Failed to exchange authorization code: ($err.msg)"
    }
    
    let tokens = $response
    let expires_in_sec = ($tokens.expires_in? | default 3600 | into int)
    let expires_at = ((date now) + ($expires_in_sec * 1sec))
    let full_tokens = ($tokens | merge { expires_at: $expires_at })
    save-tokens $full_tokens $account
    print "Successfully obtained and saved new tokens."
    $full_tokens
}

# Custom command to refresh the access token using the refresh token
def yt-oauth-refresh-token [refresh_token: string, account: string = "default"] {
    let client_id = (get-api-key "google.zed_mcp_server.client_id")
    let client_secret = (get-api-key "google.zed_mcp_server.client_secret")
    let GOOGLE_TOKEN_URL = (get-api-key "google.zed_mcp_server.token_uri")

    let body = {
        client_id: $client_id,
        client_secret: $client_secret,
        refresh_token: $refresh_token,
        grant_type: "refresh_token"
    }

    let account_label = if ($account == "default" or $account == "kurokirasama") { "kurokirasama" } else { $account }
    print $"(ansi yellow)Refreshing access token for account: (ansi magenta_bold)($account_label)(ansi reset)..."
    let response = try {
        http post $GOOGLE_TOKEN_URL --headers { Content-Type: "application/json" } ($body | to json)
    } catch { |err|
        return-error $"Failed to refresh token: ($err.msg)"
    }

    let new_tokens = $response
    let existing_tokens = (load-tokens $account)
    let refresh_token_to_keep = if ("refresh_token" in $new_tokens) {
        $new_tokens.refresh_token
    } else {
        ($existing_tokens.refresh_token? | default $refresh_token)
    }

    let expires_in_sec = ($new_tokens.expires_in? | default 3600 | into int)
    let expires_at = ((date now) + ($expires_in_sec * 1sec))
    let full_tokens = {
        access_token: $new_tokens.access_token,
        token_type: ($new_tokens.token_type? | default "Bearer"),
        expires_in: $expires_in_sec,
        refresh_token: $refresh_token_to_keep,
        expires_at: $expires_at
    }
    save-tokens $full_tokens $account
    print $"(ansi green)Successfully refreshed access token for: (ansi magenta_bold)($account_label)(ansi reset)."
    $full_tokens
}

# Initiates interactive OAuth login and token exchange for a specified YouTube account.
#
# Examples:
#   yt-oauth-login           # Authorize default account (kurokirasama)
#   yt-oauth-login iesubb    # Authorize @iesubb channel account
export def yt-oauth-login [
    account: string = "default" # Target account identifier (default: "default")
] {
    let account_label = if ($account == "default" or $account == "kurokirasama") { "kurokirasama (Personal)" } else { $"($account) (Channel)" }
    try {
        rich rule $"YouTube OAuth Login: [bold magenta]($account_label)[/]" --style "bold cyan"
    } catch {
        print $"Initiating OAuth login for account: (ansi magenta_bold)($account_label)(ansi reset)"
    }

    let auth_code = (yt-oauth-authorize)
    let tokens = (yt-oauth-exchange-code $auth_code $account)
    let token_file = (get-token-file $account)

    try {
        $"[bold green]✓ Successfully authenticated account:[/] [bold magenta]($account_label)[/]\nToken file: [cyan]($token_file)[/]\nAccess token valid for: [bold yellow]1 hour[/] (auto-refreshes seamlessly via refresh token)"
        | rich panel --title $"OAuth Login Complete: ($account)" --box rounded --border-style green
    } catch {
        print $"(ansi green_bold)✓ Successfully logged in and saved tokens for account: (ansi magenta_bold)($account_label)(ansi reset)"
        print $"(ansi dark_gray)  Token file: ($token_file)(ansi reset)"
        print $"(ansi yellow)  Note: Access token valid for 1 hour, auto-refreshed via refresh token.(ansi reset)"
    }
    $tokens
}

# Gets a valid access token for YouTube API, refreshing automatically when expired.
#
# Examples:
#   yt-get-access-token         # Get token for default account (kurokirasama)
#   yt-get-access-token iesubb  # Get token for @iesubb channel account
export def yt-get-access-token [
    account: string = "default" # Target account identifier (default: "default")
] {
    let tokens = (load-tokens $account)

    # Case 1: No tokens saved yet -> must authorize
    if ($tokens | is-empty) {
        print $"No tokens found for account '(ansi magenta_bold)($account)(ansi reset)'. Initiating authorization flow."
        let auth_code = (yt-oauth-authorize)
        let new_tokens = (yt-oauth-exchange-code $auth_code $account)
        return $new_tokens.access_token
    }

    # Case 2: Access token exists and is not expired
    if ("access_token" in $tokens) and (not ($tokens | is-token-expired)) {
        return $tokens.access_token
    }

    # Case 3: Access token is expired but refresh token exists -> refresh without browser interaction
    if ("refresh_token" in $tokens) and not ($tokens.refresh_token | is-empty) {
        let refreshed = try {
            yt-oauth-refresh-token $tokens.refresh_token $account
        } catch { |err|
            print $"Token refresh failed for account '($account)': ($err.msg)"
            null
        }
        if ($refreshed != null) and ("access_token" in $refreshed) {
            return $refreshed.access_token
        }
    }

    # Case 4: Refresh token missing or expired -> fallback to authorization flow
    print $"Token expired and refresh failed for account '(ansi magenta_bold)($account)(ansi reset)'. Initiating authorization flow."
    let auth_code = (yt-oauth-authorize)
    let new_tokens = (yt-oauth-exchange-code $auth_code $account)
    $new_tokens.access_token
}

# Checks YouTube OAuth token status for personal or channel accounts.
#
# Examples:
#   yt-api status       # Check default account (kurokirasama)
#   yt-api status --ies # Check @iesubb channel account
export def "yt-api status" [
    --ies(-i) # Check @iesubb channel account instead of default (kurokirasama)
] {
    let account = if $ies { "iesubb" } else { "default" }
    let account_label = if $ies { "iesubb (IES UBB Channel)" } else { "kurokirasama (Personal)" }
    let login_cmd = if $ies { "yt-oauth-login iesubb" } else { "yt-oauth-login" }
    let token_file = (get-token-file $account)

    if not ($token_file | path exists) {
        try {
            $"[bold red]⚠ Token file missing for account:[/] [bold magenta]($account_label)[/]\nMissing file: [dim]($token_file)[/]\n\n[bold cyan]Action Required:[/] Run [bold yellow]($login_cmd)[/] to authenticate."
            | rich panel --title $"YouTube OAuth Alert: ($account_label)" --box rounded --border-style red
        } catch {
            print $"(ansi red_bold)⚠ YouTube OAuth Alert: Account '(ansi magenta_bold)($account_label)(ansi red_bold)' has NO token file!(ansi reset)"
            print $"(ansi yellow)  Missing file: ($token_file)(ansi reset)"
            print $"(ansi cyan_bold)  Action Required: Run '($login_cmd)' to authenticate.(ansi reset)"
        }
        return {
            account: $account_label
            token_file: $token_file
            exists: false
            valid: false
            expires_at: null
            action_required: $"Run: ($login_cmd)"
        }
    }

    let tokens = (load-tokens $account)
    let has_refresh = (("refresh_token" in $tokens) and not ($tokens.refresh_token | is-empty))
    let access_expired = ($tokens | is-token-expired)
    let expires_at = ($tokens.expires_at? | default "unknown")

    mut is_valid = false
    if $has_refresh {
        if not $access_expired {
            $is_valid = true
        } else {
            let refreshed = try {
                yt-oauth-refresh-token $tokens.refresh_token $account
            } catch {
                null
            }
            if ($refreshed != null) and ("access_token" in $refreshed) {
                $is_valid = true
            }
        }
    }

    if $is_valid {
        try {
            $"[bold green]✓ Account authenticated and valid:[/] [bold magenta]($account_label)[/]\nToken file: [dim]($token_file)[/]\nAccess token expires at: [yellow]($expires_at)[/]\n[dim green]Status: Ready for YouTube Data API v3 operations (auto-refreshes seamlessly)[/]"
            | rich panel --title $"YouTube OAuth: ($account_label)" --box rounded --border-style green
        } catch {
            print $"(ansi green_bold)✓ YouTube OAuth: Account '(ansi magenta_bold)($account_label)(ansi green_bold)' is authenticated and valid.(ansi reset)"
            print $"(ansi dark_gray)  Token file: ($token_file)(ansi reset)"
            print $"(ansi dark_gray)  Expires at: ($expires_at)(ansi reset)"
        }
        {
            account: $account_label
            token_file: $token_file
            exists: true
            valid: true
            expires_at: $expires_at
            action_required: null
        }
    } else {
        try {
            $"[bold red]⚠ Token EXPIRED or INVALID for account:[/] [bold magenta]($account_label)[/]\nToken file: [dim]($token_file)[/]\nExpired at: [yellow]($expires_at)[/]\n\n[bold cyan]Action Required:[/] Run [bold yellow]($login_cmd)[/] to re-authenticate."
            | rich panel --title $"YouTube OAuth Alert: ($account_label)" --box rounded --border-style red
        } catch {
            print $"(ansi red_bold)⚠ YouTube OAuth Alert: Account '(ansi magenta_bold)($account_label)(ansi red_bold)' token is EXPIRED or INVALID!(ansi reset)"
            print $"(ansi yellow)  Token file: ($token_file)(ansi reset)"
            print $"(ansi cyan_bold)  Action Required: Run '($login_cmd)' to re-authenticate.(ansi reset)"
        }
        {
            account: $account_label
            token_file: $token_file
            exists: true
            valid: false
            expires_at: $expires_at
            action_required: $"Run: ($login_cmd)"
        }
    }
}