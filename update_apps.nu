# Fallback colors when alias_defs.nu is not loaded in scope
def echo-g [str: string] { $"(ansi -e { fg: '#00ff00' attr: b })($str)(ansi reset)" }
def echo-y [str: string] { $"(ansi -e { fg: '#ffff00' attr: b })($str)(ansi reset)" }
def echo-r [str: string] { $"(ansi -e { fg: '#ff0000' attr: b })($str)(ansi reset)" }

# Register a nushell plugin binary into $nu.plugin-path headlessly using the on-disk nu executable
export def register-nu-plugin [
    name_or_path: string # plugin name (e.g. "nu_plugin_inc" or "inc") or full path to plugin binary
] {
    let is_win = (sys host | get name | str lowercase) == "windows"
    let ext = if $is_win { ".exe" } else { "" }
    
    let full_path = if ($name_or_path | path exists) {
        $name_or_path
    } else {
        let clean_name = if ($name_or_path | str starts-with "nu_plugin_") {
            $name_or_path
        } else {
            $"nu_plugin_($name_or_path)"
        }
        let candidate = $"~/.cargo/bin/($clean_name)($ext)" | path expand
        if not ($candidate | path exists) {
            print (echo-y $"Warning: plugin binary not found at ($candidate), skipping registration")
            return false
        }
        $candidate
    }

    let nu_bin = $"~/.cargo/bin/nu($ext)" | path expand
    let nu_exec = if ($nu_bin | path exists) { $nu_bin } else { (which nu | get 0?.path? | default "nu") }
    let reg_file = $nu.plugin-path

    let res = do {
        ^$nu_exec --plugin-config $reg_file -c $"plugin add '($full_path)'"
    } | complete

    if $res.exit_code == 0 {
        print (echo-g $"  ✓ Registered ($full_path | path basename)")
        true
    } else {
        print (echo-r $"  ✗ Failed to register ($full_path | path basename): ($res.stderr)")
        false
    }
}

# Register multiple nushell plugins headlessly
export def register-nu-plugins [...plugins: string] {
    let plugin_list = if ($plugins | is-empty) {
        ["inc" "gstat" "query" "formats" "polars"]
    } else {
        $plugins | flatten
    }
    
    $plugin_list | each {|p| register-nu-plugin $p }
}

#update nushell (and plugins automatically by default)
export def "apps-update nushell" [
  --repo(-r)         #install from repo instead of cargo
  --force(-f)        #force cargo installation instead of update
  --server(-s)       #ignore polars in oracle/low-memory server
  --no-plugins(-n)   #update only nushell binary without updating/registering plugins
] {
  let nu_dir = ($env.MY_ENV_VARS.nushell_dir? | default "~/software/nushell" | path expand)
  
  if ($nu_dir | path exists) {
    try { rich rule "Step 1/4: Pulling Upstream Nushell & Configs" --style "bold cyan" } catch { print (echo-g "==> Step 1/4: Pulling latest upstream Nushell repo & default configs...") }
    try {
      cd $nu_dir
      ^git pull
    } catch {|err|
      try { rich print $"[yellow]Warning:[/] git pull on nushell repo failed: ($err.msg)" } catch { print (echo-y $"Warning: git pull on nushell repo failed: ($err.msg)") }
    }
  }

  try { rich rule "Step 2/4: Updating Nushell Binary" --style "bold cyan" } catch { print (echo-g "\n==> Step 2/4: Updating nushell binary...") }
  if $repo {
    cd $nu_dir
    bash scripts/install-all-mcp.sh
  } else {
    if $force {
      # cargo install nu --locked --features=mcp
      cargo install nu --locked
    } else {
      cargo install-update nu 
    }
  }

  if not $no_plugins {
    try { rich rule "Step 3/4: Updating Official Plugins" --style "bold cyan" } catch { print (echo-g "\n==> Step 3/4: Updating and registering official plugins...") }
    try {
      if $force {
        if $server {
          apps-update nushell-plugins --force --server
        } else {
          apps-update nushell-plugins --force
        }
      } else {
        if $server {
          apps-update nushell-plugins --server
        } else {
          apps-update nushell-plugins
        }
      }
    } catch {|err|
      try { rich print $"[bold red]Failed updating official plugins:[/] ($err.msg)" } catch { print (echo-r $"Failed updating official plugins: ($err.msg)") }
    }

    try { rich rule "Step 4/4: Updating External Plugins & Modules" --style "bold cyan" } catch { print (echo-g "\n==> Step 4/4: Updating and registering external plugins & modules...") }
    try {
      if $force {
        apps-update nushell-plugins-external --force
      } else {
        apps-update nushell-plugins-external
      }
    } catch {|err|
      try { rich print $"[bold red]Failed updating external plugins:[/] ($err.msg)" } catch { print (echo-r $"Failed updating external plugins: ($err.msg)") }
    }
  }

  if $repo and ($nu_dir | path exists) {
    try { rich print "[cyan]Cleaning local repo cargo caches...[/]" } catch { print (echo-g "\n==> Cleaning local repo cargo caches...") }
    try { cd $nu_dir; cargo clean }
  }

  try { rich print "[cyan]Updating config files...[/]" } catch { print (echo-g "\nUpdating config files...") }
  try { update-nu-config } catch { }

  try {
    "✓ Nushell binary, official plugins, and external modules updated and registered headlessly!\nNew terminal windows will immediately run the updated version with all plugins loaded."
      | rich panel --title "Nushell Update Complete" --box rounded --border-style green
  } catch {
    print (echo-g "\n✓ Nushell, official plugins, and external modules have been updated and registered headlessly!")
    print (echo-g "New terminal windows will immediately run the updated version with all plugins loaded.")
  }
}

#update nushell default plugins
export def "apps-update nushell-plugins" [
    --force(-f) #force the install
    --server(-s) #ignore polars in oracle server
] {
  print (echo-g "Updating official nushell plugins via cargo...")
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

  print (echo-g "Registering official plugins headlessly...")
  let plugins = if $server {
    ["nu_plugin_inc" "nu_plugin_gstat" "nu_plugin_query" "nu_plugin_formats"]
  } else {
    ["nu_plugin_inc" "nu_plugin_gstat" "nu_plugin_query" "nu_plugin_formats" "nu_plugin_polars"]
  }

  $plugins | each {|p| register-nu-plugin $p }
  
  if not $server {
    print (echo-g "Regenerating polars aliases...")
    try { apps-update nushell-polars }
  }

  print (echo-g "✓ Official nushell plugins updated and registered successfully!")
}

#update nushell 3rd party plugins & modules (nu_plugin_plot, nu_plugin_port_extension, nu_plugin_file, nu-rich)
export def "apps-update nushell-plugins-external" [
    --force(-f) #force reinstall/recompile even if repositories are up to date
] {
    let is_win = (sys host | get name | str lowercase) == "windows"
    let ext = if $is_win { ".exe" } else { "" }
    let base_dir = ($env.APPS_UPDATE_SOFTWARE_DIR? | default "~/software" | path expand)
    if not ($base_dir | path exists) {
        mkdir $base_dir
    }

    let dev_plot_path = ("~/Yandex.Disk/Development/linux/nushell/nu_plugin_plot" | path expand)
    let items = [
        {
            name: "nu_plugin_plot",
            repo: "https://github.com/kurokirasama/nu_plugin_plot.git",
            type: "plugin",
            binary: "nu_plugin_plot",
            custom_path: (if ($dev_plot_path | path exists) { $dev_plot_path } else { null })
        },
        {
            name: "nu_plugin_port_extension",
            repo: "https://github.com/FMotalleb/nu_plugin_port_extension.git",
            type: "plugin",
            binary: "nu_plugin_port_extension",
            custom_path: null,
            locked: true
        },
        {
            name: "nu_plugin_file",
            repo: "https://github.com/fdncred/nu_plugin_file.git",
            type: "plugin",
            binary: "nu_plugin_file",
            custom_path: null
        },
        {
            name: "nu-rich",
            repo: "https://github.com/fdncred/nu-rich.git",
            type: "module",
            binary: null,
            custom_path: null
        }
    ]

    try { rich rule "Checking 3rd-Party Nushell Plugins & Modules" --style "bold cyan" } catch { print (echo-g "==> Checking 3rd-party Nushell plugins & modules...") }

    for item in $items {
        let target_dir = if ($item.custom_path != null) { $item.custom_path } else { ($base_dir | path join $item.name) }
        mut needs_build = false

        if not ($target_dir | path exists) {
            try { rich print $"  [cyan]Cloning[/] [bold]($item.name)[/] from [dim]($item.repo)[/]..." } catch { print (echo-g $"  Cloning ($item.name) from ($item.repo)...") }
            cd $base_dir
            let clone_res = do { ^git clone $item.repo $item.name } | complete
            if $clone_res.exit_code != 0 {
                try { rich print $"  [bold red]✗ Failed to clone ($item.name):[/] ($clone_res.stderr)" } catch { print (echo-r $"  ✗ Failed to clone ($item.name): ($clone_res.stderr)") }
                continue
            }
            $needs_build = true
        } else {
            cd $target_dir
            do { ^git fetch origin } | complete | ignore

            let local_commit = (do { ^git rev-parse HEAD } | complete).stdout | str trim
            let upstream_res = (do { ^git rev-parse "@{u}" } | complete)
            let has_upstream = ($upstream_res.exit_code == 0)
            let remote_commit = if $has_upstream {
                $upstream_res.stdout | str trim
            } else {
                let main_res = (do { ^git rev-parse "origin/main" } | complete)
                if $main_res.exit_code == 0 {
                    $main_res.stdout | str trim
                } else {
                    (do { ^git rev-parse "origin/master" } | complete).stdout | str trim
                }
            }

            let bin_path = if ($item.binary != null) { $"~/.cargo/bin/($item.binary)($ext)" | path expand } else { null }
            let bin_missing = if ($bin_path != null) { not ($bin_path | path exists) } else { false }

            let cargo_toml_path = ($target_dir | path join "Cargo.toml")
            let repo_version = if ($cargo_toml_path | path exists) {
                try { open $cargo_toml_path | get package.version } catch { "" }
            } else {
                ""
            }

            let plugin_short_name = if ($item.binary != null) { ($item.binary | str replace -r "^nu_plugin_" "") } else { "" }
            let installed_version = try {
                let from_list = (try { plugin list | where name == $plugin_short_name or name == $item.binary | get 0.version } catch { "" })
                if ($from_list | is-not-empty) {
                    $from_list
                } else {
                    version | get installed_plugins | split row ", " | parse "{name} {version}" | where name == $plugin_short_name or name == $item.binary | get 0.version
                }
            } catch {
                ""
            }

            let is_up_to_date = if ($item.custom_path != null) {
                # For local dev repo, compare Cargo.toml version against installed plugin version from `ver`
                if ($repo_version | is-not-empty) and ($installed_version | is-not-empty) {
                    ($repo_version == $installed_version) and (not $bin_missing)
                } else {
                    not $bin_missing
                }
            } else {
                ($local_commit == $remote_commit) and ($local_commit | str length) > 0 and (not $bin_missing)
            }

            if $is_up_to_date and (not $force) {
                let ver_suffix = if ($installed_version | is-not-empty) { " (v" + $installed_version + ")" } else { "" }
                try { rich print $"  [bold green]✓[/] [bold]($item.name)[/]($ver_suffix) is already up to date." } catch { print (echo-g $"  ✓ ($item.name)($ver_suffix) is already up to date.") }
            } else {
                if $has_upstream {
                    try { rich print $"  [yellow]Updating[/] [bold]($item.name)[/]..." } catch { print (echo-g $"  Updating ($item.name)...") }
                    let pull_res = do { ^git pull } | complete
                    if $pull_res.exit_code != 0 {
                        try { rich print $"  [yellow]Warning:[/] git pull failed for ($item.name), proceeding with build attempt..." } catch { print (echo-y $"  Warning: git pull failed for ($item.name), proceeding with build attempt...") }
                    }
                } else {
                    let build_reason = if ($repo_version != $installed_version) and ($repo_version | is-not-empty) {
                        $" [Cargo.toml v($repo_version) != installed v($installed_version)]"
                    } else {
                        ""
                    }
                    try { rich print $"  [yellow]Rebuilding[/] local development package [bold]($item.name)[/]($build_reason)..." } catch { print (echo-g $"  Rebuilding local development package ($item.name)($build_reason)...") }
                }
                $needs_build = true
            }
        }

        if $needs_build or $force {
            cd $target_dir
            if $item.type == "plugin" {
                try { rich print $"  [cyan]Building[/] [bold]($item.name)[/] with cargo..." } catch { print (echo-g $"  Building ($item.name) with cargo...") }
                let install_res = do {
                    let lock_flag = ($item.locked? | default false)
                    if $force and $lock_flag {
                        ^cargo install --path . --locked --force
                    } else if $force {
                        ^cargo install --path . --force
                    } else if $lock_flag {
                        ^cargo install --path . --locked
                    } else {
                        ^cargo install --path .
                    }
                } | complete

                if $install_res.exit_code == 0 {
                    register-nu-plugin $item.binary
                    try { rich print $"  [dim]Cleaning build artifacts for ($item.name)...[/]" } catch { print (echo-g $"  Cleaning build artifacts for ($item.name)...") }
                    try { ^cargo clean } catch { }
                } else {
                    try { rich print $"  [bold red]✗ Failed to cargo install ($item.name):[/] ($install_res.stderr)" } catch { print (echo-r $"  ✗ Failed to cargo install ($item.name): ($install_res.stderr)") }
                }
            } else if $item.type == "module" {
                try { rich print $"  [bold green]✓[/] Module [bold]($item.name)[/] is ready." } catch { print (echo-g $"  ✓ Module ($item.name) is ready.") }
            }
        }
    }

    try { rich print "[cyan]Updating config files...[/]" } catch { print (echo-g "Updating config file...") }
    try { update-nu-config } catch { }

    try {
      "✓ 3rd-party Nushell plugins and modules (nu_plugin_plot, nu_plugin_port_extension, nu_plugin_file, nu-rich) updated and registered headlessly!"
        | rich panel --title "External Plugins Complete" --box rounded --border-style green
    } catch {
      print (echo-g "✓ 3rd-party nushell plugins and modules updated and verified successfully!")
    }
}

