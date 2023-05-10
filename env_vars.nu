let-env PATH = (
  $env.PATH 
  | each {|dir| 
      $dir 
      | split row ":"  
    } 
  | flatten
  | append whatYouNeed
  | uniq
)

# export MANPATH=$MANPATH:/usr/local/texlive/2022/texmf-dist/doc/man
# export INFOPATH=$INFOPATH:/usr/local/texlive/2022/texmf-dist/doc/info

let-env PWD_SIZE = ""
let-env GIT_STATUS = 0

let-env PROMPT_COMMAND = {|| [
  (if $env.LAST_EXIT_CODE == 0 or ($env.LAST_EXIT_CODE | is-empty) {
    (ansi -e { fg: '#000000' bg: '#00ff00' attr: b })
   } else {
    (ansi -e { fg: '#ffffff' bg: '#ff0000' attr: b })
   } 
  )
  (if $env.PWD == $env.HOME {
    if $env.GIT_STATUS == 0 {
      [$"(char -u f31b) " ($env.PWD_SIZE)] | str join
    } else {
      [$"(char -u f31b) " ($env.PWD_SIZE) $"(char -u eafc)" ($env.GIT_STATUS)] | str join
    }
   } else {
    if $env.GIT_STATUS == 0 {
      [$"(char -u f31b) " ($env.PWD_SIZE) $"(char -u e0b1)" (left_prompt)] | str join
    } else {
      [$"(char -u f31b) " ($env.PWD_SIZE) $"(char -u eafc)" ($env.GIT_STATUS) $"(char -u e0b1)" (left_prompt)] | str join 
    }
   } 
  )
  (ansi reset)] | str join
}

let-env NETWORK = {status:false, color: '#00ff00'}

##black over green
# let-env PROMPT_COMMAND_RIGHT = { 
#   if (term size).columns >= 80 {
#     [(ansi -e { fg: '#00ff00'})
#     (char -u e0b2)
#     (ansi reset)
#     (ansi -e { fg: '#000000' bg: '#00ff00' attr: b})
#     $"(get_weather_by_interval 30min)"
#     (ansi reset)
#     (ansi -e { fg: '#000000' bg: '#00ff00'})
#     (char -u e0b3)
#     $"(($env.CMD_DURATION_MS | into decimal) / 1000 | math round -p 3)s"
#     (ansi reset)]
#     | str join
#   } 
# }

##green over black
let-env PROMPT_COMMAND_RIGHT = {||
  if (term size).columns >= 80 {
    [(ansi -e { fg: $env.NETWORK.color attr: b})
    $"(get_weather_by_interval 30min)"
    (ansi reset)
    (ansi -e { fg: '#00ff00'})
    (char -u e0b3)
    $"(($env.CMD_DURATION_MS | into decimal) / 1000 | math round -p 3)s"
    (ansi reset)]
    | str join
  } 
}

let-env PROMPT_INDICATOR = {|| [
  (if $env.LAST_EXIT_CODE == 0 or ($env.LAST_EXIT_CODE | is-empty) {
    (ansi -e { fg: '#00ff00' attr: b })
   } else {
    (ansi -e { fg: '#ff0000' attr: b })
   } 
  )
  $"(char -u e0b0) "  
  (ansi reset)
  ] | str join 
}

let-env BROWSER = "lynx"

let-env LS_COLORS = "rs=0:di=01;34:ln=01;36:mh=00:pi=40;33:so=01;35:do=01;35:bd=40;33;01:cd=40;33;01:or=40;31;01:mi=00:su=37;41:sg=30;43:ca=30;41:tw=30;42:ow=34;42:st=37;44:ex=01;32:*.tar=01;31:*.tgz=01;31:*.arc=01;31:*.arj=01;31:*.taz=01;31:*.lha=01;31:*.lz4=01;31:*.lzh=01;31:*.lzma=01;31:*.tlz=01;31:*.txz=01;31:*.tzo=01;31:*.t7z=01;31:*.zip=01;31:*.z=01;31:*.dz=01;31:*.gz=01;31:*.lrz=01;31:*.lz=01;31:*.lzo=01;31:*.xz=01;31:*.zst=01;31:*.tzst=01;31:*.bz2=01;31:*.bz=01;31:*.tbz=01;31:*.tbz2=01;31:*.tz=01;31:*.deb=01;31:*.rpm=01;31:*.jar=01;31:*.war=01;31:*.ear=01;31:*.sar=01;31:*.rar=01;31:*.alz=01;31:*.ace=01;31:*.zoo=01;31:*.cpio=01;31:*.7z=01;31:*.rz=01;31:*.cab=01;31:*.wim=01;31:*.swm=01;31:*.dwm=01;31:*.esd=01;31:*.jpg=01;35:*.jpeg=01;35:*.mjpg=01;35:*.mjpeg=01;35:*.gif=01;35:*.bmp=01;35:*.pbm=01;35:*.pgm=01;35:*.ppm=01;35:*.tga=01;35:*.xbm=01;35:*.xpm=01;35:*.tif=01;35:*.tiff=01;35:*.png=01;35:*.svg=01;35:*.svgz=01;35:*.mng=01;35:*.pcx=01;35:*.mov=01;35:*.mpg=01;35:*.mpeg=01;35:*.m2v=01;35:*.mkv=01;35:*.webm=01;35:*.ogm=01;35:*.mp4=01;35:*.m4v=01;35:*.mp4v=01;35:*.vob=01;35:*.qt=01;35:*.nuv=01;35:*.wmv=01;35:*.asf=01;35:*.rm=01;35:*.rmvb=01;35:*.flc=01;35:*.avi=01;35:*.fli=01;35:*.flv=01;35:*.gl=01;35:*.dl=01;35:*.xcf=01;35:*.xwd=01;35:*.yuv=01;35:*.cgm=01;35:*.emf=01;35:*.ogv=01;35:*.ogx=01;35:*.aac=00;36:*.au=00;36:*.flac=00;36:*.m4a=00;36:*.mid=00;36:*.midi=00;36:*.mka=00;36:*.mp3=00;36:*.mpc=00;36:*.ogg=00;36:*.ra=00;36:*.wav=00;36:*.oga=00;36:*.opus=00;36:*.spx=00;36:*.xspf=00;36:*.txt=00;33:"

let-env MY_ENV_VARS = {}

let-env MY_ENV_VARS = (
  $env.MY_ENV_VARS 
  | upsert linux_backup "path"
  | upsert nu_scripts "path"
  | upsert credentials "path"
  | upsert debs "path"
  | upsert youtube_database "path"
  | upsert appImages "path"
  | upsert nushell_dir "path"
  | upsert media_database "path"
  | upsert home_wifi "home_wifi"
  | upsert google_calendars "cal1|cal2"
  | upsert google_calendars_full "cal1|cal2|cal3"
  | upsert mail "mail1"
  | upsert l_prompt "short"
  | upsert data "path"
  | upsert gdriveTranscriptionSummaryDirectory "path"
  | upsert chatgpt_config "path"
)

#for cmdg
let-env PAGER = "less"
let-env VISUAL = "nano"

#for chatgpt
let-env OPENAI_API_KEY = (
  open-credential -u ([$env.MY_ENV_VARS.credentials "credentials.open-ai.json.asc"] | path join) | get api_key
)