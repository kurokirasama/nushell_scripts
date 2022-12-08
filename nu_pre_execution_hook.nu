#checking existence of data file
if not ("~/.pwd_sizes.json" | path expand | path exists) {
    cp ([$env.MY_ENV_VARS.linux_backup pwd_sizes.json] | path join) ~/.pwd_sizes.json
}

#checking conditions
let interval = 1hr
let last_record = (open ~/.pwd_sizes.json | where directory == $env.PWD)
let now = date now
let not_update = try {
    (($last_record | get updated | get 0 | into datetime) + $interval < $now)
} catch {
    false
}
            
#calculating pwd_size
let pwd_size = (
    if ($last_record | length) == 0 {
        du $env.PWD 
        | get apparent 
        | get 0 
        | into string 
        | str replace " " "" 
    } else {
        if $not_update {
            $last_record | get size | get 0
        } else if (not ($env.PWD =~ gdrive)) and ($env.PWD | get-dirs | where name =~ gdrive | length) == 0 {
            du $env.PWD 
            | get apparent 
            | get 0 
            | into string 
            | str replace " " "" 
        } else {
            ""
        }    
    }
)

#seting up env var
let-env PWD_SIZE = $pwd_size

#updating data file
if ($last_record | length) == 0 {    
    open ~/.pwd_sizes.json  
    | append {directory: $env.PWD,size: $pwd_size, updated: $now} 
    | save -f ~/.pwd_sizes.json    
} else if not $not_update {
    open ~/.pwd_sizes.json 
    | where directory != $env.PWD 
    | append {directory: $env.PWD,size: $pwd_size, updated: $now}
    | save -f ~/.pwd_sizes.json
}