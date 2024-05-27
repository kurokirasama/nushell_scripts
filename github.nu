#copy private nushell script dir to public repo and commit
export def copy-scripts-and-commit [--gemini(-G) = false] {
  print (echo-g "updating public repository...")
  let files = (
    ls $env.MY_ENV_VARS.nu_scripts 
    | find -v private & signature & env_vars & aliases & before & send_not & deprecated
    | append (ls $env.MY_ENV_VARS.linux_backup | find append)
    | append (ls $env.MY_ENV_VARS.credentials | find -v .asc | find -v credentials)
  )

  $files | cp-pipe $env.MY_ENV_VARS.nu_scripts_public

  cd $env.MY_ENV_VARS.nu_scripts_public
  sed -i 's/\/home\/kira\/Yandex.Disk\/Backups\/linux\/nu_scripts/\/path\/to\/nushell_scripts/g' append_to_config.nu
  
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

#copy private linux backup dir to private repo and commit (alias quantum)
export def quick-ubuntu-and-tools-update-module [
  --update_scripts(-s)  #also update nushell scripts public repo
  --upload_debs(-d)     #also upload debs files to gdrive
  --force(-f)           #force the copy
  --gemini(-G)          #use google gemini-1.5-pro-latest instead of gpt-4o
] {
  let destination = "~/software/ubuntu_semiautomatic_install/" | path expand
  if not ($destination | path exists) {
    return-error "destination path doesn't exists!!"
  }
  
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
  if $upload_debs {upload-debs-to-gdrive}
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