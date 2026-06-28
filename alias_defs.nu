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

const profiles = ["no-mcp", "minimal", "standard", "webdev", "research", "googlesuit", "imagen", "websearch", "ollama", "full"]

const profile_plugins = {
    "standard": ["conductor", "google-workspace", "context-mode"],
    "webdev": ["conductor", "google-workspace", "gemini-cli-security", "gemini-docs-ext", "context-mode"],
    "research": ["conductor", "google-workspace", "context-mode"],
    "googlesuit": ["conductor", "google-workspace", "gemini-docs-ext", "context-mode"],
    "imagen": ["conductor", "google-workspace", "nanobanana", "context-mode"],
    "no-mcp": ["conductor"],
    "minimal": ["conductor", "google-workspace", "context-mode"],
    "websearch": ["conductor", "google-workspace", "context-mode"],
    "ollama": ["conductor", "google-workspace", "context-mode"],
    "full": ["conductor", "google-workspace", "gemini-cli-security", "gemini-docs-ext", "nanobanana", "context-mode"]
}

# Change gemini profiles settings.
#
# Profiles:
# - no-mcp: no mcp + conductor extension
# - minimal: nushell + context-mode mcp, conductor, google-workspace extensions
# - standard: deepwiki, context7, grep, Ref, nushell, ollama-search, exa, bravesearch, firecrawl, sequentialthinking, markdonify mcp servers + conductor, google-workspace extensions
# - webdev: standard + magicui and crome-dev-tools mcp servers + gemini-cli-security, gemini-docs-ext extensions
# - research: standard + research-semantic-paper, research-paper mcp servers, extensions
# - googlesuit: standard + google-forms, youtube mcp servers, gemini-docs-ext extensions
# - imagen: standard + imagen mcp server + nanobanana extension
# - websearch: minimal + ollama-search, exa, bravesearch, firecrawl, sequentialthinking, markdonify mcp servers
# - full: all mcp + all extensions
#
# Example:
#   gmn profile standard
export def --env "gmn profile" [
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
    "standard" => {$mcp_names | find standard & context-mode & google-workspace -n},
    "webdev" => {$mcp_names | find standard & webdev & context-mode & google-workspace -n},
    "research" => {$mcp_names | find standard & research & context-mode & google-workspace -n},
    "googlesuit" => {$mcp_names | find standard & googlesuit & context-mode & google-workspace -n},
    "imagen" => {$mcp_names | find standard & imagen & context-mode & google-workspace -n},
    "no-mcp" => {[]},
    "minimal" => {$mcp_names | find nushell & context-mode & google-workspace -n},
    "ollama" => {$mcp_names | find standard & context-mode & google-workspace -n},
    "websearch" => {$mcp_names | find nushell & context-mode & ollama-search & exa & bravesearch & firecrawl & sequentialthinking & markdonify & context-mode & google-workspace -n},
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

    # Copy hooks_agy.json from backup dir to config dir
    let hooks_src = $env.MY_ENV_VARS.linux_backup | path join "hooks_agy.json"
    let hooks_target = $env.HOME | path join .gemini config hooks.json
    if ($hooks_src | path exists) {
        mkdir ($hooks_target | path dirname)
        cp -f $hooks_src $hooks_target
    }

    # Handle plugins (extensions)
    let plugins_to_enable = $profile_plugins | get $profile
    let all_plugins = $profile_plugins | get full

    for p in $all_plugins {
      if ($p in $plugins_to_enable) {
        try { agy plugin enable $p }
        let agy_plugin_json_disabled = $env.HOME | path join .gemini antigravity-cli plugins $p plugin.json.disabled
        let agy_plugin_json = $env.HOME | path join .gemini antigravity-cli plugins $p plugin.json
        if ($agy_plugin_json_disabled | path exists) {
            try { mv $agy_plugin_json_disabled $agy_plugin_json }
        }
      } else {
        try { agy plugin disable $p }
        let agy_plugin_json = $env.HOME | path join .gemini antigravity-cli plugins $p plugin.json
        let agy_plugin_json_disabled = $env.HOME | path join .gemini antigravity-cli plugins $p plugin.json.disabled
        if ($agy_plugin_json | path exists) {
            try { mv $agy_plugin_json $agy_plugin_json_disabled }
        }
      }
    }
  }
}

