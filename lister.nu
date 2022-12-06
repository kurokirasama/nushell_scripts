#!/usr/bin/env nu

def main [file] {
	let file = ((["~/Dropbox/Directorios" $"($file).json"] | path join | path expand))

	let df = get-files -f -F 
	
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
