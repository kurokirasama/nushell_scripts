#rm last
export def rml [] {
  ls | sort-by modified | last | rm-pipe
}

#tokei wrapper
export def tokei [] {
  ^tokei | grep -v '=' | from tsv
}

#keybindings
export def get-keybindings [] {
  $env.config.keybindings
}

#go to nu config dir
export def --env goto-nuconfigdir [] {
  $nu.config-path | goto
} 

#cores temp
export def coretemp [] {
  sensors 
  | grep Core
  | detect columns --no-headers  
  | reject column0 column3 
  | rename core temp
}

#battery stats
export def batstat [] {
  upower -i /org/freedesktop/UPower/devices/battery_BAT0 
  | lines 
  | find state & time & percentage 
  | str trim
  | split column ":" 
  | transpose -r -d 
  | str trim
}

#listen ports
export def listen-ports [] {
  sudo netstat -tunlp | detect columns
}

#ram info
export def ram [] {
  free -h
  | str replace ":" "" -a
  | from ssv 
  | rename type total used free 
  | select type used free total
}

#yewtube
export def ytcli [] {
  yt set show_video True, set fullscreen False, set search_music False, set player mpv, set notifier notify-send, set order date, set user_order date, set playerargs default, set video_format webm, set ddir ($env.MY_ENV_VARS.mps), userpl kurokirasama
}

#adbtasker
export def adbtasker [] {
  adb -s ojprnfson7izpjkv tcpip 5555
  # adb shell pm grant com.fb.fluid android.permission.WRITE_SECURE_SETTINGS
}

#open gmail client (cmdg)
export def --env gmail [] {
  cd $env.MY_ENV_VARS.download_dir
  try {
    cmdg -image_protocol auto -shell ($env.HOME | path join ".cargo" "bin" "nu")
  } catch {
    cmdg -shell ($env.HOME | path join ".cargo" "bin" "nu")
  }
}

#wrapper for mermaid diagrams
#
#Usage:
#   m -i file.mmd --other_mmcd_options -o pdf/png/svg
export def --wrapped m [
  ...rest #arguments for mmcd
  --output_format(-o):string = "pdf" #png, svg or pdf
] {
  let output = ($rest | str join "::" | split row '-i::' | get 1 | split row '::' | first | path parse | get stem) + "." + $output_format

  let pdfit = if $output_format == "pdf" {"--pdfFit"} else {[]}
  let rest = $rest ++ [$pdfit]
  mmdc -p $env.MY_ENV_VARS.mermaid_puppetter_config ...$rest -o $output -b transparent
}

#wrapper for timg
export def timg [
  file?
] {
  let file = get-input $in $file
  let type = $file | typeof

  match $type {
    "table" | "list" => {
      $file | each {|f| $f | timg}
    },
    _ => {
      let file = match $type {
          "record" => {$file | get name | ansi strip},
          "string" => {$file | ansi strip}
        }
      

      ^timg $file
    }
  }
}

#download subtitles via subliminal
export def --wrapped subtitle-downloader [
  file_pattern:glob
  ...rest
  --language(-l):string = "es"
] {
  subliminal download -l $language -s $file_pattern ...$rest
}

#terminal command screenshot
@example "saves the output of ls into output.svg" { ls | termshot }
export def termshot [
    output_file:string = "output"
] {
    termframe -o $"($output_file).svg" --theme dark-pastel --width (term size).columns --height (term size).rows --font-family "Monocraft Nerd Font" --bold-is-bright true --window-style compact
}

#kill mcp node servers running
export def killnode [] {
    psn node | find mcp & exte & gemini & skip | find -v vivaldi | killn
}

#paste text from clipboard
export def paste [] {
    if $env.XDG_CURRENT_DESKTOP == "gnome" {
        xsel --output --clipboard
    } else if $env.XDG_CURRENT_DESKTOP == "Hyprland" {
        wl-paste
    }
    
}

#netspeed graph
export def netspeed [] {
let host = sys host | get hostname
  
  let device = if ($host like $env.MY_ENV_VARS.hosts.2) or ($host like $env.MY_ENV_VARS.hosts.8) {
        sys net | where name =~ '^en' | get name.0
      } else {
        sys net | where name =~ '^wl' | get name.0
      }
      
    nload -u H -U H $device
}

