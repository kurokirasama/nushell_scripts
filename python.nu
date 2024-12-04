#create virtual env
export def create-virtualenv [dir_name:string = "venv"] {
  python3 -m virtualenv $dir_name
}

export def activate [] {
  print ("'overlay use venv/bin/activate.nu' copied to clipboard!")
  "overlay use venv/bin/activate.nu" | xsel --input --clipboard
}

#jdown.py wrapper
export def jdown [
  --ubb(-b):string = "0"
] {
  overlay use ("~/Yandex.Disk/Backups/linux/my_scripts/python/venv/bin/activate.nu" | path expand)
  python3 ([$env.MY_ENV_VARS.python_scripts jdown.py] | path join) -b $ubb
}