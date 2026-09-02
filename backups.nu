#backup sublime settings
@category backup
@search-terms sublime
export def "subl backup" [] {
  cd $env.MY_ENV_VARS.linux_backup

  let source_dir = "~/.config/sublime-text"

  7z max sublime-Packages.7z ($source_dir | path join Packages | path expand)
  7z max sublime-installedPackages.7z ($source_dir | path join "Installed Packages" | path expand)
}

#restore sublime settings
@category backup
@search-terms sublime
export def "subl restore" [] {
  cd $env.MY_ENV_VARS.linux_backup

  7z x sublime-installedPackages.7z -o/home/kira/.config/sublime-text/
  7z x sublime-Packages.7z -o/home/kira/.config/sublime-text/
}

#backup nchat settings
@category backup
@search-terms nchat
export def "nchat backup" [] {
  cd $env.MY_ENV_VARS.linux_backup

  let source_dir = "~/.nchat" | path expand

  7z max nchat_config.7z ($source_dir + "/*.conf")
}

#restore nchat settings
@category backup
@search-terms nchat
export def "nchat restore" [] {
  cd $env.MY_ENV_VARS.linux_backup

  7z x nchat_config.7z -o/home/kira/.nchat
}

#backup gnome extensions settings
@category backup
@search-terms gnome
export def "gnome-extensions backup" [output_file:string = "gnome_shell_extensions_backup_24.04.txt"] {
  let file = $env.MY_ENV_VARS.linux_backup | path join extensions | path join 24.04 | path join $output_file
  dconf dump /org/gnome/shell/extensions/ | save -f $file
}

#restore gnome extensions settings
@category backup
@search-terms gnome
export def "gnome-extensions restore" [output_file:string = "gnome_shell_extensions_backup_24.04.txt"] {
  let file = $env.MY_ENV_VARS.linux_backup | path join extensions | path join 24.04 | path join $output_file
  bash -c $"dconf load /org/gnome/shell/extensions/ < ($file)"
}

