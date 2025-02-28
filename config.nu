#color config
$env.config.color_config.shape_internalcall = if TERMINUS_SUBLIME in $env {
        "light_cyan_bold"
    } else { 
        fg: "#00b7ff" attr: b
    }

$env.config.color_config.shape_external = if TERMINUS_SUBLIME in $env {"xterm_skyblue2"} else {"#00b7ff"}
$env.config.color_config.shape_external_resolved = { fg: blue attr: b }
$env.config.color_config.filesize = {|e| 
    if $e == 0b {
        'white'
    } else if $e < 1mb {
        'cyan'
    } else if $e < 1gb {
        'cyan_bold'
    } else {
        'blue'
    }
}

#table config
$env.config.table.trim.wrapping_try_keep_words = false
$env.config.table.mode = if TERMINUS_SUBLIME in $env {"ascii_rounded"} else {"rounded"}
$env.config.table.show_empty = false
$env.config.table.trim = {
    methodology: "truncating", # wrapping
    wrapping_try_keep_words: true,
    truncating_suffix: "❱" #...
  }

#miscelaneous
$env.config.history.file_format = "sqlite"
$env.config.show_banner = false
$env.config.ls.clickable_links = false
$env.config.use_kitty_protocol = true
$env.config.recursion_limit = 500
$env.config.completions.algorithm = "prefix" #fuzzy
$env.config.completions.use_ls_colors = true
$env.config.float_precision = 4;
$env.config.filesize.unit = "metric"
$env.config.cursor_shape.emacs = "blink_line"
$env.config.highlight_resolved_externals = true

