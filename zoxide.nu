# Jump to a directory using only keywords.
export def --env z [...rest:string@"__z_complete"] {
  let arg0 = ($rest | append '~').0
  let arg0 = ($rest | append '~').0
  let arg0_is_dir = (try {$arg0 | path expand | path type}) == 'dir'
  let path = if (($rest | length) <= 1) and ($arg0 == '-' or $arg0_is_dir) {
    $arg0
  } else {
    (zoxide query --exclude $env.PWD -- ...$rest | str trim -r -c "\n")
  }
  cd $path
}

# Jump to a directory using interactive search.
export def --env zi [...rest:string@"__z_complete"] {
  cd $'(zoxide query --interactive -- ...$rest | str trim -r -c "\n")'
}

# completion
def "__z_complete" [line : string, pos: int] {
  let prefix = ( $line | str trim | split row ' ' | append ' ' | skip 1 | get 0)
  let data = (^zoxide query $prefix --list | lines)
  {
    completions : $data,
                options: {
                 completion_algorithm: "fuzzy",
                 positional: false
                }
  }
}