# Switch opencode profile settings
export def --env "opn profile" [
    profile: string@$profiles = "standard"
    --matlab-mcp(-M) #add the matlab mcp server
    --list-mcp-servers-and-extensions(-l)
    --normal(-n) #use normal/free remote models instead of local ollama
] {
  let settings_file = "settings_opencode.json"
  let settings = open ($env.MY_ENV_VARS.linux_backup | path join $settings_file)
  let mcp_servers = $settings | get mcp
  let mcp_names = $mcp_servers | columns | sort
  
  if $list_mcp_servers_and_extensions {
    print (echo-g "opencode mcp servers:")
    print ($mcp_names)
    return
  }
  
  let servers = match $profile {
    "standard" => {$mcp_names | find standard & context-mode & google-workspace -n},
    "webdev" => {$mcp_names | find standard & webdev & context-mode & google-workspace -n},
    "research" => {$mcp_names | find standard & research & context-mode & google-workspace -n},
    "googlesuit" => {$mcp_names | find standard & googlesuit & context-mode & google-workspace -n},
    "imagen" => {$mcp_names | find standard & imagen & context-mode & google-workspace -n},
    "no-mcp" => {[]},
    "minimal" => {$mcp_names | find nushell & context-mode & google-workspace -n},
    "ollama" => {$mcp_names | find standard & context-mode & google-workspace -n},
    "websearch" => {$mcp_names | find nushell & context-mode & ollama-search & exa & bravesearch & firecrawl & sequentialthinking & markdonify & context-mode & google-workspace -n},
    "full" => {$mcp_names},
    _ => {return-error "Invalid profile"}
  }

  let servers = if $matlab_mcp {
    $servers ++ ($mcp_names | find -n matlab)
  } else {
    $servers
  }
  
  let filtered_mcp = if ($servers | is-empty) { {} } else { $mcp_servers | select ...$servers }

  # Host and Model Resolution
  let host_0 = $env.MY_ENV_VARS.hosts.0
  let host_1 = $env.MY_ENV_VARS.hosts.1

  let model_setup = if $normal {
    {
      model: "opencode/nemotron-3-ultra-free",
      small_model: "opencode/big-pickle"
    }
  } else if $env.HOST == $host_1 {
    {
      model: $settings.model,
      small_model: $settings.small_model
    }
  } else if $env.HOST == $host_0 {
    {
      model: "ollama/qwen3.5:4b",
      small_model: "ollama/qwen3.5:0.8b"
    }
  } else {
    print (echo-r "device with no opencode config")
    return-error "device with no opencode config"
  }

  # Build target configuration record
  # Ensure the selected model and small_model are populated under provider.ollama.models with 32k context overrides
  let config_base = $settings 
    | upsert mcp $filtered_mcp
    | upsert model $model_setup.model
    | upsert small_model $model_setup.small_model

  # Dynamically ensure qwen3.5:0.8b is defined if on host_0
  let final_config = if (not $normal) and ($env.HOST == $host_0) {
    let qwen_small = {
      id: "qwen3.5:0.8b"
      name: "qwen3.5:0.8b"
      limit: { context: 32768, output: 4096 }
      options: {
        extraBody: { num_ctx: 32768, options: { num_ctx: 32768 } }
      }
    }
    let models = $config_base | get provider.ollama.models | upsert "qwen3.5:0.8b" $qwen_small
    $config_base | upsert provider.ollama.models $models
  } else {
    $config_base
  }

  let opencode_config_path = $env.HOME | path join .config opencode opencode.json
  mkdir ($opencode_config_path | path dirname)
  $final_config | save -f $opencode_config_path
}

# Wrapper for opencode CLI
export def --env --wrapped opn [
  ...rest
  --profile(-p): string@$profiles = "standard"
  --matlab-mcp(-M) #use the matlab mcp server
  --model(-m): string #choose model
  --normal(-n) #use normal/free remote models instead of local ollama
] {
  if $normal and $matlab_mcp {
    opn profile $profile --normal --matlab-mcp
  } else if $normal {
    opn profile $profile --normal
  } else if $matlab_mcp {
    opn profile $profile --matlab-mcp
  } else {
    opn profile $profile
  }

  let opn_bin = $env.HOME | path join .opencode bin opencode
  
  let opn_cmd = if ($model | is-not-empty) {
    [$opn_bin --model $model --dangerously-skip-permissions]
  } else {
    [$opn_bin --dangerously-skip-permissions]
  }

  ^$opn_cmd.0 ...($opn_cmd | skip 1) ...$rest
}

const gemini_models = [
  "gemini-3.5-flash"
  "gemini-3.1-pro"
  "gemini-3.1-flash-lite"
  "gemini-3-flash-preview"
  "gemini-2.5-flash"
  "gemini-2.0-flash"
  "qwen2.5-coder:7b"
  "qwen2.5-coder:32b"
  "codestral"
  "llama3.1"
]