const profiles = ["no-mcp", "minimal", "standard", "webdev", "research", "googlesuit", "imagen", "websearch", "full"]

const profile_plugins = {
    "standard": ["conductor", "google-workspace"],
    "webdev": ["conductor", "google-workspace", "gemini-cli-security", "gemini-docs-ext"],
    "research": ["conductor", "google-workspace", "datacommons", "gemini-deep-research"],
    "googlesuit": ["conductor", "google-workspace", "datacommons", "gemini-docs-ext"],
    "imagen": ["conductor", "google-workspace", "nanobanana"],
    "no-mcp": ["conductor"],
    "minimal": ["conductor", "google-workspace"],
    "websearch": ["conductor", "google-workspace"],
    "full": ["conductor", "google-workspace", "datacommons", "gemini-deep-research", "gemini-cli-security", "gemini-docs-ext", "nanobanana"]
}

# Change gemini profiles settings.
#
# Profiles:
# - no-mcp: no mcp + conductor extension
# - minimal: nushell + context-mode mcp, conductor, google-workspace extensions
# - standard: deepwiki, context7, grep, Ref, nushell, ollama-search, exa, bravesearch, firecrawl, sequentialthinking, markdonify mcp servers + conductor, google-workspace extensions
# - webdev: standard + magicui and crome-dev-tools mcp servers + gemini-cli-security, gemini-docs-ext extensions
# - research: standard + research-semantic-paper, research-paper mcp servers + datacommons, gemini-deep-research extensions
# - googlesuit: standard + google-forms, youtube mcp servers + datacommons, gemini-docs-ext extensions
# - imagen: standard + imagen mcp server + nanobanana extension
# - websearch: minimal + ollama-search, exa, bravesearch, firecrawl, sequentialthinking, markdonify mcp servers
# - full: all mcp + all extensions
#
# Example:
#   gmn profile standard
export def "gmn profile" [
        profile:string@$profiles = "standard"
        --matlab-mcp(-M) #add the matlab mcp server
        --list-mcp-servers-and-extensions(-l)
        --gemini-cli(-g) #use the legacy gemini-cli instead of antigravity-cli
] {
  let settings_file = if $gemini_cli { "settings_gemini.json" } else { "settings_antigravity.json" }
  let settings = open ($env.MY_ENV_VARS.linux_backup | path join $settings_file)
  let mcp_servers = $settings | get mcpServers
  let mcp_names = $mcp_servers | columns | sort
  
  if $list_mcp_servers_and_extensions {
    print (echo-g "mcp servers:")
    print ($mcp_names)
    if $gemini_cli {
      print (echo-g "extensions:")
      gemini -l
    } else {
      print (echo-g "plugins:")
      agy plugin list
    }
    return
  }
  
  let servers = match $profile {
    "standard" => {$mcp_names | find standard & context-mode -n},
    "webdev" => {$mcp_names | find standard & webdev & context-mode -n},
    "research" => {$mcp_names | find standard & research & context-mode -n},
    "googlesuit" => {$mcp_names | find standard & googlesuit & context-mode -n},
    "imagen" => {$mcp_names | find standard & imagen & context-mode -n},
    "no-mcp" => {[]},
    "minimal" => {$mcp_names | find nushell & context-mode -n},
    "websearch" => {$mcp_names | find nushell & context-mode & ollama-search & exa & bravesearch & firecrawl & sequentialthinking & markdonify & context-mode -n},
    "full" => {$mcp_names},
    _ => {return-error "Invalid profile"}
  }

  let servers = if $matlab_mcp {
    $servers ++ ($mcp_names | find -n matlab)
  } else {
    $servers
  }
  
  let filtered_servers = if ($servers | is-empty) { {} } else { $mcp_servers | select ...$servers }
  
  if $gemini_cli {
    # Update legacy settings.json
    let target = $env.HOME | path join .gemini settings.json
    mkdir ($target | path dirname)
    $settings | upsert mcpServers $filtered_servers | save -f $target
  } else {
    # Update mcp_config.json
    let mcp_config_path = $env.HOME | path join .gemini config mcp_config.json
    mkdir ($mcp_config_path | path dirname)
    { mcpServers: $filtered_servers } | save -f $mcp_config_path

    # Update antigravity-cli settings.json
    let settings_path = $env.HOME | path join .gemini antigravity-cli settings.json
    mkdir ($settings_path | path dirname)
    $settings | upsert mcpServers $filtered_servers | save -f $settings_path

    # Handle plugins (extensions)
    let plugins_to_enable = $profile_plugins | get $profile
    let all_plugins = $profile_plugins | get full

    for p in $all_plugins {
      if ($p in $plugins_to_enable) {
        try { agy plugin enable $p }
      } else {
        try { agy plugin disable $p }
      }
    }
  }
}

