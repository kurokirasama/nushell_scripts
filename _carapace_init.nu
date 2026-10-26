# _carapace_init.nu
# Canonical Carapace external completer initialization for Nushell (Nushell 0.116.0+ [place] model)

let carapace_bin_dir = ($env.HOME | path join ".config" "carapace" "bin")
$env.PATH = ($env.PATH | split row (char esep) | where { $in != $carapace_bin_dir } | prepend $carapace_bin_dir)

def --env get-env [name] { $env | get $name }
def --env set-env [name, value] { load-env { $name: $value } }
def --env unset-env [name] { hide-env $name }

let carapace_completer = {|place|
  # Backwards compatible workaround for positional completer input, see nushell #18791
  let spans = (if ($place | describe) =~ "record" {
    $place.command? | default []
  } else if ($place | describe) =~ "list" {
    $place
  } else {
    []
  })

  if ($spans | is-empty) {
    return null
  }

  # If the current command is an alias, get its expansion
  let expanded_alias = (scope aliases | where name == $spans.0 | $in.0?.expansion?)

  let spans = (if $expanded_alias != null {
    # Put the first word of the expanded alias first in the span
    $spans | skip 1 | prepend ($expanded_alias | split row " " | take 1)
  } else {
    $spans
  })

  if ($spans | length) == 1 {
    null
  } else {
    with-env {
      CARAPACE_SHELL: 'nushell'
      CARAPACE_SHELL_ALIASES: (scope aliases | get name | uniq | str join "\n")
      CARAPACE_SHELL_BUILTINS: (help commands | where category != "" | get name | each { split row " " | first } | uniq | str join "\n")
      CARAPACE_SHELL_FUNCTIONS: (help commands | where category == "" | get name | each { split row " " | first } | uniq | str join "\n")
      CARAPACE_SHELL_VARIABLES: (scope variables | get name | uniq | str join "\n")
    } {
      carapace $spans.0 nushell ...$spans | from json
    }
  }
}

mut current = (($env | default {} config).config | default {} completions)
$current.completions = ($current.completions | default {} external)
$current.completions.external = ($current.completions.external
| default true enable
# Backwards compatible workaround for default, see nushell #15654
| upsert completer { if $in == null { $carapace_completer } else { $in } })

$env.config = $current
