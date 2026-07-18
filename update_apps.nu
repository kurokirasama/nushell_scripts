#update nushell
export def "apps-update nushell" [
  --repo(-r)    #install from repo instead of cargo
  --force(-f)   #force cargo installation instead of update
] {
  print (echo-g "deleting plugins...")
  plugin list | get filename | each {|p| plugin rm $p}
  
  print (echo-g "updating nushell...")
  cd ~/software/nushell
  git pull
  
  if $repo {
    bash scripts/install-all-mcp.sh
  } else {
    if $force {
      # cargo install nu --locked --features=mcp
      cargo install nu --locked
    } else {
      cargo install-update nu 
    }
  }

  cargo clean

  print (echo-g "now restart nushell...")
}

#update nushell default plugins
export def "apps-update nushell-plugins" [
    --force(-f) #force the install
    --server(-s) #ignore polars in oracle server
] {
  if $force {
    cargo install nu_plugin_inc nu_plugin_gstat nu_plugin_query nu_plugin_formats
    if not $server {
      cargo install nu_plugin_polars --locked
    }
  } else {
    cargo install-update nu_plugin_inc nu_plugin_gstat nu_plugin_query 
    cargo install-update nu_plugin_formats --locked
    if not $server {
      cargo install-update nu_plugin_polars --locked
    }
  }

  print (echo-g "now run:")
  print ([
    "plugin add ~/.cargo/bin/nu_plugin_inc"
    "plugin add ~/.cargo/bin/nu_plugin_gstat"
    "plugin add ~/.cargo/bin/nu_plugin_query"
    "plugin add ~/.cargo/bin/nu_plugin_formats"
    "plugin add ~/.cargo/bin/nu_plugin_polars"
  ] | str join "\n")

  print (echo-g "then run:")
  print ([
    "plugin use ~/.cargo/bin/nu_plugin_inc"
    "plugin use ~/.cargo/bin/nu_plugin_gstat"
    "plugin use ~/.cargo/bin/nu_plugin_query"
    "plugin use ~/.cargo/bin/nu_plugin_formats"
    "plugin use ~/.cargo/bin/nu_plugin_polars"
  ] | str join "\n")
}

#update nushell 3rd party plugins
#
#nu_plugin_port_extension nu_plugin_plot
export def "apps-update nushell-plugins-external" [--force(-f)] {
  if $force {
    cargo install --git https://github.com/kurokirasama/nu_plugin_plot.git --force
    cargo install --git https://github.com/FMotalleb/nu_plugin_port_extension.git --force
  } else {
    cargo install --git https://github.com/kurokirasama/nu_plugin_plot.git
    cargo install --git https://github.com/FMotalleb/nu_plugin_port_extension.git
  }

  print (echo-g "now run:")
  print ([
    "plugin add ~/.cargo/bin/nu_plugin_port_extension"
    "plugin add ~/.cargo/bin/nu_plugin_plot"
  ] | str join "\n")

  print (echo-g "then run:")
  print ([
    "plugin use ~/.cargo/bin/nu_plugin_port_extension"
    "plugin use ~/.cargo/bin/nu_plugin_plot"
  ] | str join "\n")
  
  print (echo-g "updating config file...")
  update-nu-config
}

#update polars aliases
export def "apps-update nushell-polars" [] {
    rm -f ($env.MY_ENV_VARS.nu_scripts | path join "polars_aliases.nu")
    touch ($env.MY_ENV_VARS.nu_scripts | path join "polars_aliases.nu")
    
    scope commands 
    | where name like "polars" 
    | where type == "plugin"
    | get name 
    | skip
    | each {|p| 
        $"export alias \"($p | str replace 'polars' 'pl')\" = ($p)\n" 
        | save -a ($env.MY_ENV_VARS.nu_scripts | path join "polars_aliases.nu")
    }
}

#update nu config (after nushell update)
export def update-nu-config [] {
  #config
  let default = ls ($env.MY_ENV_VARS.nushell_dir + "/**/*" | into glob) 
      | find -in default_config 
      | get name
      | get 0
  
  cp -f $default $nu.config-path

  let append_file = if (sys host | get name | str lowercase) == "windows" { "append_to_config_win.nu" } else { "append_to_config.nu" }
  open ([$env.MY_ENV_VARS.linux_backup $append_file] | path join)
  | str replace kira $env.USER -a
  | save --append $nu.config-path

  #env
  let default = ls ($env.MY_ENV_VARS.nushell_dir + "/**/*" | into glob) 
      | find -in default_env 
      | get name
      | get 0

  cp -f $default $nu.env-path

  nu -c $"source-env ($nu.config-path)"
}

#patch font with nerd font
export def patch-font [file? = "Monocraft.ttc"] {
  let nerd_font = "~/software/nerd-fonts"
  let folder = $env.MY_ENV_VARS.appImages
  let font_folder = $env.MY_ENV_VARS.linux_backup
  
  cd $folder
 
  cp ($font_folder | path join "Monocraft.ttc" | path expand) .
 
  ./fontforge.AppImage -script ([$nerd_font font-patcher] | path join | path expand) ([$env.PWD $file] | path join) --complete --careful --output "Monocraft_updated.ttc" --outputdir $env.PWD
 
  mv -f (ls *.ttc | sort-by modified | last | get name) $"($file | path parse | get stem)-nerd-fonts-patched_by_me.ttc"
  cp -f $"($file | path parse | get stem)-nerd-fonts-patched_by_me.ttc" ($font_folder | path expand)
  mv -f $"($file | path parse | get stem)-nerd-fonts-patched_by_me.ttc" $file
 
  sudo mv -f $file /usr/local/share/fonts
  fc-cache -fv;sudo fc-cache -fv
  
  print (echo-g "Now run patch-font in other machines or run!")
  print (echo-g "cp Monocraft-nerd-fonts-patched_by_me.ttc ~/Downloads/Monocraft.ttc;cd ~/Downloads;install-font Monocraft.ttc")
}

#update-upgrade system
export def supgrade [--old(-o),--apps(-a),--cargo_aps(-c)] {
  if not $old {
    print (echo-g "updating and upgrading...")
    sudo nala upgrade -y

    print (echo-g "autoremoving...")
    sudo nala autoremove -y
  } else {
    print (echo-g "updating...")
    sudo apt update -y

    print (echo-g "upgrading...")
    sudo apt upgrade -y

    print (echo-g "autoremoving...")
    sudo apt autoremove -y
  }

  print (echo-g "updating rust...")
  rustup update

  print (echo-g "updating snap packages...")
  sudo snap refresh

  print (echo-g "updating stack...")
  stack upgrade

  if $cargo_aps {
    print (echo-g "updating cargo apps...")
    cargo install-update -a
  }

  if $apps {
    print (echo-g "updating off apt apps...")
    apps-update
  }

  # echo-g "upgrading pip3 packages..."
  # pip3-upgrade
}

#update off-package manager apps
export def apps-update [] {
  try {
    apps-update sejda
  } catch {
    print (echo-r "Something went wrong with sejda instalation!")
  }
  try {
    apps-update ttyplot
  } catch {
    print (echo-r "Something went wrong with ttyplot instalation!")
  }
  try {
    apps-update pandoc
  } catch {
    print (echo-r "Something went wrong with pandoc instalation!")
  }
  try {
    apps-update taskerpermissions
  } catch {
    print (echo-r "Something went wrong with taskerpermissions instalation!")
  }
  try {
    apps-update mpris
  } catch {
    print (echo-r "Something went wrong with mpris instalation!")
  }
  try {
    apps-update monocraft
  } catch {
    print (echo-r "Something went wrong with monocraft instalation!")
  }
  try {
    apps-update yandex
  } catch {
    print (echo-r "Something went wrong with yandex instalation!")
  }
  try {
    apps-update earth
  } catch {
    print (echo-r "Something went wrong with earth instalation!")
  }
  try {
    apps-update vivaldi
  } catch {
    print (echo-r "Something went wrong with vivaldi instalation!")
  }
  try {
   apps-update chrome
  } catch {
   print (echo-r "Something went wrong with chrome instalation!")
  }
  try {
    apps-update rtk
  } catch {
    print (echo-r "RTK update failed!")
  }
  # try {
  #   apps-update nmap
  # } catch {
  #   print (echo-r "Something went wrong with nmap instalation!")
  # }
  # try {
  #   apps-update join
  # } catch {
  #   print (echo-r "Something went wrong with taskerpermissions instalation!")
  # }
}

