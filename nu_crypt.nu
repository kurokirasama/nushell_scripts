#crypt
export def nu-crypt [
	file?
	--encrypt(-e)			 #is has precedence over decrypt
	--decrypt(-d)	
	--output_file(-o):string #only for -d option
	--no_ui(-n)				 #to ask for password in cli
] {
	let file = if ($file | is-empty) {$in | get name} else {$file}

	if ($encrypt) {
		gpg --pinentry-mode loopback --symmetric --armor --yes $file
	} else if ($decrypt) {
		if ($output_file | is-empty) {
			if $no_ui {
				gpg --pinentry-mode loopback --decrypt --quiet $file
			} else {
				gpg --decrypt --quiet $file
			}
		} else {
			if $no_ui {
				gpg --pinentry-mode loopback --output $output_file --quiet --decrypt $file
			} else {
				gpg --output $output_file --quiet --decrypt $file
			}
		}
	} else {
		return-error "missing option -d or -f!"
	} 	
}

#open credentials
export def open-credential [file?,--ui(-u)] {
	let file = if ($file | is-empty) {$in | get name} else {$file}
	if $ui {
		nu-crypt -d $file | from json
	} else {
		nu-crypt -d $file -n | from json
	}
}

#save credentials
export def save-credential [content:string,file:string] {
	if ($file | is-empty) or ($content | is-empty) {
		return-error "missing arguments!"
		return
	}

	$content | save -f $file 
	nu-crypt -e $file
	rm -f $file | ignore
}