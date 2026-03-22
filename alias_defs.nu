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
  yt set show_video True, set fullscreen False, set search_music False, set player mpv, set notifier notify-send, set order date, set user_order date, set playerargs default, set video_format webm, set ddir /home/kira/Yandex.Disk/mps, userpl kurokirasama
}

#adbtasker
export def adbtasker [] {
  adb -s ojprnfson7izpjkv tcpip 5555
  # adb shell pm grant com.fb.fluid android.permission.WRITE_SECURE_SETTINGS
}

#open gmail client (cmdg)
export def --env gmail [] {
  cd $env.MY_ENV_VARS.download_dir
  cmdg -shell "/home/kira/.cargo/bin/nu"
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
      let file = (
        match $type {
          "record" => {$file | get name | ansi strip},
          "string" => {$file | ansi strip}
        }
      )

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

const profiles = ["no-mcp", "minimal", "standard", "webui", "research", "googlesuit", "imagen", "full"]

#change gemini profile settings
#profiles:
# - no-mcp: none
# - minimal: nushell mcp + conductor, google-workspace extensions
# - standard: deepwiki, context7, grep, Ref, nushell, ollama-search, exa, bravesearch, firecrawl, sequentialthinking, markdonify mcp servers + conductor, google-workspace extensions
# - webui: standard + magicui mcp servers + gemini-cli-security, gemini-docs-ext extensions
# - research: standard + research-semantic-paper, research-paper mcp servers + datacommons, gemini-deep-research extensions
# - googlesuit: standard + google-forms, youtube mcp servers + datacommons, gemini-docs-ext extensions
# - imagen: standard + imagen mcp server + nanobanana extension
# - full: all mcp + all extensions
export def "gmn profile" [
	profile:string@$profiles = "standard"
	--list-mcp-servers-and-extensions(-l)
] {
  let settings = open ($env.MY_ENV_VARS.linux_backup | path join "settings_gemini.json")
  let mcp_servers = $settings | get mcpServers
  let mcp_names = $mcp_servers | columns | sort
  
  if $list_mcp_servers_and_extensions {
  	print (echo-g "mcp servers:")
   	print ($mcp_names)
    print (echo-g "extensions:")
    gemini -l
  	return
  }
  
  let servers = match $profile {
    "standard" => {$mcp_names | find standard -n},
    "webui" => {$mcp_names | find standard & webui -n},
    "research" => {$mcp_names | find standard & research -n},
    "googlesuit" => {$mcp_names | find standard & googlesuit -n},
    "imagen" => {$mcp_names | find standard & imagen -n},
    "no-mcp" => {[]},
    "minimal" => {$mcp_names | find nushell -n},
    "full" => {$mcp_names},
    _ => {return-error "Invalid profile"}
  }

  let filtered_servers = if ($servers | is-empty) { {} } else { $mcp_servers | select ...$servers }
  
  $settings | upsert mcpServers $filtered_servers | save -f ~/.gemini/settings.json
}

#wrapper for gemini cli
export def --wrapped gmn [
  ...rest
  --profile(-p):string@$profiles = "standard"
] {
  gmn profile $profile
  
  match $profile { 
    "standard" => {gemini --approval-mode=yolo --extensions "conductor,google-workspace" ...$rest},
    "webui" => {gemini --approval-mode=yolo --extensions "conductor,google-workspace,gemini-cli-security,gemini-docs-ext" ...$rest},
    "research" => {gemini --approval-mode=yolo --extensions "conductor,google-workspace,datacommons,gemini-deep-research" ...$rest},
    "googlesuit" => {gemini --approval-mode=yolo --extensions "conductor,google-workspace,datacommons,gemini-docs-ext" ...$rest},
    "imagen" => {gemini --approval-mode=yolo --extensions "conductor,google-workspace,nanobanana" ...$rest},
    "no-mcp" => {gemini --approval-mode=yolo ...$rest},
    "minimal" => {gemini --approval-mode=yolo --extensions "conductor,google-workspace" ...$rest},
    "full" => {gemini --approval-mode=yolo ...$rest},
    _ => {return-error "Invalid profile"}
  }
}

#wrapper for claude code
export def --wrapped cld [
  ...rest
] {
	^claude --dangerously-skip-permissions
}

export alias gtes = gtypist --colors 7,0 esp.typ
