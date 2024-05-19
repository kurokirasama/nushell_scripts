######################################################
# here because they are needed in this file
######################################################

#green echo
export def echo-g [string:string] {
  echo $"(ansi -e { fg: '#00ff00' attr: b })($string)(ansi reset)"
}

#red echo
export def echo-r [string:string] {
  echo $"(ansi -e { fg: '#ff0000' attr: b })($string)(ansi reset)"
}

#custom color echo
export def echo-c [string:string,color:string,--bold(-b)] {
  if $bold {
    echo $"(ansi -e { fg: ($color) attr: b })($string)(ansi reset)"
  } else {
    echo $"(ansi -e { fg: ($color)})($string)(ansi reset)"
  }
}

#verify if a column exist within a table
export def is-column [name] { 
  $name in ($in | columns) 
}

######################################################
######################################################

#wrapper for describe
export def typeof [--full(-f)] {
  describe 
  | if not $full { 
      split row '<' | get 0 
    } else { 
      $in 
    }
}

#open code
export def op [file?,--raw] {
  let file = if ($file | is-empty) {$in | get name} else {$file}
  let extension = ($file | path parse | get extension)

  if $extension =~ "md|Rmd" {
    glow $file
  } else if $extension =~ "nu" {
    open --raw $file | nu-highlight | bat
  } else if ($extension =~ "R|c|m|py|sh") or ($extension | is-empty) {
    bat $file
  } else {
    if $raw {
      open --raw $file
    } else {
      open $file
    }
  }
}

#open file 
export def openf [file?] {
  let file = if ($file | is-empty) {$in} else {$file}

  let file = (
    match ($file | typeof) {
      "record" => {
        $file
        | get name
        | ansi strip
      },
      "table" => {
        $file
        | get name
        | get 0
        | ansi strip
      },
      _ => {$file}
    }
  )
   
  bash -c $'xdg-open "($file)" 2>/dev/null &'
}

#open last file
export def openl [] {
  lt | last | openf
}

#open google drive file 
export def openg [file?,--copy(-c)] {
  let file = if ($file | is-empty) {$in | get name} else {$file}
   
  let url = (open $file 
    | lines 
    | drop nth 0 
    | parse "{field}={value}" 
    | table2record 
    | get url
  )

  if $copy {$url | xclip -sel clip}
  print (echo-g $"($url)")
}

#accumulate a list of files into the same table
#
#Example
#ls *.json | openm
#let list = ls *.json; openm $list
export def openm [
  list? #list of files
] {
  let list = if ($list | is-empty) {$in} else {$list}
  
  $list 
  | get name
  | reduce -f [] {|it, acc| 
      $acc | append (open ($it | path expand))
    }
}

#send to printer
export def print-file [file?,--n_copies(-n):int] {
  let file = if ($file | is-empty) {$in | get name | ansi strip} else {$file}
  
  if ($file | length) == 1 {
    if ($n_copies | is-empty) {
      lp $file
    } else {
      lp -n $n_copies $file
    }
  } else {
    $file
    | each {|name| 
        print-file $name
      }
  }
}

#compress all folders into a separate file and delete them
export def "7z folders" [--not_delete(-n)] {
  if not $not_delete {
    bash -c "find . -maxdepth 1 -mindepth 1 -type d -print0 | parallel -0 --eta 7z a -t7z -sdel -bso0 -bsp0 -m0=lzma2 -mx=9 -ms=on -mmt=on {}.7z {}"
    return
  }

  bash -c "find . -maxdepth 1 -mindepth 1 -type d -print0 | parallel -0 --eta 7z a -t7z -bso0 -bsp0 -m0=lzma2 -mx=9 -ms=on -mmt=on {}.7z {}"
}

#compress to 7z using max compression
#
# Example:
# compress all files in current directory and delete them
# 7z max filename * -d
# compress all files in current directory and split into pieces of 3Gb (b|k|m|g)
# 7z max filename * "-v3g"
# both
# 7z max filename * "-v3g -sdel"
export def "7z max" [
  filename: string  #existing or not existing 7z filename
  ...rest:  string  #files to compress and extra flags for 7z (add flags between quotes)
  --delete(-d)      #delete files after compression
] {
  if ($rest | is-empty) {
    return-error "no files to compress specified"
  }
  if ($delete | is-empty) or (not $delete) {
    7z a -t7z -m0=lzma2 -mx=9 -ms=on -mmt=on $"($filename | path parse | get stem).7z" ...$rest
    return
  }
  7z a -t7z -sdel -m0=lzma2 -mx=9 -ms=on -mmt=on $"($filename | path parse | get stem).7z" ...$rest
}