#get latest release info in github repo
export def get-github-latest [
  owner:string
  repo:string
  --file_type(-f):string = "deb"
  --pattern(-p):string
] {
  let git_token = get-api-key "github.api_key"

  let assets_url = {
      scheme: "https",
      host: "api.github.com",
      path: $"/repos/($owner)/($repo)/releases/latest",
    } 
    | url join
    | http get $in -H ["Authorization", $"Bearer ($git_token)"] -H ['Accept', 'application/vnd.github+json']
    | select assets_url tag_name

  let info = http get $assets_url.assets_url -H ["Authorization", $"Bearer ($git_token)"] -H ['Accept', 'application/vnd.github+json']
    | select name browser_download_url
    | upsert version $assets_url.tag_name
    | if ($pattern | is-not-empty) {
    	find -n $pattern
    } else {
    	find -n $file_type 
    }

  if ($info | length) > 0 {
    $info | if ($repo =~ "Monocraft") {
        where name == ($repo + ".ttc") | get 0
    } else {
        get 0
    }
  } else {
    []
  }
}

#update github app release
# if file doesnt have an extension, use the pattern flag
export def github-app-update [
  owner:string
  repo:string
  --file_type(-f):string = "deb"
  --down_dir(-d):string
  --pattern(-p):string
  --alternative_name(-a):string
  --version_from_json(-j)
] {
  let down_dir = if ($down_dir | is-empty) {$env.MY_ENV_VARS.debs} else {$down_dir}
  cd $down_dir

  let info = get-github-latest $owner $repo -f $file_type -p $pattern

  if ($info | is-empty) {return}

  let url = $info | get browser_download_url | ansi strip

  let app = if ($alternative_name | is-empty) {
      $repo
    } else {
      $alternative_name
    }

  let app_file = if $version_from_json {
     [$down_dir $"($app).json"] | path join
    } else {
      ""
    }

  let find_ = $info | get name | find _ | is-empty

  let new_version = if $version_from_json {
      $info | get version
    } else {
      $info 
      | get name
      | path parse
      | get stem
      | split row (if not $find_ {"_"} else {"-"}) 
      | get 1
    }
  
  let exists = (ls | find $app | if ($pattern | is-not-empty) {find -n $pattern} else {find $file_type} | length) > 0

  if $exists {
    let current_version = if $version_from_json {
        open --raw $app_file 
        | from json
        | get version
      } else {
        if ($pattern | is-not-empty) {
        	ls | find -n $pattern
        } else {
        	ls ($"*.($file_type)" | into glob)
        }
        | find -n $app
        | get 0 
        | get name
        | path parse
        | get stem
        | split row (if not $find_ {"_"} else {"-"}) 
        | get 1
      }

    if $current_version == $new_version {
      print (echo-g $"($repo) is already in its latest version!")
      return
    }

    print (echo-g $"\nupdating ($repo)...")
    if ($pattern | is-not-empty) {
      rm $app | ignore
    } else {
      rm ($"*.($file_type)" | into glob) | ignore
    }
    aria2c --download-result=hide $url
    
    if $version_from_json {
      open --raw $app_file
      | from json 
      | upsert version $new_version 
      | save -f $app_file
    }

    if $file_type != "deb" {
      print (echo-g "file downloaded...")
      return
    }

    if ($pattern | is-empty) {
      let install = input (echo-g "Would you like to install it now? (y/n): ")
      if $install == "y" {
        sudo gdebi -n ($info.name | ansi strip)
      }
      return
    }

    let install = input (echo-g "Would you like to install it now? (y/n): ")
    if $install == "y" {
      sudo gdebi -n ($info.name | ansi strip)
    }
    return
  } 
  
  print (echo-g $"\ndownloading ($repo)...")
  aria2c --download-result=hide $url

  if $file_type == "deb" {
    let install = input (echo-g "Would you like to install it now? (y/n): ")
    if $install == "y" {
      sudo gdebi -n ($info.name | ansi strip)
    }
  }
}



#update pandoc deb
export def "apps-update pandoc" [] {
  github-app-update jgm pandoc
}

#update pandoc cross-ref
export def "apps-update pandoc-cross-ref" [] {
  cd ~/software/pandoc-crossref
  try {
    git pull
    stack install
  } catch {
    cd ~/software
    rm -rf pandoc-crossref
    git clone https://github.com/lierdakil/pandoc-crossref.git
    cd pandoc-crossref
    stack install
  }
}

#update tasker helper deb
export def "apps-update taskerpermissions" [] {
  github-app-update joaomgcd Tasker-Permissions -a taskerpermissions
}

#update mpris (for mpv)
export def "apps-update mpris" [] {
  github-app-update hoyon mpv-mpris -f so -d ([$env.MY_ENV_VARS.linux_backup "scripts"] | path join) -a mpris -j
}
  
#update monocraft font
export def "apps-update monocraft" [
  --to-patch(-p) = true     #to patch Monocraft.otf, else to use patched ttf
  --type(-t):string = "ttc"  #"otf" if -p, else "ttf"
] {
  let current_version = open --raw ([$env.MY_ENV_VARS.linux_backup Monocraft.json] | path join) 
    | from json 
    | get version
  
  
  github-app-update IdreesInc Monocraft -f $type -d $env.MY_ENV_VARS.linux_backup -j
  
  let new_version = open ([$env.MY_ENV_VARS.linux_backup Monocraft.json] | path join) | get version

  if $current_version == $new_version {
    return
  }

  if $to_patch {
    print (echo-g "New version of Monocraft downloaded, now patching nerd fonts...")
    patch-font
  } else {
    let font = [$env.MY_ENV_VARS.linux_backup (ls ($"($env.MY_ENV_VARS.linux_backup)/*.($type)" | into glob) | sort-by modified | last | get name | ansi strip)] | path join
    print (echo-g $"New version of Monocraft downloaded, now installing ($font | path parse | get stem)...")
    install-font $font
  }
}

#update chrome deb
export def "apps-update chrome" [] {
  cd $env.MY_ENV_VARS.debs

  if (ls *.deb | find chrome | length) > 0 {
    ls *.deb | find chrome | rm-pipe | ignore
  }
  
  print (echo-g "\ndownloading chrome...")
  aria2c --download-result=hide https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
}

#update google earth deb
@category sudo
export def "apps-update earth" [] {
  cd $env.MY_ENV_VARS.debs

  let new_version = http get "https://support.google.com/earth/answer/40901#zippy=%2Cearth-version" 
    | query web -q a 
    | find -n version 
    | first
  

  let current_version = open ([$env.MY_ENV_VARS.debs earth.json] | path join) | get version

  if $current_version == $new_version {
    print (echo-g "earth is already in its latest version!")
    return
  }
  
  if (ls *.deb | find earth | length) > 0 {
    ls *.deb | find earth | rm-pipe | ignore
  }
  
  print (echo-g "\ndownloading google earth...")
  aria2c --download-result=hide https://dl.google.com/dl/earth/client/current/google-earth-pro-stable_current_amd64.deb

  sudo gdebi -n google-earth-pro-stable_current_amd64.deb
}