#alias for apps-update nushell-plugins-external
export alias "apps-update nushell-external-plugins" = apps-update nushell-plugins-external


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

#update nu-datetime module (date_formats.nu)
export def "apps-update datetime" [--force(-f)] {
  let scripts_dir = $env.MY_ENV_VARS?.nu_scripts? | default "/home/kira/Yandex.Disk/my_scripts/nushell"
  let target_file = $scripts_dir | path join "date_formats.nu"
  let url = "https://raw.githubusercontent.com/fdncred/nu-datetime/main/date-formats.nu"
  print (echo-g "Checking latest date_formats.nu from nu-datetime repository...")
  try {
    let content = http get $url
    if ($target_file | path exists) and (not $force) {
      let local_content = open --raw $target_file
      if $local_content == $content {
        print (echo-g "date_formats.nu is already in its latest version!")
        return
      }
    }
    $content | save -f $target_file
    print (echo-g $"✓ Successfully updated ($target_file)")
  } catch {|err|
    return-error $"Failed to download date_formats.nu: ($err.msg)"
  }
}


#update nu config (after nushell update)
export def update-nu-config [] {
  let nu_dir = ($env.MY_ENV_VARS?.nushell_dir? | default "~/software/nushell" | path expand)
  
  # Direct paths to default sample configs in nushell source tree (instant, zero recursive disk scan)
  let default_config = ($nu_dir | path join "crates" "nu-config" "default_files" "default_config.nu")
  let default_env = ($nu_dir | path join "crates" "nu-config" "default_files" "default_env.nu")

  if ($default_config | path exists) {
    cp -f $default_config $nu.config-path
  }

  if ($default_env | path exists) {
    cp -f $default_env $nu.env-path
  }

  # Generate bootstrap lines directly without external file dependency
  let is_windows = (sys host | get name | str lowercase) == "windows"
  let default_scripts_dir = if $is_windows { "C:\\Users\\kira\\YandexDisk\\my_scripts\\nushell" } else { "~/Yandex.Disk/my_scripts/nushell" | path expand }
  let nu_scripts = ($env.MY_ENV_VARS?.nu_scripts? | default $default_scripts_dir)
  let nu_lines = if $is_windows {
    [
      $"source '($nu_scripts | path join "all.nu")'"
      $"source-env '($nu_scripts | path join "env_vars.nu")'"
      $"source-env '($nu_scripts | path join "config_win.nu")'"
    ]
  } else {
    [
      "source ~/.cache/carapace/init.nu"
      $"source '($nu_scripts | path join "all.nu")'"
      $"source-env '($nu_scripts | path join "env_vars.nu")'"
      $"source-env '($nu_scripts | path join "config.nu")'"
    ]
  } | str join "\n"

  $"\n($nu_lines)\n" | save --append $nu.config-path

  try {
    rich print "  [bold green]✓[/] Nushell configuration updated successfully."
  } catch {
    print (echo-g "✓ Nushell configuration successfully updated.")
  }
}

# update nerd-fonts repo (sparse checkout with latest font-patcher and glyphs)
export def "patch-font update-repo" [] {
  let nerd_font = ("~/software/nerd-fonts" | path expand)
  print (echo-g "Checking / updating nerd-fonts repository...")
  if not ($nerd_font | path exists) or not (($nerd_font | path join ".git") | path exists) {
    print "Cloning sparse nerd-fonts repository (shallow)..."
    mkdir ("~/software" | path expand)
    cd ("~/software" | path expand)
    try { rm -rf nerd-fonts } catch {}
    ^git clone --depth 1 --filter=blob:none --sparse https://github.com/ryanoasis/nerd-fonts.git nerd-fonts
    cd nerd-fonts
    ^git sparse-checkout init --no-cone
    ^git sparse-checkout set font-patcher "src/glyphs/*" "bin/scripts/*" glyphnames.json package.json 10-nerd-font-symbols.conf
  } else {
    print "Pulling latest changes from nerd-fonts origin..."
    cd $nerd_font
    try { ^git pull origin master } catch {}
  }
  print (echo-g "✓ nerd-fonts repository is up to date.")
}

# patch font with nerd font
export def patch-font [file? = "Monocraft.ttc", --no-update(-n)] {
  let nerd_font = ("~/software/nerd-fonts" | path expand)
  let folder = ($env.MY_ENV_VARS?.appImages? | default ("~/Yandex.Disk/Backups/appimages" | path expand))
  let font_folder = ($env.MY_ENV_VARS?.linux_backup? | default ("~/Yandex.Disk/Backups/linux" | path expand))
  
  if not $no_update {
    patch-font update-repo
  }
  
  cd $folder
 
  let src_file = ($font_folder | path join $file | path expand)
  if ($src_file | path exists) {
    cp -f $src_file .
  }
 
  let patcher = ($nerd_font | path join "font-patcher")
  let target = ($env.PWD | path join $file)
  print (echo-g $"Running font-patcher on ($file)...")
  with-env { PYTHONIOENCODING: "utf-8", LANG: "en_US.UTF-8", LC_ALL: "en_US.UTF-8" } {
    ./fontforge.AppImage -script $patcher $target --complete --careful --outputdir $env.PWD
  }
 
  let latest_ttc = (try { 
    ls *.ttc | where name !~ "-nerd-fonts-patched_by_me" and name != $target | sort-by modified | last | get name 
  } catch { "" })
  if ($latest_ttc | is-not-empty) {
    let patched_name = $"($file | path parse | get stem)-nerd-fonts-patched_by_me.ttc"
    mv -f $latest_ttc $patched_name
    cp -f $patched_name ($font_folder | path expand)
 
    try { sudo cp -f $patched_name /usr/local/share/fonts/Monocraft.ttc } catch {}
    try {
      mkdir ("~/.local/share/fonts" | path expand)
      cp -f $patched_name ("~/.local/share/fonts/Monocraft.ttc" | path expand)
      rm -f ("~/.fonts/Monocraft*.ttc" | path expand)
    } catch {}
    fc-cache -fv; try { sudo fc-cache -fv } catch {}
  }
  try { rm -f $target } catch {}

  # Clean up nerd-fonts temporary files
  try { nerd-fonts-clean } catch {}
  
  print (echo-g "✓ Font patching and cache rebuild complete.")
  print (echo-g "To deploy on remote machines, copy:")
  print (echo-g $"cp ($font_folder)/Monocraft-nerd-fonts-patched_by_me.ttc ~/.local/share/fonts/Monocraft.ttc; fc-cache -fv")
}

# Detect OS via sys host, normalized to lowercase
export def detect-os []: nothing -> string {
  let os_name = sys host | get name | str lowercase
  if ($os_name | str contains "cachyos") {
    "cachyos"
  } else if ($os_name | str contains "ubuntu") {
    "ubuntu"
  } else if ($os_name | str contains "arch") or ($os_name in ["manjaro", "endeavouros", "garuda", "artix"]) {
    "arch"
  } else {
    "unknown"
  }
}

