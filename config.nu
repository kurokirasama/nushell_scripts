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
$env.config.filesize.metric = true
$env.config.cursor_shape.emacs = "blink_line"
$env.config.highlight_resolved_externals = true

#hooks
$env.config.hooks = {
    pre_prompt: [
        {||
            $env.GIT_STATUS = (
                try {
                    if (ls .git | length) > 0 and (git status -s | str length) > 0 {
                        git status -s | lines | length
                    } else {
                        0
                    }   
                } catch {
                    0
                }
            )

            $env.CLOUD = (
                if $env.PWD =~ "rclone/" {
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
            )
        },
        {||
            $env.NETWORK = (
                $env.NETWORK 
                | upsert status (check-link https://www.google.com)
            )
            
            $env.NETWORK = (
                $env.NETWORK
                | upsert color (if $env.NETWORK.status {'#00ff00'} else {'#ffffff'})
            )
        }
    ]
    pre_execution: [
        {||
            nu ("~/Yandex.Disk/Backups/linux/my_scripts/nushell/pre_execution_hook.nu" | path expand)
        }
    ]
    env_change: {
      PWD: [
        {|before, after|
            source-env ("~/Yandex.Disk/Backups/linux/my_scripts/nushell/env_change_hook.nu" | path expand)
        }
        {|before, after| 
            try {print (ls | sort-by -i type name | grid -c)}           
        }
        {|_, dir|
            zoxide add -- $dir
        }
        {
            condition: {".autouse.nu" | path exists},
            code: "source .autouse.nu"
        }
        {
            condition: {"venv" | path exists},
            code: "overlay use venv/bin/activate.nu"
        }
      ]
    }
    display_output: {||
       table
    }
  }

#menus
let new_menus_names = ["alias_menu"]
let alias_menu = {
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
}

$env.config.menus = $env.config.menus | where name not-in $new_menus_names | append $alias_menu

#keybindings
let new_keybinds_names = ["alias_menu" "reload_config" "update_right_prompt" "insert_newline" "insert_last_argument" "insert_sudo" "completion_menu" "ide_completion_menu" "fuzzy_select_fs"]
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
          cmd: $"source-env ([($env.MY_ENV_VARS.nu_scripts) update_right_prompt.nu] | path join)"
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
        keycode: char_n
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
        name: fuzzy_select_fs
        modifier: alt
        keycode: char_z
        mode: [emacs, vi_normal, vi_insert]
        event: {
            send: executehostcommand
            cmd: "commandline edit --insert (fuzzy-dispatcher)"
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
    }
]

$env.config.keybindings = $env.config.keybindings | where name not-in $new_keybinds_names | append $new_keybinds

#for fun
# try {
#     if (random bool) {
#         print (http get -H ["Accept" "text/plain"] https://icanhazdadjoke.com)
#     } else {
#         print (http get https://api.chucknorris.io/jokes/random).value
#     }   
# }