#update yandex deb
@category sudo
export def "apps-update yandex" [] {
  cd $env.MY_ENV_VARS.debs

  let file = [$env.MY_ENV_VARS.debs yandex.json] | path join
  
  let new_date = http get http://repo.yandex.ru/yandex-disk/?instant=1 
    | lines 
    | find amd64 
    | get 0 
    | split row </a> 
    | last 
    | str trim 
    | split row " " 
    | first 2 
    | str join " " 
    | into datetime
  

  let old_date = open $file | get date | into datetime

  if $old_date >= $new_date {
    print (echo-g "yandex is already in its latest version!")
    return
  }

  if (ls *.deb | find yandex | length) > 0 {
    ls *.deb | find yandex | rm-pipe | ignore
  }
  
  if (ls *.rpm | find yandex | length) > 0 {
    ls *.rpm | find yandex | rm-pipe | ignore
  }

  print (echo-g "\ndownloading yandex...")
  aria2c --download-result=hide http://repo.yandex.ru/yandex-disk/yandex-disk_latest_amd64.deb
  aria2c --download-result=hide https://repo.yandex.ru/yandex-disk/yandex-disk-latest.x86_64.rpm

  sudo gdebi -n yandex-disk_latest_amd64.deb 

  open $file 
  | upsert date (date now | format date) 
  | save -f $file
}

#update sejda deb
@category sudo
export def "apps-update sejda" [] {
  cd $env.MY_ENV_VARS.debs

  let new_file = http get https://www.sejda.com/es/desktop 
    | lines 
    | find -n linux 
    | find -n deb 
    | find -n sejda
    | str trim 
    | str replace -a "\'" "" 
    | split row ': ' 
    | str replace "," ""
    | get 1
  

  let new_version = $new_file | split row _ | get 1

  let url = $"https://downloads.sejda-cdn.com/($new_file)"

  let sedja = (ls *.deb | find sejda | length) > 0

  if $sedja {
    let current_version = ls *.deb 
      | find -i "sejda" 
      | get 0 
      | get name 
      | split row _ 
      | get 1
    

    if $current_version == $new_version {
      print (echo-g "sedja is already in its latest version!")
      return
    }
    
    print (echo-g "\nupdating sedja...")
    rm sejda*.deb | ignore
    aria2c --download-result=hide $url
    sudo gdebi -n $new_file
  } else {
    print (echo-g "\ndownloading sedja...")
    aria2c --download-result=hide $url
    sudo gdebi -n $new_file
  }
}

#update ttyplot
@category sudo
export def "apps-update ttyplot" [] {
  cd $env.MY_ENV_VARS.debs

  let current_version = ls 
    | find -n tty 
    | get name 
    | get 0
    | split row _ 
    | get 1
  
  let url = http get https://packages.debian.org/sid/amd64/ttyplot/download
    | lines 
    | find ".deb"
    | find http 
    | find ttyplot 
    | first 
    | split row "href=\""
    | last 
    | split row "\">"
    | find ttyplot
    | first
    | ansi strip

  let filename = $url | split row / | last

  let new_version = $filename | split row _ | get 1

  if $current_version == $new_version {
    print (echo-g "ttyplot is already in the latest version!")
    return
  }
    
  print (echo-g $"\nupdating ttyplot...")

  ls *.deb | find ttyplot | rm-pipe
  aria2c --download-result=hide $url

  sudo gdebi -n $filename
}

#update vivaldi
export def "apps-update vivaldi" [] {
  cd $env.MY_ENV_VARS.debs
  
  let release_url = http get "https://vivaldi.com/download/"
    | query web -q .download-link -a href 
    | find -n deb 
    | find -n amd64 
    | get 0
  

  if ($release_url | is-empty) {
    return-error "no releases found!"
  }

  let last_version = $release_url 
    | split row _ 
    | get 1
  

  if (ls | find vivaldi | length) == 0 {
    aria2c --download-result=hide $release_url
    return 
  } 

  let current_version = ls 
    | where name like vivaldi 
    | get 0 
    | get name 
    | split row _ 
    | get 1
  

  if $current_version == $last_version {
    print (echo-g "vivaldi is already in its latest version!")
    return
  }
  
  ls | find vivaldi | find deb | rm-pipe | ignore

  print (echo-g "\ndownloading vivaldi...")
  aria2c --download-result=hide $release_url
}

#update cmdg
export def "apps-update cmdg" [
  --official # Clone the official repository
  --mine # Clone the personal fork
] {
  if ($official and $mine) or (not $official and not $mine) {
    error make {msg: "Error: You must specify either --official or --mine."}
  }

  let base_dir = ($env.APPS_UPDATE_SOFTWARE_DIR? | default "~/software" | path expand)
  let target_dir = ($base_dir | path join "cmdg")
  let target_render_dir = ($base_dir | path join "cmdg-image-render")
  let repo_url = if $mine { "https://github.com/kurokirasama/cmdg" } else { "https://github.com/ThomasHabets/cmdg.git" }
  let target_sub = if $mine { "kurokirasama/cmdg" } else { "ThomasHabets/cmdg" }

  # 1. Install or Update cmdg
  if ($target_dir | path exists) {
    let current_url = (do {
      cd $target_dir
      git remote get-url origin
    } | complete | get stdout | str trim)

    if ($current_url | str contains $target_sub) {
      cd $target_dir
      git pull
    } else {
      print (echo-g $"Repository mismatch in ($target_dir). Deleting and re-cloning...")
      rm -rf $target_dir
      cd $base_dir
      git clone $repo_url
    }
  } else {
    print (echo-g "cmdg not found, cloning and installing...")
    cd $base_dir
    git clone $repo_url
  }

  cd $target_dir
  go install ./cmd/cmdg
  print (echo-g "cmdg updated.")

  # 2. Install or Update cmdg-image-render
  if (not ($target_render_dir | path exists)) {
    print (echo-g "cmdg-image-render not found, cloning and installing...")
    cd $base_dir
    git clone git@github.com:kurokirasama/cmdg-image-render.git
  }
  cd $target_render_dir
  git pull
  go install ./cmd/cmdg-image-render
  print (echo-g "cmdg-image-render updated.")
}


#upgrade pip3 packages
export def pip3-upgrade [] {
  pip3 list --outdated --format=freeze 
  | lines 
  | split column "==" 
  | each {|pkg| 
      print (echo-g $"upgrading ($pkg.column1)...")
      pip3 install --upgrade $pkg.column1
    }
}

#install font
export def install-font [file] {
  sudo cp -f $file /usr/local/share/fonts
  fc-cache -fv;sudo fc-cache -fv
}

#update maestral
export def "apps-update maestral" [] {
  pipx upgrade maestral
}

#update whisper
export def "apps-update whisper" [] {
  if (sys host | get os_version) == "20.04" {
    pip install --upgrade --no-deps --force-reinstall git+https://github.com/openai/whisper.git
  } else {
    pipx install git+https://github.com/openai/whisper.git --force
  }
}

#update yewtube
export def "apps-update yewtube" [] {
    pipx upgrade yewtube
}

#update yt-dlp (youtube-dl fork)
export def "apps-update yt-dlp" [] {
  pipx upgrade yt-dlp
}

#update nchat (wsp)
@category sudo
export def "apps-update nchat" [] {
  try {sudo rm (which nchat | get path | get 0)}
  cd ~/software/nchat
  git pull
  
  ^mkdir -p build; cd build; cmake -DHAS_WHATSAPP=ON -DHAS_TELEGRAM=OFF ..; make -s
  sudo make install
  cd ~/software/nchat
  sudo rm -rf build/
}

