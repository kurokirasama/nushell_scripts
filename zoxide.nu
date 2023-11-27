# Jump to a directory using only keywords.
export def --env z [...rest:string@"__z_complete"] {
  let arg0 = ($rest | append '~').0
  let path = if ($rest | length) <= 1 and ($arg0 | path expand | path type) == dir {
    $arg0
  } else {
    (zoxide query --exclude $env.PWD -- $rest | str trim -r -c "\n")
  }
  cd $path
}

# Jump to a directory using interactive search.
export def --env zi [...rest:string@"__z_complete"] {
  cd $'(zoxide query -i -- $rest | str trim -r -c "\n")'
}

# completion
def "__z_complete" [line : string, pos: int] {
  let prefix = ( $line | str trim | split row ' ' | append ' ' | skip 1 | get 0)
  let data = (^zoxide query $prefix --list | lines)
  {
    completions : $data,
                options: {
                 completion_algorithm: "fuzzy"
                }
  }
}