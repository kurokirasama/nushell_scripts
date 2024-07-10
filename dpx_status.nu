#!/usr/bin/env nu

export def main [
	output:string #Usage or Status
] {
	let index = if ($output == "Usage") {0} else {1}
	let dpx_output = (
		maestral status 
		| lines 
		| parse "{item}  {status}" 
		| str trim 
		| drop nth 0 
		| get status 
		| get $index
	)

	if ($output == "Usage") {
		$dpx_output
		| str replace '%' ''
		| split row ' ' 
		| drop nth 1 3 4
		| str join ' GB / '
		| str append ' GB'
	} else {
		return $dpx_output
	} 
}

def "str append" [tail:string] {
	$in ++ $tail
}