#hooks
let hooks = {
    pre_prompt: [
        {||
            $env.CLOUD = if $env.PWD =~ "rclone/" {
                    match ($env.PWD | split row "/rclone/" | get 1 | split row "/" | get 0) {
                        $s if ($s | str starts-with "g") => {"f2df"},
                        "onedrive" => {"f8c9"},
                        "photos" => {"fbdb"}, 
                        "yandex" => {"f662"}, 
                        "box" => {"f5d3"}, 
                        "mega" => {"e673"}, 
                        _ => {"f4ac"}
                    }
                } else {
                    match (sys host | get name) {
                        $p if $p =~ "Debian*" => {"f306"},
                        "Windows" => {"f17a"},
                        "Ubuntu"  => {"f31b"},
                        "CentOs" => {"f304"},
                        "RedHat" => {"ef5d"},
                        "Rocky Linux" => {"f32b"},
                        _ => {"e712"}
                    } 
                } 
        },
        {
            condition: {".git" | path exists},
            code: "$env.GIT_STATUS = if (git status -s | str length) > 0 {git status -s | lines | length} else {0}"
        },
        {
            condition: {not (".git" | path exists)},
            code: "$env.GIT_STATUS = 0"
        }
    ]
    pre_execution: [
        {||
            #checking existence of data file
            if not ("~/.autolister.json" | path expand | path exists) {
                cp ($env.MY_ENV_VARS.linux_backup | path join autolister.json) ~/.autolister.json
            }
            
            #checking conditions
            let interval = 24hr 
            let now = date now
            let update = (open ~/.autolister.json | get updated | into datetime) + $interval < $now
            let autolister_file = open ~/.autolister.json
            
            if $update and ((sys host | get hostname) != "rayen") {
                ## list mounted drives and download directory
                nu ($env.MY_ENV_VARS.nu_scripts | path join autolister.nu)
            
                $autolister_file
                | upsert updated $now
                | save -f ~/.autolister.json
            
                ## update ip
                print (echo $"(ansi -e { fg: '#00ff00' attr: b })getting device ips...(ansi reset)")
                let host = (sys host | get hostname)
                let ips_file = $env.MY_ENV_VARS.ips
                let ips_content = open $ips_file
                let ips = nu ($env.MY_ENV_VARS.nu_scripts | path join get-ips.nu)
            
                $ips_content
                | upsert $host ($ips | from json)
                | save -f $ips_file
            }
        }
    ]
    env_change: {
      PWD: [
        {|before, after|
            #checking existence of data file
            if not ("~/.pwd_sizes.json" | path expand | path exists) {
                cp ($env.MY_ENV_VARS.linux_backup | path join pwd_sizes.json) ~/.pwd_sizes.json
            }
            
            #checking conditions
            let interval = 12hr 
            let last_record = (open ~/.pwd_sizes.json | where directory == $env.PWD)
            let now = (date now)
            let not_update = (
                if ($last_record | length) == 0 {
                    false
                } else {
                    (($last_record | get updated | get 0 | into datetime) + $interval > $now)
                }
            )
            let not_gdrive = not ($env.PWD =~ rclone)
            
            #calculating pwd_size
            let pwd_size = (
                if ($last_record | length) == 0 and $not_gdrive {
                    du $env.PWD --exclude *rclone*
                    | get apparent 
                    | get 0 
                    | into string 
                    | str replace " " "" 
                } else if $not_gdrive {
                    if $not_update {
                        $last_record | get size | get 0
                    } else {
                        du $env.PWD --exclude *rclone*
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
            $env.PWD_SIZE = $pwd_size
            let pwd_file = open ~/.pwd_sizes.json
            
            #updating data file
            if ($last_record | length) == 0 and $not_gdrive {    
                $pwd_file  
                | append {directory: $env.PWD,size: $pwd_size, updated: $now} 
                | save -f ~/.pwd_sizes.json    
            } else if (not $not_update) and $not_gdrive {
                $pwd_file
                | where directory != $env.PWD 
                | append {directory: $env.PWD,size: $pwd_size, updated: $now}
                | save -f ~/.pwd_sizes.json
            }
        },
        {|before, after| 
            try {print (ls | sort-by -i type name | grid -c)}           
        },
        {|_, after|
            zoxide add -- $after
        },
        {
            condition: {"autouse.nu" | path exists},
            code: "source autouse.nu"
        },
        {
            condition: {"venv" | path exists},
            code: "overlay use venv/bin/activate.nu"
        }
        ,
        {
            condition: {".venv" | path exists},
            code: "overlay use .venv/bin/activate.nu"
        }
      ]
    }
    display_output: {||
       table
    }
  }

$env.config.hooks = $hooks

#menus
let new_menus_names = ["alias_menu" "my_history_menu"]
let menus = [ {
        name: alias_menu
        only_buffer_difference: false
        marker: "👀 "
        type: {
          layout: columnar
          columns: 1
          col_width: 20
          col_padding: 2
        }
        style: {
          text: green
          selected_text: green_reverse
          description_text: yellow
        }
        source: { |buffer, position|
          scope aliases
          | where name == $buffer
          | each { |it| {value: $it.expansion }}
        }
    },
    # {
    #   name: my_history_menu
    #   only_buffer_difference: false
    #   marker: ''
    #   type: { layout: ide }
    #   style: {}
    #   source: {|buffer, position|
    #     {
    #       # only history of current directory
    #       value: (
    #         atuin history list --reverse false --cwd --cmd-only --print0
    #         | split row (char nul) | uniq
    #         | par-each {$in | nu-highlight}
    #         | str join (char nul)
    #         | fzf --read0 --ansi -q $buffer --height 40%
    #         | ansi strip
    #       )
    #     }
    #   }
    # }
]

$env.config.menus = $env.config.menus | where name not-in $new_menus_names | append $menus

#keybindings
let new_keybinds_names = ["alias_menu" 
    "reload_config" 
    "update_right_prompt" 
    "insert_newline" 
    "insert_last_argument" 
    "insert_sudo" 
    "completion_menu" 
    "ide_completion_menu" 
    "copy_command"
    "my_history_menu"
    "change_dir_with_fzf"
    "select_file_fzf"
    "delete_one_word_backward"
]

let new_keybinds = [
    {
        name: alias_menu
        modifier: alt
        keycode: char_a
        mode: [emacs, vi_normal, vi_insert]
        event: [
            { send: menu name: alias_menu }
            { edit: insertchar, value: ' '}
        ]
     },
    {
        name: reload_config
        modifier: alt
        keycode: char_x
        mode: emacs
        event: {
          send: executehostcommand,
          cmd: $"source ($nu.config-path)"
        }
    },
    {
        name: update_right_prompt
        modifier: alt
        keycode: char_p
        mode: emacs
        event: {
          send: executehostcommand,
          cmd: '$env.MY_ENV_VARS.l_prompt = if not ($env.MY_ENV_VARS | is-column l_prompt) {"short"} else if ($env.MY_ENV_VARS.l_prompt | is-empty) or ($env.MY_ENV_VARS.l_prompt == "short") {"long"} else {"short"}'
        }        
    },
    {
        name: insert_newline
        modifier: alt
        keycode: enter
        mode: emacs
        event: { edit: insertnewline }
    },
    {
        name: insert_last_argument
        modifier: alt
        keycode: char_i
        mode: emacs
        event: [{  
                    edit: InsertString,
                    value: "!$"
               },
               { send: Enter }]
    },
    {
        name: insert_sudo
        modifier: alt
        keycode: char_s
        mode: [emacs, vi_insert, vi_normal]
        event: [
                { edit: MoveToStart }
                { edit: InsertString,
                  value: "sudo "
                }
                { edit: MoveToEnd }
               ]
    },
    {
        name: completion_menu
        modifier: control
        keycode: char_i
        mode: [emacs vi_normal vi_insert]
        event: {
            until: [
                { send: menu name: completion_menu }
                { send: menunext }
                { edit: complete }
            ]
        }
    },
    {
        name: ide_completion_menu
        modifier: none
        keycode: tab
        mode: [emacs vi_normal vi_insert]
        event: {
            until: [
                { send: menu name: ide_completion_menu }
                { send: menunext }
                { edit: complete }
            ]
        }
    },
    {
        name: copy_command
        modifier: control_alt
        keycode: char_c
        mode: [emacs, vi_normal, vi_insert]
        event: {
            send: executehostcommand
            cmd: "commandline | xsel --input --clipboard; commandline edit --append ' # copied'"
        }
    },
    {
        name: my_history_menu
        modifier: alt
        keycode: char_r
        mode: [emacs, vi_insert, vi_normal]
        event: { send: menu name: my_history_menu }
    },
    {
        name: change_dir_with_fzf
        modifier: alt
        keycode: char_c
        mode: emacs
        event: {
          send: executehostcommand,
          cmd: "cd (ls | where type == dir | each { |it| $it.name | str prepend (ansi -e { fg: '#5555FF' attr: b})} | input list -f (echo-g 'Select dir:'))"
        }
    },
    {
        name: select_file_fzf
        modifier: alt
        keycode: char_f
        mode: emacs
        event: [
          {
            send: executehostcommand
            cmd: "let file = ls | where type == file | sort-by name | get name | input list -f (echo-g 'Select file:');commandline edit --append $'\'($file)\'';commandline set-cursor --end"
          }
        ]
    },
    {
        name: delete_one_word_backward
        modifier: alt
        keycode: backspace
        mode: [emacs, vi_insert, vi_normal]
        event: { edit: backspaceword }
    }
]

$env.config.keybindings = $env.config.keybindings | where name not-in $new_keybinds | append $new_keybinds

#for fun
# try {
#     if (random bool) {
#         print (http get -H ["Accept" "text/plain"] https://icanhazdadjoke.com)
#     } else {
#         print (http get https://api.chucknorris.io/jokes/random).value
#     }   
# }