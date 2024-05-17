#modifying $env.config...
let my_config = $env.config

#restoring custom color config
mut my_color_config = ($my_config 
	| get color_config 
	| upsert shape_internalcall (if TERMINUS_SUBLIME in $env {"light_cyan_bold"} else { fg: "#00b7ff" attr: b} )
	| upsert shape_external (if TERMINUS_SUBLIME in $env {"xterm_skyblue2"} else "#00b7ff" )
)

$my_color_config.filesize = {|e| 
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

let my_config = (
	$my_config 
	| upsert table.trim.wrapping_try_keep_words false
	| upsert color_config $my_color_config 
	| upsert show_banner false
	| upsert ls.clickable_links false
	| upsert table.mode (if TERMINUS_SUBLIME in $env {"ascii_rounded"} else {"rounded"})
    | upsert table.show_empty false
	| upsert history.file_format sqlite
)

#restoring hooks
let hooks = {
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
                        "onedrive" => {"f8c9"},
                        "gdrive" => {"e731"},
                        "photos" => {"fbdb"}, 
                        "yandex" => {"f662"}, 
                        "box" => {"f5d3"}, 
                        "mega" => {"e673"}, 
                        _ => {"f7b5"}
                    }
                } else {
                    if (sys host | get name) =~ "Windows" {"f17a"} else {"f31b"}
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
    		nu /home/kira/Yandex.Disk/Backups/linux/nu_scripts/pre_execution_hook.nu		
    	}
    ]
    env_change: {
      PWD: [
      	{|before, after|
			source-env /home/kira/Yandex.Disk/Backups/linux/nu_scripts/env_change_hook.nu
      	}
      	{|before, after| 
      		try {print (ls | sort-by -i type name | grid -c)}      		
      	}
      	{|before, after|
      		zoxide add -- $env.PWD
      	}
      ]
    }
    display_output: {||
       table
    }
  }

let my_config = ($my_config | upsert hooks $hooks)
let my_config = ($my_config | upsert completions.use_ls_colors true)

#restoring menus
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

let menus = ($my_config | get menus | indexify idx)

let alias_menu_row = (
	$menus 
	| find "alias_menu" 
	| try {
      	get idx | get 0
      } catch {
        -1
      }
)

let menus = (
	$menus 
	| where idx not-in [$alias_menu_row] 
	| reject idx 
	| append $alias_menu
)

let my_config = ($my_config | upsert menus $menus)

#restoring keybinds
let keybindings = ($my_config | get keybindings | find -v completion_menu | indexify idx)
mut new_indexes = []
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
    }
]

let n_new_k = ($new_keybinds | length)

let new_indexes = (
	$new_keybinds 
	| each {|key|
		let name = ($key | get name)
		$keybindings 
		| find $name 
		| try {
      		get idx | get 0
    	  } catch {
      		-1
    	  }
		| get 0
	}
)

##updating
let keybindings = (
	$keybindings 
	| where idx not-in $new_indexes 
	| reject idx
	| append $new_keybinds
)

let my_config = ($my_config | upsert keybindings $keybindings)

#restoring table_trim
let tableTrim = {
    methodology: truncating, # wrapping
    wrapping_try_keep_words: true,
    truncating_suffix: "❱" #...
  }

let my_config = (
    $my_config 
    | upsert table.trim $tableTrim
    | upsert use_kitty_protocol true
    | upsert completions.algorithm prefix #fuzzy
    | upsert recursion_limit 100
)

#updating $env.config
$env.config = $my_config  

try {
    if (random bool) {
        print (http get -H ["Accept" "text/plain"] https://icanhazdadjoke.com)
    } else {
        print (http get https://api.chucknorris.io/jokes/random).value
    }   
}