# Return workflow record for given OS
export def get-os-workflow [os: string] {
  match $os {
    "ubuntu" => {
      name: "ubuntu",
      update_cmd: "nala upgrade -y",
      fallback_update_cmd: "apt update && apt upgrade -y",
      cleanup_cmd: "nala autoremove -y",
      fallback_cleanup_cmd: "apt autoremove -y",
      has_nala: true,
      has_custom_pacman: false
    },
    "cachyos" => {
      name: "cachyos",
      update_cmd: "pacman -Syu",
      mirror_cmd: "cachy-rate-mirrors",
      cache_cleanup_cmd: "paccache -rvk3",
      aur_helpers: ["paru", "yay", "pamac"],
      cleanup_cmd: "pacman -Rns (pacman -Qtdq)",
      has_custom_pacman: true,
      has_cachy_update: true,
      # extended_ops: ["npm-pkgs","go-pkgs","cargo-pkgs","uv-tools","git-tools","r-pkgs","git-repos","ollama-models","fonts","omarchy"] via run-cachyos-* runners (supgrade --all)
    },
    "arch" => {
      name: "arch",
      update_cmd: "pacman -Syu",
      cache_cleanup_cmd: "paccache -rvk3",
      aur_helpers: ["paru", "yay", "pamac"],
      cleanup_cmd: "pacman -Rns (pacman -Qtdq)",
      has_custom_pacman: false
    },
    _ => {
      name: "unknown",
      update_cmd: "",
      fallback_update_cmd: "",
      cleanup_cmd: "",
      has_nala: false,
      has_custom_pacman: false
    }
  }
}

# Helper to run command with dry-run support
def run-with-dry-run [cmd: string, dry_run: bool] {
  if $dry_run {
    print $"[DRY-RUN] Would execute: ($cmd)"
    return true
  }
  try {
    ^bash -c $cmd
    true
  } catch {|e|
    print (echo-r $"Failed: ($cmd) - ($e.msg)")
    false
  }
}

def run-ubuntu-workflow [old: bool, dry_run: bool] {
  if $old {
    run-with-dry-run "sudo apt update -y" $dry_run
    run-with-dry-run "sudo apt upgrade -y" $dry_run
  } else {
    if (which nala | is-not-empty) {
      run-with-dry-run "sudo nala upgrade -y" $dry_run
    } else {
      run-with-dry-run "sudo apt update -y" $dry_run
      run-with-dry-run "sudo apt upgrade -y" $dry_run
    }
  }
  run-with-dry-run "sudo apt autoremove -y" $dry_run
}

def run-cachyos-workflow [skip_mirrors: bool, skip_cache_cleanup: bool, skip_aur: bool, dry_run: bool] {
  if not $skip_mirrors {
    if (which cachy-rate-mirrors | is-not-empty) {
      run-with-dry-run "sudo cachy-rate-mirrors" $dry_run
    }
  }
  run-with-dry-run "sudo pacman -Syu" $dry_run
  if not $skip_cache_cleanup {
    if (which paccache | is-not-empty) {
      run-with-dry-run "sudo paccache -rvk3" $dry_run
    }
  }
  if not $skip_aur {
    for helper in ["paru", "yay", "pamac"] {
      if (which $helper | is-not-empty) {
        run-with-dry-run $"($helper) -Syu" $dry_run
        break
      }
    }
  }
  if (which pacman | is-not-empty) {
    try {
      if $dry_run {
        print $"[DRY-RUN] Would execute: pacman -Rns (pacman -Qtdq) [orphans]"
      } else {
        let orphans = ^pacman -Qtdq | complete | get stdout | str trim
        if ($orphans | is-not-empty) {
          ^bash -c "sudo pacman -Rns --noconfirm (pacman -Qtdq)"
        }
      }
    } catch {}
  }
}

def run-arch-workflow [skip_cache_cleanup: bool, skip_aur: bool, dry_run: bool] {
  run-with-dry-run "sudo pacman -Syu" $dry_run
  if not $skip_cache_cleanup {
    if (which paccache | is-not-empty) {
      run-with-dry-run "sudo paccache -rvk3" $dry_run
    }
  }
  if not $skip_aur {
    for helper in ["paru", "yay", "pamac"] {
      if (which $helper | is-not-empty) {
        run-with-dry-run $"($helper) -Syu" $dry_run
        break
      }
    }
  }
  if (which pacman | is-not-empty) {
    try {
      if $dry_run {
        print $"[DRY-RUN] Would execute: pacman -Rns (pacman -Qtdq) [orphans]"
      } else {
        let orphans = ^pacman -Qtdq | complete | get stdout | str trim
        if ($orphans | is-not-empty) {
          ^bash -c "sudo pacman -Rns --noconfirm (pacman -Qtdq)"
        }
      }
    } catch {}
  }
}

# CachyOS category runners (ponytail: simple dispatch, add per-category logic if needed)
export def run-cachyos-npm-pkgs [dry_run: bool]: nothing -> nothing {
  for cmd in ["apps-update claude", "apps-update gemini", "apps-update mermaid-ascii", "apps-update mermaid-filter", "apps-update mermaid-cli", "apps-update fast-cli", "apps-update tldr", "apps-update context-mode"] {
    if $dry_run { print $"[DRY-RUN] Would execute: ($cmd)" } else { try { bash -c $cmd | ignore } catch {|e| print (echo-y $"Warning ($cmd): ($e.msg)") } }
  }
  for pkg in ["subsync", "puppeteer", "@google/clasp", "pyright", "byterover-cli"] {
    if $dry_run { print $"[DRY-RUN] Would execute: npm update -g ($pkg)" } else { try { ^npm update -g $pkg | ignore } catch {|e| print (echo-y $"Warning npm ($pkg): ($e.msg)") } }
  }
}
export def run-cachyos-go-pkgs [dry_run: bool]: nothing -> nothing {
  for cmd in ["apps-update glow", "apps-update ttt", "apps-update cariddi", "apps-update gowall", "apps-update reader", "apps-update hakrawler", "apps-update draw"] {
    if $dry_run { print $"[DRY-RUN] Would execute: ($cmd)" } else { try { bash -c $cmd | ignore } catch {|e| print (echo-y $"Warning ($cmd): ($e.msg)") } }
  }
  for pkg in ["github.com/ChausseBenjamin/termpicker@latest", "github.com/ThomasHabets/cmdg/cmd/cmdg@latest", "github.com/ThomasHabets/cmdg/cmd/med@latest", "github.com/kurokirasama/cmdg-image-render/cmd/cmdg-image-render@latest"] {
    if $dry_run { print $"[DRY-RUN] Would execute: go install ($pkg)" } else { try { go install $pkg | ignore } catch {|e| print (echo-y $"Warning go ($pkg): ($e.msg)") } }
  }
}
export def run-cachyos-cargo-pkgs [dry_run: bool]: nothing -> nothing {
  for cmd in ["apps-update termframe", "apps-update oxicord", "apps-update ox", "apps-update lstr"] {
    if $dry_run { print $"[DRY-RUN] Would execute: ($cmd)" } else { try { bash -c $cmd | ignore } catch {|e| print (echo-y $"Warning ($cmd): ($e.msg)") } }
  }
  if (which cargo | is-not-empty) {
    run-with-dry-run "cargo install-update -a" $dry_run
    for pkg in ["toktop", "bat", "zoxide", "tokei", "bottom", "simple-http-server", "alass-cli", "cargo-update", "ht", "doxx", "xleak"] {
      if $dry_run { print $"[DRY-RUN] Would execute: cargo install ($pkg)" } else { try { cargo install $pkg | ignore } catch {|e| print (echo-y $"Warning cargo ($pkg): ($e.msg)") } }
    }
  }
}
export def run-cachyos-uv-tools [dry_run: bool]: nothing -> nothing {
  for cmd in ["apps-update linecast", "apps-update subliminal", "apps-update whisper", "apps-update nvitop"] {
    if $dry_run { print $"[DRY-RUN] Would execute: ($cmd)" } else { try { bash -c $cmd | ignore } catch {|e| print (echo-y $"Warning ($cmd): ($e.msg)") } }
  }
  for tool in ["termdown", "tldr"] {
    if $dry_run { print $"[DRY-RUN] Would execute: uv tool upgrade ($tool) or pipx upgrade ($tool)" } else {
      if (which uv | is-not-empty) { try { uv tool upgrade $tool | ignore } catch {} } else if (which pipx | is-not-empty) { try { pipx upgrade $tool | ignore } catch {} }
    }
  }
}
export def run-cachyos-git-tools [dry_run: bool]: nothing -> nothing {
  for cmd in ["apps-update ddgr", "apps-update rclone", "apps-update matlab-lsp"] {
    if $dry_run { print $"[DRY-RUN] Would execute: ($cmd)" } else { try { bash -c $cmd | ignore } catch {|e| print (echo-y $"Warning ($cmd): ($e.msg)") } }
  }
}
export def run-cachyos-language-runtimes [dry_run: bool]: nothing -> nothing {
  if (which go | is-not-empty) { run-with-dry-run "go install golang.org/dl/go@latest" $dry_run }
  if (which uv | is-not-empty) { run-with-dry-run "uv self update" $dry_run }
  if (which npm | is-not-empty) { run-with-dry-run "npm update -g npm" $dry_run }
  if (which rustup | is-not-empty) { run-with-dry-run "rustup update" $dry_run }
}

def run-common-operations [dry_run: bool, cargo_aps: bool]: nothing -> nothing {
  if (which snap | is-not-empty) {
    run-with-dry-run "sudo snap refresh" $dry_run
  }
  if (which flatpak | is-not-empty) {
    run-with-dry-run "flatpak update -y" $dry_run
  }
  if (which fwupdmgr | is-not-empty) {
    run-with-dry-run "sudo fwupdmgr update" $dry_run
  }
  if (which rustup | is-not-empty) {
    run-with-dry-run "rustup update" $dry_run
  }
  if (which stack | is-not-empty) {
    run-with-dry-run "stack upgrade" $dry_run
  }
  if $cargo_aps {
    if (which cargo | is-not-empty) {
      run-with-dry-run "cargo install-update -a" $dry_run
    }
  }
}

