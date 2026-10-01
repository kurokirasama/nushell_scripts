$env.config.history.file_format = "sqlite"
$env.config.show_banner = false

# Configure PATH for binary access during debug sessions
$env.path = $env.path
| split row (char esep)
| append ($env.HOME | path join ".cargo" "bin")
| append ($env.HOME | path join ".local" "bin")
| append ($env.HOME | path join "go" "bin")
| append ('/usr/local/go/bin' | path expand)
| uniq
| where {path exists}
