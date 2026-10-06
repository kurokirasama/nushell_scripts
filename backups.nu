use crypt.nu [nu-crypt]

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
    let os_id = (try { open /etc/os-release | lines | where {|l| $l starts-with "ID="} | first | str replace 'ID=' '' | str trim -c '"' | ansi strip } catch { "" })
    $os_id == "cachyos"
}

def echo-g [str: string] { $"(ansi -e { fg: '#00ff00' attr: b })($str)(ansi reset)" }
def echo-y [str: string] { $"(ansi -e { fg: '#ffff00' attr: b })($str)(ansi reset)" }
def echo-r [str: string] { $"(ansi -e { fg: '#ff0000' attr: b })($str)(ansi reset)" }

# Internal helper for modular and testable Hyprland backup
export def perform-hyprland-backup [
    --source-dir: string = ""
    --target-dir: string = ""
    --cachyos
    --dry-run
] {
    let src_dir = if ($source_dir | is-empty) { ($env.HOME | path join ".config") } else { $source_dir }
    let linux_backup = (try { $env.MY_ENV_VARS.linux_backup } catch { "~/Yandex.Disk/Backups/linux" } | path expand)
    let dst_dir = if ($target_dir | is-empty) {
        if $cachyos {
            $linux_backup | path join "cachyos-omarchy-hyperland"
        } else {
            $linux_backup | path join "hyprland"
        }
    } else {
        $target_dir
    }

    if $dry_run {
        print (echo-g $"[DRY-RUN] Would backup Hyprland configurations from ($src_dir) to ($dst_dir)")
        if $cachyos {
            print "  Directories: hypr, omarchy, fontconfig, wallust, eww, wlogout, waybar, swaync, rofi, walker, mako, gtk-3.0, gtk-4.0, qt6ct, qt5ct, environment.d, ghostty, xkb, voxtype, zathura"
            print "  Standalone files: .gtkrc-2.0, mimeapps.list, xdg-terminals.list, screensaver.txt, sync-bar-theming.sh, hypridle.conf, voxtype_config.toml, auto-power-profile, greeter.toml, sync.toml"
            if (($src_dir | path join "hyprmoncfg") | path exists) {
                let hostname = (sys host | get hostname)
                print $"  Machine-specific: hyprmoncfg/($hostname).7z - display profiles stored host-keyed"
            }
        } else {
            print "  Directories: waybar, hypr, wlogout, swaync, rofi, wallust"
        }
        return
    }

    mkdir $dst_dir
    let staging_dir = (mktemp -d -t cachy_hypr_backup_XXXXXX)

    if $cachyos {
        let cachy_dirs = [
            { dir: "hypr", arch: "hypr" },
            { dir: "omarchy", arch: "omarchy" },
            { dir: "fontconfig", arch: "fontconfig" },
            { dir: "wallust", arch: "wallust" },
            { dir: "eww", arch: "eww" },
            { dir: "wlogout", arch: "wlogout" },
            { dir: "waybar", arch: "waybar" },
            { dir: "swaync", arch: "swaync" },
            { dir: "rofi", arch: "rofi" },
            { dir: "walker", arch: "walker" },
            { dir: "mako", arch: "mako" },
            { dir: "gtk-3.0", arch: "gtk-3.0" },
            { dir: "gtk-4.0", arch: "gtk-4.0" },
            { dir: "qt6ct", arch: "qt6ct" },
            { dir: "qt5ct", arch: "qt5ct" },
            { dir: "environment.d", arch: "environment" },
            { dir: "ghostty", arch: "ghostty" },
            { dir: "xkb", arch: "xkb" },
            { dir: "voxtype", arch: "voxtype" },
            { dir: "zathura", arch: "zathura" }
        ]

        for item in $cachy_dirs {
            let comp_path = ($src_dir | path join $item.dir)
            if ($comp_path | path exists) {
                let arch_file = ($staging_dir | path join $"($item.arch).7z")
                try {
                    do { ^7z a -t7z -snl -m0=lzma2 -mx=9 -ms=on -mmt=on $arch_file $comp_path } | complete
                    mv -f $arch_file ($dst_dir | path join $"($item.arch).7z")
                } catch { |err|
                    print $"Warning archiving ($item.dir): ($err.msg)"
                }
            }
        }

        # Machine-specific hyprmoncfg display profiles (host-keyed archive)
        let hmc_src = ($src_dir | path join "hyprmoncfg")
        if ($hmc_src | path exists) {
            let hostname = (sys host | get hostname)
            let hmc_dst_dir = ($dst_dir | path join "hyprmoncfg")
            mkdir $hmc_dst_dir
            let arch_file = ($staging_dir | path join $"($hostname).7z")
            try {
                do { ^7z a -t7z -snl -m0=lzma2 -mx=9 -ms=on -mmt=on $arch_file $hmc_src } | complete
                mv -f $arch_file ($hmc_dst_dir | path join $"($hostname).7z")
                print (echo-g $"✓ Backed up hyprmoncfg profiles -> hyprmoncfg/($hostname).7z")
            } catch { |err|
                print $"Warning archiving hyprmoncfg: ($err.msg)"
            }
        }

        # Standalone files
        let gtkrc_src = if ($source_dir | is-empty) { ($env.HOME | path join ".gtkrc-2.0") } else { ($src_dir | path join ".gtkrc-2.0") }
        if ($gtkrc_src | path exists) {
            cp -f $gtkrc_src ($dst_dir | path join ".gtkrc-2.0")
        }

        let mime_src = ($src_dir | path join "mimeapps.list")
        if ($mime_src | path exists) {
            cp -f $mime_src ($dst_dir | path join "mimeapps.list")
        }

        let xdg_src = ($src_dir | path join "xdg-terminals.list")
        if ($xdg_src | path exists) {
            cp -f $xdg_src ($dst_dir | path join "xdg-terminals.list")
        }

        let screensaver_candidates = [
            ($src_dir | path join "omarchy" "screensaver.txt"),
            ($src_dir | path join "screensaver.txt")
        ]
        for c in $screensaver_candidates {
            if ($c | path exists) {
                cp -f $c ($dst_dir | path join "screensaver.txt")
                break
            }
        }

        let sync_bar_candidates = [
            ($src_dir | path join "omarchy" "hooks" "theme-set.d" "sync-bar-theming.sh"),
            ($src_dir | path join "sync-bar-theming.sh")
        ]
        for c in $sync_bar_candidates {
            if ($c | path exists) {
                cp -f $c ($dst_dir | path join "sync-bar-theming.sh")
                break
            }
        }

        let hypridle_candidates = [
            ($src_dir | path join "hypr" "hypridle.conf"),
            ($src_dir | path join "hypridle.conf")
        ]
        for c in $hypridle_candidates {
            if ($c | path exists) {
                cp -f $c ($dst_dir | path join "hypridle.conf")
                break
            }
        }

        let voxtype_candidates = [
            ($src_dir | path join "voxtype" "config.toml"),
            ($src_dir | path join "voxtype_config.toml")
        ]
        for c in $voxtype_candidates {
            if ($c | path exists) {
                cp -f $c ($dst_dir | path join "voxtype_config.toml")
                break
            }
        }

        # System files (if present and readable)
        if ("/usr/local/bin/auto-power-profile" | path exists) {
            try { cp -f "/usr/local/bin/auto-power-profile" ($dst_dir | path join "auto-power-profile") } catch {}
        }
        if ("/etc/greetd/hyprland.toml" | path exists) {
            try { cp -f "/etc/greetd/hyprland.toml" ($dst_dir | path join "greeter.toml") } catch {}
        } else if ("/etc/greetd/greeter.toml" | path exists) {
            try { cp -f "/etc/greetd/greeter.toml" ($dst_dir | path join "greeter.toml") } catch {}
        }
        if ("/etc/greetd/sync.toml" | path exists) {
            try { cp -f "/etc/greetd/sync.toml" ($dst_dir | path join "sync.toml") } catch {}
        }
    } else {
        let ubu_dirs = ["waybar", "hypr", "wlogout", "swaync", "rofi", "wallust"]
        for dir_name in $ubu_dirs {
            let comp_path = ($src_dir | path join $dir_name)
            if ($comp_path | path exists) {
                let arch_file = ($staging_dir | path join $"($dir_name).7z")
                try {
                    do { ^7z a -t7z -snl -m0=lzma2 -mx=9 -ms=on -mmt=on $arch_file $comp_path } | complete
                    mv -f $arch_file ($dst_dir | path join $"($dir_name).7z")
                } catch { |err|
                    print $"Warning archiving ($dir_name): ($err.msg)"
                }
            }
        }
    }

    try { rm -rf $staging_dir } catch {}
}