# Update and upgrade system packages, auto-detecting OS (Ubuntu/CachyOS/Arch) via sys host.
# Applies the proper workflow: Ubuntu uses nala/apt, CachyOS/Arch use pacman + cachy-rate-mirrors/paccache/AUR helpers.
# Common operations (snap, flatpak, fwupdmgr, rustup, stack, cargo) run on all OSes.
# CachyOS extended: --npm-pkgs, --go-pkgs, --cargo-pkgs, --uv-tools, --git-tools, --r-pkgs, --git-repos, --ollama-models, --fonts, --omarchy, --all
# Flags: --old (Ubuntu apt), --cargo_aps (cargo update), --skip-mirrors/cache-cleanup/aur, --dry-run, CachyOS category flags, --all
export def supgrade [--old(-o),--cargo_aps(-c),--skip-mirrors,--skip-cache-cleanup,--skip-aur,--dry-run, --npm-pkgs, --go-pkgs, --cargo-pkgs, --uv-tools, --git-tools, --r-pkgs, --git-repos, --ollama-models, --fonts, --omarchy, --all] {
  let os = detect-os
  print (echo-g $"Detected OS: ($os)")

  mut workflow = get-os-workflow $os
  if $workflow.name == "unknown" {
    print (echo-r $"Unknown OS '($os)', falling back to ubuntu workflow")
    $workflow = get-os-workflow "ubuntu"
  }

  if $dry_run {
    print (echo-g "=== DRY RUN MODE ===")
    print (echo-g $"Would run ($workflow.name) workflow")
  }

  print (echo-g $"Using ($workflow.name) workflow...")

  match $workflow.name {
    "ubuntu" => { run-ubuntu-workflow $old $dry_run },
    "cachyos" => { run-cachyos-workflow $skip_mirrors $skip_cache_cleanup $skip_aur $dry_run },
    "arch" => { run-arch-workflow $skip_cache_cleanup $skip_aur $dry_run },
    _ => { run-ubuntu-workflow $old $dry_run }
  }

  # CachyOS extended category operations (only on cachyos workflow)
  if $workflow.name == "cachyos" {
    if ($all or $npm_pkgs) { print (echo-g "Running npm packages update..."); run-cachyos-npm-pkgs $dry_run }
    if ($all or $go_pkgs) { print (echo-g "Running Go packages update..."); run-cachyos-go-pkgs $dry_run }
    if ($all or $cargo_pkgs) { print (echo-g "Running Cargo packages update..."); run-cachyos-cargo-pkgs $dry_run }
    if ($all or $uv_tools) { print (echo-g "Running UV tools update..."); run-cachyos-uv-tools $dry_run }
    if ($all or $git_tools) { print (echo-g "Running Git tools update..."); run-cachyos-git-tools $dry_run }
    if ($all or $r_pkgs) { print (echo-g "Running R packages update..."); try { if $dry_run { print "[DRY-RUN] Would execute: apps-update r-pkgs" } else { apps-update r-pkgs } } catch {|e| print (echo-y $"apps-update r-pkgs failed: ($e.msg)") } }
    if ($all or $git_repos) { print (echo-g "Running Git repos update..."); try { if $dry_run { print "[DRY-RUN] Would execute: apps-update git-repos" } else { apps-update git-repos } } catch {|e| print (echo-y $"apps-update git-repos failed: ($e.msg)") } }
    if ($all or $ollama_models) { print (echo-g "Running Ollama models update..."); try { if $dry_run { print "[DRY-RUN] Would execute: apps-update ollama-models" } else { apps-update ollama-models } } catch {|e| print (echo-y $"apps-update ollama-models failed: ($e.msg)") } }
    if ($all or $fonts) { print (echo-g "Running fonts update..."); try { if $dry_run { print "[DRY-RUN] Would execute: apps-update fonts-nerd" } else { apps-update fonts-nerd } } catch {|e| print (echo-y $"apps-update fonts-nerd failed: ($e.msg)") } }
    if ($all or $omarchy) { print (echo-g "Running Omarchy update..."); try { if $dry_run { print "[DRY-RUN] Would execute: apps-update omarchy" } else { apps-update omarchy } } catch {|e| print (echo-y $"apps-update omarchy failed: ($e.msg)") } }
    if $all { print (echo-g "Running language runtimes update..."); run-cachyos-language-runtimes $dry_run }
  } else {
    if ($all or $npm_pkgs or $go_pkgs or $cargo_pkgs or $uv_tools or $git_tools or $r_pkgs or $git_repos or $ollama_models or $fonts or $omarchy) {
      print (echo-y "Warning: CachyOS-specific flags ignored on non-CachyOS workflow")
    }
  }

  run-common-operations $dry_run $cargo_aps

  if not $dry_run {
    print (echo-g "=== Upgrade Complete ===")
    print (echo-g $"OS: ($os) via ($workflow.name) workflow")
  } else {
    print (echo-g "=== Dry Run Complete ===")
  }
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
  try {
    apps-update datetime
  } catch {
    print (echo-r "Datetime update failed!")
  }
  try {
    sober-update
  } catch {
    print (echo-r "Something went wrong with Sober (Roblox) update!")
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

# Normalize a version string to a three-part semver-compatible string.
# Example: "3.10" -> "3.10.0", "3.10-1" -> "3.10.0"
export def normalize-version [v: string] {
  let clean = ($v | split row "-" | get 0 | ansi strip | str trim)
  let parts = ($clean | split row ".")
  if ($parts | length) == 1 {
    $"($parts.0).0.0"
  } else if ($parts | length) == 2 {
    $"($parts.0).($parts.1).0"
  } else {
    $clean
  }
}

# Compare two normalized semver strings to see if v1 >= v2.
# Since v0.115.1 semver comparisons parse as bool, direct comparison replaces
# the old sort-based workaround.
export def semver-ge [v1: string, v2: string] {
  if $v1 == $v2 { return true }
  try {
    ($v1 | into semver) >= ($v2 | into semver)
  } catch {
    return ($v1 == $v2)
  }
}

# Check if the installed system version is greater than or equal to the latest version.
export def is-system-up-to-date [sys_ver: string, new_ver: string] {
  if ($sys_ver | is-empty) { return false }
  let norm_sys = (normalize-version $sys_ver)
  let norm_new = (normalize-version $new_ver)
  return (semver-ge $norm_sys $norm_new)
}

# Retrieve the installed package/binary version for a given application.
export def get-system-app-version [app: string] {
  let dpkg_res = (do { dpkg-query -W -f='${Version}' $app } | complete)
  if $dpkg_res.exit_code == 0 and ($dpkg_res.stdout | is-not-empty) {
    return ($dpkg_res.stdout | ansi strip | str trim)
  }
  
  let which_res = (do { which $app } | complete)
  if $which_res.exit_code == 0 and ($which_res.stdout | is-not-empty) {
    let ver_res = (do { nu -c $"($app) --version" } | complete)
    if $ver_res.exit_code == 0 and ($ver_res.stdout | is-not-empty) {
      let line = ($ver_res.stdout | lines | get 0 | ansi strip | str trim)
      let match = ($line | parse -r '(?P<ver>\d+(\.\d+)+)')
      if ($match | is-not-empty) {
        return ($match.0.ver)
      }
    }
  }
  
  return ""
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
      if $file_type == "deb" {
        let sys_ver = (get-system-app-version $app)
        if (is-system-up-to-date $sys_ver $new_version) {
          print (echo-g $"($repo) is already in its latest version!")
          return
        } else {
          let deb_file_list = (
            if ($pattern | is-not-empty) {
              ls | find -n $pattern
            } else {
              ls ($"*.($file_type)" | into glob)
            }
            | find -n $app
          )
          if ($deb_file_list | is-not-empty) {
            let deb_name = ($deb_file_list.0.name | ansi strip)
            let sys_desc = (if ($sys_ver | is-empty) { "uninstalled" } else { $sys_ver })
            print (echo-g $"($repo) version ($new_version) is already downloaded locally in ($down_dir), but system version is '($sys_desc)'.")
            let install = input (echo-g "Would you like to install it now? (y/n): ")
            if $install == "y" {
              sudo gdebi -n $deb_name
            }
            return
          }
        }
      } else {
        print (echo-g $"($repo) is already in its latest version!")
        return
      }
    }
  }

  # check if the new version is already downloaded locally (regardless of $exists)
  let new_version_file = (
    if ($pattern | is-not-empty) {
      ls | find -n $pattern
    } else {
      ls ($"*.($file_type)" | into glob)
    }
    | find -n $app
    | where {|f|
      let v = $f.name
        | path parse
        | get stem
        | split row (if not $find_ {"_"} else {"-"})
        | get 1
      $v == $new_version
    }
  )
  if ($new_version_file | is-not-empty) {
    print (echo-g $"($repo) version ($new_version) already downloaded locally, skipping download.")
    if $file_type == "deb" {
      let install = input (echo-g "Would you like to install it now? (y/n): ")
      if $install == "y" {
        sudo gdebi -n ($new_version_file.0.name | ansi strip)
      }
    } else {
      print (echo-g "file already downloaded...")
    }
    return
  }

  if $exists {
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
    print (echo-g "chrome deb already downloaded locally, skipping download.")
    return
  }
  
  print (echo-g "\ndownloading chrome...")
  aria2c --download-result=hide https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
}

#update google earth deb
@category sudo
export def "apps-update earth" [] {
  cd $env.MY_ENV_VARS.debs

  let new_version = try {
    http get "https://support.google.com/earth/answer/40901#zippy=%2Cearth-version" 
    | lines 
    | find -n version 
    | first
  } catch { "" }
  

  let current_version = open ([$env.MY_ENV_VARS.debs earth.json] | path join) | get version

  if $current_version == $new_version {
    print (echo-g "earth is already in its latest version!")
    return
  }
  
  if (ls *.deb | find earth | length) > 0 {
    print (echo-g "google earth deb already downloaded locally, skipping download.")
    sudo gdebi -n (ls *.deb | find earth | get 0 | get name | ansi strip)
    return
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
    print (echo-g "yandex deb already downloaded locally, skipping download.")
    sudo gdebi -n yandex-disk_latest_amd64.deb
    open $file
    | upsert date (date now | format date)
    | save -f $file
    return
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
    
    # check if the new version is already downloaded
    let existing_new = ls *.deb
      | find -i "sejda"
      | where {|f| ($f.name | split row _ | get 1) == $new_version }
    if ($existing_new | is-not-empty) {
      print (echo-g $"sejda version ($new_version) already downloaded locally, skipping download.")
      sudo gdebi -n ($existing_new.0.name | ansi strip)
      return
    }

    print (echo-g "\nupdating sedja...")
    rm sejda*.deb | ignore
    aria2c --download-result=hide $url
    sudo gdebi -n $new_file
  } else {
    # check if the new version is already downloaded (fresh install)
    let existing_new = ls *.deb
      | find -i "sejda"
      | where {|f| ($f.name | split row _ | get 1) == $new_version }
    if ($existing_new | is-not-empty) {
      print (echo-g $"sejda version ($new_version) already downloaded locally, skipping download.")
      sudo gdebi -n ($existing_new.0.name | ansi strip)
      return
    }

    print (echo-g "\ndownloading sedja...")
    aria2c --download-result=hide $url
    sudo gdebi -n $new_file
  }
}

#update ttyplot
@category sudo
export def "apps-update ttyplot" [] {
  cd $env.MY_ENV_VARS.debs

  let existing_files = ls | find -n tty | get name
  let current_version = if ($existing_files | is-empty) {
    ""
  } else {
    $existing_files | get 0 | split row _ | get 1
  }

  let scraped = try {
    let result = http get https://packages.debian.org/sid/amd64/ttyplot/download
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
    { ok: true, url: $result }
  } catch { |e|
    { ok: false, error: $"Failed to fetch ttyplot download URL: ($e.msg)" }
  }

  if not $scraped.ok {
    print (echo-r $scraped.error)
    return
  }

  let url = $scraped.url

  let filename = $url | split row / | last

  let new_version = $filename | split row _ | get 1

  if $current_version == $new_version {
    print (echo-g "ttyplot is already in the latest version!")
    return
  }

  # check if the new version is already downloaded
  let existing_new = ls | find -n tty | where {|f| ($f.name | split row _ | get 1) == $new_version }
  if ($existing_new | is-not-empty) {
    print (echo-g $"ttyplot version ($new_version) already downloaded locally, skipping download.")
    sudo gdebi -n ($existing_new.0.name | ansi strip)
    return
  }

  print (echo-g $"\nupdating ttyplot...")

  let old_debs = glob $"($env.MY_ENV_VARS.debs)/*ttyplot*.deb"
  if not ($old_debs | is-empty) {
    $old_debs | each {|f| rm $f}
  }
  aria2c --download-result=hide $url

  sudo gdebi -n $filename
}

