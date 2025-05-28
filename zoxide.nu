# Jump to a directory using only keywords.
export def --env --wrapped z [...rest:string@"__z_complete"] {
  let path = match $rest {
    [] => {'~'},
    [ '-' ] => {'-'},
    [ $arg ] if ($arg | path expand | path type) == 'dir' => {$arg}
    _ => {
      zoxide query --exclude $env.PWD -- ...$rest | str trim -r -c "\n"
    }
  }
  cd $path
}

# Jump to a directory using interactive search.
export def --env --wrapped zi [...rest:string@"__z_complete"] {
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