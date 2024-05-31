export def activate [] {
  print ("'overlay use venv/bin/activate.nu' copied to clipboard!")
  "overlay use venv/bin/activate.nu" | xsel --input --clipboard
}

#jdown.py wrapper
export def jdown [
  --ubb(-b):string = "0"
] {
  overlay use /home/kira/Yandex.Disk/Comandos_python/venv/bin/activate.nu
  python3 ([$env.MY_ENV_VARS.python_scripts jdown.py] | path join) -b $ubb
}