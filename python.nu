# Create a python virtual environment and configure cloud sync exclusions.
#
# Parameters:
#   dir_name: The name or path of the directory to create the virtual environment in.
#
# Example:
#   create-virtualenv my_project/venv
export def create-virtualenv [dir_name:string = "venv"] {
  let venv_path = $dir_name | path expand
  
  # 1. First create the folder
  mkdir $venv_path
  
  # Resolve Dropbox and Yandex.Disk roots (support mocking for unit tests)
  let dropbox_root = $env.MOCK_DROPBOX_ROOT? | default ("~/Dropbox" | path expand)
  let yandex_root = $env.MOCK_YANDEX_ROOT? | default ("~/Yandex.Disk" | path expand)
  
  # 2. Detect if the path is inside Dropbox or Yandex.Disk
  if ($venv_path | str starts-with $dropbox_root) {
    # Dropbox logic
    let relative_path = $venv_path | path relative-to $dropbox_root
    # Check if maestral is in PATH
    if (which maestral | is-not-empty) {
      print $"Excluding ($venv_path) from Dropbox sync using Maestral..."
      let res = maestral excluded add $relative_path | complete
      if $res.exit_code != 0 {
        print -e $"Warning: maestral excluded add failed: ($res.stderr | str trim)"
      }
    } else {
      print -e $"Warning: maestral executable not found in PATH. Skipping Dropbox exclusion."
    }
  } else if ($venv_path | str starts-with $yandex_root) {
    # Yandex.Disk logic
    print $"Stopping Yandex.Disk daemon..."
    do -i { nu --config ~/.config/nushell/config.nu --env-config ~/.config/nushell/env.nu -c 'ydx stop' }
    
    let primary_cfg = $env.MOCK_YANDEX_CONFIG_FILE? | default "/home/kira/.config/yandex-disk/config.cfg"
    print $"Updating Yandex.Disk config: ($primary_cfg)..."
    _update-yandex-config $primary_cfg $venv_path
    
    let backup_dir = $env.MY_ENV_VARS.linux_backup? | default ""
    if not ($backup_dir | is-empty) {
      let backup_cfg = [$backup_dir "ydx_config.cfg"] | path join
      print $"Updating backup Yandex.Disk config: ($backup_cfg)..."
      _update-yandex-config $backup_cfg $venv_path
    } else {
      print -e "Warning: $env.MY_ENV_VARS.linux_backup is not configured. Skipping backup config update."
    }
    
    print $"Starting Yandex.Disk daemon..."
    do -i { nu --config ~/.config/nushell/config.nu --env-config ~/.config/nushell/env.nu -c 'ydx start' }
  }
  
  # 3. Actually create the virtualenv
  python3 -m virtualenv $dir_name
}

# Helper to update yandex config file
def _update-yandex-config [config_file: path, new_exclude: string] {
  if not ($config_file | path exists) {
    print -e $"Warning: Yandex config file ($config_file) not found."
    return
  }
  
  let content = open --raw $config_file | lines
  let has_exclude = $content | any {|line| $line | str starts-with "exclude-dirs=" }
  
  let new_content = $content | each {|line|
    if ($line | str starts-with "exclude-dirs=") {
      let parts = $line | split row '='
      let val_with_quotes = $parts | get 1
      let val = $val_with_quotes | str replace --regex '^"' '' | str replace --regex '"$' ''
      let dirs = if ($val | is-empty) { [] } else { $val | split row ',' | str trim }
      
      let updated_dirs = if ($new_exclude in $dirs) {
        $dirs
      } else {
        $dirs | append $new_exclude
      }
      let new_val = $updated_dirs | str join ","
      $"exclude-dirs=\"($new_val)\""
    } else {
      $line
    }
  }
  
  let final_content = if not $has_exclude {
    $new_content | append $"exclude-dirs=\"($new_exclude)\""
  } else {
    $new_content
  }
  
  $final_content | str join "\n" | save -f $config_file
}

export def activate [] {
  print ("'overlay use venv/bin/activate.nu' copied to clipboard!")
  "overlay use venv/bin/activate.nu" | copy
}

#jdown.py wrapper
export def jdown [
  --ubb(-b):string = "0"
] {
  overlay use ("~/Yandex.Disk/my_scripts/python/venv/bin/activate.nu" | path expand)
  python3 ([$env.MY_ENV_VARS.python_scripts jdown.py] | path join) -b $ubb
}