#!/usr/bin/env nu

export def main [
	output:string #Usage or Status
] {
	let ydx_info = (
		yandex-disk status 
		| grep -E "Sync|Total|Used|Trash" 
		| lines 
		| split column ':' 
		| str trim 
		| rename item status
	)

	if ($output == "Status") {
		return ($ydx_info | get status.0)
	} else {
		return ($ydx_info.status | skip | roll down | reverse | str join " / ")
	}
}