# Internal helper for modular and testable Hyprland restore
export def perform-hyprland-restore [
    --source-dir: string = ""
    --target-dir: string = ""
    --cachyos
    --dry-run
] {
    let linux_backup = (try { $env.MY_ENV_VARS.linux_backup } catch { "~/Yandex.Disk/Backups/linux" } | path expand)
    let src_dir = if ($source_dir | is-empty) {
        if $cachyos {
            $linux_backup | path join "cachyos-omarchy-hyperland"
        } else {
            $linux_backup | path join "hyprland"
        }
    } else {
        $source_dir
    }
    let dst_dir = if ($target_dir | is-empty) { ($env.HOME | path join ".config") } else { $target_dir }

    if not ($src_dir | path exists) {
        error make { msg: $"Backup folder ($src_dir) does not exist." }
    }

    if $dry_run {
        print (echo-g $"[DRY-RUN] Would restore Hyprland configurations from ($src_dir) to ($dst_dir)")
        let archives = (glob ($src_dir | path join "*.7z"))
        print $"  Found ($archives | length) archives in ($src_dir)"
        let hmc_hostname = (sys host | get hostname)
        let hmc_arch = ($src_dir | path join "hyprmoncfg" $"($hmc_hostname).7z")
        let hmc_state = if ($hmc_arch | path exists) { "present" } else { "absent" }
        print $"  Machine-specific archive: hyprmoncfg/($hmc_hostname).7z - ($hmc_state)"
        return
    }

    mkdir $dst_dir

    for archive in (glob ($src_dir | path join "*.7z")) {
        try {
            do { ^7z x -snl $archive $"-o($dst_dir)" -y } | complete
        } catch { |err|
            print $"Warning extracting ($archive): ($err.msg)"
        }
    }

    # Machine-specific hyprmoncfg display profiles (host-keyed restore; CachyOS only)
    if $cachyos {
        let hmc_restore_hostname = (sys host | get hostname)
        let hmc_restore_arch = ($src_dir | path join "hyprmoncfg" $"($hmc_restore_hostname).7z")
        if ($hmc_restore_arch | path exists) {
            try {
                do { ^7z x -snl $hmc_restore_arch $"-o($dst_dir)" -y } | complete
                print (echo-g $"✓ Restored machine-specific hyprmoncfg profiles for ($hmc_restore_hostname)")
            } catch { |err|
                print (echo-y $"Warning restoring hyprmoncfg profiles: ($err.msg)")
            }
        } else {
            print (echo-y $"Notice: no machine-specific hyprmoncfg archive for ($hmc_restore_hostname) - skipping")
        }
    }

    # Restore standalone files
    let gtkrc_b = ($src_dir | path join ".gtkrc-2.0")
    if ($gtkrc_b | path exists) {
        if ($target_dir | is-empty) {
            try { cp -f $gtkrc_b ($env.HOME | path join ".gtkrc-2.0") } catch {}
        } else {
            try { cp -f $gtkrc_b ($dst_dir | path join ".gtkrc-2.0") } catch {}
        }
    }

    let mimeapps = ($src_dir | path join "mimeapps.list")
    if ($mimeapps | path exists) {
        try { cp -f $mimeapps ($dst_dir | path join "mimeapps.list") } catch {}
    }

    let xdg_terminals = ($src_dir | path join "xdg-terminals.list")
    if ($xdg_terminals | path exists) {
        try { cp -f $xdg_terminals ($dst_dir | path join "xdg-terminals.list") } catch {}
    }

    let screensaver = ($src_dir | path join "screensaver.txt")
    if ($screensaver | path exists) {
        let omarchy_dest = ($dst_dir | path join "omarchy")
        mkdir $omarchy_dest
        try { cp -f $screensaver ($omarchy_dest | path join "screensaver.txt") } catch {}
        if ($target_dir | is-not-empty) {
            try { cp -f $screensaver ($dst_dir | path join "screensaver.txt") } catch {}
        }
    }

    let sync_bar = ($src_dir | path join "sync-bar-theming.sh")
    if ($sync_bar | path exists) {
        let sync_hook_dir = ($dst_dir | path join "omarchy" "hooks" "theme-set.d")
        mkdir $sync_hook_dir
        let sync_hook_dst = ($sync_hook_dir | path join "sync-bar-theming.sh")
        try {
            cp -f $sync_bar $sync_hook_dst
            chmod +x $sync_hook_dst
        } catch {}
    }

    let hypridle = ($src_dir | path join "hypridle.conf")
    if ($hypridle | path exists) {
        let hypr_dest = ($dst_dir | path join "hypr")
        mkdir $hypr_dest
        try { cp -f $hypridle ($hypr_dest | path join "hypridle.conf") } catch {}
    }

    let voxtype_cfg = ($src_dir | path join "voxtype_config.toml")
    if ($voxtype_cfg | path exists) {
        let voxtype_dest = ($dst_dir | path join "voxtype")
        mkdir $voxtype_dest
        try { cp -f $voxtype_cfg ($voxtype_dest | path join "config.toml") } catch {}
    }

    # Restore system files if running system-wide
    if ($target_dir | is-empty) {
        let auto_power = ($src_dir | path join "auto-power-profile")
        if ($auto_power | path exists) {
            try {
                sudo cp -f $auto_power /usr/local/bin/auto-power-profile
                sudo chmod +x /usr/local/bin/auto-power-profile
            } catch {
                print (echo-y "Notice: /usr/local/bin/auto-power-profile could not be restored automatically without sudo.")
            }
        }

        let greeter = ($src_dir | path join "greeter.toml")
        if ($greeter | path exists) and ("/etc/greetd" | path exists) {
            try {
                sudo cp -f $greeter /etc/greetd/hyprland.toml
            } catch {
                print (echo-y "Notice: /etc/greetd/hyprland.toml could not be restored automatically without sudo.")
            }
        }

        let sync_toml = ($src_dir | path join "sync.toml")
        if ($sync_toml | path exists) and ("/etc/greetd" | path exists) {
            try {
                sudo cp -f $sync_toml /etc/greetd/sync.toml
            } catch {
                print (echo-y "Notice: /etc/greetd/sync.toml could not be restored automatically without sudo.")
            }
        }
    }

    # Permissions enforcement on scripts
    for script_file in (glob ($dst_dir | path join "hypr" "scripts" "*.nu")) {
        try { chmod +x $script_file } catch {}
    }
    for script_file in (glob ($dst_dir | path join "hypr" "scripts" "*.sh")) {
        try { chmod +x $script_file } catch {}
    }
    for hook_file in (glob ($dst_dir | path join "omarchy" "hooks" "*" "*.sh")) {
        try { chmod +x $hook_file } catch {}
    }
    for plugin_script in (glob ($dst_dir | path join "omarchy" "plugins" "*" "scripts" "*")) {
        try { chmod +x $plugin_script } catch {}
    }
}

