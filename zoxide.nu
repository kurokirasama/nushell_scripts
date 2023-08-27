# Jump to a directory using only keywords.
export def-env __zoxide_z [...rest:string@"nu-complete zoxide path"] {
  let arg0 = ($rest | append '~').0
  let path = if ($rest | length) <= 1 and ($arg0 | path expand | path type) == dir {
    $arg0
  } else {
    (zoxide query --exclude $env.PWD -- $rest | str trim -r -c "\n")
  }
  cd $path
}

# Jump to a directory using interactive search.
export def-env __zoxide_zi  [...rest:string@"nu-complete zoxide path"] {
  cd $'(zoxide query -i -- $rest | str trim -r -c "\n")'
}

# Commands for zoxide. Disable these using --no-cmd. 
export alias z = __zoxide_z
export alias zi = __zoxide_zi