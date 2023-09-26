$env.config = ($env.config | upsert hooks {
    env_change: {
        PWD: [
            {|before, after|
                if ([$after environment.yml] | path join | path exists) {
                    # Read env name from environment
                    let envName = open environment.yml | get name
                    # If already activated, skip
                    if ($env.CONDA_DEFAULT_ENV == $envName) {
                        return
                    }
                    # Get the list of envs, skipping activation if the envName is not present
                    let envs = conda env list --json | from json | get envs | path basename
                    if $envName in $envs {
                        conda activate $envName
                    }
                } 
            }
        ]
    }
})



## conditional source config
# const WINDOWS_CONFIG = "my_windows_config.nu"
# const UNIX_CONFIG = "my_unix_config.nu"

# const ACTUAL_CONFIG = if $nu.os-info.name == "windows" {
#     $WINDOWS_CONFIG
# } else {
#     $UNIX_CONFIG
# }

# source $ACTUAL_CONFIG