#update ffmpeg with cuda
@category sudo
export def "apps-update myffmpeg" [--force(-f)] {
  cd ~/software/nvidia/nv-codec-headers
  let pull = git pull

  if $pull != "Already up to date." or $force {
    print (echo-g "updating nv-codec-headers...")
    git pull
    sudo make install
  } else {
    echo-g "nv-codec-headers already up to date!"
  }

  cd ~/software/nvidia/ffmpeg
  let pull = git pull

  if $pull == "Already up to date." and (not $force) {
    print (echo-g "ffmpeg already up to date!")
    return
  }

  print (echo-g "updating ffmpeg...")
  git pull
  ./configure --enable-nonfree --enable-cuda-nvcc --enable-libnpp --enable-gpl --enable-libx264 --enable-libx265 --extra-cflags=-I/usr/local/cuda/include --extra-ldflags=-L/usr/local/cuda/lib64
  bash -c "make -j $(nproc)"
  ./ffmpeg -h
}

#update claude cli
export def "apps-update claude" [] {
  npm update -g @anthropic-ai/claude-code
}

#update claude cli
export def "apps-update mermaid-ascii" [] {
  npm update -g @mermaid-js/mermaid-cli
}

#update open-codex
export def "apps-update open-codex" [] {
  npm update -g open-codex
}

#update mermaid filter
export def "apps-update mermaid-filter" [] {
  npm install --global mermaid-filter
}

#update mermaid-cli
export def "apps-update mermaid-cli" [] {
  npm update -g @mermaid-js/mermaid-cli
}

#update fast-cli
export def "apps-update fast-cli" [] {
  npm update -g fast-cli
}

#update tldr
export def "apps-update tldr" [] {
  npm update -g tldr
}

#update ddgr (gg)
@category sudo
export def "apps-update ddgr" [] {
  cd ~/software/ddgr
  git pull
  sudo make install
}

#update rclone
@category sudo
export def "apps-update rclone" [] {
  bash -c "sudo -v ; curl -s# https://rclone.org/install.sh | sudo bash"
}

#update matlab lsp server
export def "apps-update matlab-lsp" [] {
  cd ~/software/MATLAB-language-server
  git reset --hard
  git pull 
  npm install
  npm run compile
  npm run package
}

#update glow
export def "apps-update glow" [] {
  go install github.com/charmbracelet/glow@latest
}

#update obsidian
export def "apps-update obsidian" [] {
  github-app-update obsidianmd obsidian-releases -a obsidian
}

#update ox
export def "apps-update ox" [] {
  cargo install --git https://github.com/curlpipe/ox ox
}

#update rustc
export def "apps-update rustc" [] {
  rustup default stable-x86_64-unknown-linux-gnu
  rustup override set stable-x86_64-unknown-linux-gnu
  rustup update
  # rustup self uninstall
}

#update ollama
export def "apps-update ollama" [] {
  curl -fsSL https://ollama.com/install.sh | sh
}

#update open-code
export def "apps-update open-code" [] {
  let old_version = try { (^opencode --version | str trim) } catch { "not installed" }
  print $"Current OpenCode version: ($old_version)"
  
  print "Updating OpenCode..."
  bash -c "curl -fsSL https://opencode.ai/install | bash"
  
  let new_version = try { (^opencode --version | str trim) } catch { "install failed" }
  print $"New OpenCode version: ($new_version)"
}
#update rtk (AI orchestrator)
export def "apps-update rtk" [
  --force(-f)   #force reinstall even if same version
  --skip-init   #skip agent re-initialization after update
] {
  let arch = (^uname -m | str trim)
  let target = if $arch == "x86_64" {
    "x86_64-unknown-linux-musl"
  } else if $arch == "aarch64" {
    "aarch64-unknown-linux-gnu"
  } else {
    error make {msg: $"Unsupported architecture: ($arch)"}
  }

  let current_version = try {
    (^rtk --version | str trim | split row " " | last)
  } catch {
    error make {msg: "RTK is not installed. Run the install script first."}
  }

  print $"Current RTK version: ($current_version)"

  let latest_info = try {
    http get https://api.github.com/repos/rtk-ai/rtk/releases/latest -H [Accept, application/vnd.github+json]
  } catch { |err|
    error make {msg: $"Failed to fetch latest version: ($err.msg)"}
  }

  let latest_version = ($latest_info | get tag_name | str trim -c "v")
  print $"Latest RTK version: ($latest_version)"

  if not $force {
    let sorted = [($current_version | into semver), ($latest_version | into semver)] | sort | each { into string }
    if $sorted.1 == $current_version {
      print (echo-g "RTK is already at the latest version!")
      return
    }
  }

  print (echo-g $"Updating RTK to v($latest_version)...")
  let temp_dir = (^mktemp -d | str trim)

  let archive_url = $"https://github.com/rtk-ai/rtk/releases/download/v($latest_version)/rtk-($target).tar.gz"
  let checksums_url = $"https://github.com/rtk-ai/rtk/releases/download/v($latest_version)/checksums.txt"
  let archive_path = ($temp_dir | path join "rtk.tar.gz")
  let checksums_path = ($temp_dir | path join "checksums.txt")

  print (echo-g "Downloading binary...")
  aria2c --download-result=hide --dir $temp_dir --out "rtk.tar.gz" $archive_url
  aria2c --download-result=hide --dir $temp_dir --out "checksums.txt" $checksums_url

  print (echo-g "Verifying SHA-256 checksum...")
  let asset_name = $"rtk-($target).tar.gz"
  let expected_hash = (open --raw $checksums_path
    | lines
    | find -n $asset_name
    | first
    | split row "  "
    | first
    | str trim)
  let actual_hash = (^sha256sum $archive_path | split row " " | first)

  if $expected_hash != $actual_hash {
    rm -rf $temp_dir
    error make {msg: $"Checksum mismatch! Expected ($expected_hash)"}
  }

  print (echo-g "Checksum verified. Extracting...")
  tar -xzf $archive_path -C $temp_dir

  let install_dir = ("~/.local/bin" | path expand)
  ^mkdir -p $install_dir
  mv -f ($temp_dir | path join "rtk") ($install_dir | path join "rtk")
  chmod +x ($install_dir | path join "rtk")

  rm -rf $temp_dir

  print (echo-g $"RTK updated to v($latest_version)!")

  # Phase 3: Agent re-initialization
  if not $skip_init {
    print (echo-g "Re-initializing RTK agents...")
    let init_commands = [
      {cmd: "rtk init -g", label: "global initialization"},
      {cmd: "rtk init -g --gemini", label: "Gemini CLI configuration"},
      {cmd: "rtk init -g --opencode", label: "OpenCode configuration"},
      {cmd: "rtk init --agent antigravity", label: "Antigravity CLI configuration"},
    ]
    let results = ($init_commands | each { |init|
      try {
        ^nu -c $init.cmd o+e>| null
        {label: $init.label, ok: true}
      } catch {
        {label: $init.label, ok: false}
      }
    })
    let init_ok = ($results | where ok == true | length)
    let init_fail = ($results | where ok == false | length)
    for r in $results {
      if $r.ok {
        print (echo-g $"  - ($r.label): OK")
      } else {
        print (echo-y $"  - ($r.label): FAILED")
      }
    }
    print (echo-g $"Init complete: ($init_ok) succeeded, ($init_fail) failed")
  }
}

#update reader
export def "apps-update reader" [] {
  go install github.com/mrusme/reader@latest
}

#update mega-get
@category sudo
export def "apps-update mega-get" [] {
  cd ~/Downloads/
  if (sys host | get os_version) == "20.04" {
    aria2c https://mega.nz/linux/repo/xUbuntu_20.04/amd64/megacmd-xUbuntu_20.04_amd64.deb
    sudo apt install ("megacmd-xUbuntu_20.04_amd64.deb" | path expand)
    mv -u megacmd-xUbuntu_20.04_amd64.deb $env.MY_ENV_VARS.debs

    return
  } 
  
  aria2c https://mega.nz/linux/repo/xUbuntu_24.04/amd64/megacmd-xUbuntu_24.04_amd64.deb
  sudo apt install ("megacmd-xUbuntu_24.04_amd64.deb" | path expand)
  mv -u megacmd-xUbuntu_24.04_amd64.deb $env.MY_ENV_VARS.debs
}

