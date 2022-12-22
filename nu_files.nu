#compress all folders into a separate file and delete them
export def "7z folders" [--not_delete(-n)] {
  if not $not_delete {
    bash -c "find . -maxdepth 1 -mindepth 1 -type d -print0 | parallel -0 --eta 7z a -t7z -sdel -bso0 -bsp0 -m0=lzma2 -mx=9 -ms=on -mmt=on {}.7z {}"
  } else {
    bash -c "find . -maxdepth 1 -mindepth 1 -type d -print0 | parallel -0 --eta 7z a -t7z -bso0 -bsp0 -m0=lzma2 -mx=9 -ms=on -mmt=on {}.7z {}"
  }
}

#compress to 7z using max compression
export def "7z max" [
  filename: string  #existing or not existing 7z filename
  ...rest:  string  #files to compress and extra flags for 7z (add flags between quotes)
  --delete(-d)      #delete files after compression
  #
  # Example:
  # compress all files in current directory and delete them
  # 7z max filename * -d
  # compress all files in current directory and split into pieces of 3Gb (b|k|m|g)
  # 7z max filename * "-v3g"
  # both
  # 7z max filename * "-v3g -sdel"
] {
  if ($rest | is-empty) {
    return-error "no files to compress specified"
  } else if ($delete | is-empty) or (not $delete) {
    7z a -t7z -m0=lzma2 -mx=9 -ms=on -mmt=on $"($filename | path parse | get stem).7z" $rest
  } else {
    7z a -t7z -sdel -m0=lzma2 -mx=9 -ms=on -mmt=on $"($filename | path parse | get stem).7z" $rest
  }
}

#rm trough pipe
#
#Example
#ls *.txt | first 5 | rm-pipe
export def rm-pipe [] {
  if not ($in | is-empty) {
    get name 
    | ansi strip
    | par-each {|file| 
        rm -rf $file
      } 
    | flatten
  }
}

#cp trough pipe to same dir
export def cp-pipe [
  to: string#target directory
  #
  #Example
  #ls *.txt | first 5 | cp-pipe ~/temp
] {
  get name 
  | ansi strip
  | each {|file| 
      echo-g $"copying ($file)..." 
      ^cp -r $file ($to | path expand) 
    } 
}

#mv trough pipe to same dir
export def mv-pipe [
  to: string#target directory
  #
  #Example
  #ls *.txt | first 5 | mv-pipe ~/temp
] {
  get name 
  | ansi strip
  | each {|file|
      echo-g $"moving ($file)..." 
      ^mv $file ($to | path expand)
    }
}

#ls by date (newer last)
export def lt [
  --reverse(-r) #reverse order
] {
  if ($reverse | is-empty) or (not $reverse) {
    ls | sort-by modified  
  } else {
    ls | sort-by modified -r
  } 
}

#ls in text grid
export def lg [
  --date(-t)    #sort by date
  --reverse(-r) #reverse order
] {
  let t = if $date {"true"} else {"false"}
  let r = if $reverse {"true"} else {"false"}

  switch $t {
    "true": { 
      switch $r {
        "true": { 
          ls | sort-by -r modified | grid -c
        },
        "false": { 
          ls | sort-by modified | grid -c
        }
      }
    },
    "false": { 
      switch $r {
        "true": { 
          ls | sort-by -i -r type name | grid -c
        },
        "false": { 
          ls | sort-by -i type name | grid -c
        }
      }
    }
  }
}

#ls sorted by name
export def ln [--du(-d)] {
  if $du {
    ls --du | sort-by -i type name 
  } else {
    ls | sort-by -i type name 
  }
}

#ls only name
export def lo [] {
  ls 
  | sort-by -i type name 
  | reject type size modified 
}

#ls sorted by extension
export def le [] {
  ls
  | sort-by -i type name 
  | insert "ext" { 
      $in.name 
      | path parse 
      | get extension 
    } 
  | sort-by ext
}

#get list of files recursively
export def get-files [--full(-f),--dir(-d):string,--full_path(-F)] {
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


#find file in dir recursively
export def find-file [search,--directory(-d):string] {
  if ($directory | is-empty) {
    get-files -f | where name =~ $search
  } else {
    get-files -f -d $directory | where name =~ $search
  }
}

#get list of directories in current path
export def get-dirs [dir?, --full(-f)] {
  try {
    if ($dir | is-empty) {
      if $full {
        ls **/*
      } else {
        ls
      } 
      | where type == dir 
      | sort-by -i name
    } else {
      ls $dir
      | where type == dir 
      | sort-by -i name
    }
  } catch {
    {name: ""}
  }
}

#join multiple pdfs
export def join-pdfs [
  ...rest: #list of pdf files to concatenate
] {
  if ($rest | is-empty) {
    return-error "not enough pdfs provided"
  } else {
    pdftk $rest cat output output.pdf
    echo-g "pdf merged in output.pdf"
  }
}

#create media database for downloads and all mounted disks
export def autolister [user = $env.USER] {
  echo-g "listing Downloads..."
  cd ~/Downloads
  lister Downloads

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

#list all files ans save it to json in Dropbox/Directorios
export def lister [file] {
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

#create anime dirs according to files
export def mk-anime [] {
  try {
    get-files
  } catch {
    return-error "no files found"
    return
  }
  | get name 
  | each {|file| 
      $file 
      | parse "{fansub} {name} - {chapter}"
    } 
  | flatten 
  | get name 
  | uniq 
  | each {|dir| 
      if not ($dir | path expand | path exists) {
        mkdir $dir
      }

      get-files 
      | find -i $dir 
      | mv-pipe $dir
      | ignore
    }
}

#open google analytics csv file
export def open-analytics [$file?] {
  let file = if ($file | is-empty) {$in | get name} else {$file}

  open $file --raw 
  | lines 
  | find -v "#" 
  | drop nth 0 
  | str collect "\n" 
  | from csv 
}

#fix green dirs
export def fix-green-dirs [] {
  get-dirs | each {|dir| chmod o-w $dir.name}
}

#delete empty dirs recursively
export def rm-empty-dirs [] {
  ls --du **/* 
  | where type == dir 
  | where size <= 4.0Kib
  | rm-pipe
}

#here because they are needed in this file

#green echo
export def echo-g [string:string] {
  echo $"(ansi -e { fg: '#00ff00' attr: b })($string)(ansi reset)"
}

#red echo
export def echo-r [string:string] {
  echo $"(ansi -e { fg: '#ff0000' attr: b })($string)(ansi reset)"
}

#switch-case like instruction
export def switch [
  var                #input var to test
  cases: record      #record with all cases
  otherwise?: record #record code for otherwise
  #
  # Example:
  # let x = "3"
  # switch $x {
  #   1: { echo "you chose one" },
  #   2: { echo "you chose two" },
  #   3: { echo "you chose three" }
  # }
  #
  # let x = "4"
  # switch $x {
  #   1: { echo "you chose one" },
  #   2: { echo "you chose two" },
  #   3: { echo "you chose three" }
  # } { otherwise: { echo "otherwise" }}
  #
] {
  if ($cases | is-column $var) {
    $cases 
    | get $var 
    | do $in
  } else if not ($otherwise | is-empty) {
    $otherwise 
    | get "otherwise" 
    | do $in
  }
}

#verify if a column exist within a table
export def is-column [name] { 
  $name in ($in | columns) 
}