#backup libre office settings
@category backup
@search-terms libreoffice
export def "libreoff backup" [] {
  cp -r ~/.config/libreoffice/* ([$env.MY_ENV_VARS.linux_backup libreoffice] | path join)
}

#restore libre office settings
@category backup
@search-terms libreoffice
export def "libreoff restore" [] {
  cp -r ($env.MY_ENV_VARS.linux_backup + "/libreoffice/*") ~/.config/libreoffice/
}

#filter commands for sublime syntax file
@category utility
@search-terms filter
export def filter-command [type_of_command:string] {
  scope commands
  | where type == $type_of_command
  | get name
  | each {|com|
      $com | split row " " | get 0
    }
  | uniq
  | str join " | "
}

#update nushell sublime syntax
@category utility
@search-terms nushell sublime
export def "nushell-syntax-2-sublime" [
 --push(-p) #push changes in submile syntax repo
] {
  let builtin = filter-command built-in
  let plugins = filter-command plugin
  let custom = filter-command custom
  let keywords = filter-command keyword

  let aliases = scope aliases
      | get name
      | uniq
      | str join " | "

  let personal_external = $env.PATH
    | find -n bash & nushell
    | get 0
    | path expand
    | ls $in
    | find -v Readme
    | get name
    | path parse
    | get stem
    | str join " | "

  let operators = help operators | get operator | find -r "[a-z]" | str join " | "

  let extra_keywords = " | else | catch"
  let builtin = "    (?x: " + $builtin + ")"
  let plugins = "    (?x: " + $plugins + ")"
  let custom = "    (?x: " + $custom + ")"
  let keywords = "    (?x: " + $keywords + $extra_keywords + ")"
  let aliases = "    (?x: " + $aliases + ")"
  let personal_external = "    (?x: " + $personal_external + ")"
  let operators = "    (?x: " + $operators + ")"

  let new_commands = [] ++ [$builtin] ++ [$custom] ++ [$plugins] ++ [$keywords] ++ [$aliases] ++ [$personal_external] ++ [$operators]

  mut file = open ~/.config/sublime-text/Packages/User/nushell.sublime-syntax | lines
  let idx = $file | indexify | find '(?x:' | get index | drop | enumerate

  for i in $idx {
    $file = $file | upsert $i.item ($new_commands | get $i.index)
  }

  $file | save -f ~/.config/sublime-text/Packages/User/nushell.sublime-syntax

  cp ~/.config/sublime-text/Packages/User/nushell.sublime-syntax $env.MY_ENV_VARS.nushell_syntax_public

  if $push {
    cd $env.MY_ENV_VARS.nushell_syntax_public
    ai git-push -G
  }
}

#backup nushell history
@category backup
@search-terms history backup
export def "history backup" [
  output?:string = "hist" #output filename
] {
  open $nu.history-path | query db $"vacuum main into '($output).db'"
}

#export rclone config
@category backup
@search-terms rclone config export
export def "rclone export" [] {
  cd ~/.config/rclone
  nu-crypt -e -n rclone.conf
  mv rclone.conf.asc $env.MY_ENV_VARS.linux_backup
}

#import rclone config
@category backup
@search-terms rclone config import
export def "rclone import" [] {
  cd $env.MY_ENV_VARS.linux_backup
  nu-crypt -d -n rclone.conf.asc | save -f ~/.config/rclone/rclone.conf
  rclone listremotes
}

#backup guake settings
@category backup
@search-terms guake backup
export def "guake backup" [] {
  guake --save-preferences ($env.MY_ENV_VARS.linux_backup | path join guakesettings.txt)
}

#restore guake settings
@category backup
@search-terms guake restore
export def "guake restore" [] {
  guake --restore-preferences ($env.MY_ENV_VARS.linux_backup | path join guakesettings.txt)
}

#export zoxide database
@category backup
@search-terms zoxide backup
export def "zoxide backup" [] {
  cp ~/.local/share/zoxide/db.zo $env.MY_ENV_VARS.linux_backup
}

#backup zed settings
@category backup
@search-terms zed backup
export def "zed-backup" [] {
  cd $env.MY_ENV_VARS.debs
  7z max zed_config ("~/.config/zed" | path expand)
}

#restore zed settings
@category backup
@search-terms zed restore
export def "zed-restore" [] {
  cd $env.MY_ENV_VARS.debs
  7z x zed_config.7z -o/home/kira/.config/ -y
}

#backup ghostty settings
@category backup
@search-terms ghostty backup
export def "ghostty backup" [] {
  cd $env.MY_ENV_VARS.linux_backup
  7z max ghostty_config ("~/.config/ghostty" | path expand)
}

#restore ghostty settings
@category backup
@search-terms ghostty restore
export def "ghostty restore" [] {
  cd $env.MY_ENV_VARS.linux_backup
  7z x ghostty_config.7z -o/home/kira/.config/ -y
}

#backup cliamp settings
@category backup
@search-terms cliamp backup
export def "cliamp-backup" [] {
  cd $env.MY_ENV_VARS.linux_backup
  7z max cliamp_config.7z ("~/.config/cliamp" | path expand) -x!*.log -x!*.sock -x!*.pid
}

#restore cliamp settings
@category backup
@search-terms cliamp restore
export def "cliamp-restore" [] {
  cd $env.MY_ENV_VARS.linux_backup
  7z x cliamp_config.7z -o/home/kira/.config/ -y
}

def is-cachyos [] {
    let os_id = (try { open /etc/os-release | lines | find -r '^ID=' | first | str replace 'ID=' '' | str trim -c '"' } catch { "" })
    $os_id == "cachyos"
}

#backup hyprland configs
@category backup
@search-terms hyprland backup
export def "hyprlnd backup" [
    --cachyos(-c) # Backup CachyOS Hyprland & Omarchy configuration
] {
    if $cachyos and not (is-cachyos) {
        error make { msg: "Cannot use --cachyos flag on a non-CachyOS system." }
    }

    let target_folder = if $cachyos {
        $env.MY_ENV_VARS.linux_backup | path join "cachyos-omarchy-hyperland"
    } else {
        $env.MY_ENV_VARS.linux_backup | path join "hyprland"
    }

    mkdir $target_folder
    cd ~/.config/

    if $cachyos {
        7z max hypr hypr/
        if ("omarchy" | path exists) { 7z max omarchy omarchy/ }
        if ("fontconfig" | path exists) { 7z max fontconfig fontconfig/ }
        if ("eww" | path exists) { 7z max eww eww/ }
        if ("wlogout" | path exists) { 7z max wlogout wlogout/ }
        if ("waybar" | path exists) { 7z max waybar waybar/ }
        if ("swaync" | path exists) { 7z max swaync swaync/ }
        if ("rofi" | path exists) { 7z max rofi rofi/ }
        if ("walker" | path exists) { 7z max walker walker/ }
        if ("mako" | path exists) { 7z max mako mako/ }
    } else {
        7z max waybar waybar/
        7z max hypr hypr/
        7z max wlogout wlogout/
        7z max swaync swaync/
        7z max rofi rofi/
        7z max wallust wallust/
    }
    
    mv *.7z $target_folder
}

#restore hyprland configs
@category backup
@search-terms hyprland restore
export def "hyprlnd restore" [
    --cachyos(-c) # Restore CachyOS Hyprland & Omarchy configuration
] {
    if $cachyos and not (is-cachyos) {
        error make { msg: "Cannot restore CachyOS Hyprland configs on a non-CachyOS system." }
    }

    let source_folder = if $cachyos {
        $env.MY_ENV_VARS.linux_backup | path join "cachyos-omarchy-hyperland"
    } else {
        $env.MY_ENV_VARS.linux_backup | path join "hyprland"
    }

    if not ($source_folder | path exists) {
        error make { msg: $"Backup folder ($source_folder) does not exist." }
    }

    cd $source_folder
    let target_dest = ($env.HOME | path join ".config")
    ls *.7z | get name | each {|f| 7z x $f -o($target_dest) -y}
}

#backup ttt settings
@category backup
@search-terms ttt backup
export def "ttt-backup" [] {
  cd $env.MY_ENV_VARS.linux_backup
  7z max ttt_config ("~/.config/ttt" | path expand)
}

#restore ttt settings
@category backup
@search-terms ttt restore
export def "ttt-restore" [] {
  cd $env.MY_ENV_VARS.linux_backup
  7z x ttt_config.7z -o/home/kira/.config/ -y
}

#backup yt-x settings
@category backup
@search-terms yt-x backup
export def "yt-x backup" [] {
  cd $env.MY_ENV_VARS.linux_backup
  7z max yt-x_config.7z ("~/.config/yt-x" | path expand)
}

#restore yt-x settings
@category backup
@search-terms yt-x restore
export def "yt-x restore" [] {
  cd $env.MY_ENV_VARS.linux_backup
  7z x yt-x_config.7z -o/home/kira/.config/ -y
}

#backup yt-dlp settings
@category backup
@search-terms yt-dlp backup
export def "yt-dlp backup" [] {
  cd $env.MY_ENV_VARS.linux_backup
  7z max yt-dlp_config.7z ("~/.config/yt-dlp" | path expand)
}

#restore yt-dlp settings
@category backup
@search-terms yt-dlp restore
export def "yt-dlp restore" [] {
  cd $env.MY_ENV_VARS.linux_backup
  7z x yt-dlp_config.7z -o/home/kira/.config/ -y
}

#backup antigravity (gemini cli) settings and plugins
@category backup
@search-terms antigravity agy gmn gemini backup
export def "agy backup" [] {
  let backup_dir = (try { $env.MY_ENV_VARS.linux_backup } catch { "~/Yandex.Disk/Backups/linux" } | path expand)
  cd $backup_dir

  # 1. Back up live settings.json if present
  let live_settings = [
    ("~/.gemini/antigravity-cli/settings.json" | path expand),
    ("~/.gemini/settings.json" | path expand)
  ] | where { |p| $p | path exists }
  if ($live_settings | is-not-empty) {
    let src = $live_settings | first
    cp -f $src ($backup_dir | path join "settings_antigravity.json")
    print (echo-g $"✓ Saved live Antigravity settings to ($backup_dir)/settings_antigravity.json")
  }

  # 2. Archive plugins directory
  let plugin_dirs = [
    ("~/.gemini/config/plugins" | path expand),
    ("~/.gemini/antigravity-cli/plugins" | path expand)
  ] | where { |p| $p | path exists }
  if ($plugin_dirs | is-not-empty) {
    let p_src = $plugin_dirs | first
    try { 7z max antigravity_plugins.7z $p_src } catch {}
    print (echo-g "✓ Archived Antigravity plugins to antigravity_plugins.7z")
  }

  # 3. Conductor skills backup
  let conductor_src = [
    ("~/.gemini/config/plugins/conductor/skills" | path expand),
    ("~/.gemini/antigravity-cli/plugins/conductor/skills" | path expand)
  ] | where { |p| $p | path exists }
  if ($conductor_src | is-not-empty) {
    let c_dest = (try { $env.MY_ENV_VARS.llms_configs } catch { "~/Yandex.Disk/llms_configs" } | path expand | path join "conductor_skills_backup" "agy")
    mkdir $c_dest
    for s in (glob (($conductor_src | first) | path join "*")) {
      cp -r $s $c_dest
    }
    print (echo-g "✓ Backed up Conductor AGY skills to llms_configs/conductor_skills_backup/agy")
  }
}

#restore antigravity (gemini cli) settings and plugins
@category backup
@search-terms antigravity agy gmn gemini restore
export def "agy restore" [] {
  let backup_dir = (try { $env.MY_ENV_VARS.linux_backup } catch { "~/Yandex.Disk/Backups/linux" } | path expand)
  cd $backup_dir

  # 1. Restore plugins archive
  let archive = ($backup_dir | path join "antigravity_plugins.7z")
  if ($archive | path exists) {
    let dest1 = ("~/.gemini/config" | path expand)
    let dest2 = ("~/.gemini/antigravity-cli" | path expand)
    mkdir $dest1 $dest2
    try { 7z x $archive -o($dest1) -y } catch {}
    try { 7z x $archive -o($dest2) -y } catch {}
    print (echo-g "✓ Restored Antigravity plugins")
  }

  # 2. Restore settings
  let settings_src = ($backup_dir | path join "settings_antigravity.json")
  if ($settings_src | path exists) {
    let s_dest1 = ("~/.gemini/antigravity-cli/settings.json" | path expand)
    let s_dest2 = ("~/.gemini/settings.json" | path expand)
    mkdir ("~/.gemini/antigravity-cli" | path expand) ("~/.gemini" | path expand)
    cp -f $settings_src $s_dest1
    cp -f $settings_src $s_dest2
    print (echo-g "✓ Restored Antigravity settings")
  }

  # 3. Synchronize skills & rules
  try {
    use ~/Yandex.Disk/my_scripts/nushell/def_system.nu [link-skills, update-gemini-md]
    link-skills
    update-gemini-md
  } catch {}
}

# Aliases for agy backup / restore
export alias "gmn backup" = agy backup
export alias "gmn restore" = agy restore

#backup claude code settings and config
@category backup
@search-terms claude cld backup
export def "cld backup" [] {
  let backup_dir = (try { $env.MY_ENV_VARS.linux_backup } catch { "~/Yandex.Disk/Backups/linux" } | path expand)
  cd $backup_dir

  let live_settings = [
    ("~/.claude/settings.json" | path expand),
    ("~/.claude.json" | path expand)
  ] | where { |p| $p | path exists }
  if ($live_settings | is-not-empty) {
    cp -f ($live_settings | first) ($backup_dir | path join "settings_claude.json")
    print (echo-g $"✓ Saved Claude Code settings to ($backup_dir)/settings_claude.json")
  }

  let claude_dir = ("~/.claude" | path expand)
  if ($claude_dir | path exists) {
    try { 7z max claude_config.7z $claude_dir "-xr!skills" "-xr!agents" "-xr!tasks" "-xr!projects" "-xr!cache" "-xr!session-transcripts" "-xr!node_modules" "-xr!marketplaces" "-xr!*.log" "-xr!*.tmp" } catch {}
    print (echo-g "✓ Archived Claude Code configuration to claude_config.7z")
  }
}

#restore claude code settings and config
@category backup
@search-terms claude cld restore
export def "cld restore" [] {
  let backup_dir = (try { $env.MY_ENV_VARS.linux_backup } catch { "~/Yandex.Disk/Backups/linux" } | path expand)
  cd $backup_dir

  let settings_src = ($backup_dir | path join "settings_claude.json")
  if ($settings_src | path exists) {
    mkdir ("~/.claude" | path expand)
    cp -f $settings_src ("~/.claude/settings.json" | path expand)
    cp -f $settings_src ("~/.claude.json" | path expand)
    print (echo-g "✓ Restored Claude Code settings")
  }

  let archive = ($backup_dir | path join "claude_config.7z")
  if ($archive | path exists) {
    try { 7z x $archive -o($env.HOME) -y } catch {}
  }

  try {
    use ~/Yandex.Disk/my_scripts/nushell/def_system.nu [link-skills, link-agents, update-gemini-md]
    link-skills
    link-agents
    update-gemini-md
  } catch {}
}

export alias "claude backup" = cld backup
export alias "claude restore" = cld restore

#backup opencode settings and config
@category backup
@search-terms opencode opn backup
export def "opn backup" [] {
  let backup_dir = (try { $env.MY_ENV_VARS.linux_backup } catch { "~/Yandex.Disk/Backups/linux" } | path expand)
  cd $backup_dir

  let opencode_dir = ("~/.config/opencode" | path expand)
  let live_config = ($opencode_dir | path join "config.json")
  if ($live_config | path exists) {
    cp -f $live_config ($backup_dir | path join "settings_opencode.json")
    print (echo-g $"✓ Saved OpenCode config to ($backup_dir)/settings_opencode.json")
  }

  if ($opencode_dir | path exists) {
    try { 7z max opencode_config.7z $opencode_dir "-xr!skills" "-xr!agents" "-xr!node_modules" "-xr!marketplaces" "-xr!*.db" "-xr!*.db-wal" "-xr!*.db-shm" "-xr!*.log" "-xr!cache" "-xr!sessions" "-xr!traces" } catch {}
    print (echo-g "✓ Archived OpenCode configuration to opencode_config.7z")
  }
}

#restore opencode settings and config
@category backup
@search-terms opencode opn restore
export def "opn restore" [] {
  let backup_dir = (try { $env.MY_ENV_VARS.linux_backup } catch { "~/Yandex.Disk/Backups/linux" } | path expand)
  cd $backup_dir

  let settings_src = ($backup_dir | path join "settings_opencode.json")
  let opencode_dir = ("~/.config/opencode" | path expand)
  mkdir $opencode_dir
  if ($settings_src | path exists) {
    cp -f $settings_src ($opencode_dir | path join "config.json")
    print (echo-g "✓ Restored OpenCode settings to config.json")
  }

  let archive = ($backup_dir | path join "opencode_config.7z")
  if ($archive | path exists) {
    try { 7z x $archive -o($env.HOME | path join ".config") -y } catch {}
  }

  try {
    use ~/Yandex.Disk/my_scripts/nushell/def_system.nu [link-skills, link-agents, update-gemini-md]
    link-skills
    link-agents
    update-gemini-md
  } catch {}
}

export alias "opencode backup" = opn backup
export alias "opencode restore" = opn restore

#backup cmdg settings and credentials
@category backup
@search-terms cmdg backup gmail
export def "cmdg backup" [] {
  let backup_dir = (try { $env.MY_ENV_VARS.linux_backup } catch { "~/Yandex.Disk/Backups/linux" } | path expand)
  let cmdg_conf = ("~/.cmdg/cmdg.conf" | path expand)

  if not ($cmdg_conf | path exists) {
    print (echo-r $"cmdg config file not found at ($cmdg_conf)")
    return
  }

  do {
    cd ("~/.cmdg" | path expand)
    nu-crypt -e -n "cmdg.conf"
    let asc_file = ("~/.cmdg/cmdg.conf.asc" | path expand)
    if ($asc_file | path exists) {
      mv -f $asc_file ($backup_dir | path join "cmdg.conf.asc")
      print (echo-g $"✓ Encrypted and backed up cmdg config to ($backup_dir)/cmdg.conf.asc")
    }
  }

  let sig_file = ("~/.signature" | path expand)
  if ($sig_file | path exists) {
    cp -f $sig_file ($backup_dir | path join "cmdg_signature")
    print (echo-g $"✓ Saved cmdg signature to ($backup_dir)/cmdg_signature")
  }
}

#restore cmdg settings and credentials
@category backup
@search-terms cmdg restore gmail
export def "cmdg restore" [] {
  let backup_dir = (try { $env.MY_ENV_VARS.linux_backup } catch { "~/Yandex.Disk/Backups/linux" } | path expand)
  let backup_conf = ($backup_dir | path join "cmdg.conf.asc")
  let target_dir = ("~/.cmdg" | path expand)
  let target_conf = ($target_dir | path join "cmdg.conf")

  if ($backup_conf | path exists) {
    mkdir $target_dir
    chmod 700 $target_dir
    nu-crypt -d -n $backup_conf | save -f $target_conf
    chmod 600 $target_conf
    print (echo-g $"✓ Restored cmdg config to ($target_conf)")
  } else {
    print (echo-y $"Notice: cmdg backup not found at ($backup_conf)")
  }

  let backup_sig = ($backup_dir | path join "cmdg_signature")
  if ($backup_sig | path exists) {
    cp -f $backup_sig ("~/.signature" | path expand)
    print (echo-g "✓ Restored cmdg signature to ~/.signature")
  }
}