#update timg
@category sudo
export def "apps-update timg" [] {
  cd ~/software/timg
  git pull
  ^mkdir -p build
  cd build 
  cmake ../ -DWITH_OPENSLIDE_SUPPORT=On
  make
  sudo make install
}

#update subliminal
export def "apps-update subliminal" [] {
  pipx upgrade subliminal
}

#update nvitop
export def "apps-update nvitop" [] {
  pipx install "git+https://github.com/XuehaiPan/nvitop.git#egg=nvitop" --force
}

#update scrcpy
@category sudo
export def "apps-update scrcpy" [] {
  cd ~/software/scrcpy
  git pull

  # scrcpy 4.0+ requires SDL3, which is not in Ubuntu 24.04 repos
  if ((sys host | get name | str lowercase) in ["linux" "ubuntu"]) and (lsb_release -rs | str trim) == "24.04" {
    let sdl3_path = $env.HOME | path join "software/scrcpy/app/deps/work/install/linux-native-shared/lib/pkgconfig"
    
    let sdl3_exists = with-env { PKG_CONFIG_PATH: $sdl3_path } { 
      pkg-config --exists sdl3 
      $env.LAST_EXIT_CODE == 0
    }

    if not $sdl3_exists {
      print (echo-g "SDL3 not found or check failed, attempting to build from source...")
      # Ensure dependencies for SDL3 are present
      sudo nala install -y libasound2-dev libpulse-dev libx11-dev libwayland-dev libxext-dev libxrandr-dev libxcursor-dev libxi-dev libxinerama-dev libxss-dev libxkbcommon-dev libdrm-dev libgbm-dev libgl1-mesa-dev libgles2-mesa-dev libegl1-mesa-dev libdbus-1-dev libibus-1.0-dev libudev-dev libpipewire-0.3-dev
      
      bash app/deps/sdl.sh linux native shared
    }
    
    with-env { PKG_CONFIG_PATH: ([$sdl3_path ($env.PKG_CONFIG_PATH? | default "")] | str join (char esep)) } {
      ./install_release.sh
    }
  } else {
    ./install_release.sh
  }
}

#update gemini-cli
export def "apps-update gemini" [
  --gemini-cli(-g) #use the legacy gemini-cli instead of antigravity-cli
] {
  if $gemini_cli {
    npm install --engine-strict -g @google/gemini-cli@latest
  } else {
  agy update
  }
}

#update cariddi
export def "apps-update cariddi" [] {
    go install github.com/edoardottt/cariddi/cmd/cariddi@latest
}

#update termframe
export def "apps-update termframe" [] {
    cargo install --git https://github.com/pamburus/termframe.git --locked
}

#update gowall
export def "apps-update gowall" [] {
    go install github.com/Achno/gowall@latest
}

#update windows zed
export def "apps-update zed-windows" [] {
    let path = "~/rclone" | path join $env.MY_ENV_VARS.gdrive_mount_point | path join "Public/Software" | path expand
    let mounted = $path | path exists
    if not $mounted {
      print (echo-g "mounting gdrive...")
      rmount $env.MY_ENV_VARS.gdrive_mount_point
      sleep 2sec
    }
    
    cd ~/Downloads/
    aria2c https://zed.dev/api/releases/stable/latest/Zed-x86_64.exe
    cp -pf Zed-x86_64.exe $path
    rm Zed-x86_64.exe
}

#update cliamp
@category sudo
export def "apps-update cliamp" [] {
        sudo cliamp upgrade
}

# Check if context-mode plugin is installed in Claude Code.
# Returns `true` if installed, `false` otherwise.
export def check-context-mode-plugin []: nothing -> bool {
  let list_output = try {
    claude plugin list
  } catch {
    return false
  }
  let list_str = $list_output | into string
  ($list_str =~ "context-mode")
}

# Install context-mode plugin in Claude Code via marketplace.
# Returns `true` if installation succeeded, `false` if it failed.
export def install-context-mode-plugin []: nothing -> bool {
  print (echo-g "Installing context-mode plugin for Claude Code...")
  let add_result = try {
    claude plugin marketplace add mksglu/context-mode
    true
  } catch { |err|
    print $"Warning: Failed to add context-mode from marketplace: ($err.msg)"
    false
  }
  if not $add_result {
    return false
  }
  let install_result = try {
    claude plugin install context-mode@context-mode
    true
  } catch { |err|
    print $"Warning: Failed to install context-mode plugin: ($err.msg)"
    false
  }
  $install_result
}

# Update context-mode MCP server
export def "apps-update context-mode" [] {
  print (echo-g "Checking context-mode plugin for Claude Code...")
  let plugin_installed = check-context-mode-plugin
  if not $plugin_installed {
    print (echo-y "context-mode not found in Claude Code plugins. Attempting installation...")
    let install_ok = install-context-mode-plugin
    if $install_ok {
      print (echo-g "context-mode plugin installed successfully for Claude Code.")
    } else {
      print (echo-y "Warning: Could not install context-mode plugin. Continuing with config sync...")
    }
  } else {
    print (echo-g "context-mode plugin is already installed in Claude Code.")
  }

  npm update -g context-mode

  # Update/Reinstall context-mode plugin for agy (Antigravity CLI)
  if (which agy | is-not-empty) {
    print (echo-g "Updating context-mode plugin for agy...")
    try {
      ^agy plugin install https://github.com/mksglu/context-mode/tree/main/configs/antigravity-cli
      print (echo-g "context-mode plugin for agy updated successfully.")
    } catch { |err|
      print $"Warning: Could not update context-mode plugin for agy: ($err.msg)"
    }
  }

  # Upgrade OpenCode to remove legacy MCP config and set hooks
  try {
    with-env { CONTEXT_MODE_PLATFORM: "opencode" } {
      context-mode upgrade
    }
  } catch { |err|
    print $"Warning: Failed to run context-mode upgrade: ($err.msg)"
  }

  # Ensure context-mode is registered in the OpenCode plugin array
  let opencode_config = "~/.config/opencode/opencode.json" | path expand
  if ($opencode_config | path exists) {
    let config = open $opencode_config
    let plugins = $config | get -o plugin | default []
    if not ("context-mode" in $plugins) {
      let updated_plugins = $plugins | append "context-mode"
      $config | upsert plugin $updated_plugins | save -f $opencode_config
      print "context-mode plugin registered in ~/.config/opencode/opencode.json"
    }
  }

  let npm_root = npm root -g | str trim | path expand
  let agy_rules_path = $npm_root | path join "context-mode" "configs" "antigravity" "GEMINI.md"
  let gemini_rules_path = $npm_root | path join "context-mode" "configs" "gemini-cli" "GEMINI.md"

  if not ($agy_rules_path | path exists) or not ($gemini_rules_path | path exists) {
    error make {msg: $"context-mode config templates not found in ($npm_root)"}
  }

  let agy_rules = open --raw $agy_rules_path
  let gemini_rules = open --raw $gemini_rules_path

  let start_marker = "## Session Continuity"
  let end_marker = "## ctx commands"
  
  let start_idx = $gemini_rules | str index-of $start_marker
  let end_idx = $gemini_rules | str index-of $end_marker
  
  if $start_idx == -1 or $end_idx == -1 {
    error make {msg: "Could not find expected markers in gemini-cli/GEMINI.md"}
  }
  
  let memory_rules = $gemini_rules | str substring $start_idx..$end_idx

  let insert_marker = "## Output constraints"
  let insert_idx = $agy_rules | str index-of $insert_marker
  
  let unified_rules = if $insert_idx == -1 {
    let alt_marker = "## ctx commands"
    let alt_idx = $agy_rules | str index-of $alt_marker
    if $alt_idx == -1 {
      $agy_rules + "\n\n" + $memory_rules
    } else {
      let first_part = $agy_rules | str substring 0..$alt_idx
      let second_part = $agy_rules | str substring $alt_idx..
      $first_part + "\n" + $memory_rules + "\n" + $second_part
    }
  } else {
    let first_part = $agy_rules | str substring 0..$insert_idx
    let second_part = $agy_rules | str substring $insert_idx..
    $first_part + "\n" + $memory_rules + "\n" + $second_part
  }

  let bak_path = ("/home/kira/Yandex.Disk/llms_configs/gemini-bak.md" | path expand)
  let bak_content = open --raw $bak_path
  
  let rule_marker = "# context-mode — MANDATORY routing rules"
  let rule_idx = $bak_content | str index-of $rule_marker
  if $rule_idx == -1 {
    error make {msg: $"Could not find rules heading '($rule_marker)' in ($bak_path)"}
  }
  
  let first_part = $bak_content | str substring 0..$rule_idx
  let new_bak_content = $first_part + $unified_rules
  
  $new_bak_content | save -f $bak_path
  print "gemini-bak.md updated with unified context-mode routing rules."

  # Sync the files
  update-gemini-md
  print "Global GEMINI.md, AGENTS.md, and CLAUDE.md files synchronized."
}

