#!/usr/bin/env nu

do -i {nethogs -c 2 -t -d 5}  
| complete 
| get stdout
| lines 
| find --regex '^/' 
| first 5 
| parse  "{NAME}\t{UP}\t{DOWN}" 
| update NAME {|it| 
	$it.NAME 
	| str replace -a '/\d+' '' 
	| path parse 
	| get stem
  } 
| update UP {|up| 
	$up.UP | fill -a l -c "0" -w 7
  } 
| update DOWN {|up| 
	$up.DOWN | fill -a l -c "0" -w 7
  } 
| format "{NAME}:{UP}:{DOWN}" 
| str collect "\n"
| save -f /home/kira/.nethogs

echo "\n" | save --append /home/kira/.nethogs