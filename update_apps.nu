#update nushell
export def "apps-update nushell" [
  --repo(-r)    #install from repo instead of cargo
  --plugins(-p) #install e3rd party plugins
] {
  print (echo-g "deleting plugins...")
  plugin list | get filename | each {|p| plugin rm $p}
  
  print (echo-g "updating nushell...")
  cd ~/software/nushell
  git pull
  
  if $repo {
    bash scripts/install-all.sh
  } else {
    cargo install-update nu 
  }

  cargo clean

  print (echo-g "updating config file...")
  update-nu-config

  print (echo-g "now restart nushell...")
}

#update nushell default plugins
export def "apps-update nushell-plugins" [] {
  cargo install-update nu_plugin_inc nu_plugin_gstat nu_plugin_query nu_plugin_formats 
  cargo install nu_plugin_polars

  plugin add ~/.cargo/bin/nu_plugin_inc
  plugin add ~/.cargo/bin/nu_plugin_gstat
  plugin add ~/.cargo/bin/nu_plugin_query
  plugin add ~/.cargo/bin/nu_plugin_formats
  plugin add ~/.cargo/bin/nu_plugin_polars

  plugin use ~/.cargo/bin/nu_plugin_inc
  plugin use ~/.cargo/bin/nu_plugin_gstat
  plugin use ~/.cargo/bin/nu_plugin_query
  plugin use ~/.cargo/bin/nu_plugin_formats
  plugin use ~/.cargo/bin/nu_plugin_polars
}

#update nushell 3rd party plugins
#
#nu_plugin_net nu_plugin_highlight nu_plugin_units nu_plugin_port_scan nu_plugin_image
export def "apps-update nushell-external-plugins" [] {
  cargo install-update nu_plugin_highlight
  cargo install --git https://github.com/Euphrasiologist/nu_plugin_plot
  cargo install --git https://github.com/FMotalleb/nu_plugin_port_scan.git
  cargo install --git https://github.com/FMotalleb/nu_plugin_image.git

  plugin add ~/.cargo/bin/nu_plugin_highlight
  plugin add ~/.cargo/bin/nu_plugin_port_scan
  plugin add ~/.cargo/bin/nu_plugin_image
  plugin add ~/.cargo/bin/nu_plugin_plot

  plugin use ~/.cargo/bin/nu_plugin_highlight
  plugin use ~/.cargo/bin/nu_plugin_port_scan
  plugin use ~/.cargo/bin/nu_plugin_image
  plugin use ~/.cargo/bin/nu_plugin_plot
}

#update nu config (after nushell update)
export def update-nu-config [] {
  #config
  let default = (
    ls ($env.MY_ENV_VARS.nushell_dir + "/**/*" | into glob) 
      | find -i default_config 
      | get name
      | ansi strip
      | get 0
  )
  
  cp -f $default $nu.config-path

  open ([$env.MY_ENV_VARS.linux_backup "append_to_config.nu"] | path join)
  | str replace kira $env.USER -a
  | save --append $nu.config-path

  #env
  let default = (
    ls ($env.MY_ENV_VARS.nushell_dir + "/**/*" | into glob) 
      | find -i default_env 
      | update name {|n| 
          $n.name | ansi strip
        }
      | get name
      | get 0
  )

  cp $default $nu.env-path

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
    apps-update nyxt
  } catch {
    print (echo-r "Something went wrong with nyxt instalation!")
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
    apps-update lutris #ignore if ppa works again
  } catch {
    print (echo-r "Something went wrong with lutris instalation!")
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
    apps-update zoom
  } catch {
    print (echo-r "Something went wrong with zoom instalation!")
  }
  # try {
  #  apps-update chrome
  # } catch {
  #  print (echo-r "Something went wrong with chrome instalation!")
  # }
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
] {
  let git_token = $env.MY_ENV_VARS.api_keys.github.api_key

  let assets_url = {
      scheme: "https",
      host: "api.github.com",
      path: $"/repos/($owner)/($repo)/releases/latest",
    } 
    | url join
    | http get $in -H ["Authorization", $"Bearer ($git_token)"] -H ['Accept', 'application/vnd.github+json']
    | select assets_url tag_name

  let info = (
    http get $assets_url.assets_url -H ["Authorization", $"Bearer ($git_token)"] -H ['Accept', 'application/vnd.github+json']
    | select name browser_download_url
    | upsert version $assets_url.tag_name
    | find $file_type 
  )

  if ($info | length) > 0 {
    $info | get 0
  } else {
    []
  }
}

