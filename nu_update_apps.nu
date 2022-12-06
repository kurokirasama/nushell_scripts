#get latest release info in github repo
export def get-github-latest [
  owner:string
  repo:string
  --file_type(-f) = "deb"
] {
  let git_token = (
    open-credential ([$env.MY_ENV_VARS.credentials github_credentials.json.asc] | path join) 
    | get token
  )

  let assets_url = (
    fetch $"https://api.github.com/repos/($owner)/($repo)/releases/latest" -H ["Authorization", $"Bearer ($git_token)"] -H ['Accept', 'application/vnd.github+json']
    | select assets_url tag_name
  )

  let info = (
    fetch $assets_url.assets_url -H ["Authorization", $"Bearer ($git_token)"] -H ['Accept', 'application/vnd.github+json']
    | find $file_type 
    | get 0
    | select name browser_download_url
    | upsert version $assets_url.tag_name
  )

  $info
}

#update github app release
export def github-app-update [
  owner:string
  repo:string
  --file_type(-f) = "deb"
  --down_dir(-d) = $env.MY_ENV_VARS.debs
  --alternative_name(-a):string
  --version_from_json(-j)
] {
  cd $down_dir

  let info = get-github-latest $owner $repo -f $file_type

  let url = ($info | get browser_download_url)

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
  
  let exists = ((ls $"*.($file_type)" | find $app | length) > 0)

  if $exists {
    let current_version = (
      if $version_from_json {
        open --raw $app_file 
        | from json
        | get version
      } else {
        ls $"*.($file_type)"
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

    if $current_version != $new_version {
      echo-g $"\nupdating ($repo)..."
      rm $"*($app)*.($file_type)" | ignore
      aria2c --download-result=hide $url

      if $version_from_json {
        open --raw $app_file
        | from json 
        | upsert version $new_version 
        | save -f $app_file
      }

      if $file_type == "deb" {
        let install = (input (echo-g "Would you like to install it now? (y/n): "))
        if $install == "y" {
          sudo gdebi -n $info.name
        }
      }
    } else {
      echo-g $"($repo) already in its latest version!"
    }

  } else {
    echo-g $"\ndownloading ($repo)..."
    aria2c --download-result=hide $url

    if $file_type == "deb" {
      let install = (input (echo-g "Would you like to install it now? (y/n): "))
      if $install == "y" {
        sudo gdebi -n $info.name
      }
    }
  }
}

#update off-package manager apps
#zoom, chrome, earth, yandex, sejda, nmap, ttyplot, nyxt, pandoc, tasker, lutris, mpris, monocraft
export def apps-update [] {
  #non github apps
  zoom-update
  chrome-update
  earth-update
  yandex-update
  sejda-update
  nmap-update
  ttyplot-update

  #github debs
  github-app-update atlas-engineer nyxt
  github-app-update jgm pandoc
  github-app-update joaomgcd Tasker-Permissions -a taskerpermissions
  github-app-update lutris lutris

  #mpv mpris
  github-app-update hoyon mpv-mpris -f so -d ([$env.MY_ENV_VARS.linux_backup "scripts"] | path join) -a mpris -j

  #monocraft font
  let current_version = (
    open --raw ([$env.MY_ENV_VARS.linux_backup Monocraft.json] | path join) 
    | from json 
    | get version
  )
  
  github-app-update IdreesInc Monocraft -f otf -d $env.MY_ENV_VARS.linux_backup -j
  
  let new_version = (
    open ([$env.MY_ENV_VARS.linux_backup Monocraft.json] | path join) 
    | get version
  )

  if $current_version != new_version {
    echo-g "New version of Monocraft downloaded, now patching nerd fonts..."
    nu ([$env.MY_ENV_VARS.linux_backup "software/appimages/patch-font.nu"] | path join)
  }
}

#update zoom
export def zoom-update [] {
  cd $env.MY_ENV_VARS.debs

  if (ls *.deb | find zoom | length) > 0 {
    ls *.deb | find zoom | rm-pipe | ignore
  }
  
  echo-g "\ndownloading zoom..."
  aria2c --download-result=hide https://zoom.us/client/latest/zoom_amd64.deb

  let install = (input (echo-g "Would you like to install it? (y/n): "))
  if $install == "y" {
    sudo gdebi -n (ls *.deb | find zoom | get 0 | get name | ansi strip)
  }
}

#update chrome deb
export def chrome-update [] {
  cd $env.MY_ENV_VARS.debs

  if (ls *.deb | find chrome | length) > 0 {
    ls *.deb | find chrome | rm-pipe | ignore
  }
  
  echo-g "\ndownloading chrome..."
  aria2c --download-result=hide https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
}

#update google earth deb
export def earth-update [] {
  cd $env.MY_ENV_VARS.debs

  if (ls *.deb | find earth | length) > 0 {
    ls *.deb | find earth | rm-pipe | ignore
  }
  
  echo-g "\ndownloading google earth..."
  aria2c --download-result=hide https://dl.google.com/dl/earth/client/current/google-earth-pro-stable_current_amd64.deb
}

#update yandex deb
export def yandex-update [] {
  cd $env.MY_ENV_VARS.debs

  if (ls *.deb | find yandex | length) > 0 {
    ls *.deb | find yandex | rm-pipe | ignore
  }
  
  echo-g "\ndownloading yandex..."
  aria2c --download-result=hide http://repo.yandex.ru/yandex-disk/yandex-disk_latest_amd64.deb
}

#update sejda deb
export def sejda-update [] {
  cd $env.MY_ENV_VARS.debs

  let new_file = (
    fetch https://www.sejda.com/es/desktop 
    | lines 
    | find linux 
    | find deb 
    | str trim 
    | str replace -a "\'" "" 
    | split row ': ' 
    | get 1
  )

  let new_version = ($new_file | split row _ | get 1)

  let url = $"https://sejda-cdn.com/downloads/($new_file)"

  let sedja = ((ls *.deb | find sejda | length) > 0)

  if $sedja {
    let current_version = (
      ls *.deb 
      | find "sejda" 
      | get 0 
      | get name 
      | split row _ 
      | get 1
    )

    if $current_version != $new_version {
      echo-g "\nupdating sedja..."
      rm sejda*.deb | ignore
      aria2c --download-result=hide $url
      sudo gdebi -n $new_file
    } else {
      echo-g "sedja already in its latest version!"
    }

  } else {
    echo-g "\ndownloading sedja..."
    aria2c --download-result=hide $url
    sudo gdebi -n $new_file
  }
}

#update nmap
export def nmap-update [] {
  cd $env.MY_ENV_VARS.debs

  let new_file = (
    fetch https://nmap.org/dist 
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

  let new_version = ($new_file  | split row .x | get 0 | str replace nmap- "")

  let nmap_list = ((ls *.deb | find nmap | length) > 0)

  if $nmap_list {
    let current_version = (
      ls *.deb 
      | find nmap 
      | get 0 
      | get name 
      | split row _ 
      | get 1
    )

    if $current_version != $new_version {
      echo-g "\nupdating nmap..."
      rm nmap*.deb | ignore

      aria2c --download-result=hide $url
      sudo alien -v -k $new_file

      let new_deb = (ls *.deb | find nmap | get 0 | get name | ansi strip)

      sudo gdebi -n $new_deb
      ls $new_file | rm-pipe | ignore
    } else {
      echo-g "nmap already in its latest version!"
    }

  } else {
    echo-g "\ndownloading nmap..."
    aria2c --download-result=hide $url
    sudo alien -v -k $new_file

    let new_deb = (ls *.deb | find nmap | get 0 | get name | ansi strip)

    sudo gdebi -n $new_deb
    ls $new_file | rm-pipe | ignore
  }
}

#update ttyplot
export def ttyplot-update [] {
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
    fetch https://packages.debian.org/sid/amd64/ttyplot/download
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

  let filename = ($url | split row / | last)

  let new_version = ($filename | split row _ | get 1)

  if $current_version != new_version {
    echo-g $"\nupdating ttyplot..."

    ls *.deb | find ttyplot | rm-pipe
    aria2c --download-result=hide $url

    sudo gdebi -n $filename
  } else {
    echo-g "ttyplot already in the latest version!"
  }
}

#update cmdg
export def gmail-update [] {
  cd ~/software/cmdg
  git pull
  go build ./cmd/cmdg
  sudo cp cmdg /usr/local/bin
}

#update nushell
export def nu-update [] {
  cd ~/software/nushell
  let status = (git status -s | lines)

  if ($status | length) > 0 {
    git pull
    bash install-all.sh
    update-nu-config
  } else {
    echo-g "nushell already up to date!"
  }
}

#update maestral
export def maestral-update [] {
  pip3 install --upgrade maestral
  pip3 install --upgrade maestral[gui]
}