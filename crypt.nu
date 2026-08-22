# Cryptographic utilities and secure credential management with RAM-disk caching

def get-credential-cache-path [] {
	let is_win = (sys host | get name | str lowercase) == "windows"
	if $is_win {
		$env.TEMP? | default "C:\\Temp" | path join "nu_creds_cache.json"
	} else if ("/dev/shm" | path exists) {
		$"/dev/shm/.nu_creds_cache_(sys host | get hostname).json"
	} else {
		$env.HOME | path join ".cache" "nu_creds_cache.json"
	}
}

#crypt
export def nu-crypt [
	file?
	--encrypt(-e)
	--decrypt(-d)
	--output_file(-o):string #only for -d option
	--no_ui(-n)				 #to ask for password in cli
] {
	let input_file = if ($file | is-not-empty) { $file } else if ($in | is-not-empty) { $in } else { null }
	if ($input_file | is-empty) {
		error make { msg: "no file provided to nu-crypt" }
	}

	match [$encrypt,$decrypt] {
		[true,false] => { gpg --pinentry-mode loopback --symmetric --armor --yes $input_file },
		[false,true] => {
			if ($output_file | is-empty) {
				if $no_ui {
					gpg --pinentry-mode loopback --decrypt --quiet $input_file
				} else {
					gpg --decrypt --quiet $input_file
				}
			} else {
				if $no_ui {
					gpg --pinentry-mode loopback --output $output_file --quiet --decrypt $input_file
				} else {
					gpg --output $output_file --quiet --decrypt $input_file
				}
			}
		},
		_ => { error make { msg: "flag combination not allowed in nu-crypt" } }
	}
}

#open credentials with caching
export def open-credential [file?, --ui(-u), --no-cache] {
	let input_file = if ($file | is-not-empty) { $file } else if ($in | is-not-empty) { $in } else { null }
	let cache_path = (get-credential-cache-path)

	if (not $no_cache) and ($cache_path | path exists) and ($input_file | is-not-empty) and ($input_file | path exists) {
		let file_mtime = (ls -l $input_file | get 0.modified)
		let cache_mtime = (ls -l $cache_path | get 0.modified)
		if $cache_mtime >= $file_mtime {
			let cached = try { open $cache_path } catch { null }
			if ($cached | is-not-empty) {
				return $cached
			}
		}
	}

	let decrypted = if $ui {
		nu-crypt -d $input_file | from json
	} else {
		nu-crypt -d $input_file -n | from json
	}

	try {
		$decrypted | to json | save -f $cache_path
		chmod 600 $cache_path
	} catch {}

	return $decrypted
}

#save credentials
export def save-credential [content, field:string] {
	if ($field | is-empty) or ($content | is-empty) {
		error make { msg: "missing arguments in save-credential" }
	}

	let credentials_e = $env.MY_ENV_VARS.credentials | path join credentials.json.asc
	let credentials = $env.MY_ENV_VARS.credentials | path join credentials.json

	open-credential $credentials_e
	| upsert $field $content
	| save -f $credentials

	nu-crypt -e $credentials
	rm -f $credentials | ignore

	# Invalidate cache
	let cache_path = (get-credential-cache-path)
	rm -f $cache_path | ignore
}