#!/usr/bin/env nu

def main [user:string = "kira"] {
	let host = sys host | get hostname

	print (echo-g "listing Downloads...")
	cd ~/Downloads
	lister ("Downloads" + "_" + $host)

	let drives = sys disks | where mount like $"/media/($user)"

	if ($drives | length) > 0 {
		$drives
		| get mount
		| each { |drive|
				print (echo-g $"listing ($drive | ansi strip)...")
				cd ($drive | ansi strip)
				lister ($drive | path parse | get stem | split row " " | get 0)
			}
	}
}

#list all files and save it to json in Dropbox/Directorios
export def lister [file:string] {
  let file = (["~/Dropbox/Directorios" $"($file).json"] | path join | path expand)

  let df = (try {
      get-files -f -F 
    } catch {
      []
    }
  )

  if ($df | length) == 0 {
    if $file like "Downloads" and ($file | path expand | path exists) { 
      rm $file
    }
    return
  }

  let last = $df | reject name | update size {into int} | polars into-df

  let df = (
    $df
    | each {|file| 
      $file
      | get name 
      | parse $"{origin}/($env.USER)/{location}/{rest}"
      }
    | flatten
  ) 

  let first = $df | select origin location | polars into-df

  let second = (
    $df 
    | select rest 
    | each {|file| 
      $file 
      | get rest 
      | path parse -e ''
      } 
    | polars into-df 
    | polars drop extension 
    | polars rename [parent stem] [path file]
  )

  $first 
  | polars append $second 
  | polars append $last 
  | polars into-nu 
  | update size {into filesize} 
  | save -f $file
}

#get list of files recursively
def get-files [
    dir?
    --recursive(-f)
    --full_paths(-F)
    --sort_by_date(-t)
] {
    let dir = $dir | default "."
    let pattern = if $recursive { "**/*" } else { "*" } | into glob
    cd $dir

    ls --full-paths=$full_paths $pattern
    | where type == file 
    | if $sort_by_date {
        sort-by -i modified
    } else {
        sort-by -i name
    }
}

#green echo
def echo-g [string:string] {
  echo $"(ansi -e { fg: '#00ff00' attr: b })($string)(ansi reset)"
}