#update vivaldi
export def "apps-update vivaldi" [] {
  cd $env.MY_ENV_VARS.debs
  
  let release_url = try {
    http get "https://vivaldi.com/download/"
    | lines 
    | find -n deb 
    | find -n amd64 
    | first
  } catch { "" }
  

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
  
  # check if the new version is already downloaded
  let existing_new = ls | where name like vivaldi | where {|f| ($f.name | split row _ | get 1) == $last_version }
  if ($existing_new | is-not-empty) {
    print (echo-g $"vivaldi version ($last_version) already downloaded locally, skipping download.")
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
export def install-font [file: string] {
  let font_path = ($file | path expand)
  if not ($font_path | path exists) {
    print (echo-r $"Font file not found: ($font_path)")
    return
  }
  print (echo-g $"Installing font ($font_path)...")
  try {
    mkdir ("~/.local/share/fonts" | path expand)
    cp -f $font_path ("~/.local/share/fonts/" | path expand)
  } catch {}
  try {
    sudo mkdir -p /usr/local/share/fonts
    sudo cp -f $font_path /usr/local/share/fonts/
  } catch {}
  fc-cache -fv
  try { sudo fc-cache -fv } catch {}
  print (echo-g "✓ Font installed and font cache updated successfully.")
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

#update ffmpeg with cuda and nv-codec-headers
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

#update mermaid-ascii
export def "apps-update mermaid-ascii" [] {
  npm update -g mermaid-ascii
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

# rclone install.sh exits with 3 when the installed version is already up to date,
# which is a success condition, not an error
def is-rclone-update-success [exit_code: int] {
  $exit_code == 0 or $exit_code == 3
}

#update rclone
@category sudo
export def "apps-update rclone" [] {
  try {
    bash -c "sudo -v ; curl -s# https://rclone.org/install.sh | sudo bash"
  } catch { }
  if $env.LAST_EXIT_CODE == 3 {
    print "rclone is already up to date."
  } else if (not (is-rclone-update-success $env.LAST_EXIT_CODE)) {
    return-error $"rclone update failed with exit code ($env.LAST_EXIT_CODE)"
  }
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

#update ttt (Terminal Text Tool)
export def "apps-update ttt" [] {
  if (which ttt | is-empty) {
    print (echo-g "ttt is not installed. Installing...")
  } else {
    print (echo-g "Updating ttt...")
  }
  go install github.com/eugenioenko/ttt/cmd/ttt@latest
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

#update r packages (CRAN + GitHub from Rpackages.R)
export def "apps-update r-pkgs" [--dry-run]: nothing -> nothing {
  if $dry_run {
    print "[DRY-RUN] Would update R packages from Rpackages.R and GitHub sources"
    return
  }
  let candidates = [
    ($env.MY_ENV_VARS.linux_backup? | default "~/Yandex.Disk/Backups/linux" | path expand | path join "Rpackages.R")
    ("~/Yandex.Disk/Backups/linux/Rpackages.R" | path expand)
    ("./Rpackages.R" | path expand)
  ]
  mut rpackages_file = ""
  for c in $candidates {
    if ($c | path exists) { $rpackages_file = $c; break }
  }
  if ($rpackages_file | is-empty) {
    print (echo-y "Rpackages.R not found, skipping")
    return
  }
  print (echo-g $"Updating R packages from ($rpackages_file)...")
  try {
    ^mkdir -p ~/R/library
    ^R --vanilla -f $rpackages_file
  } catch {|e| print (echo-y $"Warning R CRAN install: ($e.msg)")}
  try {
    R --vanilla -e ".libPaths(c('~/R/library', .libPaths())); if (!'lobstr' %in% rownames(installed.packages())) install.packages('lobstr', repos='https://cloud.r-project.org/', lib='~/R/library'); if (!'sloop' %in% rownames(installed.packages())) install.packages('sloop', repos='https://cloud.r-project.org/', lib='~/R/library')"
  } catch {|e| print (echo-y $"Warning lobstr/sloop: ($e.msg)")}
  for pkg in ["jeroenjanssens/rush", "coolbutuseless/devout", "coolbutuseless/miniansi", "coolbutuseless/devoutansi", "jeroenjanssens/tmuxr", "jeroenjanssens/knitractive", "jeroenjanssens/rexpect"] {
    try {
      let r_code = (["remotes::install_github(\"", $pkg, "\", dependencies=TRUE, force=TRUE)"] | str join)
      ^R --vanilla -e $r_code
    } catch {|e| print (echo-y $"Warning GitHub ($pkg): ($e.msg)")}
  }
  print (echo-g "R packages update complete")
}

#update git repositories (all known from install_cachyos_02.nu)
export def "apps-update git-repos" [--dry-run]: nothing -> nothing {
  if $dry_run {
    print "[DRY-RUN] Would git pull all known repositories in ~/software"
    return
  }
  let repos = [
    "cachyos_semiautomatic_install", "obsidian-mcp-server", "markdownify-mcp", "dalle-mcp", "imagen-3.0-generate-google-mcp-server", "google-sheets-mcp", "google-forms-mcp", "Proton-Community-Updater", "ddgr", "pandoc-theorem", "mermaid-ascii", "ox.wiki", "nv-codec-headers", "nu-rich", "nu_plugin_file", "nu_plugin_plot", "nu_plugin_port_extension", "delogo", "Logodetect", "private-gpt", "exo", "MATLAB-language-server", "cmdg-image-render", "nerd-fonts"
  ]
  cd ~/software
  for repo in $repos {
    if ($repo | path exists) {
      try {
        print (echo-g $"Updating ($repo)...")
        cd $repo; git pull; cd ~/software
      } catch {|e| print (echo-y $"Warning pulling ($repo): ($e.msg)"); try { cd ~/software } catch {} }
    } else {
      print (echo-y $"Skipping ($repo): not found in ~/software")
    }
  }
  let nu_bin = if ("~/.cargo/bin/nu" | path expand | path exists) { "~/.cargo/bin/nu" | path expand } else { which nu | get 0?.path? | default "nu" }
  for p in (try { ls ~/.cargo/bin/nu_plugin_* | get name } catch { [] }) {
    try { do { ^$nu_bin -c $"plugin add '($p)'" } | complete } catch {}
  }
  print (echo-g "Git repositories update complete")
}

#update ollama models (pull latest for each installed model)
export def "apps-update ollama-models" [--dry-run]: nothing -> nothing {
  if $dry_run {
    print "[DRY-RUN] Would pull latest for all installed Ollama models"
    return
  }
  if (which ollama | is-empty) { print (echo-y "ollama not installed"); return }
  let models = try { ollama list | lines | skip 1 | each {|l| $l | split column " " --collapse-empty | get column1.0? | default "" | str trim } | where {|x| $x | is-not-empty } } catch {|e| [] }
  if ($models | is-empty) { print (echo-y "No ollama models found"); return }
  for m in $models {
    try {
      print (echo-g $"Pulling Ollama model ($m)...")
      ollama pull $m
    } catch {|e| print (echo-y $"Warning pulling ($m): ($e.msg)")}
  }
  print (echo-g "Ollama models update complete")
}

#update nerd fonts, hack, ubuntu fonts
export def "apps-update fonts-nerd" [--dry-run]: nothing -> nothing {
  if $dry_run {
    print "[DRY-RUN] Would update Nerd Fonts, Hack, Ubuntu fonts and rebuild cache"
    return
  }
  cd ~/software
  if not ("nerd-fonts" | path exists) {
    try { git clone --depth 1 https://github.com/ryanoasis/nerd-fonts.git } catch {|e| print (echo-y $"clone nerd-fonts failed: ($e.msg)")}
  }
  if ("nerd-fonts" | path exists) {
    try {
      cd nerd-fonts; git pull; chmod +x font-patcher
      bash -c 'find . -type f \( -name "*.otf" -o -name "*Symbol*" \) -exec cp {} ~/.local/share/fonts/ \; 2>/dev/null || true'
      cd ~/software
    } catch {|e| print (echo-y $"nerd-fonts update failed: ($e.msg)")}
  }
  let backup_dir = ($env.MY_ENV_VARS.linux_backup? | default "~/Yandex.Disk/Backups/linux" | path expand)
  if ($backup_dir | path join "Hack-Font.7z" | path exists) {
    try { 7z x ($backup_dir | path join "Hack-Font.7z") -o($env.HOME | path join "temp_fonts") -y | ignore } catch {}
  }
  if ($backup_dir | path join "ubuntu-fonts.7z" | path exists) {
    try { 7z x ($backup_dir | path join "ubuntu-fonts.7z") -o($env.HOME | path join "temp_fonts") -y | ignore } catch {}
  }
  if ($env.HOME | path join "temp_fonts" | path exists) {
    bash -c "sudo mv ~/temp_fonts/* /usr/local/share/fonts/ 2>/dev/null || true; rm -rf ~/temp_fonts 2>/dev/null || true"
  }
  try { ^mkdir -p ~/.local/share/fonts } catch {}
  fc-cache -fv | ignore; try { sudo fc-cache -fv | ignore } catch {}
  if (which omarchy | is-not-empty) { try { ^omarchy font set "Monocraft Nerd Font" | ignore } catch {} }
  print (echo-g "Fonts update complete")
}

#update omarchy framework
export def "apps-update omarchy" [--dry-run]: nothing -> nothing {
  if $dry_run {
    print "[DRY-RUN] Would update Omarchy framework"
    return
  }
  let omarchy_tmp = "/tmp/omarchy_cachyos"
  try { rm -rf $omarchy_tmp } catch {}
  try {
    git clone https://github.com/mroboff/omarchy-on-cachyos.git $omarchy_tmp
    cd ($omarchy_tmp | path join "bin")
    chmod +x fetch-omarchy.sh install-omarchy-on-cachyos.sh nvidia.sh
    bash -c "sed -i 's|\\$SCRIPT_DIR/../../omarchy|\\$SCRIPT_DIR/../omarchy|g' fetch-omarchy.sh install-omarchy-on-cachyos.sh"
    bash -c "sed -i 's/read -r OMARCHY_USER_NAME/[ -z \"\\$OMARCHY_USER_NAME\" ] \\&\\& read -r OMARCHY_USER_NAME/' install-omarchy-on-cachyos.sh"
    bash -c "sed -i 's/read -r OMARCHY_USER_EMAIL/[ -z \"\\$OMARCHY_USER_EMAIL\" ] \\&\\& read -r OMARCHY_USER_EMAIL/' install-omarchy-on-cachyos.sh"
    bash -c "sed -i 's/sudo pacman -Syu/sudo pacman -Sy --noconfirm/' install-omarchy-on-cachyos.sh"
    bash -c "printf '2\\ny\\n' | ./fetch-omarchy.sh"
    bash -c "sed -i 's|./fetch-omarchy.sh|# ./fetch-omarchy.sh|' install-omarchy-on-cachyos.sh"
    bash -c "sed -i 's|chmod +x install.sh|# chmod +x install.sh|' install-omarchy-on-cachyos.sh"
    bash -c "sed -i 's|./install.sh|bash install/config/all.sh 2>/dev/null; bash install/user/all.sh 2>/dev/null|' install-omarchy-on-cachyos.sh"
    $env.OMARCHY_USER_NAME = (try { $env.SUDO_USER } catch { $env.USER })
    $env.OMARCHY_USER_EMAIL = "kurapika666@gmail.com"
    bash -c "printf '\\n\\n\\n' | ./install-omarchy-on-cachyos.sh"
    print (echo-g "Omarchy update completed")
  } catch {|e| print (echo-r $"Omarchy update failed: ($e.msg)")}
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
    if ($current_version | into semver) >= ($latest_version | into semver) {
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
    let deb_file = "megacmd-xUbuntu_20.04_amd64.deb"
    if ($deb_file | path exists) or ([$env.MY_ENV_VARS.debs $deb_file] | path join | path exists) {
      print (echo-g "mega-get deb already downloaded locally, skipping download.")
      sudo apt install ($deb_file | path expand)
      return
    }
    aria2c https://mega.nz/linux/repo/xUbuntu_20.04/amd64/$deb_file
    sudo apt install ("megacmd-xUbuntu_20.04_amd64.deb" | path expand)
    mv -u megacmd-xUbuntu_20.04_amd64.deb $env.MY_ENV_VARS.debs

    return
  } 
  
  let deb_file = "megacmd-xUbuntu_24.04_amd64.deb"
  if ($deb_file | path exists) or ([$env.MY_ENV_VARS.debs $deb_file] | path join | path exists) {
    print (echo-g "mega-get deb already downloaded locally, skipping download.")
    sudo apt install ($deb_file | path expand)
    return
  }
  aria2c https://mega.nz/linux/repo/xUbuntu_24.04/amd64/$deb_file
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

#update antigravity-cli
export def "apps-update agy" [] {
  agy update
}

#update/install antigravity remote control headless daemon (agy-daemon)
#
# Remote Control Linking:
# To link this machine to https://antigravity.google.com:
# 1. Run `agy --remote-control` interactively in your terminal once.
# 2. Open the printed Google sign-in link, authenticate, and paste the code.
# 3. The token is saved to `~/.gemini/jetski-standalone-oauth-token` and your machine appears on https://antigravity.google.com.
# 4. Restart or manage the background service via `apps-update agy-daemon`.
export def "apps-update agy-daemon" [
  --install(-i) #install and configure systemd user service if missing or requested
] {
  let service_file = ("~/.config/systemd/user/agy-remote-control.service" | path expand)
  let wrapper_file = ("~/.antigravity/bin/run_agy_remote_control.sh" | path expand)
  let timer_file = ("~/.config/systemd/user/agy-remote-control-update.timer" | path expand)
  let update_svc_file = ("~/.config/systemd/user/agy-remote-control-update.service" | path expand)
  let token_file = ("~/.gemini/jetski-standalone-oauth-token" | path expand)

  let is_installed = ($service_file | path exists) and ($wrapper_file | path exists)

  if (not $is_installed) and (not $install) {
    try { rich print "[bold yellow]⚠ agy-daemon systemd service is not installed.[/]" } catch { print (echo-y "⚠ agy-daemon systemd service is not installed.") }
    try { rich print "[cyan]To install and configure agy-daemon, run:[/]" } catch { print (echo-g "To install and configure agy-daemon, run:") }
    try { rich print "  [bold green]apps-update agy-daemon --install[/]" } catch { print (echo-g "  apps-update agy-daemon --install") }
    return
  }

  if $install or (not $is_installed) {
    try { rich rule "Installing Antigravity Remote Control Daemon (agy-daemon)" --style "bold cyan" } catch { print (echo-g "==> Installing Antigravity Remote Control Headless Daemon (agy-daemon)...") }
    mkdir ("~/.antigravity/bin" | path expand)
    mkdir ("~/.config/systemd/user" | path expand)

    let wrapper_content = "#!/usr/bin/env bash
# Antigravity Remote Control Daemon Launcher
set -euo pipefail

export PATH=\"$HOME/.local/bin:$HOME/bin:$PATH\"
export USER=\"${USER:-$(whoami)}\"
export HOME=\"${HOME:-$(getent passwd \"$USER\" | cut -d: -f6)}\"

mkdir -p \"$HOME/.antigravity\"
AGY_BIN=\"$HOME/.local/bin/agy\"
[[ -x \"$AGY_BIN\" ]] || AGY_BIN=$(command -v agy)
exec \"$AGY_BIN\" --remote-control \"$@\"
"
    $wrapper_content | save -f $wrapper_file
    ^chmod +x $wrapper_file

    let service_content = "[Unit]
Description=Antigravity Remote Control Headless Daemon
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=%h/.antigravity/bin/run_agy_remote_control.sh
Restart=always
RestartSec=10
StandardOutput=append:%h/.antigravity/agy_daemon.log
StandardError=append:%h/.antigravity/agy_daemon.log

[Install]
WantedBy=default.target
"
    $service_content | save -f $service_file

    let update_svc_content = "[Unit]
Description=Update Antigravity Remote Control Daemon
After=network-online.target

[Service]
Type=oneshot
ExecStart=%h/.local/bin/agy update
ExecStartPost=/usr/bin/systemctl --user restart agy-remote-control.service
"
    $update_svc_content | save -f $update_svc_file

    let timer_content = "[Unit]
Description=Daily update timer for Antigravity Remote Control Daemon

[Timer]
OnCalendar=daily
Persistent=true
RandomizedDelaySec=1800

[Install]
WantedBy=timers.target
"
    $timer_content | save -f $timer_file

    do { ^systemctl --user daemon-reload } | complete | ignore
    try { ^loginctl enable-linger $env.USER } catch { }
    do { ^systemctl --user enable agy-remote-control.service } | complete | ignore
    do { ^systemctl --user enable agy-remote-control-update.timer } | complete | ignore
    do { ^systemctl --user start agy-remote-control-update.timer } | complete | ignore
    do { ^systemctl --user restart agy-remote-control.service } | complete | ignore

    try { rich print "[bold green]✓ agy-daemon systemd user service and auto-update timer installed and started successfully![/]" } catch { print (echo-g "✓ agy-daemon systemd user service and auto-update timer installed and started successfully!") }

    if not ($token_file | path exists) {
      print ""
      try { rich print "[bold yellow]⚠ One-Time Remote Control Linking Required:[/]" } catch { print (echo-y "⚠ One-Time Remote Control Linking Required:") }
      try { rich print "  To link this machine to [bold cyan]https://antigravity.google.com[/]:" } catch { print (echo-g "  To link this machine to https://antigravity.google.com:") }
      try { rich print "  1. Run [bold green]agy --remote-control[/] in your terminal once." } catch { print (echo-g "  1. Run agy --remote-control in your terminal once.") }
      try { rich print "  2. Complete Google sign-in to save [dim]~/.gemini/jetski-standalone-oauth-token[/]." } catch { print (echo-g "  2. Complete Google sign-in to save ~/.gemini/jetski-standalone-oauth-token.") }
      try { rich print "  3. Your machine will appear in the dashboard at [bold cyan]https://antigravity.google.com[/]!" } catch { print (echo-g "  3. Your machine will appear in the dashboard at https://antigravity.google.com!") }
    }
    return
  }

  try { rich rule "Updating Antigravity Remote Control Daemon" --style "bold cyan" } catch { print (echo-g "==> Updating agy binary and restarting agy-daemon...") }
  agy update
  do { ^systemctl --user restart agy-remote-control.service } | complete | ignore
  try { rich print "[bold green]✓ agy binary updated and agy-remote-control.service restarted successfully![/]" } catch { print (echo-g "✓ agy binary updated and agy-remote-control.service restarted successfully!") }

  if not ($token_file | path exists) {
    print ""
    try { rich print "[bold yellow]⚠ Notice: Machine not yet linked to https://antigravity.google.com[/]" } catch { print (echo-y "⚠ Notice: Machine not yet linked to https://antigravity.google.com") }
    try { rich print "  Run [bold green]agy --remote-control[/] interactively once to complete one-time Google sign-in." } catch { print (echo-g "  Run agy --remote-control interactively once to complete one-time Google sign-in.") }
  }
}

#update gemini-cli
export def "apps-update gemini" [] {
  npm install --engine-strict -g @google/gemini-cli@latest
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

#update linecast
export def "apps-update linecast" [] {
  if (which uv | is-not-empty) {
    uv tool upgrade linecast
  } else if (which pipx | is-not-empty) {
    pipx upgrade linecast
  } else {
    pip install -U linecast
  }
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

# Run a matlab subcommand with GNU timeout, capturing stdout.
# Handles exit 124 (timeout) as empty string; forwards stdout on other exits for parsing.
# timeout_sec: seconds before SIGTERM; verbose: print command, exit code, and stdout preview
# ponytail: uses GNU timeout (coreutils) for minimal diff; pure nushell job-spawn fallback if timeout missing
# Example: run-matlab-with-timeout ["-batch", "disp(matlabroot)"] 15 false
export def run-matlab-with-timeout [args: list<string>, timeout_sec: int, verbose: bool] {
  if $verbose {
    try { print (echo-c $"  → Trying: matlab ($args | str join ' ') \(timeout ($timeout_sec)s\)" "yellow") } catch { print $"  → Trying: matlab ($args | str join ' ') \(timeout ($timeout_sec)s\)" }
  }
  let result = try {
    run-external "timeout" $"($timeout_sec)s" "matlab" ...$args | complete
  } catch {|e|
    {stdout: "", stderr: $e.msg, exit_code: 1}
  }
  if $verbose {
    print $"    exit: ($result.exit_code) stdout: ($result.stdout | str length) chars stderr: ($result.stderr | str length) chars"
    if ($result.stdout | str trim | is-not-empty) {
      print $"    stdout preview: ($result.stdout | str trim | lines | last | str trim)"
    }
  }
  if $result.exit_code == 124 {
    # timeout — but matlab may have printed root just before kill; check stdout
    let maybe = $result.stdout | str trim | lines | last | default "" | str trim
    if ($maybe | is-not-empty) and ($maybe | path exists) {
      if $verbose { try { print (echo-c $"    timed out after ($timeout_sec)s but stdout has valid root: ($maybe) — using it" "yellow") } catch { print $"    timed out after ($timeout_sec)s but stdout has root: ($maybe)" } }
      return $result.stdout | str trim
    }
    if $verbose { try { print (echo-c $"    timed out after ($timeout_sec)s" "yellow") } catch { print $"    timed out after ($timeout_sec)s" } }
    ""
  } else if $result.exit_code != 0 {
    if $verbose { try { print (echo-c $"    failed exit ($result.exit_code): ($result.stderr | str trim | lines | first | default '' | str trim)" "yellow") } catch { print $"    failed exit ($result.exit_code)" } }
    $result.stdout | str trim
  } else {
    $result.stdout | str trim
  }
}

# Detect MATLAB root with timeout, retry, and fallback chain.
# Tries: matlab -batch (timeout), retry 2x, which matlab -> realpath -> parent of bin/, common R* globs, matlab -nosplash -nodesktop (30s)
# --matlab-timeout: seconds for first batch attempt (retry is 2x); --verbose: print each attempt and preview
# Example: detect-matlab-root --matlab-timeout 15 --verbose
export def detect-matlab-root [--matlab-timeout: int = 15, --verbose] {
  # --- Attempt 1: matlab -batch with configured timeout ---
  let batch_cmd = "setenv('SHELL','/bin/bash'); disp(matlabroot)"
  let out1 = run-matlab-with-timeout ["-batch", $batch_cmd] $matlab_timeout $verbose
  let root1 = if ($out1 | is-empty) { "" } else { $out1 | str trim | lines | last | str trim }
  if ($root1 | is-not-empty) and ($root1 | path exists) {
    if $verbose { try { print (echo-g $"  ✓ Found via batch: ($root1)") } catch { print $"  ✓ Found via batch: ($root1)" } }
    return $root1
  }
  if $verbose and ($root1 | is-not-empty) {
    try { print (echo-c $"  ⚠ Batch returned non-existent path: ($root1)" "yellow") } catch { print $"  ⚠ Batch returned non-existent path: ($root1)" }
  }

  # --- Retry: 2x timeout ---
  let retry_timeout = $matlab_timeout * 2
  try { print (echo-c $"  ⚠ Timeout or empty after ($matlab_timeout)s, retrying with ($retry_timeout)s..." "yellow") } catch { print $"  ⚠ Timeout or empty after ($matlab_timeout)s, retrying with ($retry_timeout)s..." }
  let out2 = run-matlab-with-timeout ["-batch", $batch_cmd] $retry_timeout $verbose
  let root2 = if ($out2 | is-empty) { "" } else { $out2 | str trim | lines | last | str trim }
  if ($root2 | is-not-empty) and ($root2 | path exists) {
    if $verbose { try { print (echo-g $"  ✓ Found via batch retry: ($root2)") } catch { print $"  ✓ Found via batch retry: ($root2)" } }
    return $root2
  }

  # --- Fallback 1: which matlab -> resolve symlink -> parent of bin/ ---
  if $verbose { try { print (echo-c "  → Fallback: which matlab" "yellow") } catch { print "  → Fallback: which matlab" } }
  let matlab_path = try { which matlab | get path.0 | str trim } catch { "" }
  if ($matlab_path | is-not-empty) {
    if $verbose { print $"    which: ($matlab_path)" }
    let real = try { run-external "realpath" $matlab_path | complete | get stdout | str trim } catch { $matlab_path }
    let real_trim = if ($real | is-empty) { $matlab_path } else { $real | str trim }
    if $verbose { print $"    realpath: ($real_trim)" }
    let candidate = ($real_trim | path dirname | path dirname)
    if $verbose { print $"    candidate root: ($candidate)" }
    if ($candidate | path exists) and (($candidate | path join "bin/matlab" | path exists) or ($candidate | path join "bin/glnxa64/MATLAB" | path exists)) {
      if $verbose { try { print (echo-g $"  ✓ Found via which: ($candidate)") } catch { print $"  ✓ Found via which: ($candidate)" } } else { try { print (echo-c $"  ⚠ Batch failed, using fallback which → ($candidate)" "yellow") } catch { print $"  ⚠ Batch failed, using fallback which → ($candidate)" } }
      return $candidate
    }
    # also try direct parent without realpath (in case realpath failed)
    let candidate2 = ($matlab_path | path dirname | path dirname)
    if ($candidate2 != $candidate) and ($candidate2 | path exists) and (($candidate2 | path join "bin/matlab" | path exists)) {
      if $verbose { try { print (echo-g $"  ✓ Found via which (direct): ($candidate2)") } catch { print $"  ✓ Found via which (direct): ($candidate2)" } } else { try { print (echo-c $"  ⚠ Batch failed, using fallback which → ($candidate2)" "yellow") } catch { print $"  ⚠ Batch failed, using fallback which → ($candidate2)" } }
      return $candidate2
    }
  } else {
    if $verbose { try { print (echo-c "    which matlab: not found" "yellow") } catch { print "    which matlab: not found" } }
  }

  # --- Fallback 2: common install paths + glob for any R* ---
  if $verbose { try { print (echo-c "  → Fallback: common install paths" "yellow") } catch { print "  → Fallback: common install paths" } }
  mut candidates = [
    ("/usr/local/MATLAB/R2026a" | path expand)
    ("/opt/MATLAB/R2026a" | path expand)
    ("~/MATLAB/R2026a" | path expand)
  ]
  for g in ["/usr/local/MATLAB/R*", "/opt/MATLAB/R*", "~/MATLAB/R*"] {
    try {
      let expanded = glob ($g | path expand) | where {|p| ($p | path join "bin/matlab" | path exists) } | sort | reverse
      for p in $expanded { if $p not-in $candidates { $candidates = $candidates | append $p } }
    } catch {}
  }
  for c in $candidates {
    if $verbose { print $"    checking: ($c)" }
    if ($c | path exists) and ($c | path join "bin/matlab" | path exists) {
      if $verbose { try { print (echo-g $"  ✓ Found via common path: ($c)") } catch { print $"  ✓ Found via common path: ($c)" } } else { try { print (echo-c $"  ⚠ Batch failed, using fallback path → ($c)" "yellow") } catch { print $"  ⚠ Batch failed, using fallback path → ($c)" } }
      return $c
    }
  }

  # --- Fallback 3: matlab -nosplash -nodesktop -r with longer timeout ---
  if $verbose { try { print (echo-c "  → Fallback: matlab -nosplash -nodesktop (30s)" "yellow") } catch { print "  → Fallback: matlab -nosplash -nodesktop (30s)" } } else { try { print (echo-c "  → Fallback: matlab -nosplash -nodesktop..." "yellow") } catch { print "  → Fallback: matlab -nosplash -nodesktop..." } }
  let r_cmd = "setenv('SHELL','/bin/bash'); disp(matlabroot); quit"
  let out3 = run-matlab-with-timeout ["-nosplash", "-nodesktop", "-r", $r_cmd] 30 $verbose
  let root3 = if ($out3 | is-empty) { "" } else { $out3 | str trim | lines | last | str trim }
  if ($root3 | is-not-empty) and ($root3 | path exists) {
    if $verbose { try { print (echo-g $"  ✓ Found via nosplash: ($root3)") } catch { print $"  ✓ Found via nosplash: ($root3)" } } else { try { print (echo-g $"  ✓ Found via nosplash fallback: ($root3)") } catch { print $"  ✓ Found via nosplash fallback: ($root3)" } }
    return $root3
  }

  # --- All failed ---
  ""
}

#update/install matlab-agentic-toolkit (new method: agenticToolkitInstaller.mltbx)
export def "apps-update matlab-agentic-toolkit" [--matlab-timeout: int = 15, --non-interactive(-n), --verbose(-v)] {
	let linux_backup = $env.MY_ENV_VARS.linux_backup
	let mcp_bin_dir      = ("~/.matlab/agentic-toolkits/bin" | path expand)
	let mcp_binary       = ($mcp_bin_dir | path join "matlab-mcp-server")
	let mcp_binary_tmp   = "/tmp/matlab-mcp-server"
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

	# --- FR1: Dynamic MATLAB root detection (with timeout, retry, fallback) ---
	print (echo-c "\n⚙  Detecting MATLAB root..." "cyan")
	if $verbose { print (echo-c $"  timeout: ($matlab_timeout)s, verbose: on" "cyan") }
	let matlab_root = if $verbose {
	  detect-matlab-root --matlab-timeout $matlab_timeout --verbose
	} else {
	  detect-matlab-root --matlab-timeout $matlab_timeout
	}
	if ($matlab_root | is-empty) {
		let t2 = $matlab_timeout * 2
		return-error $"MATLAB root detection failed. Tried: batch 1 (($matlab_timeout)s), batch retry (($t2)s), which matlab, common paths (/usr/local/MATLAB/R*, /opt/MATLAB/R*, ~/MATLAB/R*), nosplash (30s). Check: 'matlab' in PATH, license server reachable, run 'matlab -nodesktop' manually for diagnostics. Use -v for verbose output."
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

	# --- FR2.1: Ensure MCP binary is staged before calling setupAgenticToolkit ---
	# Staged to /tmp/matlab-mcp-server so MATLAB copyfile source and destination are unique
	if not ($mcp_binary_tmp | path exists) {
		if ($mcp_binary | path exists) {
			try { cp --force $mcp_binary $mcp_binary_tmp } catch {}
		} else {
			print (echo-c "\n⬇  MCP binary not found — downloading before setup..." "cyan")
			try {
				http get $mcp_bin_url | save --force $mcp_binary_tmp
				run-external "chmod" "+x" $mcp_binary_tmp
				print (echo-g $"   → Staged MCP binary to ($mcp_binary_tmp)")
			} catch {
				return-error $"Failed to download MCP binary from ($mcp_bin_url). Check internet connection."
			}
		}
	}

	# --- FR3: setupAgenticToolkit — interactive or non-interactive mode ---
	# Skills install to ~/.agents/skills/ system-wide — available to ALL agents.
	let is_installed = ($config_json | path exists)
	let action = if $is_installed { "update" } else { "install" }
	let prompt_param = if $non_interactive { "Prompt=false, " } else { "Prompt=true, " }

	# On fresh install: run setupAgenticToolkit
	if not $is_installed {
		let shebang = "setenv('SHELL','/bin/bash'); "
		let setup_cmd = (
			$shebang +
			"matlab.addons.install('" + $installer_tmp + "', true); " +
			"setupAgenticToolkit('install', " +
			$prompt_param +
			"MCPServerLocation='" + $mcp_binary_tmp + "', " +
			"MCPToolboxLocation='" + $mcp_toolbox_tmp + "'); " +
			"exit"
		)

		if $non_interactive {
			print (echo-c "\n🔧  Running setupAgenticToolkit('install') non-interactively..." "cyan")
		} else {
			print (echo-c "\n🔧  Running setupAgenticToolkit('install') interactively..." "cyan")
			print (echo-c "    Select skill groups when prompted (Enter = all)." "yellow")
		}

		run-external "matlab" "-nosplash" "-nodisplay" "-r" $setup_cmd

		try { rm $installer_tmp } catch {}
		try { rm $mcp_toolbox_tmp } catch {}
		try { rm $mcp_binary_tmp } catch {}
	} else {
		# Update run: skill files in skills-catalog/ are replaced on each release.
		# Must re-run setupAgenticToolkit('update') to refresh the symlinks/files.
		let shebang = "setenv('SHELL','/bin/bash'); "
		let setup_cmd = (
			$shebang +
			"matlab.addons.install('" + $installer_tmp + "', true); " +
			"setupAgenticToolkit('update', " +
			$prompt_param +
			"MCPServerLocation='" + $mcp_binary_tmp + "', " +
			"MCPToolboxLocation='" + $mcp_toolbox_tmp + "'); " +
			"exit"
		)

		if $non_interactive {
			print (echo-c "\n🔧  Running setupAgenticToolkit('update') non-interactively to refresh skills..." "cyan")
		} else {
			print (echo-c "\n🔧  Running setupAgenticToolkit('update') to refresh skills..." "cyan")
			print (echo-c "    Select skill groups when prompted (Enter = all)." "yellow")
		}

		run-external "matlab" "-nosplash" "-nodisplay" "-r" $setup_cmd

		try { rm $installer_tmp } catch {}
		try { rm $mcp_toolbox_tmp } catch {}
		try { rm $mcp_binary_tmp } catch {}
	}



	# --- FR2.5: MCP binary version check / update ---
	# (Binary is guaranteed present at this point via FR2.1 or prior run)
	print (echo-c "\n📦  Checking MATLAB MCP Server binary version..." "cyan")

	# Fetch latest version tag from GitHub API
	let latest_tag = try {
		http get $mcp_releases_api | get tag_name | str trim
	} catch {
		print (echo-c "   ⚠ Could not fetch latest MCP server version from GitHub (rate limit or offline). Skipping remote check." "yellow")
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
	} else if ($current_ver | is-not-empty) {
		let current_tag = ($current_ver | split row " " | last | str trim)
		print (echo-g $"   ✓ Binary present at ($mcp_binary) \(version: ($current_tag)\). Remote check was skipped.")
	} else {
		print (echo-c $"   ⚠ Binary present at ($mcp_binary), but could not determine version." "yellow")
	}

	# --- FR1 (post-install): Re-detect MATLAB root in case version changed ---
	let matlab_root_final = if $verbose {
	  detect-matlab-root --matlab-timeout $matlab_timeout --verbose
	} else {
	  detect-matlab-root --matlab-timeout $matlab_timeout
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
#runs setupAgenticToolkit('configure') in -nodisplay mode to select agents and skill groups
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
		"setenv('SHELL', '/bin/bash'); " +
		"setupAgenticToolkit('configure'" +
		(if ($mcp_binary | path exists) { ", MCPServerLocation='" + $mcp_binary + "'" } else { "" }) +
		(if ($mcp_toolbox | path exists) { ", MCPToolboxLocation='" + $mcp_toolbox + "'" } else { "" }) +
		"); exit"
	)

	print (echo-c "\n🔧  Running setupAgenticToolkit('configure') interactively..." "cyan")
	print (echo-c "    Select agent platforms and skill groups when prompted." "yellow")
	print (echo-c "    (e.g. enter '1,5' for Claude Code + Gemini CLI)\n" "yellow")

	run-external "matlab" "-nosplash" "-nodisplay" "-r" $configure_cmd

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


# Extract candidate app name from todo text
def get-app-name-from-todo [text: string] {
  let parts = $text | str lowercase | split row -r '[\s\-_:(),\+]+'
  let ignore_words = ["release", "releases", "released", "version", "update", "updates", "updated", "of", "new", "deb", "cli", "font", "to", "for", "and", "the", "a", "app", "software", "from", "github", "mcp", "server", "lsp", "stable", "latest", "current", "amd64"]
  let candidates = $parts | where {|w| (($w | str trim) != "") and ($w not-in $ignore_words) and ($w !~ '^\d+(\.\d+)*$') and ($w !~ '^v\d+') }
  $candidates
}

# Check if an app is installed on the system
def is-app-installed [app_name: string] {
  let mappings = {
    chrome: ["google-chrome", "google-chrome-stable", "chrome"]
    earth: ["google-earth-pro", "google-earth"]
    nushell: ["nu"]
    yandex: ["yandex-disk", "yandex-browser", "yandex"]
    taskerpermissions: ["adb"]
    myffmpeg: ["ffmpeg"]
    claude: ["claude"]
    gemini: ["gemini"]
    agy: ["agy", "antigravity", "antigravity-cli"]
    agy-daemon: ["agy-daemon", "agy-remote-control"]
    rtk: ["rtk"]
  }

  if $app_name == "agy-daemon" or $app_name == "agy-remote-control" {
    if ("~/.config/systemd/user/agy-remote-control.service" | path exists) and (which agy | is-not-empty) {
      return true
    }
  }

  let candidates = if ($app_name in ($mappings | columns)) {
    $mappings | get $app_name
  } else {
    [$app_name]
  }

  for c in $candidates {
    if (which $c | is-not-empty) {
      return true
    }
  }

  for c in $candidates {
    if (help commands | get name | find $c | is-not-empty) {
      return true
    }
  }

  false
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

  # Get apps-update commands name and description
  let commands_info = help commands | find -n "apps-update " | select name description
    | where {|c| $c.name !~ "install" and $c.name != "apps-update help" and $c.name != "apps-update"}
    | each {|c|
        let sub_name = $c.name | ansi strip | str replace "apps-update " ""
        let desc = $c.description | default "" | ansi strip | str lowercase
        let clean_desc = ($desc
          | str replace -r '^(update/install|update|install|upgrade)\s+' ''
          | str replace -r '\s*\(.*?\)' ''
          | str replace -r '\s+(deb|cli|font|lsp server|mcp server|server)$' ''
          | str trim)
        {name: $sub_name, clean_desc: $clean_desc}
      }

  # Match todos against command name and description
  mut matched = []
  mut unmatched_installed = []

  for todo in $all_todos {
    let text_lower = $todo.text | str lowercase
    let found = $commands_info | where {|c|
      let n = $c.name
      let d = $c.clean_desc
      (($text_lower | str contains $n) or ($text_lower | str contains ($n | str replace -a "-" " ")) or ($text_lower | str contains ($n | str replace -a "-" "")) or (($text_lower | str replace -a "-" "") | str contains $n) or (($text_lower | str replace -a "-" " ") | str contains $n) or ($d != "" and (($text_lower | str contains $d) or ($text_lower | str contains ($d | str replace -a "-" " ")) or ($text_lower | str contains ($d | str replace -a "-" "")) or (($text_lower | str replace -a "-" "") | str contains $d) or (($text_lower | str replace -a "-" " ") | str contains $d))))
    } | sort-by {|c| $c.name | str length} --reverse

    if ($found | is-not-empty) {
      let matched_cmd = $found | first
      let cmd_name = $matched_cmd.name
      
      # Check if the app is installed
      if (is-app-installed $cmd_name) {
        $matched = $matched | append {todo_text: $todo.text, todo_id: $todo._id, update_command: $cmd_name}
      } else {
        if not $dry_run {
          print $"(ansi yellow)App '($cmd_name)' is not installed on this system. Marking todo '($todo.text)' as completed.(ansi reset)"
          h complete-todos --ids [$todo._id]
        } else {
          print $"(ansi yellow)[Dry Run] App '($cmd_name)' is not installed. Would mark todo '($todo.text)' as completed.(ansi reset)"
        }
      }
    } else {
      # Unmatched todo: extract candidate app names
      let candidates = get-app-name-from-todo $todo.text
      mut app_installed = false
      for cand in $candidates {
        if (is-app-installed $cand) {
          $app_installed = true
          break
        }
      }

      if $app_installed {
        $unmatched_installed = $unmatched_installed | append $todo
      } else {
        # App is not installed on the system, mark the todo as done
        if not $dry_run {
          print $"(ansi yellow)App is not installed on this system. Marking todo '($todo.text)' as completed.(ansi reset)"
          h complete-todos --ids [$todo._id]
        } else {
          print $"(ansi yellow)[Dry Run] App is not installed. Would mark todo '($todo.text)' as completed.(ansi reset)"
        }
      }
    }
  }

  $matched = $matched | uniq-by update_command

  if ($matched | is-empty) {
    if ($unmatched_installed | is-not-empty) {
      print "Found software update todos but no matching update commands."
      print "Pending updates for installed apps without a command:"
      print ($unmatched_installed | select text | table)
    } else {
      print "No pending software update todos for installed apps found."
    }
    return
  }

  if $dry_run {
    print $"\nDry run — ($matched | length) (if ($matched | length) == 1 { "update" } else { "updates" }) matched:"
    print ($matched | select todo_text update_command | table)
    return
  }

  mut results = []
  for todo in $matched {
    print $"(ansi green)Updating ($todo.update_command)...(ansi reset)"
    let temp_file = (mktemp)
    let update_cmd = ("nu --config ~/.config/nushell/config.nu --env-config ~/.config/nushell/env.nu -c \"apps-update " + $todo.update_command + "\"; echo $? > " + $temp_file)
    run-external "bash" "-c" $update_cmd
    let exit_code = (try { open $temp_file | str trim | into int } catch { 1 })
    try { rm -f $temp_file } catch {}

    if $exit_code == 0 {
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

# Install Sober (Roblox player) Flatpak on Ubuntu or CachyOS
export def install-sober [] {
  let is_cachyos = (try { open /etc/os-release | lines | find -r '^ID=' | first | str replace 'ID=' '' | str trim -c '"' } catch { "" }) == "cachyos"
  if $is_cachyos {
    print (echo-g "Installing flatpak via pacman...")
    sudo pacman -S --noconfirm --needed flatpak
  } else {
    print (echo-g "Installing flatpak via nala/apt...")
    if (which nala | is-not-empty) {
      sudo nala install -y flatpak
    } else {
      sudo apt install -y flatpak
    }
  }

  print (echo-g "Adding Flathub remote...")
  flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

  print (echo-g "Installing Sober (org.vinegarhq.Sober) from Flathub...")
  flatpak install -y flathub org.vinegarhq.Sober
}

# Update Sober (Roblox player) Flatpak package
export def sober-update [] {
  print (echo-g "Updating Sober (Roblox player) Flatpak package...")
  flatpak update -y org.vinegarhq.Sober
}

# Alias for sober-update
export alias "apps-update sober" = sober-update