#update github app release
export def github-app-update [
  owner:string
  repo:string
  --file_type(-f):string = "deb"
  --down_dir(-d):string
  --alternative_name(-a):string
  --version_from_json(-j)
] {
  let down_dir = if ($down_dir | is-empty) {$env.MY_ENV_VARS.debs} else {$down_dir}
  cd $down_dir

  let info = get-github-latest $owner $repo -f $file_type

  if ($info | is-empty) {return}

  let url = $info | get browser_download_url | ansi strip

  let app = (
    if ($alternative_name | is-empty) {
      $repo
    } else {
      $alternative_name
    }
  ) 

  let app_file = (
    if $version_from_json {
     [$down_dir $"($app).json"] | path join
    } else {
      ""
    }
  )

  let find_ = (
    $info 
    | get name 
    | find _ 
    | is-empty
  )

  let new_version = (
    if $version_from_json {
      $info 
    | get version
    } else {
      $info 
      | get name
      | path parse
      | get stem
      | split row (if not $find_ {"_"} else {"-"}) 
      | get 1
    }
  )
  
  let exists = (ls | find $app | find $file_type | length) > 0

  if $exists {
    let current_version = (
      if $version_from_json {
        open --raw $app_file 
        | from json
        | get version
      } else {
        ls ($"*.($file_type)" | into glob)
        | find $app
        | get 0 
        | get name 
        | ansi strip
        | path parse
        | get stem
        | split row (if not $find_ {"_"} else {"-"}) 
        | get 1
      }
    )

    if $current_version == $new_version {
      print (echo-g $"($repo) is already in its latest version!")
      return
    }

    print (echo-g $"\nupdating ($repo)...")
    rm ($"*($app)*.($file_type)" | into glob) | ignore
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

    let install = (input (echo-g "Would you like to install it now? (y/n): "))
    if $install == "y" {
      sudo gdebi -n ($info.name | ansi strip)
    }
    return
  } 
  
  print (echo-g $"\ndownloading ($repo)...")
  aria2c --download-result=hide $url

  if $file_type == "deb" {
    let install = (input (echo-g "Would you like to install it now? (y/n): "))
    if $install == "y" {
      sudo gdebi -n ($info.name | ansi strip)
    }
  }
}

