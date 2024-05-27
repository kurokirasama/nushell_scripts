#html2text.py wrapper
export def html2text [
  html?:string
  --enable_flags(-e)
] {
  let html = if ($html | is-empty) {$in} else {$html}
  cd $env.MY_ENV_VARS.python_scripts
  overlay use /home/kira/Yandex.Disk/Comandos_python/venv/bin/activate.nu

  if $enable_flags {
    $html | ./html2text.py --ignore-links --ignore-images --dash-unordered-list
  } else {
    $html | ./html2text.py
  }
}

#jdown.py wrapper
export def jdown [
  --ubb(-b):string = "0"
] {
  overlay use /home/kira/Yandex.Disk/Comandos_python/venv/bin/activate.nu
  python3 ([$env.MY_ENV_VARS.python_scripts jdown.py] | path join) -b $ubb
}