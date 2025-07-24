#!/usr/bin/env nu

export def main [] {
	let ydx_info = (
		/usr/bin/yandex-disk status 
		| grep -E "Sync|Total|Used|Trash" 
		| lines 
		| split column ':' 
		| str trim 
		| rename item status
		| find -v file
	)

	let output = $ydx_info | get status.0
	let output_2 = $ydx_info.status | skip | roll down | reverse | str join " / "
	
	return ("Status: " + $output + "\nUsage: " + $output_2)
}
