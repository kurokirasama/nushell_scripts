#!/usr/bin/env nu

def main [user = "kira"] {
	let host = (sys | get host | get hostname)

	echo-g "listing Downloads..."
	cd ~/Downloads
	lister ("Downloads" + "_" + $host)

	let drives = try {
		duf -json 
  	| from json 
  	| find $"/media/($user)" 
  	| get mount_point
	} catch {
		[]
	}

	if ($drives | length) > 0 {
		$drives
		| each { |drive|
				echo-g $"listing ($drive | ansi strip)..."
				cd ($drive | ansi strip)
				lister ($drive | ansi strip | path parse | get stem | split row " " | get 0)
			}
	}
}

#list all files and save it to json in Dropbox/Directorios
def lister [file] {
	let file = (["~/Dropbox/Directorios" $"($file).json"] | path join | path expand)

	let df = try {
			get-files -f -F 
		} catch {
			[]
		}

	if ($df | length) == 0 {
		if $file =~ "Downloads" and ($file | path expand | path exists) { 
      rm $file
    }
		return
	}

	let last = ($df | into df | drop name) 

	let df = (
		$df
		| each {|file| 
			$file
			| get name 
			| parse $"{origin}/($env.USER)/{location}/{rest}"
		  }
		| flatten
	) 

	let first = ($df | select origin location | into df) 

	let second = (
		$df 
		| select rest 
		| each {|file| 
			$file 
			| get rest 
			| path parse -e ''
		  } 
		| into df 
		| drop extension 
		| rename [parent stem] [path file]
	)

	$first | append $second | append $last | into nu | save -f $file
}

#get list of files recursively
def get-files [--full(-f),--dir(-d):string,--full_path(-F)] {
  if $full {
    if not ($dir | is-empty) {
      if $full_path {
        ls -f $"($dir)/**/*"
        } else {
          ls $"($dir)/**/*"
        }
    } else {
      if $full_path {
        ls -f **/*
      } else {
        ls **/*
      }
    }
  } else {
    if not ($dir | is-empty) {
      if $full_path {
        ls -f $"($dir)"
      } else {
        ls $"($dir)"
      }
    } else {
      if $full_path {
        ls -f
      } else {
        ls
      }
    }
  } 
  | where type == file 
  | sort-by -i name
}

#green echo
def echo-g [string:string] {
  echo $"(ansi -e { fg: '#00ff00' attr: b })($string)(ansi reset)"
}