#update markdonify-mcp
export def "apps-update markdonify-mcp" [] {
  cd ~/software/markdownify-mcp
  git pull
  pnpm install
  pnpm run build
}

#update/install matlab-agentic-toolkit (new method: agenticToolkitInstaller.mltbx)
export def "apps-update matlab-agentic-toolkit" [] {
	let linux_backup = $env.MY_ENV_VARS.linux_backup
	let mcp_bin_dir      = ("~/.matlab/agentic-toolkits/bin" | path expand)
	let mcp_binary       = ($mcp_bin_dir | path join "matlab-mcp-server")
	let mcp_bin_url      = "https://github.com/matlab/matlab-mcp-server/releases/latest/download/matlab-mcp-server-linux-x64"
	let mcp_toolbox_url  = "https://github.com/matlab/matlab-mcp-server/releases/latest/download/MATLABMCPServerToolbox.mltbx"
	let mcp_toolbox_tmp  = "/tmp/MATLABMCPServerToolbox.mltbx"
	let mcp_releases_api = "https://api.github.com/repos/matlab/matlab-mcp-server/releases/latest"
	let config_json      = ("~/.matlab/agentic-toolkits/config.json" | path expand)
	let installer_url    = "https://github.com/matlab/simulink-agentic-toolkit/releases/latest/download/agenticToolkitInstaller.mltbx"
	let installer_tmp    = "/tmp/agenticToolkitInstaller.mltbx"
	let old_clone        = ("~/software/matlab-agentic-toolkit" | path expand)

	# Agent settings files to manage (key: file name, value: mcp key style)
	let agent_files = [
		{file: "settings_gemini.json",      style: "mcpServers"}
		{file: "settings_claude.json",      style: "mcpServers"}
		{file: "settings_antigravity.json", style: "mcpServers"}
		{file: "settings_opencode.json",    style: "mcp"}
	]

	# --- FR1: Dynamic MATLAB root detection ---
	print (echo-c "\n⚙  Detecting MATLAB root..." "cyan")
	let matlab_root = try {
		# Use `lines | last` to strip any MATLAB startup warning lines above the actual path
		matlab -batch "setenv('SHELL','/bin/bash'); disp(matlabroot)" | complete | get stdout | str trim | lines | last
	} catch {
		return-error "MATLAB not found or failed! Ensure 'matlab' is in PATH."
	}
	if ($matlab_root | is-empty) {
		return-error "Could not detect MATLAB root (empty output from matlabroot)."
	}
	print (echo-g $"   → MATLAB root: ($matlab_root)")

	# --- FR2: Download installer add-on and MCP toolbox ---
	print (echo-c "\n⬇  Downloading agenticToolkitInstaller.mltbx..." "cyan")
	try {
		http get $installer_url | save --force $installer_tmp
	} catch {
		return-error $"Failed to download installer from ($installer_url). Check your internet connection."
	}

	print (echo-c "\n⬇  Downloading MATLABMCPServerToolbox.mltbx..." "cyan")
	try {
		http get $mcp_toolbox_url | save --force $mcp_toolbox_tmp
	} catch {
		return-error $"Failed to download MCP toolbox from ($mcp_toolbox_url). Check your internet connection."
	}

	# --- FR2.1: Ensure MCP binary is present before calling setupAgenticToolkit ---
	# (binary needed for MCPServerLocation arg — download now if missing)
	if not ($mcp_binary | path exists) {
		print (echo-c "\n⬇  MCP binary not found — downloading before setup..." "cyan")
		mkdir $mcp_bin_dir
		try {
			http get $mcp_bin_url | save --force $mcp_binary
			run-external "chmod" "+x" $mcp_binary
			print (echo-g $"   → Downloaded MCP binary to ($mcp_binary)")
		} catch {
			return-error $"Failed to download MCP binary from ($mcp_bin_url). Check internet connection."
		}
	}

	# --- FR3: setupAgenticToolkit — requires interactive user input ---
	# MATLAB's input() is hardcoded and cannot be bypassed in -batch mode.
	# Skills install to ~/.agents/skills/ system-wide — available to ALL agents.
	# The user must choose skill groups manually (docs: install only what you need).
	let is_installed = ($config_json | path exists)
	let action = if $is_installed { "update" } else { "install" }

	# On fresh install: run setupAgenticToolkit interactively.
	# -nodesktop -r mode inherits the TTY so MATLAB input() works fine.
	# Only -batch disables interaction — we avoid it here.
	if not $is_installed {
		let shebang = "setenv('SHELL','/bin/bash'); "
		let setup_cmd = (
			$shebang +
			"matlab.addons.install('" + $installer_tmp + "', true); " +
			"setupAgenticToolkit('install', " +
			"MCPServerLocation='" + $mcp_binary + "', " +
			"MCPToolboxLocation='" + $mcp_toolbox_tmp + "'); " +
			"exit"
		)

		print (echo-c "\n🔧  Running setupAgenticToolkit('install') interactively..." "cyan")
		print (echo-c "    Select skill groups when prompted (Enter = all)." "yellow")

		run-external "matlab" "-nosplash" "-nodesktop" "-r" $setup_cmd

		try { rm $installer_tmp } catch {}
		try { rm $mcp_toolbox_tmp } catch {}
	} else {
		# Update run: skill files in skills-catalog/ are replaced on each release.
		# Must re-run setupAgenticToolkit('update') to refresh the symlinks/files.
		let shebang = "setenv('SHELL','/bin/bash'); "
		let setup_cmd = (
			$shebang +
			"matlab.addons.install('" + $installer_tmp + "', true); " +
			"setupAgenticToolkit('update', " +
			"MCPServerLocation='" + $mcp_binary + "', " +
			"MCPToolboxLocation='" + $mcp_toolbox_tmp + "'); " +
			"exit"
		)

		print (echo-c "\n🔧  Running setupAgenticToolkit('update') to refresh skills..." "cyan")
		print (echo-c "    Select skill groups when prompted (Enter = all)." "yellow")

		run-external "matlab" "-nosplash" "-nodesktop" "-r" $setup_cmd

		try { rm $installer_tmp } catch {}
		try { rm $mcp_toolbox_tmp } catch {}
	}



	# --- FR2.5: MCP binary version check / update ---
	# (Binary is guaranteed present at this point via FR2.1 or prior run)
	print (echo-c "\n📦  Checking MATLAB MCP Server binary version..." "cyan")

	# Fetch latest version tag from GitHub API
	let latest_tag = try {
		http get $mcp_releases_api | get tag_name | str trim
	} catch {
		print (echo-c "   ⚠ Could not fetch latest MCP server version from GitHub. Skipping version check." "yellow")
		""
	}

	let current_ver = try {
		run-external $mcp_binary "--version" | complete | get stdout | str trim
	} catch { "" }

	if ($latest_tag | is-not-empty) and ($current_ver | is-not-empty) {
		# Extract version number from output (e.g. "matlab-mcp-server v0.11.2" → "v0.11.2")
		let current_tag = ($current_ver | split row " " | last | str trim)
		print (echo-g $"   Current: ($current_tag)  Latest: ($latest_tag)")

		if $current_tag != $latest_tag {
			print (echo-c ("   ⬆ Update available: " + $current_tag + " → " + $latest_tag + ". Updating...") "yellow")
			try {
				http get $mcp_bin_url | save --force $mcp_binary
				run-external "chmod" "+x" $mcp_binary
				print (echo-g $"   → MCP server binary updated to ($latest_tag)")
			} catch {
				print (echo-c $"   ⚠ Failed to download updated binary. Keeping current ($current_tag)." "yellow")
			}
		} else {
			print (echo-g $"   ✓ MCP server binary is up to date ($current_tag)")
		}
	} else {
		print (echo-c $"   Binary present at ($mcp_binary). Version check skipped (could not determine version)." "yellow")
	}

	# --- FR1 (post-install): Re-detect MATLAB root in case version changed ---
	let matlab_root_final = try {
		matlab -batch "setenv('SHELL','/bin/bash'); disp(matlabroot)" | complete | get stdout | str trim | lines | last
	} catch {
		$matlab_root
	}
	let active_root = if ($matlab_root_final | is-empty) { $matlab_root } else { $matlab_root_final }

	# --- FR4: MCP configuration verification & update ---
	print (echo-c "\n🔍  Checking MCP configuration in agent settings files..." "cyan")

	mut mcp_summary = []

	for row in $agent_files {
		let file_path = ($linux_backup | path join $row.file)
		if not ($file_path | path exists) {
			$mcp_summary = ($mcp_summary | append {file: $row.file, status: "⚠ FILE NOT FOUND"})
			continue
		}

		let data = open $file_path

		if $row.style == "mcpServers" {
			# Format: { mcpServers: { matlab: { command: "...", args: ["--matlab-root", "<root>", ...] } } }
			if ($data | get -o mcpServers.matlab | is-not-empty) {
				# Update --matlab-root value in args list
				let old_args = ($data | get mcpServers.matlab.args)
				let root_idx = ($old_args | enumerate | where item == "--matlab-root" | get 0?.index? | default (-1))
				let updated_args = if $root_idx >= 0 {
					$old_args | enumerate | each {|it|
						if $it.index == ($root_idx + 1) { $active_root } else { $it.item }
					}
				} else { $old_args }
				# Ensure --disable-telemetry=true is present (must reapply after each update)
				let final_args = if ("--disable-telemetry=true" in $updated_args) {
					$updated_args
				} else {
					$updated_args | append "--disable-telemetry=true"
				}
				$data | update mcpServers.matlab.args $final_args | save --force $file_path
				let telemetry_note = if ("--disable-telemetry=true" in $updated_args) { "" } else { " + telemetry disabled" }
				$mcp_summary = ($mcp_summary | append {file: $row.file, status: ("✓ Updated" + $telemetry_note)})
			} else {
				# Add fresh entry
				let new_entry = {
					command: $mcp_binary
					args: [
						"--matlab-root", $active_root,
						"--initialize-matlab-on-startup=true",
						"--matlab-display-mode=nodesktop",
						"--matlab-session-mode=auto",
						"--disable-telemetry=true",
						"--initial-working-folder=${PWD}"
					]
				}
				$data | upsert mcpServers.matlab $new_entry | save --force $file_path
				$mcp_summary = ($mcp_summary | append {file: $row.file, status: "✓ Added matlab MCP entry"})
			}
		} else {
			# opencode format: { mcp: { matlab: { type: "local", command: ["<bin>", "--matlab-root", "<root>", ...], enabled: true } } }
			if ($data | get -o mcp.matlab | is-not-empty) {
				# Update --matlab-root value in command array
				let old_cmd = ($data | get mcp.matlab.command)
				let root_idx = ($old_cmd | enumerate | where item == "--matlab-root" | get 0?.index? | default (-1))
				let updated_cmd = if $root_idx >= 0 {
					$old_cmd | enumerate | each {|it|
						if $it.index == ($root_idx + 1) { $active_root } else { $it.item }
					}
				} else { $old_cmd }
				# Ensure --disable-telemetry=true is present (must reapply after each update)
				let final_cmd = if ("--disable-telemetry=true" in $updated_cmd) {
					$updated_cmd
				} else {
					$updated_cmd | append "--disable-telemetry=true"
				}
				$data | update mcp.matlab.command $final_cmd | save --force $file_path
				let telemetry_note = if ("--disable-telemetry=true" in $updated_cmd) { "" } else { " + telemetry disabled" }
				$mcp_summary = ($mcp_summary | append {file: $row.file, status: ("✓ Updated" + $telemetry_note)})
			} else {
				# Add fresh entry
				let new_entry = {
					type: "local"
					command: [
						$mcp_binary,
						"--matlab-root", $active_root,
						"--initialize-matlab-on-startup=true",
						"--matlab-display-mode=nodesktop",
						"--matlab-session-mode=auto",
						"--disable-telemetry=true",
						"--initial-working-folder=${PWD}"
					]
					enabled: true
				}
				$data | upsert mcp.matlab $new_entry | save --force $file_path
				$mcp_summary = ($mcp_summary | append {file: $row.file, status: "✓ Added matlab MCP entry"})
			}
		}
	}

	# --- FR4.1: Patch global ~/.gemini/settings.json written by setupAgenticToolkit ---
	# setupAgenticToolkit overwrites this file and strips --disable-telemetry=true.
	let global_gemini = ("~/.gemini/settings.json" | path expand)
	if ($global_gemini | path exists) {
		let gdata = open $global_gemini
		if ($gdata | get -o mcpServers.matlab | is-not-empty) {
			let gargs = ($gdata | get mcpServers.matlab.args)
			if ("--disable-telemetry=true" not-in $gargs) {
				$gdata | update mcpServers.matlab.args ($gargs | append "--disable-telemetry=true") | save --force $global_gemini
				print (echo-g "   → ~/.gemini/settings.json: telemetry disabled")
			} else {
				print (echo-g "   → ~/.gemini/settings.json: telemetry already disabled")
			}
		}
	}

	# --- FR5: Final status message ---
	print (echo-c "\n╔═══════════════════════════════════════╗" "green")
	print (echo-c $"║  MATLAB Agentic Toolkit — ($action | str uppercase) done  " "green")
	print (echo-c "╚═══════════════════════════════════════╝" "green")
	print (echo-g $"\n  MATLAB root : ($active_root)")
	print (echo-g $"  Action      : ($action)")
	print (echo-c "\n  MCP Settings:" "cyan")
	for s in $mcp_summary {
		print (echo-g $"    ($s.file) → ($s.status)")
	}

}

