#backtracing errors
# $env.NU_BACKTRACE = 1

$env.CONSTANTS.pi = 3.141592653589793
$env.CONSTANTS.e = 2.718281828459045
$env.CONSTANTS.golden_ratio = 1.618033988749895
$env.CONSTANTS.gamma = 0.5772156649015329
$env.CONSTANTS.phi = 1.618033988749895
$env.CONSTANTS.silver_ratio = 2.41421356237309

let negative_prompt = "placeholder_negative_prompt"

#MY_ENV_VARS
$env.MY_ENV_VARS = {}

let is_windows = (sys host | get name | str lowercase) == "windows"

let base_linux = if $is_windows {
  r#'C:\Users\username\AppData\Roaming\nushell\linux'#
} else {
  ("~/scripts/linux" | path expand)
}

let base_yandex = if $is_windows {
  r#'C:\Users\username\AppData\Roaming\nushell\linux'#
} else {
  ("~/scripts" | path expand)
}

$env.MY_ENV_VARS = $env.MY_ENV_VARS
  | upsert backup (if $is_windows { $base_linux | path join ".." } else { "~/scripts/Backups" | path expand })
  | upsert linux_backup $base_linux
  | upsert nu_scripts ($base_yandex | path join "my_scripts" "nushell")
  | upsert python_scripts ($base_yandex | path join "my_scripts" "python")
  | upsert nu_scripts_public (if $is_windows { $base_yandex | path join "Development" "linux" "nushell" "nushell_scripts" } else { "~/nushell_scripts" | path expand })
  | upsert nushell_syntax_public (if $is_windows { $base_yandex | path join "Development" "linux" "sublime" "nushell_sublime_syntax" } else { "~/nushell_sublime_syntax" | path expand })
  | upsert credentials ($base_linux | path join "credentials")
  | upsert debs ($base_yandex | path join "Backups" "debs")
  | upsert gdrive_debs (if $is_windows { r#'G:\My Drive\Backup'# } else { "~/cloud/Backup" | path expand })
  | upsert mega_debs (if $is_windows { r#'M:\'# } else { "~/rclone/mega" | path expand })
  | upsert youtube_database ($base_linux | path join "youtube_music_playlists")
  | upsert ai_database ($base_yandex | path join "ai_database")
  | upsert appImages (if $is_windows { "" } else { $base_linux | path join ".." "appimages" })
  | upsert local_manga ($base_yandex | path join "Manga")
  | upsert external_manga (if $is_windows { r#'E:\Manga'# } else { "~/media/External_Drive/Manga" | path expand })
  | upsert zoom (if $is_windows { r#'C:\Users\username\Documents'# } else { "~/Documents" | path expand })
  | upsert mps ($base_yandex | path join "mps")
  | upsert dropbox (if $is_windows { r#'C:\Users\username\Dropbox'# } else { "~/Dropbox" | path expand })
  | upsert nushell_dir (if $is_windows { r#'C:\Users\username\AppData\Roaming\nushell'# } else { "~/software/nushell" | path expand })
  | upsert media_database (if $is_windows { r#'C:\Users\username\Dropbox\Media'# } else { "~/media" | path expand })
  | upsert ips ($base_linux | path join "ips.json")
  | upsert home_wifi "Home_WiFi"
  | upsert home_loc "0.000000,0.000000"
  | upsert work_wifi "Work_WiFi"
  | upsert work_loc "0.000000,0.000000"
  | upsert not_home_wifi "Mobile_Hotspot"
  | upsert mail "user@example.com"
  | upsert mail_ubb "user_work@example.com"
  | upsert mail_lmgg "user_personal@example.com"
  | upsert l_prompt "short"
  | upsert data ($base_yandex | path join "cards")
  | upsert download_dir ($base_yandex | path join "Downloads")
  | upsert gdriveTranscriptionSummaryDirectory (if $is_windows { r#'G:\My Drive\Notes'# } else { "~/cloud/notes" | path expand })
  | upsert gdrive_mount_point "cloud_drive"
  | upsert mega_mount_point "mega"
  | upsert llms_configs ($base_yandex | path join "llms_configs")
  | upsert chatgpt ($base_yandex | path join "ChatGpt")
  | upsert datasets ($base_yandex | path join "Downloads" "datasets")
  | upsert yandex_disk_repo "git@example.com:username/repo.git"
  | upsert tasker_server.devices.main.name "DEVICE_MAIN_ID"
  | upsert tasker_server.devices.main.file ($base_yandex | path join "devices" "main.json")
  | upsert tasker_server.devices.alfred1.name "DEVICE_SECONDARY_ID"
  | upsert tasker_server.devices.alfred1.file ($base_yandex | path join "devices" "secondary.json")
  | upsert mermaid_puppetter_config ([$base_linux "puppeteer.json"] | path join)
  | upsert pandoc_theme ([$base_linux "pandoc_highlight.theme"] | path join)
  | upsert ox_plugins ($base_linux | path join "ox" "plugins")
  | upsert api_keys {}
  | upsert negative_prompt $negative_prompt
  | upsert oracle_server_key ("~/.ssh/id_rsa" | path expand)
  | upsert habitica_avatar ($base_linux | path join "avatar.png")
  | upsert webapps ($base_yandex | path join "webapps")
  | upsert address "123 Main Street, City, Country"
  | upsert base_yandex $base_yandex
  | upsert OBSIDIAN_VAULT_ROOT ($base_yandex | path join "obsidian" "vaults")

$env.MY_ENV_VARS = $env.MY_ENV_VARS | upsert hosts (try { open $env.MY_ENV_VARS.ips | columns } catch { [] })

# default gemini model, initialized with default and updated dynamically by ai_google.nu export-env
$env.MY_ENV_VARS = $env.MY_ENV_VARS | upsert gemini_model_to_use ($env.MY_ENV_VARS.gemini_model_to_use? | default "gemini-3.7-flash")

# NU_LIB_DIRS configuration
let rich_dir = if $is_windows {
  r#'C:\Users\username\software\nu-rich'#
} else {
  ("~/software/nu-rich" | path expand)
}

let scripts_parent = if $is_windows {
  r#'C:\Users\username\AppData\Roaming\nushell\linux'#
} else {
  ($base_yandex | path join "my_scripts")
}

$env.NU_LIB_DIRS = (
  $env.NU_LIB_DIRS?
  | default []
  | append $env.MY_ENV_VARS.nu_scripts
  | append $scripts_parent
  | append $rich_dir
  | where { path exists }
  | uniq
)

#privateGPT
$env.PYENV_ROOT = $"($env.HOME)/.pyenv"

#bun and pnpm
$env.BUN_INSTALL = $env.HOME | path join ".bun"
$env.PNPM_HOME = if $is_windows { r#'C:\Users\username\AppData\Local\pnpm'# } else { "/home/username/.local/share/pnpm" }

#PATH
$env.PATH = (
  $env.PATH
  | split row (char esep)
  | prepend ('/usr/local/MATLAB/R2024b/bin' | path expand)
  | prepend ('/opt/MATLAB/R2024b/bin' | path expand)
  | prepend ('/usr/local/go/bin' | path expand)
  | prepend ('~/go/bin/' | path expand)
  | prepend ('~/.local/bin' | path expand)
  | prepend ($base_yandex | path join "my_scripts" "bash_for_nushell")
  | prepend ($base_yandex | path join "my_scripts" "r")
  | prepend ($"~/R/x86_64-pc-linux-gnu-library/(ls ~/R/x86_64-*/* | sort-by name | last | get name | split row "/" | last)/rush/exec" | path expand)
  | prepend '/usr/local/texlive/2022/bin/x86_64-linux'
  | prepend ('~/.cargo/bin' | path expand)
  | prepend $"($env.PYENV_ROOT)/bin"
  | prepend ('~/.fzf/bin/' | path expand)
  | prepend ('~/.atuin/bin/' | path expand)
  | prepend (if $is_windows { r#'C:\Users\username\.pyenv\pyenv-win\shims'# } else { "/home/username/.pyenv/shims" })
  | prepend (if $is_windows { r#'C:\Users\username\AppData\Roaming\nvm\v22.16.0'# } else { "/home/username/.nvm/versions/node/v22.16.0/bin" })
  | prepend ($env.BUN_INSTALL | path join "bin")
  | prepend $env.PNPM_HOME
  | prepend ("~/.opencode/bin" | path expand)
)

$env.PATH = $env.PATH | uniq | where {path exists}

$env.PWD_SIZE = ""
$env.GIT_STATUS = try {
  if (ls .git | length) > 0 and (git status -s | str length) > 0 {
    git status -s | lines | length
  } else {
    0
  }
} catch {
  0
}

$env.HOST = sys host | get hostname

# Default cloud icon (will be updated by hooks in config.nu)
$env.CLOUD = "f4ac"

$env.HOST_GLYPH = (
  if $env.HOST == ($env.MY_ENV_VARS.hosts? | get -o 0) {
      "eb06"
  } else if $env.HOST == ($env.MY_ENV_VARS.hosts? | get -o 1) {
      "f109"
  } else if $env.HOST == ($env.MY_ENV_VARS.hosts? | get -o 2) {
      "f4a9"
  } else if $env.HOST == ($env.MY_ENV_VARS.hosts? | get -o 3) {
      "f233"
  } else if $env.HOST == ($env.MY_ENV_VARS.hosts? | get -o 6) {
      "f15c9"
  } else if $env.HOST == ($env.MY_ENV_VARS.hosts? | get -o 8) {
      "f048b"
  } else {
      "f2c0"
  }
)

$env.PROMPT_COMMAND = {[
  (if $env.LAST_EXIT_CODE == 0 or ($env.LAST_EXIT_CODE | is-empty) {#color
    if TERMINUS_SUBLIME in $env {#in sublime-text
      (ansi -e { fg: '#000000' bg: '#00ff00'})
    } else {
      (ansi -e { fg: '#000000' bg: '#00ff00' attr: b })
    }
   } else {#not in sublime-text
    if TERMINUS_SUBLIME in $env {
      (ansi -e { fg: '#ffffff' bg: '#ff0000'})
    } else {
      (ansi -e { fg: '#ffffff' bg: '#ff0000' attr: b })
    }
   }
  )
  (let git_branch = (if ($env.GIT_BRANCH | is-not-empty) { [$"(char -u e0a0)" ($env.GIT_BRANCH)] | str join } else { "" });
   let git_ahead = (if $env.GIT_AHEAD > 0 { [$"(char -u f176)" ($env.GIT_AHEAD)] | str join } else { "" });
   # GIT_BEHIND set by pre_prompt hook in config.nu (same pattern as GIT_AHEAD et al.)
   let git_behind = (if $env.GIT_BEHIND > 0 { [$"(char -u f175)" ($env.GIT_BEHIND)] | str join } else { "" });
   let git_staged = (if $env.GIT_STAGED > 0 { [$"(char -u f12f1)" ($env.GIT_STAGED)] | str join } else { "" });
   let git_modified = (if $env.GIT_MODIFIED > 0 { [$"(char -u eafc)" ($env.GIT_MODIFIED)] | str join } else { "" });
   let git_deleted = (if $env.GIT_DELETED > 0 { [$"(char -u f12f1)" ($env.GIT_DELETED)] | str join } else { "" });
   let git_untracked = (if $env.GIT_UNTRACKED > 0 { [$"(char -u f1238)" ($env.GIT_UNTRACKED)] | str join } else { "" });
   let git_prompt = ([$git_branch $git_ahead $git_behind $git_staged $git_modified $git_deleted $git_untracked] | where ($it | is-not-empty) | str join "");
   
   if $env.PWD == $env.HOME {#in home, no expansion of prompt (left_prompt)
    if ($git_prompt | is-empty) {#if no git directory or clean
      [$"(char -u $env.CLOUD) (char -u $env.HOST_GLYPH) (char -u e0b3)" ($env.PWD_SIZE)] | str join
    } else {#if git directory with changes
      [$"(char -u $env.CLOUD) (char -u $env.HOST_GLYPH) (char -u e0b3)" ($env.PWD_SIZE) $git_prompt] | str join
    }
   } else {
    let separator = (if ("autouse.nu" | path exists) { $"(char -u f120)" } else { $"(char -u e0b1)" });
    if ($git_prompt | is-empty) {
      [$"(char -u $env.CLOUD) (char -u $env.HOST_GLYPH) (char -u e0b3)" ($env.PWD_SIZE) $separator (left_prompt)] | str join
    } else {
      [$"(char -u $env.CLOUD) (char -u $env.HOST_GLYPH) (char -u e0b3)" ($env.PWD_SIZE) $git_prompt $separator (left_prompt)] | str join
    }
   }
  )
  (ansi reset)] | str join
}

$env.MY_ENV_VARS.NETWORK.status = try {
      http get "https://www.google.com" | ignore;true
    } catch {
      false
    }

$env.MY_ENV_VARS.NETWORK.color = if $env.MY_ENV_VARS.NETWORK.status {'#00ff00'} else {'#ffffff'}

##green over black
$env.PROMPT_COMMAND_RIGHT = {||
  if (term size).columns >= 80 {
    [(if TERMINUS_SUBLIME in $env {
          (ansi -e { fg: $env.MY_ENV_VARS.NETWORK.color})
      } else {
          (ansi -e { fg: $env.MY_ENV_VARS.NETWORK.color attr: b})
      })
    $"(get_weather_by_interval 30min)"
    (ansi reset)
    (ansi -e { fg: '#00ff00'})
    (char -u e0b3)
    $"(($env.CMD_DURATION_MS | into float) / 1000 | math round -p 3)s"
    (ansi reset)]
    | str join
  }
}

$env.PROMPT_INDICATOR = {|| [
  (if $env.LAST_EXIT_CODE == 0 or ($env.LAST_EXIT_CODE | is-empty) {
    if TERMINUS_SUBLIME in $env {
      (ansi -e { fg: '#00ff00'})
    } else {
      (ansi -e { fg: '#00ff00' attr: b })
    }
   } else {
    if TERMINUS_SUBLIME in $env {
      (ansi -e { fg: '#ff0000'})
    } else {
      (ansi -e { fg: '#ff0000' attr: b })
    }
   }
  )
  $"(char -u e0b0) "
  (ansi reset)
  ] | str join
}

$env.BROWSER = "lynx" #reader

#for cmdg
$env.PAGER = "less"
$env.VISUAL = "ttt"

#for mermaid in pandoc
$env.PUPPETEER_EXECUTABLE_PATH = if $is_windows { r#'C:\Program Files\Google\Chrome\Application\chrome.exe'# } else { "/usr/bin/google-chrome" }

#carapace
$env.CARAPACE_LENIENT = 1
$env.CARAPACE_BRIDGES = 'zsh,fish,bash,inshellisense' # optional

#for yt-api authentication
$env.TOKEN_FILE = ($env.HOME | path join ".youtube_oauth_token.json")

# SDL3 custom path for scrcpy
let sdl3_pc_path = $env.HOME | path join "software/scrcpy/app/deps/work/install/linux-native-shared/lib/pkgconfig"
if ($sdl3_pc_path | path exists) {
    $env.PKG_CONFIG_PATH = ([$sdl3_pc_path ($env.PKG_CONFIG_PATH? | default "")] | str join (char esep))
}

#api_keys
use crypt.nu [open-credential]
use apis.nu [get-api-key]
$env.MY_ENV_VARS = $env.MY_ENV_VARS | upsert api_keys (try { open-credential -u ($env.MY_ENV_VARS.credentials | path join credentials.json.asc) } catch { {} })

$env.DC_API_KEY = (try { get-api-key "datacommons" } catch { "" })
$env.GEMINI_API_KEY = (try { get-api-key "google.gemini_paid" } catch { "" })
$env.GEMINI_CLI_WORKSPACE_FORCE_FILE_STORAGE = true #gemini-cli google workspace extension workaround

$env.LS_COLORS = "rs=0:di=01;34:ln=01;36:mh=00:pi=40;33:so=01;35:do=01;35:bd=40;33;01:cd=40;33;01:or=40;31;01:mi=00:su=37;41:sg=30;43:ca=30;41:tw=30;42:ow=34;42:st=37;44:ex=01;32:*.tar=01;31:*.tgz=01;31:*.arc=01;31:*.arj=01;31:*.taz=01;31:*.lha=01;31:*.lz4=01;31:*.lzh=01;31:*.lzma=01;31:*.tlz=01;31:*.txz=01;31:*.tzo=01;31:*.t7z=01;31:*.zip=01;31:*.z=01;31:*.dz=01;31:*.gz=01;31:*.lrz=01;31:*.lz=01;31:*.lzo=01;31:*.xz=01;31:*.zst=01;31:*.tzst=01;31:*.bz2=01;31:*.bz=01;31:*.tbz=01;31:*.tbz2=01;31:*.tz=01;31:*.deb=01;31:*.rpm=01;31:*.jar=01;31:*.war=01;31:*.ear=01;31:*.sar=01;31:*.rar=01;31:*.alz=01;31:*.ace=01;31:*.zoo=01;31:*.cpio=01;31:*.7z=01;31:*.rz=01;31:*.cab=01;31:*.wim=01;31:*.swm=01;31:*.dwm=01;31:*.esd=01;31:*.jpg=01;35:*.jpeg=01;35:*.mjpg=01;35:*.mjpeg=01;35:*.gif=01;35:*.bmp=01;35:*.pbm=01;35:*.pgm=01;35:*.ppm=01;35:*.tga=01;35:*.xbm=01;35:*.xpm=01;35:*.tif=01;35:*.tiff=01;35:*.png=01;35:*.svg=01;35:*.svgz=01;35:*.mng=01;35:*.pcx=01;35:*.mov=01;35:*.mpg=01;35:*.mpeg=01;35:*.m2v=01;35:*.mkv=01;35:*.webm=01;35:*.ogm=01;35:*.mp4=01;35:*.m4v=01;35:*.mp4v=01;35:*.vob=01;35:*.qt=01;35:*.nuv=01;35:*.wmv=01;35:*.asf=01;35:*.rm=01;35:*.rmvb=01;35:*.flc=01;35:*.avi=01;35:*.fli=01;35:*.flv=01;35:*.gl=01;35:*.dl=01;35:*.xcf=01;35:*.xwd=01;35:*.yuv=01;35:*.cgm=01;35:*.emf=01;35:*.ogv=01;35:*.ogx=01;35:*.aac=00;36:*.au=00;36:*.flac=00;36:*.m4a=00;36:*.mid=00;36:*.midi=00;36:*.mka=00;36:*.mp3=00;36:*.mpc=00;36:*.ogg=00;36:*.ra=00;36:*.wav=00;36:*.oga=00;36:*.opus=00;36:*.spx=00;36:*.xspf=00;36:*.txt=00;33:"
