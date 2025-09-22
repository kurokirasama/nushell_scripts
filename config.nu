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
$env.config.completions.algorithm = "prefix" #fuzzy, substring
$env.config.completions.use_ls_colors = true
$env.config.float_precision = 4;
$env.config.filesize.unit = "metric"
$env.config.cursor_shape.emacs = "blink_line"
$env.config.highlight_resolved_externals = true
$env.config.table.missing_value_symbol = (char -u e374)

#hooks
let hooks = {
    pre_prompt: [
        {||
            $env.CLOUD = if $env.PWD like "rclone/" {
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
                        $p if $p like "Debian*" => {"f306"},
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
            let interval = 12hr 
            let now = date now
            let update = (open ~/.autolister.json | get updated | into datetime) + $interval < $now
            let autolister_file = open ~/.autolister.json
            
            if $update and ((sys host | get hostname) != "rayen") {
                ## list mounted drives and download directory
                try {
                    nu ($env.MY_ENV_VARS.nu_scripts | path join autolister.nu)
                }
                
                $autolister_file
                | upsert updated $now
                | save -f ~/.autolister.json
            
                ## update ip
                print (echo $"(ansi -e { fg: '#00ff00' attr: b })getting device ips...(ansi reset)")
                let host = (sys host | get hostname)
                let ips_file = $env.MY_ENV_VARS.ips
                let ips_content = open $ips_file
                let ips = nu ($env.MY_ENV_VARS.nu_scripts | path join get-ips.nu) ...$env.MY_ENV_VARS.hosts

            
                $ips_content
                | upsert $host ($ips | from json)
                | save -f $ips_file
                
                ## verify habitica
                let hstats = h stats
                if not $hstats.logged_in_today {
                    print (echo $"(ansi -e { fg: '#ff0000' attr: b })Not logged in to habitica yet, logging in now...(ansi reset)")
                    if ($hstats.dailys_to_complete > 0) {
                        print (echo $"(ansi -e { fg: '#FF0000' attr: b })You had ($hstats.dailys_to_complete) dailys to complete yesterday, completing them now...(ansi reset)")
                    }
                    h login
                    print (echo $"(ansi -e { fg: '#00ff00' attr: b })These are today's dailys:(ansi reset)")
                    print (h ls dailys -pi | get text)
                    print (echo $"(ansi -e { fg: '#00ff00' attr: b })These are latest todos:(ansi reset)")
                    print (h ls todos -i | last 15 | get text)
                }
                
                let hstats = h stats
                if $hstats.pending_quest {
                    print (echo $"(ansi -e { fg: '#FFA500' attr: b })You have a pending quest invitation, accepting it now...(ansi reset)")
                    h auto-quest 
                }
                
                if ($hstats.dailys_to_complete > 0) {
                    print (echo $"(ansi -e { fg: '#FFA500' attr: b })You have ($hstats.dailys_to_complete) dailys to complete today, completing them now...(ansi reset)")
                    try {h mark-dailys-done}
                }
                
                if (h ls dailys -ni | where text =~ supgrade | length) > 0 {
                    print (echo $"(ansi -e { fg: '#FFA500' attr: b })You have to upgrade your system today!(ansi reset)")
                }
                
                print (h stats)
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
            let not_gdrive = not ($env.PWD like rclone)
            
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
            try {print (ls | sort-by -i type name | grid -ci)}           
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
    display_output: {tee {table | print} | $env.last = $in}
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
    "change_dir_with_fzf"
    "select_file_fzf"
    "delete_one_word_backward"
    "insert_view_code"
    "insert_let"
    "help"
] #"my_history_menu"

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
                { send: Enter }
               ]
    },
    {
        name: completion_menu
        modifier: none
        keycode: tab
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
        modifier: control
        keycode: char_i
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
            cmd: "commandline | copy; commandline edit --append ' # copied'"
        }
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
    },
    {
        name: insert_view_code
        modifier: alt
        keycode: char_v
        mode: [emacs, vi_insert, vi_normal]
        event: [
                { edit: MoveToStart }
                { edit: InsertString,
                  value: "view-code "
                }
                { send: Enter }
               ]
    },
    {
        name: insert_let
        modifier: alt
        keycode: char_l
        mode: [emacs, vi_insert, vi_normal]
        event: [
                { edit: MoveToStart }
                { edit: InsertString,
                  value: "let "
                }
                { edit: MoveToEnd }
               ]
    },
    {
        name: help
        modifier: alt
        keycode: char_q
        mode: [emacs, vi_insert, vi_normal]
        event: [
                { edit: MoveToStart }
                { edit: InsertString,
                  value: "? "
                }
                { send: Enter }
               ]
    },
]

    # {
    #     name: my_history_menu
    #     modifier: alt
    #     keycode: char_r
    #     mode: [emacs, vi_insert, vi_normal]
    #     event: { send: menu name: my_history_menu }
    # },

$env.config.keybindings = $env.config.keybindings | where name not-in $new_keybinds | append $new_keybinds

#for fun
# try {
#     if (random bool) {
#         print (http get -H ["Accept" "text/plain"] https://icanhazdadjoke.com)
#     } else {
#         print (http get https://api.chucknorris.io/jokes/random).value
#     }   
# }
