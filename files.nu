######################################################
# here because they are needed in this file
######################################################

#generate error output
export def return-error [msg] {
  error make -u {msg: $"(echo-r $msg)"}
}

#green echo
export def echo-g [text:string] {
  echo $"(ansi -e { fg: '#00ff00' attr: b })($text)(ansi reset)"
}

#red echo
export def echo-r [text:string] {
  echo $"(ansi -e { fg: '#ff0000' attr: b })($text)(ansi reset)"
}

#custom color echo
export def echo-c [
    text:string #text to print
    color:string  #color of text
    --bold(-b)    #print in bold
] {
  if $bold {
    echo $"(ansi -e { fg: ($color) attr: b })($text)(ansi reset)"
  } else {
    echo $"(ansi -e { fg: ($color)})($text)(ansi reset)"
  }
}

#verify if a column exist within a table
export def is-column [name] { 
  $name in ($in | columns) 
}

######################################################
######################################################

#wrapper for describe
export def typeof [
    --full(-f)
    --list-of-tables(-l) #for list of records that should have been a table
] {
  let inp = $in
  mut type = $inp | describe

  if not $full {
    $type = $inp | describe | split row '<' | get 0
  }

  if $list_of_tables {
    if $type == "list" {
        # Check if the list has column names, indicating it's effectively a table
        if ($inp | first | typeof) == "record" {
        return "table"
        }
    }
  }
  
  return $type
}

#open text file
export def op [
  file?         # filename
  --raw(-r)     # open in raw mode if using defaul open
  --open(-o)    # use default open
  --sublime(-s) # use sublime text
  --zed(-z)     # use zed text editor
] {
  let file = get-input $in $file -n
  let extension = $file | path parse | get extension

  if $open {
    open $file
  } else if $raw {
    open --raw $file
  } else if $sublime {
    subl $file
  } else if $zed {
    zed $file
  } else {
    match $extension {
      "md"|"Rmd" => {glow $file},
      "nu" => {open --raw $file | nu-highlight | bat --paging auto},
      "R"|"c"|"m"|"py"|"sh" => {bat --paging auto $file},
      "csv"|"json"|"sqlite"|"xls"|"xlsx"|"tsv|toml" => {open $file},
      "doc"|"docx"|"pdf"|"png"|"jpg" => {openf $file},
      _ => {bat --paging auto $file}
    }
  }
}

#open file 
export def openf [file?] {
  let file = get-input $in $file

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
   
  job spawn {xdg-open $file} | ignore
}

#open last file
export def openl [] {
  lt | last | openf
}

#accumulate a list of files into the same table
#
#Example
#ls *.json | openm
#let list = ls *.json; openm $list
export def openm [
  list? #list of files
] {
  let list = get-input $in $list
  
  $list 
  | get name
  | reduce -f [] {|it, acc| 
      $acc | append (open ($it | path expand))
    }
}

#send to printer
export def print-file [file?,--n_copies(-n):int] {
  let file = get-input $in $file -n | ansi strip
    
  match ($file | typeof) {
    "string" => {
            if ($n_copies | is-empty) {
              lp $file
            } else {
              lp -n $n_copies $file
            }
      },
    "list" => {
            $file
            | each {|name| 
                print-file $name
              }
      },
    _ => {return-error $"($file | typeof) not allowed!"}
  }
}

#compress all folders into a separate file and delete them
export def "7z folders" [
  --not_delete(-n)
] {
  if $not_delete {
    bash -c "find . -maxdepth 1 -mindepth 1 -type d -print0 | parallel -0 --eta 7z a -t7z -bso0 -bsp0 -m0=lzma2 -mx=9 -ms=on -mmt=on {}.7z {}"
    return
  }

  bash -c "find . -maxdepth 1 -mindepth 1 -type d -print0 | parallel -0 --eta 7z a -t7z -sdel -bso0 -bsp0 -m0=lzma2 -mx=9 -ms=on -mmt=on {}.7z {}"
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
export def --wrapped "7z max" [
  filename: string  #existing or not existing 7z filename
  ...rest           #files to compress and extra flags for 7z
  --delete(-d)      #delete files after compression
] {
  if ($rest | is-empty) {
    return-error "no files to compress!!"
  }

  if $delete {
    7z a -t7z -sdel -m0=lzma2 -mx=9 -ms=on -mmt=on $"($filename | path parse | get stem).7z" ...$rest
    return
  }
  
  7z a -t7z -m0=lzma2 -mx=9 -ms=on -mmt=on $"($filename | path parse | get stem).7z" ...$rest
}

#rm trough pipe
#
#Example
#ls *.txt | first 5 | rm-pipe
export def rm-pipe [] {
  let files = $in 
  
  if ($files | is-empty) {return "no files provided!"}

  let files = if ($files | typeof) == "record" {
    $files | transpose | transpose -r
  } else {
    $files
  } | get name | ansi strip

  let number = ($files | length) - 1

  for i in 0..$number {
    progress_bar ($i + 1) ($number + 1)     
    rm -rf ($files | get $i) | ignore
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
  let files = $in
  let files = if ($files | typeof) == "record" {
    $files | transpose | transpose -r
  } else {
    $files
  } | get name | ansi strip

  let number = ($files | length) - 1

  for i in 0..$number {    
    progress_bar ($i + 1) ($number + 1)

    if $force {
      cp -fr ($files | get $i) ($to | path expand)
      continue
    }

    cp -ur ($files | get $i) ($to | path expand)
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
  let files = $in 
  let files = if ($files | typeof) == "record" {
    $files | transpose | transpose -r
  } else {
    $files
  } | get name | ansi strip

  let number = ($files | length) - 1

  for i in 0..$number {
    progress_bar ($i + 1) ($number + 1)

    if $force {
      mv -f ($files | get $i) ($to | path expand)
      continue
    } 
    
    mv -u ($files | get $i) ($to | path expand)    
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
          ls | sort-by -r modified | grid -ci
        },
        false => {
          ls | sort-by modified | grid -ci
        }
      }
    },
    false => {
      match $reverse {
        true => {
          ls | sort-by -i -r type name | grid -ci
        },
        false => {
          ls | sort-by -i type name | grid -ci
        }
      }
    }
  }
}

