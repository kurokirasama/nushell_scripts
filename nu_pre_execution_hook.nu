#checking existence of data file
if not ("~/.pwd_sizes.json" | path expand | path exists) {
    cp ([$env.MY_ENV_VARS.linux_backup pwd_sizes.json] | path join) ~/.pwd_sizes.json
}

#checking conditions
let interval = 1hr
let last_update = (open ~/.pwd_sizes.json | get update)
let last_record = (open ~/.pwd_sizes.json  | get data | where directory == $env.PWD)
let not_update = ((open ~/.pwd_sizes.json | get update | into datetime) + $interval < (date now))
            
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
    let data = (
        open ~/.pwd_sizes.json 
        | get data 
        | append {directory: $env.PWD,size: $pwd_size}
    )
    
    open ~/.pwd_sizes.json  
    | upsert data $data 
    | save -f ~/.pwd_sizes.json    

} else if not $not_update {
    let data = (
        open ~/.pwd_sizes.json 
        | get data 
        | find -v $env.PWD 
        | append {directory: $env.PWD,size: $pwd_size}
    )

    open ~/.pwd_sizes.json  
    | upsert data $data 
    | save -f ~/.pwd_sizes.json
}