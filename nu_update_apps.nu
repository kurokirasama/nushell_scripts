#update off-package manager apps
#zoom, chrome, earth, yandex, sejda, nmap, nyxt, tasker, ttyplot, pandoc, mpris
export def apps-update [] {
  zoom-update
  chrome-update
  earth-update
  yandex-update
  sejda-update
  nmap-update
  nyxt-update
  tasker-update
  ttyplot-update
  pandoc-update
  mpris-update
  monocraft-update
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

#update tasker permissions deb
export def tasker-update [] {
  cd $env.MY_ENV_VARS.debs

  let url = (
    fetch https://github.com/joaomgcd/Tasker-Permissions/releases/ 
    | lines 
    | find .deb 
    | find href 
    | get 0 
    | split row "href=" 
    | find amd64
    | get 0
    | ansi strip 
    | split row ">" 
    | get 0 
    | str replace -a "\"" "" 
  )

  let new_file = ($url | split row / | last)

  let new_version = ($url | split row _ | get 1)

  let tasker = ((ls *.deb | find tasker | length) > 0)

  if $tasker {
    let current_version = (
      ls *.deb 
      | find "tasker" 
      | get 0 
      | get name 
      | split row _ 
      | get 1
    )

    if $current_version != $new_version {
      echo-g "\nupdating tasker permissions..."
      rm *tasker*.deb | ignore
      aria2c --download-result=hide $url
      sudo gdebi -n $new_file
    }

  } else {
    echo-g "\ndownloading tasker..."
    aria2c --download-result=hide $url
    sudo gdebi -n $new_file
  }
}

#update nyxt deb
export def nyxt-update [] {
  cd $env.MY_ENV_VARS.debs

  let info = (
    fetch https://github.com/atlas-engineer/nyxt/releases
    | lines 
    | find .deb 
    | first 
    | split row "\"" 
    | get 1
  )

  let url = $"https://github.com($info)"

  let new_version = (
    $info 
    | split row /
    | last
    | split row _ 
    | get 1
  )
  
  let nyxt = ((ls *.deb | find "nyxt" | length) > 0)


  if $nyxt {
    let current_version = (
      ls *.deb 
      | find "nyxt" 
      | get 0 
      | get name 
      | ansi strip
      | split row _ 
      | get 1
    )

    if $current_version != $new_version {
      echo-g "\nupdating nyxt..."
      rm nyxt*.deb | ignore
      aria2c --download-result=hide $url

      let new_deb = (ls *.deb | find "nyxt" | get 0 | get name | ansi strip)
      sudo gdebi -n $new_deb
    }

  } else {
    echo-g "\ndownloading nyxt..."
    aria2c --download-result=hide $url

    let install = (input (echo-g "Would you like to install it? (y/n): "))
    if $install == "y" {
      let new_deb = (ls *.deb | find nyxt | get 0 | get name | ansi strip)
      sudo gdebi -n $new_deb
    }
  }
}

#update pandoc deb
export def pandoc-update [] {
  cd $env.MY_ENV_VARS.debs

  let info = (
    fetch https://github.com/jgm/pandoc/releases
    | lines 
    | find .deb 
    | find amd64
    | first 
    | split row "\"" 
    | get 1
  )

  let url = $"https://github.com($info)"

  let new_version = (
    $info 
    | split row /
    | last
    | split row -
    | get 1
  )
  
  let pandoc = ((ls *.deb | find pandoc | length) > 0)

  if $pandoc {
    let current_version = (
      ls *.deb 
      | find "pandoc" 
      | get 0 
      | get name 
      | split row - 
      | get 1
    )

    if $current_version != $new_version {
      echo-g "\nupdating pandoc..."
      rm pandoc*.deb | ignore
      aria2c --download-result=hide $url

      let install = (input (echo-g "Would you like to install it? (y/n): "))
      if $install == "y" {
        let new_deb = (ls *.deb | find "pandoc" | get 0 | get name | ansi strip)
        sudo gdebi -n $new_deb
      }
    }

  } else {
    echo-g "\ndownloading pandoc..."
    aria2c --download-result=hide $url

    let install = (input (echo-g "Would you like to install it? (y/n): "))
    if $install == "y" {
      let new_deb = (ls *.deb | find "pandoc" | get 0 | get name | ansi strip)
      sudo gdebi -n $new_deb
    }
  }
}

#update ttyplot deb
export def ttyplot-update [] {
  cd $env.MY_ENV_VARS.debs

  let info = (
    fetch https://github.com/tenox7/ttyplot/releases 
    | lines 
    | find .deb 
    | get 0 
    | split row /
  )

  let main_version = ($info | get 5)
  let new_file = ($info 
    | get 6 
    | split row "\"" 
    | get 0
  )

  let new_version = (
    $new_file 
    | split row _ 
    | get 1 
    | split row .deb 
    | get 0
  )

  let url = $"https://github.com/tenox7/ttyplot/releases/download/($main_version)/($new_file)"

  let tty = ((ls *.deb | find ttyplot | length) > 0)

  if $tty {
    let current_version = (
      ls *.deb 
      | find ttyplot 
      | get 0 
      | get name 
      | split row _ 
      | get 1 
      | split row .deb 
      | get 0
    )

    if $current_version != $new_version {
      echo-g "\nupdating ttyplot..."
      rm ttyplot*.deb | ignore
      aria2c --download-result=hide $url
      sudo gdebi -n $new_file
    }

  } else {
    echo-g "\ndownloading ttyplot..."
    aria2c --download-result=hide $url
    sudo gdebi -n $new_file
  }
}

#update mpris for mpv
export def mpris-update [] {
  cd ([$env.MY_ENV_VARS.linux_backup "scripts"] | path join)

  let info = (
    fetch https://github.com/hoyon/mpv-mpris/releases 
    | lines 
    | find -i mpris.so 
    | get 0 
    | split row "\""  
    | get 1
  )

  let url = $"https://github.com($info)"

  let new_version = (
    $info 
    | split row /
    | drop
    | last
  )
  
  let mpris = ((ls mpris.so | length) > 0)

  if $mpris {
    let current_version = (open mpris.json | get version)

    if $current_version != $new_version {
      echo-g "updating mpris..."
      rm mpris.so | ignore
      aria2c --download-result=hide $url -o mpris.so

      open mpris.json | upsert version $new_version | save mpris.json
    }

  } else {
    echo-g "downloading mpris..."
    aria2c --download-result=hide $url -o mpris.so

    open mpris.json | upsert version $new_version | save mpris.json
  }
}

#update monocraft font
export def monocraft-update [] {
  cd $env.MY_ENV_VARS.linux_backup

  let info = (
    fetch https://github.com/IdreesInc/Monocraft/releases
    | lines 
    | find -i Monocraft.otf 
    | get 0 
    | split row "\""  
    | get 1
  )

  let url = $"https://github.com($info)"

  let new_version = (
    $info 
    | split row /
    | drop
    | last
  )
  
  let monocraft = ((ls Monocraft.otf | length) > 0)

  if $monocraft {
    let current_version = (open monocraft.json | get version)

    if $current_version != $new_version {
      echo-g "updating Monocraft..."
      rm Monocraft.otf | ignore
      aria2c --download-result=hide $url -o Monocraft.otf
      open monocraft.json | upsert version $new_version | save monocraft.json

      cp Monocraft.otf ~/.fonts/
      fc-cache -fv
    }

  } else {
    echo-g "downloading Monocraft..."
    aria2c --download-result=hide $url -o Monocraft.otf
    open monocraft.json | upsert version $new_version | save monocraft.json

    cp Monocraft.otf ~/.fonts/
    fc-cache -fv
  }
}

