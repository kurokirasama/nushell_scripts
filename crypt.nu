#crypt
export def nu-crypt [
	file?
	--encrypt(-e)			 #is has precedence over decrypt
	--decrypt(-d)	
	--output_file(-o):string #only for -d option
	--no_ui(-n)				 #to ask for password in cli
] {
	let file = get-input $in $file -n

	match [$encrypt,$decrypt] {
		[true,false] => {gpg --pinentry-mode loopback --symmetric --armor --yes $file},
		[false,true] => {
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
		},
		_ => {return-error "flag combination not allowed!!"} 	
	}
}

#open credentials
export def open-credential [file?,--ui(-u)] {
	let file = get-input $in $file -n
	if $ui {
		nu-crypt -d $file | from json
	} else {
		nu-crypt -d $file -n | from json
	}
}

#save credentials
export def save-credential [content,field:string] {
	if ($field | is-empty) or ($content | is-empty) {
		return-error "missing arguments!"
	}

	let credentials_e = $env.MY_ENV_VARS.credentials | path join credentials.json.asc
	let credentials = $env.MY_ENV_VARS.credentials | path join credentials.json

	open-credential $credentials_e
	| upsert $field $content
	| save -f $credentials

	nu-crypt -e $credentials
	rm -f $credentials | ignore
}