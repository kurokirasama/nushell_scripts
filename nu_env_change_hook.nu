## pwd size
#checking existence of data file
if not ("~/.pwd_sizes.json" | path expand | path exists) {
    cp ([$env.MY_ENV_VARS.linux_backup pwd_sizes.json] | path join) ~/.pwd_sizes.json
}

#checking conditions
let interval = 12hr 
let last_record = (open ~/.pwd_sizes.json | where directory == $env.PWD)
let now = (date now)
let not_update = if ($last_record | length) == 0 {
    false
} else {
    (($last_record | get updated | get 0 | into datetime) + $interval > $now)
}
let not_gdrive = not ($env.PWD =~ gdrive)

#calculating pwd_size
let pwd_size = (
    if ($last_record | length) == 0 and $not_gdrive {
        du $env.PWD --exclude gdrive/*
        | get apparent 
        | get 0 
        | into string 
        | str replace " " "" 
    } else if $not_gdrive {
        if $not_update {
            $last_record | get size | get 0
        } else {
            du $env.PWD --exclude gdrive/*
            | get apparent 
            | get 0 
            | into string 
            | str replace " " "" 
        }
    } else {
        ""
    }    
)

#seting up env var
let-env PWD_SIZE = $pwd_size

#updating data file
if ($last_record | length) == 0 and $not_gdrive {    
    open ~/.pwd_sizes.json  
    | append {directory: $env.PWD,size: $pwd_size, updated: $now} 
    | save -f ~/.pwd_sizes.json    
} else if (not $not_update) and $not_gdrive {
    open ~/.pwd_sizes.json 
    | where directory != $env.PWD 
    | append {directory: $env.PWD,size: $pwd_size, updated: $now}
    | save -f ~/.pwd_sizes.json
}