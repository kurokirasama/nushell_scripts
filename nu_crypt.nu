#crypt
export def nu-crypt [
	file?
	--encrypt(-e)	#is has precedence over decrypt
	--decrypt(-d)	
] {
	let file = if ($file | is-empty) {$in | get name} else {$file}

	if ($encrypt) {
		gpg --symmetric --armor --yes $file
	} else if ($decrypt) {
		gpg --decrypt --quiet $file
	} else {
		echo-r "missing option -d or -f!"
	} 	
}

#open credentials
export def open-credential [file?] {
	let file = if ($file | is-empty) {$in | get name} else {$file}
	nu-crypt -d $file | from json
}

#save credentials
export def save-credential [content:string,file:string] {
	if ($file | is-empty) || ($content | is-empty) {
		echo-r "missing arguments!"
		return
	}

	$content | save -f $file 
	nu-crypt -e $file
	rm -f $file | ignore
}