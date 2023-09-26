#string prepend
export def "str prepend" [toprepend] { 
  build-string $toprepend $in
}

#string append
export def "str append" [toappend] { 
  build-string $in $toappend
}

#build-string (temporary, replace all build-string instances by "+" syntax)
export def build-string [...rest] {
  $rest | str join ""
}

#string repeat
export def "str repeat" [count: int] { 
  each {|it| 
    let str = $it; echo 1..$count 
    | each {||
        echo $str 
      } 
  } 
}

#remove accent
export def "str remove-accent" [text?:string] {
  let text = if ($text | is-empty) {$in} else {$text} 
  return ($text | sed 'y/áéíóúÁÉÍÓÚ/aeiouAEIOU/')
}

#convert hh:mm:ss to duration
export def "into duration-from-hhmmss" [hhmmss?] {
  if ($hhmmss | is-empty) {
    $in
  } else {
    $hhmmss   
  }
  | split row :
  | enumerate
  | each {|row| 
      ($row.item | into int) * (60 ** (2 - $row.index))
    } 
  | math sum
  | into string 
  | str append sec
  | into duration
}

#convert duration to hh:mm:ss
export def "into hhmmss" [dur:duration] {
  let seconds = (
    $dur
    | into duration --unit sec
    | into string 
    | split row " "
    | get 0
    | into int
  )

  let h = (($seconds / 3600) | into int | into string | fill -a r -c "0" -w 2)
  let m = (($seconds / 60 ) | into int | into string | fill -a r -c "0" -w 2)
  let s = ($seconds mod 60 | into string | fill -a r -c "0" -w 2)

  $"($h):($m):($s)"
}

#extract first link from text
export def open-link [] {
  lines 
  | find http
  | first 
  | get 0
  | openf
}

#date formatting
export def "date my-format" [
  date?: string #date in form 
  --extra = ""  #some text to append to the date (default empty)
  #
  #format date in the form Mmm ss, hh:mm
  #Example: "Apr 24, 15:08"
] {
  let date = if ($date | is-empty) {$in} else {$date}

  date now 
  | date format "%Y"
  | str append " " 
  | str append $date
  | str append "+00:00" 
  | into datetime 
  | date format "%Y.%m.%d_%H.%M"
  | str append $extra
}

#date renaming
export def rename-date [file,--extra = ""] {
  let extension = ($file | path parse | get extension)
  let new_name = (
    $file 
    | path parse
    | get stem 
    | date my-format --extra $extra
    | str append $".($extension)"
  )
}