#backup hyprland configs
@category backup
@search-terms hyprland backup
export def "hyprlnd backup" [
    --cachyos(-c) # Backup CachyOS Hyprland & Omarchy configuration
    --dry-run     # Preview actions without modifying filesystem
] {
    let is_cachy = if $cachyos {
        if not (is-cachyos) {
            error make { msg: "Cannot use --cachyos flag on a non-CachyOS system." }
        }
        true
    } else {
        (is-cachyos)
    }

    perform-hyprland-backup --cachyos=$is_cachy --dry-run=$dry_run
}

#restore hyprland configs
@category backup
@search-terms hyprland restore
export def "hyprlnd restore" [
    --cachyos(-c) # Restore CachyOS Hyprland & Omarchy configuration
    --dry-run     # Preview actions without modifying filesystem
] {
    let is_cachy = if $cachyos {
        if not (is-cachyos) {
            error make { msg: "Cannot restore CachyOS Hyprland configs on a non-CachyOS system." }
        }
        true
    } else {
        (is-cachyos)
    }

    perform-hyprland-restore --cachyos=$is_cachy --dry-run=$dry_run
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

#backup vivaldi browser settings and extension configurations
@category backup
@search-terms vivaldi browser backup
export def vivaldi-backup [] {
  let backup_dir = (try { $env.MY_ENV_VARS.linux_backup } catch { "~/Yandex.Disk/Backups/linux" } | path expand)
  let vivaldi_src = ("~/.config/vivaldi" | path expand)

  if not ($vivaldi_src | path exists) {
    print (echo-r $"Vivaldi config directory not found at ($vivaldi_src)")
    return
  }

  let archive = ($backup_dir | path join "vivaldi_config.7z")
  print (echo-g $"Archiving Vivaldi configuration to ($archive)...")

  do {
    cd ("~/.config" | path expand)
    ^7z a -snl -t7z -m0=lzma2 -mx=5 -ms=on -mmt=on $archive vivaldi ...[
      "-xr!IndexedDB"
      "-xr!Service Worker"
      "-xr!File System"
      "-xr!Cache"
      "-xr!GPUCache"
      "-xr!Code Cache"
      "-xr!DawnWebGPUCache"
      "-xr!Crash Reports"
      "-xr!Singleton*"
      "-xr!*.lock"
      "-xr!LOCK"
      "-xr!Login Data*"
      "-xr!WidevineCdm"
      "-xr!component_crx_cache"
      "-xr!extensions_crx_cache"
    ]
  }

  if ($archive | path exists) {
    print (echo-g $"✓ Vivaldi configuration backed up successfully to ($archive)")
  } else {
    print (echo-r "Failed to create Vivaldi backup archive.")
  }
}

#restore vivaldi browser settings and extension configurations
@category backup
@search-terms vivaldi browser restore
export def vivaldi-restore [] {
  let backup_dir = (try { $env.MY_ENV_VARS.linux_backup } catch { "~/Yandex.Disk/Backups/linux" } | path expand)
  let archive = ($backup_dir | path join "vivaldi_config.7z")

  if not ($archive | path exists) {
    print (echo-r $"Vivaldi backup archive not found at ($archive)")
    return
  }

  # Close any running Vivaldi instances to prevent overwriting or lock contention
  let running = (try { ps | where name =~ "vivaldi" } catch { [] })
  if ($running | is-not-empty) {
    print (echo-y "Closing running Vivaldi instances before restoring...")
    try { ^pkill -x vivaldi-bin } catch {}
    sleep 1sec
  }

  let dest_dir = ("~/.config" | path expand)
  print (echo-g $"Restoring Vivaldi configuration to ($dest_dir)/vivaldi...")
  ^7z x $archive $"-o($dest_dir)" -y

  print (echo-g "✓ Vivaldi configuration restored successfully to ~/.config/vivaldi")
}

export alias "vivaldi backup" = vivaldi-backup
export alias "vivaldi restore" = vivaldi-restore