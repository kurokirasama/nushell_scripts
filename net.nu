#!/usr/bin/env nu

def main [] {
	let nethogs = do -i {nethogs -c 2 -t -d 5} | complete | get stdout | lines 
	let ref_index = $nethogs | find-index refreshing | get 1
	
	$nethogs
	| skip ($ref_index + 1) 
	| drop 
	| parse "{NAME}\t{UP}\t{DOWN}" 
	| where NAME !~ '^[0-9]'
	| update NAME {|it| 
			extract-name $it.NAME
	  } 
	| update UP {|up| 
			$up.UP | fill -a l -c "0" -w 7
	  } 
	| update DOWN {|up| 
			$up.DOWN | fill -a l -c "0" -w 7
	  } 
	| format pattern "{NAME}:{UP}:{DOWN}" 
	| str join "\n"
	| to text
	| awk -F: '{printf "%-30s %15s %15s\n", $1, $2, $3}'
	# | save -f ("~/.nethogs" | path expand)
	
	# echo "\n" | save --append ("~/.nethogs" | path expand)
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
	if $path =~ 'jd2' {
		"jd"
	} else if $path =~ 'jd2' {
		"maestral"
	} else if $path =~ '^/usr/bin' {
		$path | split row '/' | get 3
	} else if $path !~ '^/' {
		$path | split row '/' | get 0
	} else if $path =~ '^/opt' {
		$path | split row '/' | get 2
	} else {
		$path | path parse | get stem
	}
}