#update nyxt deb
export def "apps-update nyxt" [] {
  github-app-update atlas-engineer nyxt -f flatpak
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

#update join deb
export def "apps-update join" [] {
  github-app-update joaomgcd JoinDesktop -a join
}
  
#update lutris deb
export def "apps-update lutris" [] {
  github-app-update lutris lutris
}

#update mpris (for mpv)
export def "apps-update mpris" [] {
  github-app-update hoyon mpv-mpris -f so -d ([$env.MY_ENV_VARS.linux_backup "scripts"] | path join) -a mpris -j
}
  
#update monocraft font
export def "apps-update monocraft" [
  --to_patch(-p) = true     #to patch Monocraft.otf, else to use patched ttf
  --type(-t):string = "ttc"  #"otf" if -p, else "ttf"
] {
  let current_version = (
    open --raw ([$env.MY_ENV_VARS.linux_backup Monocraft.json] | path join) 
    | from json 
    | get version
  )
  
  github-app-update IdreesInc Monocraft -f $type -d $env.MY_ENV_VARS.linux_backup -j
  
  let new_version = (
    open ([$env.MY_ENV_VARS.linux_backup Monocraft.json] | path join) 
    | get version
  )

  if $current_version == $new_version {
    print (echo-g "Monocraft is already in its latest version...")
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

#update zoom
export def "apps-update zoom" [] {
  cd $env.MY_ENV_VARS.debs
  
  let current_version = open zoom.json | get version

  print ("current version: " + $current_version)

  print (echo-g "go to https://us05web.zoom.us/support/down4j")

  let release_url = input (echo-g "paste deb url here: ")

  if ($release_url | is-empty) {
    return
  }

  let last_version = (
    $release_url
    | split row "/" 
    | get 4
  )

  if $current_version == $last_version {
    print (echo-g "zoom is already in its latest version!")
    return
  }

  ls | find zoom | find deb | rm-pipe | ignore

  print (echo-g "\ndownloading zoom...")
  aria2c --download-result=hide $release_url
  sudo gdebi -n (ls *.deb | find zoom | get 0 | get name | ansi strip)

  open ([$env.MY_ENV_VARS.debs zoom.json] | path join) 
  | upsert version $last_version 
  | save -f ([$env.MY_ENV_VARS.debs zoom.json] | path join) 

  apps-update chrome 
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
export def "apps-update earth" [] {
  cd $env.MY_ENV_VARS.debs

  let new_version = (
    http get "https://support.google.com/earth/answer/40901#zippy=%2Cearth-version" 
    | query web -q a 
    | find version 
    | first
    | ansi strip
  )

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
export def "apps-update yandex" [] {
  cd $env.MY_ENV_VARS.debs

  let file = [$env.MY_ENV_VARS.debs yandex.json] | path join
  
  let new_date = (
    http get http://repo.yandex.ru/yandex-disk/?instant=1 
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
  )

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
export def "apps-update sejda" [] {
  cd $env.MY_ENV_VARS.debs

  let new_file = (
    http get https://www.sejda.com/es/desktop 
    | lines 
    | find linux 
    | find deb 
    | str trim 
    | str replace -a "\'" "" 
    | split row ': ' 
    | get 1
  )

  let new_version = $new_file | split row _ | get 1

  let url = $"https://downloads.sejda-cdn.com/($new_file)"

  let sedja = (ls *.deb | find sejda | length) > 0

  if $sedja {
    let current_version = (
      ls *.deb 
      | find "sejda" 
      | get 0 
      | get name 
      | split row _ 
      | get 1
    )

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

#update nmap
export def "apps-update nmap" [] {
  cd $env.MY_ENV_VARS.debs

  let new_file = (
    http get https://nmap.org/dist 
    | lines 
    | find "href=\"nmap"  
    | find rpm 
    | find x86_64 
    | get 0 
    | split row "href=" 
    | get 1 
    | split row > 
    | get 0 
    | str replace -a "\"" "" 
  )

  let url = $"https://nmap.org/dist/($new_file)"

  let new_version = $new_file  | split row .x | get 0 | str replace nmap- ""

  let nmap_list = (ls *.deb | find nmap | length) > 0

  if $nmap_list {
    let current_version = (
      ls *.deb 
      | find nmap 
      | get 0 
      | get name 
      | split row _ 
      | get 1
    )

    if $current_version == $new_version {
      print (echo-g "nmap is already in its latest version!")
      return
    }
    
    print (echo-g "\nupdating nmap...")
    rm nmap*.deb | ignore

    aria2c --download-result=hide $url
    sudo alien -v -k $new_file

    let new_deb = ls *.deb | find nmap | get 0 | get name | ansi strip

    sudo gdebi -n $new_deb
    ls $new_file | rm-pipe | ignore
  } else {
    print (echo-g "\ndownloading nmap...")
    aria2c --download-result=hide $url
    sudo alien -v -k $new_file

    let new_deb = (ls *.deb | find nmap | get 0 | get name | ansi strip)

    sudo gdebi -n $new_deb
    ls $new_file | rm-pipe | ignore
  }
}

#update ttyplot
export def "apps-update ttyplot" [] {
  cd $env.MY_ENV_VARS.debs

  let current_version = (
    ls 
    | find tty 
    | get name 
    | get 0 
    | ansi strip 
    | split row _ 
    | get 1
  )
  
  let url = (
    http get https://packages.debian.org/sid/amd64/ttyplot/download
    | lines 
    | find .deb 
    | find http 
    | find ttyplot 
    | first 
    | split row "href=\""
    | last 
    | split row "\">"
    | first
  )

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
  
  let release_url = (
    http get "https://vivaldi.com/download/"
    | query web -q .download-link -a href 
    | find deb 
    | find amd64 
    | get 0
    | ansi strip 
  )

  if ($release_url | length) == 0 {
    return-error "no releases found!"
  }

  let last_version = (
    $release_url 
    | split row _ 
    | get 1
  )

  if (ls | find vivaldi | length) == 0 {
    aria2c --download-result=hide $release_url
    return 
  } 

  let current_version = (
    ls 
    | where name =~ vivaldi 
    | get 0 
    | get name 
    | split row _ 
    | get 1
  )

  if $current_version == $last_version {
    print (echo-g "vivaldi is already in its latest version!")
    return
  }
  
  ls | find vivaldi | find deb | rm-pipe | ignore

  print (echo-g "\ndownloading vivaldi...")
  aria2c --download-result=hide $release_url
}

#update cmdg
export def "apps-update gmail" [] {
  cd ~/software/cmdg
  git pull
  go build ./cmd/cmdg
  sudo cp cmdg /usr/local/bin
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

#update guake
export def "apps-update guake" [] {
  pipx upgrade guake
}

#update whisper
export def "apps-update whisper" [] {
  if (sys host | get os_version) == 20.04 {
    pip install --upgrade --no-deps --force-reinstall git+https://github.com/openai/whisper.git
  } else {
    pipx install git+https://github.com/openai/whisper.git --force
  }
}

#update yewtube
export def "apps-update yewtube" [] {
  if (sys host | get os_version) == 20.04 {
    pip3 install --user yewtube --upgrade
  } else {
    pipx upgrade yewtube
  }
}

#update yt-dlp (youtube-dl fork)
export def "apps-update yt-dlp" [] {
  if (sys host | get os_version) == "20.04" {
    python3 -m pip install --force-reinstall https://github.com/yt-dlp/yt-dlp/archive/master.tar.gz
  } else {
    return-error "only available in Ubuntu 20.04. In 24.04 is system-wide via package manager."
  }
}

#update nchat (wsp)
export def "apps-update nchat" [] {
  sudo rm (which nchat | get path | get 0)
  cd ~/software/nchat
  git pull
  
  ^mkdir -p build; cd build; cmake -DHAS_WHATSAPP=ON -DHAS_TELEGRAM=OFF ..; make -s
  sudo make install
}

#update ffmpeg with cuda
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
  ./configure --enable-nonfree --enable-cuda-nvcc --enable-libnpp --extra-cflags=-I/usr/local/cuda/include --extra-ldflags=-L/usr/local/cuda/lib64
  ./ffmpeg -h
}

#update evernote-backuo tool
export def "apps-update evernote-backup" [] {
  pip install --user --upgrade evernote-backup
}

#update joplin
export def "apps-update joplin" [] {
  print (echo-g "updating joplin ui...")
  wget -O - https://raw.githubusercontent.com/laurent22/joplin/dev/Joplin_install_and_update.sh | bash

  print (echo-g "updating jopling cli...")
  bash -c "NPM_CONFIG_PREFIX=~/.joplin-bin npm install -g joplin"
  sudo rm -f /usr/bin/joplin
  bash -c "sudo ln -s ~/.joplin-bin/bin/joplin /usr/bin/joplin"
}

#update tiv
export def "apps-update tiv" [] {
  cd ~/software/TerminalImageViewer/
  git pull; cd src/
  make; sudo make install
}

#update mermaid filter
export def "apps-update mermaid" [] {
  sudo npm update --global mermaid-filter
}

#update mermaid-cli
export def "apps-update mermaid-cli" [] {
  sudo npm update -g @mermaid-js/mermaid-cli
}

#update ddgr (gg)
export def "apps-update ddgr" [] {
  cd ~/software/ddgr
  git pull
  sudo make install
}

#update rclone
export def "apps-update rclone" [] {
  bash -c "sudo -v ; curl -s# https://rclone.org/install.sh | sudo bash"
}

#update matlab lsp server
export def "apps-update matlab-lsp" [] {
  cd ~/software/MATLAB-language-server
  git pull 
  npm install; npm run compile; npm run package
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

  #download plugins
  let git_token = $env.MY_ENV_VARS.api_keys.github.api_key

  # cd $env.MY_ENV_VARS.ox_plugins
  
  # {
  #   scheme: "https",
  #   host: "api.github.com",
  #   path: $"/repos/curlpipe/ox/contents/plugins",
  # } 
  # | url join
  # | http get $in -H ["Authorization", $"Bearer ($git_token)"] -H ['Accept', 'application/vnd.github+json']
  # | get download_url 
  # | each {|url| aria2c --allow-overwrite=true $url}

  #updating help in programmer system message
  # if (sys host | get hostname) == "deathnote" {
  #   cd /home/kira/software/ox.wiki
  #   git pull
  #   let ox_config = open Configuration.md

  #   let p_system_file = [$env.MY_ENV_VARS.chatgpt_config system programmer.md] | path join
  #   let r_line = grp "ox editor lua scripting reference" $p_system_file | get line.0 | into int
  #   let p_system = open $p_system_file | lines | first $r_line | to text

  #   $p_system ++ "\n" ++ $ox_config | save -f $p_system_file
  # }
}

#update rustc
export def "apps-update rustc" [] {
  rustup default stable-x86_64-unknown-linux-gnu
  rustup override set stable-x86_64-unknown-linux-gnu
  rustup update
  # rustup self uninstall
}