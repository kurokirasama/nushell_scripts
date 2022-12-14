#crypt
export def nu-crypt [
	file?
	--encrypt(-e)			 #is has precedence over decrypt
	--decrypt(-d)	
	--output_file(-o):string #only for -d option
] {
	let file = if ($file | is-empty) {$in | get name} else {$file}

	if ($encrypt) {
		gpg --symmetric --armor --yes $file
	} else if ($decrypt) {
		if ($output_file | is-empty) {
			gpg --decrypt --quiet $file
		} else {
			gpg --output $output_file --quiet --decrypt $file
		}
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
	if ($file | is-empty) or ($content | is-empty) {
		echo-r "missing arguments!"
		return
	}

	$content | save -f $file 
	nu-crypt -e $file
	rm -f $file | ignore
}