#wrapper for antigravity cli
export def --env --wrapped gmn [
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

# Change claude profiles settings.
#
# Profiles:
# - no-mcp: no mcp
# - minimal: nushell + context-mode mcp
# - standard: deepwiki, context7, grep, Ref, nushell, ollama-search, exa, bravesearch, firecrawl, sequentialthinking, markdonify mcp servers
# - webdev: standard + magicui and crome-dev-tools mcp servers
# - research: standard + research-semantic-paper, research-paper mcp servers
# - googlesuit: standard + google-forms, youtube mcp servers
# - imagen: standard + dalle
# - full: all mcp servers
#
# Example:
#   cld profile standard
export def --env "cld profile" [
        profile:string@$profiles = "standard"
        --matlab-mcp(-M) #add the matlab mcp server
] {
  let settings = open ($env.MY_ENV_VARS.linux_backup | path join "settings_claude.json")
  let mcp_servers = $settings.mcpServers
  let mcp_names = $mcp_servers | columns | sort
  
  let servers = match $profile {
    "standard" => {$mcp_names | find standard & context-mode & google-workspace -n},
    "webdev" => {$mcp_names | find standard & webdev & context-mode & google-workspace -n},
    "research" => {$mcp_names | find standard & research & context-mode & google-workspace -n},
    "googlesuit" => {$mcp_names | find standard & googlesuit & context-mode & google-workspace -n},
    "imagen" => {$mcp_names | find standard & imagen & context-mode & google-workspace -n},
    "no-mcp" => {[]},
    "minimal" => {$mcp_names | find nushell & context-mode & google-workspace -n},
    "ollama" => {$mcp_names | find standard & context-mode & google-workspace -n},
    "websearch" => {$mcp_names | find nushell & context-mode & ollama-search & exa & bravesearch & firecrawl & sequentialthinking & markdonify & context-mode & google-workspace -n},
    "full" => {$mcp_names},
    _ => {return-error "Invalid profile"}
  }

  let servers = if $matlab_mcp {
    $servers ++ ($mcp_names | find -n matlab)
  } else {
    $servers
  }

  let filtered_mcp = if ($servers | is-empty) { {} } else { $mcp_servers | select ...$servers }
  
  # Update Claude general settings
  let settings_path = $env.HOME | path join .claude settings.json
  mkdir ($settings_path | path dirname)
  $settings.claude_json_settings | save -f $settings_path

  # Update Claude MCP servers (preserving other keys like userID, OAuth, projects)
  let mcp_config_path = $env.HOME | path join .claude.json
  let current_mcp_config = if ($mcp_config_path | path exists) { open $mcp_config_path } else { {} }
  $current_mcp_config 
    | merge $settings.claude_json_settings 
    | upsert mcpServers $filtered_mcp 
    | save -f $mcp_config_path
  
  if $profile == "ollama" {
    $env.OPENAI_BASE_URL = "http://localhost:11434/v1"
    $env.OPENAI_API_KEY = "ollama"
  }

  print (echo-g $"Claude profile '($profile)' applied successfully.")
}

#wrapper for claude code
export def --env --wrapped cld [
  ...rest
  --profile(-p):string@$profiles = "standard"
  --matlab-mcp(-M) #use the matlab mcp server
] {
  if $matlab_mcp {
    cld profile $profile --matlab-mcp
  } else {
    cld profile $profile
  }
  ^claude --dangerously-skip-permissions ...$rest
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

# Switch to ollama profile for agents
export def "ollama profile" [] {
  gmn profile ollama
}

# Get installed ollama models
export def get-ollama-models [] {
  try {
    ollama list | tail -n +2 | awk "{print \$1}" | lines | where ($it | is-not-empty)
  } catch {
    []
  }
}

# Get info for a specific ollama model
export def get-ollama-model-info [model: string] {
  try {
    let raw = ollama show $model
    let context_len = $raw 
      | lines 
      | where $it =~ "context length" 
      | first 
      | str trim
      | split row -r "\\s+" 
      | last 
      | into int
    
    { context: $context_len }
  } catch {
    { context: 32000 } # default safe fallback
  }
}

# wrapper for ollama models using claude code integration
export def --env --wrapped olm [
  ...rest
  --profile(-p):string@$profiles = "standard"
  --matlab-mcp(-M) #use the matlab mcp server
  --model(-m): string # choose model
  --list(-l)         # list and select model from input list
] {
  if $matlab_mcp {
    cld profile $profile --matlab-mcp
  } else {
    cld profile $profile
  }

  let available_models = get-ollama-models
  
  let model = if $list {
    $available_models | input list -fd (echo-g "Select Ollama Model:")
  } else if ($model | is-not-empty) {
    $model
  } else {
    # Choose best available
    let priorities = ["rafw007/qwen35-claude-coder:9b","qwen3-coder:latest", "gemma4:12b", "gemma4:e4b", "gemma4:e2b"]
    let best = $priorities | where { |p| ($available_models | find $p | is-not-empty) } | first
    if ($best | is-not-empty) { $best } else { $available_models | first }
  }

  if ($model | is-empty) {
    print (echo-r "No Ollama models found.")
    return
  }

  let info = get-ollama-model-info $model
  let ctx = $info.context
  # Set output tokens to max possible (capped at 32k or context/2)
  let out_val = [($ctx / 4), 4096] | math max | into int
  let out = $out_val | into string

  let msg = ["Launching local agent with model: ", $model, " (Context: ", ($ctx | into string), ", Max Output: ", $out, ")"] | str join
  print (echo-g $msg)
  
  with-env {
    CLAUDE_CODE_MAX_OUTPUT_TOKENS: $out,
    CLAUDE_CODE_MAX_CONTEXT_TOKENS: ($ctx | into string),
    CLAUDE_CODE_DISABLE_THINKING: "1",
    MAX_THINKING_TOKENS: "0"
  } {
    # Use ollama launch to bridge claude to the local model
    ollama launch claude --model $model -- ...$rest
  }
}
