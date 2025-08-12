$env.config.history.file_format = "sqlite"
$env.config.show_banner = false

# Configure PATH to search for external command completions
$env.path = $env.path
| split row (char esep)
| append ($env.HOME | path join ".cargo" "bin")
| append ($env.HOME | path join ".local" "bin")
| append ($env.HOME | path join "go" "bin")
| append ('/usr/local/go/bin' | path expand) 
| uniq
| filter {path exists}

# Set up external completer (requires carapace)
$env.CARAPACE_LENIENT = 1
$env.CARAPACE_BRIDGES = 'zsh,fish,bash,inshellisense'
