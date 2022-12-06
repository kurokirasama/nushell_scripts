#!/usr/bin/env nu

do -i {nethogs -c 2 -t -d 5}  
| complete 
| get stdout
| grep '^/' 
| head -n 5 
| lines 
| split column "\t" 
| update column1 {|it| 
	$it.column1 
	| split row " " 
	| first 
	| str replace -a '/\d+' '' 
	| path parse 
	| get stem
  } 
| rename NAME UP DOWN
| str trim
| update UP {|up|
	$up.UP | str rpad -l 7 -c '0'
  }
| update DOWN {|up|
	$up.DOWN | str rpad -l 7 -c '0'
  }
| format "{NAME}:{UP}:{DOWN}"
| str collect "\n"
| save -f /home/kira/.nethogs

echo "\n" | save --append /home/kira/.nethogs