#configure MATLAB Agentic Toolkit skill groups and agent platforms interactively
#runs setupAgenticToolkit('configure') in -nodesktop mode to select agents and skill groups
#without re-downloading or re-installing the full toolkit
export def "matlab configure-skills" [] {
	let mcp_binary     = ("~/.matlab/agentic-toolkits/bin/matlab-mcp-server" | path expand)
	let mcp_toolbox    = ("~/.matlab/agentic-toolkits/toolbox/MATLABMCPServerToolbox.mltbx" | path expand)
	let global_gemini  = ("~/.gemini/settings.json" | path expand)

	# Verify setupAgenticToolkit is available (toolkit must be installed first)
	let config_json = ("~/.matlab/agentic-toolkits/config.json" | path expand)
	if not ($config_json | path exists) {
		return-error "MATLAB Agentic Toolkit not installed yet. Run `apps-update matlab-agentic-toolkit` first."
	}

	# Build the configure command — pass local binary/toolbox paths to avoid re-downloading
	let configure_cmd = (
		"setupAgenticToolkit('configure'" +
		(if ($mcp_binary | path exists) { ", MCPServerLocation='" + $mcp_binary + "'" } else { "" }) +
		(if ($mcp_toolbox | path exists) { ", MCPToolboxLocation='" + $mcp_toolbox + "'" } else { "" }) +
		"); exit"
	)

	print (echo-c "\n🔧  Running setupAgenticToolkit('configure') interactively..." "cyan")
	print (echo-c "    Select agent platforms and skill groups when prompted." "yellow")
	print (echo-c "    (e.g. enter '1,5' for Claude Code + Gemini CLI)\n" "yellow")

	run-external "matlab" "-nosplash" "-nodesktop" "-r" $configure_cmd

	# Re-apply --disable-telemetry to global Gemini settings (setupAgenticToolkit may reset it)
	if ($global_gemini | path exists) {
		let gdata = open $global_gemini
		if ($gdata | get -o mcpServers.matlab | is-not-empty) {
			let gargs = ($gdata | get mcpServers.matlab.args)
			if ("--disable-telemetry=true" not-in $gargs) {
				$gdata | update mcpServers.matlab.args ($gargs | append "--disable-telemetry=true") | save --force $global_gemini
				print (echo-g "\n   → ~/.gemini/settings.json: --disable-telemetry=true re-applied")
			}
		}
	}

	print (echo-g "\n✓  Skill group configuration complete.")
}


