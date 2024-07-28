#!/usr/bin/env nu

export def main [] {
	let dpx_output = (
		maestral status 
		| lines 
		| parse "{item}  {status}" 
		| str trim 
		| drop nth 0 
		| get status 
		| get 0 1
	)

	let output = $dpx_output | get 1
	let output_2 = $dpx_output
		| get 0
		| str replace '%' ''
		| split row ' ' 
		| drop nth 1 3 4
		| str join ' GB / '
		| str append ' GB'

	return ("Status: " + $output + "\nUsage: " + $output_2)
}

def "str append" [tail:string] {
	$in ++ $tail
}