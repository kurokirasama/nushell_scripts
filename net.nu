#!/usr/bin/env nu

def main [how_many: int = 2] {
	let nethogs = do -i {nethogs -c 2 -t -d 5} | complete | get stdout | lines 
	let ref_index = $nethogs | find-index Refreshing | get 1
	
	$nethogs
	| skip ($ref_index + 1) 
	| drop 
	| parse "{NAME}\t{UP}\t{DOWN}" 
	| update NAME {|it| 
			extract-name $it.NAME
	  } 
	| update UP {|up| 
			$up.UP | split chars | first 5 | str join
	  } 
	| update DOWN {|up| 
			$up.DOWN | split chars | first 5 | str join
	  } 
	| format pattern "{NAME}:{UP}:{DOWN}" 
	| first $how_many
	| str join "\n"
	| to text
	| awk -F: '{printf "%-30s %15s %15s\n", $1, $2, $3}'
}

def indexify [
  column_name?: string = 'index' #export default: index
  ] { 
  enumerate 
  | upsert $column_name {|el| 
      $el.index
    } 
  | flatten
}

def find-index [name: string,default? = -1] {
  $in
  | indexify
  | find $name
  | try {
      get index
    } catch {
      $default 
    }
}

def extract-name [path] {
	if $path like '^[0-9]' {
		"transmission"
	} else if $path like 'jd2' {
		"jd"
	} else if $path like 'maestral' {
		"maestral"
	} else if $path like 'cmdg' {
		"cmdg"
	} else if $path like 'ssh' {
		"ssh"
	} else if $path like 'ssh' {
		"nchat"
	} else if $path like 'yandex' {
		"yandex"
	} else if $path like 'zed' {
		"zed"
	} else if $path like 'gnome-software' {
		"gnome-software"
	} else if $path like 'bin/nu' {
		"nu"
	} else if $path like '^/usr/bin' {
		$path | split row '/' | get 3
	} else if $path not-like '^/' {
		$path | split row '/' | get 0
	} else if $path like '^/opt' {
		$path | split row '/' | get 2
	} else {
		$path | path parse | get stem
	}
}
