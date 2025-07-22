#copy private nushell script dir to public repo and commit
export def copy-scripts-and-commit [--gemini(-G) = false] {
  print (echo-g "updating public repository...")
  let files = (
    ls $env.MY_ENV_VARS.nu_scripts
    | find -v private & signature & env_vars & aliases & before & send_not & deprecated & Gemini
    | append (ls $env.MY_ENV_VARS.linux_backup | find -n append)
    | append (ls $env.MY_ENV_VARS.credentials | find -v .asc | find -v credential)
  )

  $files | cp-pipe $env.MY_ENV_VARS.nu_scripts_public

  cd $env.MY_ENV_VARS.nu_scripts_public
  sed -i 's/\/home\/kira\/Yandex.Disk\/Backups\/linux\/my_scripts\/nushell/\/path\/to\/nushell_scripts/g' append_to_config.nu

  if $gemini {
    ai git-push -G
  } else {
    ai git-push -g
  }
}

#clone ubuntu backup repo as main local repo
export def clone-ubuntu-install [] {
  cd ~/software
  git clone $env.MY_ENV_VARS.private_linux_backup_repo
}

#clone yandex.disk repo as main local repo
export def clone-yandex-disk [] {
  cd ~/software
  git clone $env.MY_ENV_VARS.yandex_disk_repo Yandex.Disk
}

#copy private linux backup dir to private repo and commit (alias quantum)
export def quick-ubuntu-and-tools-update-module [
  --update-scripts(-s)  #also update nushell scripts public repo
  --upload-debs(-d)     #also upload debs files to gdrive
  --upload-zed(-z)      #also upload zed files to mega
  --force(-f)           #force the copy
  --gemini(-G)          #use google gemini-1.5-pro-latest instead of gpt-4o
] {
  let destination = "~/software/ubuntu_semiautomatic_install/" | path expand
  if not ($destination | path exists) {
    return-error "destination path doesn't exists!!"
  }

  copy-yandex-and-commit -G $gemini

  print (echo-g "updating private repository...")
  if $force {
    cp -rfp ($env.MY_ENV_VARS.linux_backup + "/*" | into glob) $destination
  } else {
    cp -rup ($env.MY_ENV_VARS.linux_backup + "/*" | into glob) $destination
  }

  cd $destination
  if $gemini {
    ai git-push -G
  } else {
    ai git-push -g
  }

  if $update_scripts {copy-scripts-and-commit -G $gemini}
  if $upload_debs {upload-debs-to-mega}
  # if $upload_zed {upload-zed-backup-to-mega}
}

#alias for short call
export alias quantum = quick-ubuntu-and-tools-update-module

#upload deb files to gdrive
export def upload-debs-to-gdrive [] {
  let mounted = ($env.MY_ENV_VARS.gdrive_debs | path expand | path exists)
  if not $mounted {
    print (echo-g "mounting gdrive...")
    rmount $env.MY_ENV_VARS.gdrive_mount_point
    sleep 4sec
  }

  let old_deb_date = ls ([$env.MY_ENV_VARS.gdrive_debs debs.7z] | path join) | get modified | get 0

  let last_deb_date = ls $env.MY_ENV_VARS.debs | sort-by modified | last | get modified

  if $last_deb_date > $old_deb_date {
    print (echo-g "updating deb files to gdrive...")
    cd $env.MY_ENV_VARS.debs; cd ..
    7z max debs debs/
    mv -f debs.7z $env.MY_ENV_VARS.gdrive_debs
  }
}

#upload deb files to mega
export def upload-debs-to-mega [] {
  let mounted = $env.MY_ENV_VARS.mega_debs | path join debs.7z | path expand | path exists
  if not $mounted {
    print (echo-g "mounting mega...")
    rmount $env.MY_ENV_VARS.mega_mount_point
    sleep 4sec
  }

  let old_deb_date = ls ([$env.MY_ENV_VARS.mega_debs debs.7z] | path join) | get modified | get 0

  let last_deb_date = ls $env.MY_ENV_VARS.debs | sort-by modified | last | get modified

  if $last_deb_date > $old_deb_date {
    print (echo-g "uploading deb files to mega...")
    cd $env.MY_ENV_VARS.debs; cd ..
    7z max debs debs/
    mv -fp debs.7z $env.MY_ENV_VARS.mega_debs
  }
}

#update yandex.disk repository
export def copy-yandex-and-commit [--gemini(-G) = false] {
  print (echo-g "updating Yandex.Disk repository...")
  cp -rpu $env.MY_ENV_VARS.ai_database ~/software/Yandex.Disk/
  cp -rpu $env.MY_ENV_VARS.chatgpt ~/software/Yandex.Disk/
  cp -rpu $env.MY_ENV_VARS.linux_backup ~/software/Yandex.Disk/Backups/
  cp -pu ($env.MY_ENV_VARS.appImages | path join "fontforge.AppImage") ~/software/Yandex.Disk/Backups/appimages/

  cd ~/software/Yandex.Disk/
  if $gemini {
    ai git-push -G
  } else {
    ai git-push -g
  }
}

#upload zed backup to mega
export def upload-zed-backup-to-mega [] {
  let mounted = $env.MY_ENV_VARS.mega_debs | path join debs.7z | path expand | path exists
  if not $mounted {
    print (echo-g "mounting mega...")
    rmount $env.MY_ENV_VARS.mega_mount_point
    sleep 4sec
  }

  let old_zed_date = ls ([$env.MY_ENV_VARS.mega_debs zed_extensions.7z] | path join) | get modified | get 0

  let last_zed_date = ls ([$env.MY_ENV_VARS.zed_backup zed_extensions.7z] | path join) | get modified | get 0

  if $last_zed_date > $old_zed_date {
    cd $env.MY_ENV_VARS.zed_backup; 
    mv -fp zed_extensions.7z $env.MY_ENV_VARS.mega_debs
  }
}
