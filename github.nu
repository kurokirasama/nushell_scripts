#generate an anonymized version of env_vars.nu for public release
export def anonymize-env-vars [
    source_path?: string # path to source env_vars.nu (defaults to workspace env_vars.nu)
    dest_path?: string   # destination path (defaults to nu_scripts_public/env_vars.nu)
] {
    let src = if ($source_path != null) { $source_path } else { ($env.MY_ENV_VARS.nu_scripts | path join "env_vars.nu") }
    let dst = if ($dest_path != null) { $dest_path } else { ($env.MY_ENV_VARS.nu_scripts_public | path join "env_vars.nu") }
    
    if not ($src | path exists) {
        print (echo-r $"Source file not found: ($src)")
        return
    }
    
    let content = open --raw $src
        | str replace --regex 'let negative_prompt = ".*?"' 'let negative_prompt = "placeholder_negative_prompt"'
        | str replace -a "kurokirasama@gmail.com" "user@example.com"
        | str replace -a "lgomez@ubiobio.cl" "user_work@example.com"
        | str replace -a "luismiguelgomezguzman@gmail.com" "user_personal@example.com"
        | str replace -a "-36.877568,-73.148715" "0.000000,0.000000"
        | str replace -a "-36.821795,-73.014665" "0.000000,0.000000"
        | str replace -a '"Kira"' '"Home_WiFi"'
        | str replace -a '"wifi-ubb"' '"Work_WiFi"'
        | str replace -a '"Amarita"' '"Mobile_Hotspot"'
        | str replace -a '"el huemul 6258, san pedro de la paz, chile"' '"123 Main Street, City, Country"'
        | str replace -a '"22101316G"' '"DEVICE_MAIN_ID"'
        | str replace -a '"ZTE BLADE A530"' '"DEVICE_SECONDARY_ID"'
        | str replace -a "git@gitlab.com:kurokirasama/yandex.disk.git" "git@example.com:username/repo.git"
        | str replace -a "oracle-server.key" "id_rsa"
        | str replace -a "usuario" "username"
        | str replace -a "/home/kira" "/home/username"
        | str replace -a "~/Yandex.Disk/Backups/linux" "~/scripts/linux"
        | str replace -a "~/Yandex.Disk/Development/linux/nushell/nushell_scripts" "~/nushell_scripts"
        | str replace -a "~/Yandex.Disk/Development/linux/sublime/nushell_sublime_syntax" "~/nushell_sublime_syntax"
        | str replace -a "~/Yandex.Disk" "~/scripts"
        | str replace -a "G:\\My Drive\\Yandex.Disk.Backup" "G:\\My Drive\\Backup"
        | str replace -a "G:\\My Drive\\Depto\\DireccionEscuelaIngenieria\\NotasReunionesAi" "G:\\My Drive\\Notes"
        | str replace -a '~/rclone/gubb/Yandex.Disk.Backup' '~/cloud/Backup'
        | str replace -a '~/rclone/gubb/Depto/DireccionEscuelaIngenieria/NotasReunionesAi' '~/cloud/notes'
        | str replace -a '~/media/Seagate Portable Drive/Manga' '~/media/External_Drive/Manga'
        | str replace -a '~/Documents/Zoom' '~/Documents'
        | str replace -a "Documents\\Zoom" "Documents"
        | str replace -a '~/Dropbox/Directorios' '~/media'
        | str replace -a "Dropbox\\Directorios" "Dropbox\\Media"
        | str replace -a 'Android_Devices" "Common" "Download" "http_main.json' 'devices" "main.json'
        | str replace -a 'Android_Devices" "Common" "Download" "http_alfred1.json' 'devices" "secondary.json'
        | str replace -a 'wizard_gemini2.png' 'avatar.png'
        | str replace -a '"gubb"' '"cloud_drive"'
        | str replace -a "open $env.MY_ENV_VARS.ips | columns" "try { open $env.MY_ENV_VARS.ips | columns } catch { [] }"
        | str replace -a "$env.MY_ENV_VARS = $env.MY_ENV_VARS | upsert api_keys (open-credential -u ($env.MY_ENV_VARS.credentials | path join credentials.json.asc))" "$env.MY_ENV_VARS = $env.MY_ENV_VARS | upsert api_keys (try { open-credential -u ($env.MY_ENV_VARS.credentials | path join credentials.json.asc) } catch { {} })"
        | str replace -a '$env.DC_API_KEY = (get-api-key "datacommons")' '$env.DC_API_KEY = (try { get-api-key "datacommons" } catch { "" })'
        | str replace -a '$env.GEMINI_API_KEY = (get-api-key "google.gemini_paid")' '$env.GEMINI_API_KEY = (try { get-api-key "google.gemini_paid" } catch { "" })'
        
    $content | save -f $dst
    try { rich print $"  [bold green]✓[/] Anonymized [bold]env_vars.nu[/] saved to ($dst)" } catch { print (echo-g $"  ✓ Anonymized env_vars.nu saved to ($dst)") }
}

#copy private nushell script dir to public repo and commit
export def copy-scripts-and-commit [--gemini(-G) = false] {
  try { rich rule "Updating Public GitHub Repository" --style "bold cyan" } catch { print (echo-g "updating public repository...") }
  let files = ls $env.MY_ENV_VARS.nu_scripts
    | find -v defs_private & signature & env_vars & before & send_not & deprecated & GEMINI & conductor & tests & plan & docs & todos.md & CLAUDE & AGENTS
    | append (ls $env.MY_ENV_VARS.credentials | find -v .asc | find -v credential)
  

  $files | cp-pipe $env.MY_ENV_VARS.nu_scripts_public

  cd $env.MY_ENV_VARS.nu_scripts_public
  let linux_scripts = $env.MY_ENV_VARS.nu_scripts

  if ("all.nu" | path exists) {
    let public_all = open --raw all.nu
      | str replace -a "/home/kira/software/nu-rich" "~/software/nu-rich"
      | lines
      | where { |line|
          not ($line =~ 'defs_private')
        }
      | str join "\n"
    $public_all | save -f all.nu
    try { rich print "  [bold green]✓[/] Cleaned public [bold]all.nu[/]" } catch { print (echo-g "  ✓ Cleaned public all.nu") }
  }

  try { anonymize-env-vars } catch { }

  try {
    "✓ All public scripts copied, all.nu cleaned, and env_vars.nu anonymized.\nProceeding with AI git commit and push."
      | rich panel --title "Public Sync Prepared" --box rounded --border-style green
  } catch { }

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
  --update-yandex-repo(-y)  #also update yandex.disk repo
  --upload-debs(-d)         #also upload debs files to gdrive
  --gemini(-G)              #use google gemini instead of gpt
  --review(-r)              #review the changes before committing
] {
  if $update_yandex_repo {
    copy-yandex-and-commit -G $gemini
  }

  copy-scripts-and-commit -G $gemini

  if $upload_debs {
    upload-debs-to-mega
  }
}

#alias for short call
export alias quantum = quick-ubuntu-and-tools-update-module -G

#upload deb files to gdrive
export def upload-debs-to-gdrive [] {
  let mounted = $env.MY_ENV_VARS.gdrive_debs | path expand | path exists
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
  cp -rpu ($env.MY_ENV_VARS.appImages | path join "fontforge.AppImage") ~/software/Yandex.Disk/Backups/appimages/
  rsync -rpu --exclude=".git" ~/Yandex.Disk/webapps ~/software/Yandex.Disk/

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