#rm trough pipe
#
#Example
#ls *.txt | first 5 | rm-pipe
export def rm-pipe [] {
  let files = $in | get name | ansi-strip-table
  
  if ($files | is-empty) {return}

  let number = ($files | length) - 1
  for i in 0..$number {     
    ^rm -rf ($files | get $i) | ignore

    progress_bar ($i + 1) ($number + 1)
  }
}

#cp trough pipe to same dir
#
#Example
#ls *.txt | first 5 | cp-pipe ~/temp
export def cp-pipe [
  to: string  #target directory
  --force(-f) #force copy
] {
  let files = $in | get name | ansi-strip-table
  let number = ($files | length) - 1

  for i in 0..$number {    
    let file = $files | get $i 
    
    if $force {
      ^cp -fr $file ($to | path expand)
    } else {
      ^cp -ur $file ($to | path expand)
    }

    progress_bar ($i + 1) ($number + 1)
  } 
}

#mv trough pipe to same dir
#
#Example
#ls *.txt | first 5 | mv-pipe ~/temp
export def mv-pipe [
  to: string  #target directory
  --force(-f) #force rewrite of file
] {
  let files = $in | get name | ansi-strip-table
  let number = ($files | length) - 1

  for i in 0..$number {
    let file = $files | get $i 

    if $force {
      ^mv -f $file ($to | path expand)
    } else {
      ^mv -u $file ($to | path expand)
    }

    progress_bar ($i + 1) ($number + 1)
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
  match $date {
    true => {
      match $reverse {
        true => {
          ls | sort-by -r modified | grid -c
        },
        false => {
          ls | sort-by modified | grid -c
        }
      }
    },
    false => {
      match $reverse {
        true => {
          ls | sort-by -i -r type name | grid -c
        },
        false => {
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
  | insert "ext" {|in|
      $in.name 
      | path parse 
      | get extension 
    } 
  | sort-by ext
}

#get list of files recursively
export def get-files [
  --full(-f)      #recursive
  --dir(-d):string
  --full_path(-F)
  --sort_by_date(-t)
] {

  let files = (
    if $full {
      if not ($dir | is-empty) {
        if $full_path {
          ls -f ($"($dir)/**/*" | into glob)
          } else {
            ls ($"($dir)/**/*" | into glob)
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
  ) 

  $files 
  | where type == file 
  | if $sort_by_date {
    sort-by -i modified
    } else {
      sort-by -i name
    }
}

#find file in dir recursively
export def find-file [search,--directory(-d):string] {
  if ($directory | is-empty) {
    get-files -f | find =~ $search
  } else {
    get-files -f -d $directory | find =~ $search
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
  }
  
  pdftk ...$rest cat output output.pdf
  print (echo-g "pdf merged in output.pdf")
}

#create media database for downloads and all mounted disks
export def autolister [user?] {
  let user = if ($user | is-empty) {$env.USER} else {$user}
  let host = (sys host | get hostname)

  print (echo-g "listing Downloads...")
  cd ~/Downloads
  lister ("Downloads" + "_" + $host)

  let drives = (try {
    duf -json 
    | from json 
    | find $"/media/($user)" 
    | get mount_point
    | ansi strip
  } catch {
    []
  })

  if ($drives | length) > 0 {
    $drives
    | each { |drive|
        print (echo-g $"listing ($drive)...")
        cd $drive
        lister ($drive | path parse | get stem | split row " " | get 0)
      }
  }
}

#list all files and save it to json in Dropbox/Directorios
export def lister [file] {
  let file = (["~/Dropbox/Directorios" $"($file).json"] | path join | path expand)

  let df = (try {
      get-files -f -F 
    } catch {
      []
    }
  )

  if ($df | length) == 0 {
    if $file =~ "Downloads" and ($file | path expand | path exists) { 
      rm $file
    }
    return
  }

  let last = ($df | dfr into-df | dfr drop name) 

  let df = (
    $df
    | each {|file| 
      $file
      | get name 
      | parse $"{origin}/($env.USER)/{location}/{rest}"
      }
    | flatten
  ) 

  let first = ($df | select origin location | dfr into-df) 

  let second = (
    $df 
    | select rest 
    | each {|file| 
      $file 
      | get rest 
      | path parse -e ''
      } 
    | dfr into-df 
    | dfr drop extension 
    | dfr rename [parent stem] [path file]
  )

  $first | dfr append $second | dfr append $last | dfr into-nu | save -f $file
}

#create anime dirs according to files
export def mk-anime [--wzf] {
  if $wzf {
    try {
      get-files
    } catch {
      return-error "no files found"
    }
    | get name 
    | each {|file| 
        $file 
        | parse "[{fansub}]{name}_Capitulo{rest}"
      } 
    | flatten 
    | get name 
    | uniq 
    | each {|dir| 
        if not ($dir | ansi strip | path expand | path exists) {
          mkdir $dir
        }

        get-files 
        | find -i $dir 
        | mv-pipe $dir
        | ignore
      }

    return  
  }

  try {
    get-files
  } catch {
    return-error "no files found"
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
export def open-analytics [file?] {
  let file = if ($file | is-empty) {$in | get name} else {$file}

  open $file --raw 
  | lines 
  | find -v "#" 
  | drop nth 0 
  | str join "\n" 
  | from csv 
}

#delete empty google analytics csv files
export def clean-analytics [file?] {
  ls | find Analytics | where size <= 151B | rm-pipe 
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

#replicate directory structure to a new location
export def replicate-tree [to:string] {
  get-dirs -f
  | each {|dir|
      let new_dir = ($dir | get name | str prepend $"($to | path expand)/")
      if not ($new_dir | path exists) {
        print (echo-g $"creating ($new_dir)...")
        mkdir $new_dir | ignore
      }
  }
}

#rename all files starting with certain prefix, enumerating them
export def re-enamerate [prefix] {
  let files = (get-files | where name =~ $"^($prefix)" | sort-by modified)
  let n_files = ($files | length)
  let n_digits = (($n_files | math log 10) + 1 | math floor | into int)

  mut index = 0
  mut not_move = []
  mut new_name = ""

  for i in 0..($n_files - 1) {
    let name = ($files | get $i | get name)
    let info = ($name | path parse)
    
    $new_name = ([$prefix "_" ($index | into string | fill -a r -c "0" -w $n_digits) "." ($info | get extension)] | str join)

    if not ($name in $not_move) {
      while ($new_name | path expand | path exists) {
        $not_move = ($not_move | append $new_name)
        $index = $index + 1
        $new_name = ([$prefix "_" ($index | into string | fill -a r -c "0" -w $n_digits) "." ($info | get extension)] | str join)
      }

      mv $name $new_name | ignore
    }
  }
}

#concatenate all files in current directory
#
#asummes all are text files
export def join-text-files [
  extension:string #extension of files to concatenate
  output:string    #output filename (without extension)
] {
  open ("*." + $extension) | save -f ($output + "." + $extension)
}

#manually rename files in a directory
export def rename-all [] {
    let files = (ls -s | where type == file | get name)
    let temp_file = mktemp -t --suffix .txt
    $files | to text | save -f $temp_file

    ^$env.VISUAL $temp_file

    let new_files = (open $temp_file | str trim | lines)
    rm --permanent $temp_file

    if $new_files != $files and ($new_files | length) == ($files | length) {
        let file_table = ($files | wrap old_name | merge ($new_files | wrap new_name) | where {$in.old_name != $in.new_name})
        $file_table | each { mv $in.old_name $in.new_name }
        $file_table
    } else {
        echo-g "No files renamed"
    }
}

#convert svg image into a pdf file
export def svg2pdf [
  svg_file    #include extension  
  pdf_output? #include extension
] {
  let pdf_output = if ($pdf_output | is-empty) {($svg_file | path parse | get stem) + ".pdf"} else {$pdf_output}
  rsvg-convert -f pdf -o $pdf_output $svg_file
}