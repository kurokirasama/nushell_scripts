#modifying $env.config...
let my_config = ($env.config)

#restoring custom color config
let my_color_config = ($my_config 
	| get color_config 
	| upsert shape_internalcall { fg: "##00b7ff" attr: b} 
	| upsert shape_external "#00b7ff"
)

let my_config = (
	$my_config 
	| upsert table.trim.wrapping_try_keep_words false
	| upsert color_config $my_color_config 
	| upsert show_banner false
	| upsert ls.clickable_links false
	| upsert table.mode reinforced
	| upsert history.file_format sqlite
)

#restoring hooks
let hooks = {
    pre_prompt: [{
        print $"Time elapsed: (($env.CMD_DURATION_MS | into decimal) / 1000) s"
        }]
    pre_execution: [{
      $nothing  
    }]
    env_change: {
      PWD: [
      	{|before, after|
			print ""
      	}
      	{|before, after| 
      		print (ls | sort-by -i type name | grid -c)
      	}
      ]
    }
    display_output: {
       table
    }
  }

# source-env ([$env.MY_ENV_VARS.nu_scripts nu_pre_execution_hook.nu] | path join)
	  # let-env LAST_OUTPUT = $in;
      # print ($env.LAST_OUTPUT | table);
      # if (term size).columns >= 100 { table -e } else { table }

let my_config = ($my_config | upsert hooks $hooks)

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
           $nu.scope.aliases
           | where alias == $buffer
           | each { |it| {value: $it.expansion }}
       }
     }

let menus = ($my_config | get menus)

let alias_menu_row = (
	if ($menus | any {|row| $row.name == alias_menu}) {
		for $row in 0..(($menus | length) - 1) {
			if ($menus | get $row | get name) == alias_menu {
				$row
			}
		}
	} else {
	-1
	} 
)

let menus = (
	if $alias_menu_row == -1 {
		$menus | append $alias_menu
	} else {
		$menus | drop nth ($alias_menu_row | get 0) | append $alias_menu
	}
)

let my_config = ($my_config | upsert "menus" $menus)

#restoring keybinds
##alias
let alias_keybind = ({
  	name: alias_menu
  	modifier: alt
  	keycode: char_a
  	mode: [emacs, vi_normal, vi_insert]
  	event: { send: menu name: alias_menu }
})

let keybindings = ($my_config | get keybindings)

let alias_menu_row = (
	if ($keybindings | any {|row| $row.name == alias_menu}) {
		for $row in 0..(($keybindings | length) - 1) {
			if ($keybindings | get $row | get name) == alias_menu {
				$row
			}
		}
	} else {
	-1
	} 
)

let keybindings = (
	if $alias_menu_row == -1 {
		$keybindings | append $alias_keybind
	} else {
		$keybindings | drop nth ($alias_menu_row | get 0) | append $alias_keybind
	}
)

##reload
let reload_keybind = (
	{
        name: reload_config
        modifier: alt
        keycode: char_x
        mode: emacs
        event: {
          send: executehostcommand,
          cmd: $"source ($nu.config-path)"
      }
    }
)

let alias_menu_row = (
	if ($keybindings | any {|row| $row.name == reload_config}) {
		for $row in 0..(($keybindings | length) - 1) {
			if ($keybindings | get $row | get name) == reload_config {
				$row
			}
		}
	} else {
	-1
	} 
)

let keybindings = (
	if $alias_menu_row == -1 {
		$keybindings | append $reload_keybind
	} else {
		$keybindings | drop nth ($alias_menu_row | get 0) | append $reload_keybind
	}
)

let my_config = ($my_config | upsert "keybindings" $keybindings)


##update right prompt
let prompt_keybind = (
	{
        name: update_right_prompt
        modifier: alt
        keycode: char_p
        mode: emacs
        event: {
          send: executehostcommand,
          cmd: $"source-env ([($env.MY_ENV_VARS.nu_scripts) update_right_prompt.nu] | path join)"
      }        
    }
)

let alias_menu_row = (
	if ($keybindings | any {|row| $row.name == update_right_prompt}) {
		for $row in 0..(($keybindings | length) - 1) {
			if ($keybindings | get $row | get name) == update_right_prompt {
				$row
			}
		}
	} else {
	-1
	} 
)

let keybindings = (
	if $alias_menu_row == -1 {
		$keybindings | append $prompt_keybind
	} else {
		$keybindings | drop nth ($alias_menu_row | get 0) | append $prompt_keybind
	}
)

let my_config = ($my_config | upsert "keybindings" $keybindings)

##insert new line in terminal
let insert_newline = (
	{
        name: insert_newline
        modifier: alt
        keycode: enter
        mode: emacs
        event: { edit: insertnewline }
    }
)

let alias_menu_row = (
	if ($keybindings | any {|row| $row.name == insert_newline}) {
		for $row in 0..(($keybindings | length) - 1) {
			if ($keybindings | get $row | get name) == insert_newline {
				$row
			}
		}
	} else {
	-1
	} 
)

let keybindings = (
	if $alias_menu_row == -1 {
		$keybindings | append $insert_newline
	} else {
		$keybindings | drop nth ($alias_menu_row | get 0) | append $insert_newline
	}
)

let my_config = ($my_config | upsert "keybindings" $keybindings)

#restoring table_trim
let tableTrim = {
    methodology: truncating, # wrapping
    wrapping_try_keep_words: true,
    truncating_suffix: "❱" #...
  }

let my_config = ($my_config | upsert table.trim $tableTrim)

#updating $env.config
let-env config = $my_config  