#update apps from habitica todos
export def "apps-update from-todos" [--dry-run] {
  let hostname = sys host | get hostname
  let label = $"software-updates-($hostname)"

  let todos = h ls todos | select _id text tags label_name completed | flatten | where completed == false

  let label_todos = $todos | where label_name =~ $label

  let release_todos = $todos | where text =~ "Release" and label_name !~ $label

  if ($label_todos | is-empty) and ($release_todos | is-empty) {
    print "No pending software update todos found."
    return
  }

  let all_todos = $label_todos | append $release_todos

  let commands = help commands | find "apps-update " | get name | ansi strip
    | where {|c| $c !~ "install" and $c != "apps-update help" and $c != "apps-update"}
    | each {|c| $c | str replace "apps-update " ""}

  let matched = $all_todos | each {|todo|
    let text_lower = $todo.text | str lowercase
    let found = $commands | where {|c| ($text_lower | str contains $c) or ($text_lower | str contains ($c | str replace "-" " ")) or ($text_lower | str contains ($c | str replace "-" "")) }
      | sort-by {|c| $c | str length} --reverse
    if ($found | is-empty) {
      null
    } else {
      let cmd = $found | first
      {todo_text: $todo.text, todo_id: $todo._id, update_command: $cmd}
    }
  } | compact | uniq-by update_command

  if ($matched | is-empty) {
    print "Found software update todos but no matching update commands."
    return
  }

  if $dry_run {
    print $"\nDry run — ($matched | length) update(s) matched:"
    print ($matched | select todo_text update_command | table)
    return
  }

  mut results = []
  for todo in $matched {
    print $"(ansi green)Updating ($todo.update_command)...(ansi reset)"
    let result = nu --config ~/.config/nushell/config.nu --env-config ~/.config/nushell/env.nu -c $"apps-update ($todo.update_command)" | complete
    if $result.exit_code == 0 {
      h complete-todos --ids [$todo.todo_id]
      print "done"
      $results = $results | append {todo_text: $todo.todo_text, update_command: $todo.update_command, status: "completed"}
    } else {
      print $"(ansi red)failed(ansi reset)"
      $results = $results | append {todo_text: $todo.todo_text, update_command: $todo.update_command, status: "failed"}
    }
  }

  let completed = $results | where status == "completed" | length
  let failed = $results | where status == "failed" | length

  print $"\nSummary: ($completed) completed, ($failed) failed"
  if $failed > 0 {
    print "\nFailed updates:"
    print ($results | where status == "failed" | select todo_text update_command | table)
  }
}


export def "apps-update help" [] {
    scope commands 
    | where name starts-with "apps-update "
    | select name description 
    | update name {|c| $c.name | split row " " | last} 
    | where name != "help" and name != "apps-update"
    | sort-by name
    | rename subcommand
}

#update fzf
export def "apps-update fzf" [] {
  let fzf_dir = ("~/.fzf" | path expand)
  if not ($fzf_dir | path exists) {
    print (echo-g "cloning fzf...")
    git clone --depth 1 https://github.com/junegunn/fzf.git $fzf_dir
  } else {
    print (echo-g "updating fzf...")
    cd $fzf_dir
    git pull
  }
  
  print (echo-g "installing fzf...")
  cd $fzf_dir
  ./install --all
}

#update oxicord
export def "apps-update oxicord" [] {
	cargo install oxicord --git https://github.com/linuxmobile/oxicord.git
}

#update science-skills repo and link skills
export def "apps-update science-skills" [] {
    let repo = $env.MY_ENV_VARS.llms_configs | path join skills science-skills
    cd $repo
    ^git pull
    link-skills
}

#update gemini-skills repo and link skills
export def "apps-update gemini-skills" [] {
    let repo = $env.MY_ENV_VARS.llms_configs | path join skills gemini-api-skills gemini-skills
    cd $repo
    ^git pull
    link-skills
}

#update ponytail extension across AI tools
export def "apps-update ponytail" [] {
  print (echo-g "Checking and updating Ponytail ruleset extension...")

  # 1. Gemini / Antigravity (agy)
  if (which gemini | is-not-empty) {
    print (echo-g "Updating Ponytail for Gemini CLI / agy...")
    try {
      ^gemini extensions install https://github.com/DietrichGebert/ponytail
      print (echo-g "Gemini/agy Ponytail update complete.")
    } catch { |err|
      print (echo-r $"Failed to update Ponytail for Gemini/agy: ($err.msg)")
    }
  } else {
    print (echo-y "Gemini CLI not found, skipping.")
  }

  # 2. Claude Code
  if (which claude | is-not-empty) {
    print (echo-g "Updating Ponytail for Claude Code...")
    try {
      ^claude plugin marketplace add DietrichGebert/ponytail
      ^claude plugin install ponytail@ponytail
      print (echo-g "Claude Code Ponytail update complete.")
    } catch { |err|
      print (echo-r $"Failed to update Ponytail for Claude Code: ($err.msg)")
    }
  } else {
    print (echo-y "Claude Code not found, skipping.")
  }

  # 3. OpenCode
  let opencode_config = "~/.config/opencode/opencode.json" | path expand
  if ($opencode_config | path exists) {
    print (echo-g "Registering Ponytail in OpenCode config...")
    try {
      let config = open $opencode_config
      let plugins = $config | get -o plugin | default []
      if not ("@dietrichgebert/ponytail" in $plugins) {
        let updated_plugins = $plugins | append "@dietrichgebert/ponytail"
        $config | upsert plugin $updated_plugins | save -f $opencode_config
        print (echo-g "Ponytail registered in ~/.config/opencode/opencode.json")
      } else {
        print (echo-g "Ponytail already registered in OpenCode config.")
      }
    } catch { |err|
      print (echo-r $"Failed to update OpenCode config for Ponytail: ($err.msg)")
    }
  } else {
    print (echo-y "OpenCode config not found, skipping.")
  }

}