const gemini_models = [
  "gemini-3.5-flash"
  "gemini-3.1-pro"
  "gemini-3.1-flash-lite"
  "gemini-3-flash-preview"
  "gemini-2.5-flash"
  "gemini-2.0-flash"
]

#wrapper for antigravity cli
export def --wrapped gmn [
  ...rest
  --profile(-p):string@$profiles = "standard"
  --matlab-mcp(-M) #use the matlab mcp server
  --model(-m):string@$gemini_models #choose model
  --gemini-cli(-g) #use the legacy gemini-cli instead of antigravity-cli
] {
  if $matlab_mcp and $gemini_cli {
    gmn profile $profile --matlab-mcp --gemini-cli
  } else if $matlab_mcp {
    gmn profile $profile --matlab-mcp
  } else if $gemini_cli {
    gmn profile $profile --gemini-cli
  } else {
    gmn profile $profile
  }

  if $gemini_cli {
    let extensions = if $profile == "full" { [] } else { $profile_plugins | get $profile }

    let gemini_cmd = if ($model | is-not-empty) {
      if ($extensions | is-empty) {
        [gemini --model $model --approval-mode=yolo]
      } else {
        [gemini --model $model --approval-mode=yolo --extensions ($extensions | str join ",")]
      }
    } else {
      if ($extensions | is-empty) {
        [gemini --approval-mode=yolo]
      } else {
        [gemini --approval-mode=yolo --extensions ($extensions | str join ",")]
      }
    }

    ^$gemini_cmd.0 ...($gemini_cmd | skip 1) ...$rest
    return
  }

  let agy_cmd = if ($model | is-not-empty) {
    [agy --model $model --dangerously-skip-permissions]
  } else {
    [agy --dangerously-skip-permissions]
  }

  ^$agy_cmd.0 ...($agy_cmd | skip 1) ...$rest
}

#wrapper for claude code
export def --wrapped cld [
  ...rest
] {
	^claude --dangerously-skip-permissions
}

export alias gtes = gtypist --colors 7,0 esp.typ

#wrapper for cliamp
export def ytm2 [
        --local-youtube-playlist(-l) #select youtube playlist url from list, otherwise all liked music from local playlist
        --youtube-music(-m) #use cliamp builtin youtube music provider
        --youtube(-y) #use cliamp builtin youtube provider
] {
        let is_work = (sys host | get hostname) == "lgomez-desktop"
        let common = [--shuffle --visualizer Wave --eq-preset Rock --start-theme mine --auto-play --repeat all]

        if $youtube {
            if $is_work { ^cliamp-wrapper --provider youtube ...$common } else { ^cliamp --provider youtube ...$common }
            return
        }

        if $youtube_music {
            if $is_work { ^cliamp-wrapper --provider ytmusic ...$common } else { ^cliamp --provider ytmusic ...$common }
            return
        }

        let playlist = match $local_youtube_playlist {
                true => {
                        open ($env.MY_ENV_VARS.linux_backup | path join "youtube_music_playlists" | path join "youtube_playlists_urls.json")
                        | input list -fd name (echo-g "Select a playlist:")
                        | get url
                },
                false => {
                        $env.MY_ENV_VARS.linux_backup | path join "youtube_music_playlists" | path join "all_likes.m3u" 
                }
        }

        if $is_work { ^cliamp-wrapper $playlist ...$common } else { ^cliamp $playlist ...$common }
}