#ls sorted by name
export def ln [--du(-d),--sort_by_size(-s)] {
  if $du {
    if $sort_by_size {
      ls --du | sort-by -i type name | sort-by size
    } else {
      ls --du | sort-by -i type name
    }
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

#find file in dir recursively
export def find-file [search,--directory(-d):string] {
  if ($directory | is-empty) {
    get-files -f | find -n $search
  } else {
    get-files $directory -f | find -n $search
  }
}

#get list of directories in current path
export def get-dirs [dir?, --full(-f),--all(-a)] {
  try {
    if $all {
      if ($dir | is-empty) {
        if $full {
          ls -a **/*
        } else {
          ls -a 
        } 
        | where type == dir 
        | sort-by -i name
      } else {
        ls -a $dir
        | where type == dir 
        | sort-by -i name
      }
    } else {
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
    }
  } catch {
    {name: ""}
  }
}

#join multiple pdfs
export def "pdf join" [
  ...rest: #list of pdf files to concatenate
] {
  let rest = if ($rest | is-empty) {$in | get name} else {$rest}
  if ($rest | is-empty) {
    return-error "no pdf provided!"
  }
  
  pdftk ...$rest cat output output.pdf
  print (echo-g "pdf merged in output.pdf")
}

#split a pdf by page
export def "pdf split" [
  file?: #pdf file name
] {
  let file = get-input $in $file -n
  if ($file | is-empty) {
    return-error "no pdf provided!"
  }
  
  pdftk $file burst
}

#create media database for downloads and all mounted disks
export def autolister [user?] {
  let user = get-input $env.USER $user
  let host = $env.HOST

  print (echo-g "listing Downloads...")
  cd ~/Downloads
  lister ("Downloads" + "_" + $host)

  let drives = sys disks | where mount like $"/media/($user)" 

  if ($drives | length) > 0 {
    $drives
    | get mount
    | each { |drive|
        print (echo-g $"listing ($drive)...")
        cd $drive
        lister ($drive | path parse | get stem | split row " " | str join _)
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

#create anime dirs according to files
export def mk-anime [--wzf] {
  if $wzf {
    try {
      get-files
    } catch {
      return-error "no files found"
    }
    | get name 
    | parse "[{fansub}]{name}_Capitulo{rest}"
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
  | parse "{fansub} {name} - {chapter}"
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

#create manga dirs according to files
export def mk-manga [] {
  try {
    get-files
  } catch {
    return-error "no files found"
  }
  | get name 
  | path parse
  | get stem
  | parse --regex '(?P<chars>.*) (?P<num>\d+)(?P<suffix>.*)$'
  | get chars 
  | uniq 
  | parse --regex '^(?P<chars>.*?)(?: (?P<num>\d+))?$' 
  | get chars 
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
  let file = get-input $in $file -n

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
  let files = get-files | where name like $"^($prefix)" | sort-by modified
  let n_files = $files | length
  let n_digits = ($n_files | math log 10) + 1 | math floor | into int

  mut index = 0
  mut not_move = []
  mut new_name = ""

  for i in 0..($n_files - 1) {
    let name = ($files | get $i | get name)
    let info = ($name | path parse)
    
    $new_name = [$prefix "_" ($index | into string | fill -a r -c "0" -w $n_digits) "." ($info | get extension)] | str join

    if not ($name in $not_move) {
      while ($new_name | path expand | path exists) {
        $not_move = $not_move | append $new_name
        $index = $index + 1
        $new_name = [$prefix "_" ($index | into string | fill -a r -c "0" -w $n_digits) "." ($info | get extension)] | str join
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
  open ("*." + $extension | into glob) | save -f ($output + "." + $extension)
}

#manually rename files in a directory
export def rename-all [] {
    let files = ls -s | where type == file | get name
    let temp_file = mktemp -t --suffix .txt
    $files | to text | save -f $temp_file

    ^$env.VISUAL $temp_file

    let new_files = open $temp_file | str trim | lines
    rm --permanent $temp_file

    if $new_files != $files and ($new_files | length) == ($files | length) {
        let file_table = $files | wrap old_name | merge ($new_files | wrap new_name) | where {$in.old_name != $in.new_name}
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
  let pdf_output = get-input ($svg_file | path parse | get stem) $pdf_output 
  rsvg-convert -f pdf -o $pdf_output $svg_file
}

#rename file via pattern replace
export def rename-file [
  old_pattern:string #pattern to replace 
  new_pattern:string #new pattern
  files_pattern:string #pattern for listing target files or dirs
  --regex(-r) #use regular expression for patter substitution
] {
  let files = ls ($files_pattern | into glob)
  let total = $files | length

  $files
  | get name
  | enumerate 
  | each {|file|      
      let new_name = if $regex {
          $file.item | str replace -r $old_pattern $new_pattern
        } else {
          $file.item | str replace $old_pattern $new_pattern
        }
        
      mv $file.item $new_name

      progress_bar ($file.index + 1) $total
  }
}

# Renames subtitles files according to tv shows names found in a directory
# Accepted syntaxes for season/episode are: 304, s3e04, s03e04, 3x04 (case insensitive)
export def subtitle-renamer [] {
    # Get all subtitle files in current directory
    let subtitle_files = [
        (glob *.srt)
        (glob *.ssa)
        (glob *.sub)
    ] | flatten | where { |f| $f | path exists }

    # Get all movie files in current directory
    let movie_files = [
        (glob *.avi)
        (glob *.mp4)
        (glob *.mkv)
    ] | flatten | where { |f| $f | path exists }

    # Process each subtitle file
    for subtitle in $subtitle_files {
        let subtitle_name = $subtitle | path basename
        
        # Try to match season and episode patterns (case insensitive)
        let season_episode = match $subtitle_name {
            # s01e02 pattern
            $s if ($s | str downcase | find -r "s([0-9]+)e([0-9]+)" | is-not-empty) => {
                $subtitle_name 
                | str downcase 
                | parse --regex '^(?P<title>.+?)\s+s(?P<season>[0-9]+)e(?P<episode>[0-9]+)\.\w+$'
                | update season { into int } 
                | get 0 
                | reject title
            },
            # 1x02 pattern
            $s if ($s | str downcase | find -r "([0-9]+)x([0-9]+)" | is-not-empty) => {
                $subtitle_name 
                | str downcase 
                | parse --regex '^(?P<title>.*?) (?P<season>\d+)x(?P<episode>\d+)\.\w+$' 
                | update season { into int } 
                | get 0 
                | reject title
            },
            # 102 pattern (1=season, 02=episode)
            $s if ($s | str downcase | find -r "([0-9]+)([0-9][0-9])" | is-not-empty) => {
                $subtitle_name 
                | str downcase 
                | parse --regex '^(?P<title>.+?)\s+(?P<season>\d+)(?P<episode>\d{2})\.\w+$'
                | update season { into int } 
                | get 0 
                | reject title
            },
            _ => null
        }
        
        if $season_episode != null {
            print (echo-g $"Found '($subtitle_name)'")
            let season = $season_episode.season
            let episode = $season_episode.episode
            
            # Look for matching movie file
            for movie in $movie_files {
                let movie_name = $movie | path basename
                let movie_base = $movie | path basename | path parse | get stem
                let subtitle_ext = $subtitle | path parse | get extension
                
                # Check if movie name contains the season/episode pattern (case insensitive)
                let is_match = (
                    ($movie_name | str downcase | find -r $"($season)($episode)" | is-not-empty ) or
                    ($movie_name | str downcase | find -r $"s0?($season)e($episode)" | is-not-empty ) or
                    ($movie_name | str downcase | find -r $"($season)x($episode)" | is-not-empty )
                )
                
                if $is_match {
                    let new_name = $"($movie_base).($subtitle_ext)"
                    
                    if $subtitle_name == $new_name {
                        print (echo-c "Already ok" "green")
                    } else if ($new_name | path exists) {
                        print (echo-c $"A file named '($new_name)' already exists, skipping" "green")
                    } else {
                        mv $subtitle $new_name
                        print (echo-c $"Renamed '($subtitle_name)' to '($new_name)'" "green")
                    }
                    break
                }
            }
        }
    }
}

# Download file with nu
export def nuwget [
    url: string
    --directory (-d): path # Base dir
    --output (-o): path    # File name
    --force (-f)           # Overwrite file
    --silent (-s)          # Don't print anything
] {
    if ($directory | is-not-empty) { cd $directory }
    let $file_name = $output | default { $url | url parse | get path | split row '/' | url decode | last }

    if not $force and ($file_name | path exists) { error make -u {msg: "File already exists"} }

    let $time = timeit { http get $url | save --progress --force=$force $file_name }

    if not $silent {
        print "Download results:"
        {
            url: $url
            file: ($file_name | path basename)
            cwd: ($file_name | path expand | path dirname)
            time: $time
            speed: $"((ls $file_name | get 0.size) / ($time | into int | $in / 10 ** 9))/s"
        }
        | print
    }
}
