#string prepend
export def "str prepend" [toprepend:string] { 
  $toprepend + $in
}

#string append
export def "str append" [tail: string]: [string -> string, list<string> -> list<string>] {
  let input = $in
  match ($input | describe | str replace --regex '<.*' '') {
    "string" => { $input ++ $tail },
    "list" => { $input | each {|el| $el ++ $tail} },
    _ => {return-error "only string or list allowed!"}
  }
}

#string repeat 
#
#needs nushell std library
export def "str repeat" [count: int] { 
  repeat $count | str join ""
}

#remove accent
export def "str remove-accent" [text?:string] {
  let text = if ($text | is-empty) {$in} else {$text} 
  return ($text | sed 'y/áéíóúÁÉÍÓÚ/aeiouAEIOU/')
}

#convert hh:mm:ss to duration
export def "into duration-from-hhmmss" [hhmmss?:string] {
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
export def "into hhmmss" [dur?:duration] {
  let dur = if ($dur | is-empty) {$in} else {$dur}
  let seconds = (
    $dur
    | format duration sec
    | split row " "
    | get 0
    | into int
  )

  let h = $seconds / 3600 | into int | into string | fill -a r -c "0" -w 2
  let m = ($seconds / 60) mod 60 | into int | into string | fill -a r -c "0" -w 2
  let s = $seconds mod 60 | into int | into string | fill -a r -c "0" -w 2

  $h + ":" + $m + ":" + $s 
}

#extract first link from text
export def open-link [] {
  lines 
  | find http
  | first 
  | get 0
  | openf
}

#format date
#
#format date in the form Mmm ss, hh:mm
#Example: "Apr 24, 15:08"
export def "date my-format" [
  date?: string #date in form 
  --extra = ""  #some text to append to the date (default empty)
] {
  let date = if ($date | is-empty) {$in} else {$date}

  date now 
  | format date "%Y"
  | str append " " 
  | str append $date
  | str append "+00:00" 
  | into datetime 
  | format date "%Y.%m.%d_%H.%M"
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

#progress bar
#
#Example 1:
# def test [] {
#     let max = 200
#     mut progress_bar = progress_bar 0 $max
#     for i in 1..($max) {
#         $progress_bar = (progress_bar $i $max $progress_bar)
#         sleep 0.01sec
#     }
# }
#
#Example 2 :
# def test [] {
#     let max = 200
#     mut progress_bar = ""
#     for i in 0..($max) {
#         $progress_bar = (progress_bar $i $max $progress_bar)
#         sleep 0.01sec
#     }
# }
export def progress_bar [
    count:int 
    max:int 
    progress_bar?:string
    --symbol(-s):string = "█"
    --color(-c):string = "#FFFFFF"
    --background_symbol = "▒"
    --background_color(-B) = "#A0A0A0"
    --legacy(-l)
] {
  if $legacy {
    let max = if $max == 0 {1} else {$max}
    let term_length = (term size).columns
    let max_number_of_chars = $term_length / 2 | math ceil
    let bar_increment = (
      if $max >= $max_number_of_chars {
        $max / $max_number_of_chars | math ceil
      } else {
        $max_number_of_chars / $max | math floor
      }
    )

    let $offset = (
      match $term_length {
        83 => {
          if $max >= $max_number_of_chars {
            7
          } else {
            15
          }
        },
        159 => {
          if $max >= $max_number_of_chars {
            -4
          } else {
            5
          }
        },
        79 => {
          if $max >= $max_number_of_chars {
            9
          } else {
            17
          }
        },
        _ => {0}
      }
    )

    mut progress_bar = if ($progress_bar | is-empty) {$symbol} else {$progress_bar}

    print -n (
        [
            (ansi -e { fg: $background_color })
            "\r"
            ($background_symbol | fill -c $background_symbol -w ($max_number_of_chars + $offset) -a r)
            "\r"
            (ansi -e { fg: $color })
            $"(($count / $max * 100) | into string -d 2 | fill -c 0 -a r -w 6)% " 
            ($progress_bar)
            (ansi reset)
        ] 
        | str join
    )

    if $max >= $max_number_of_chars {
      if $count mod $bar_increment == 0 { 
          $progress_bar = $progress_bar + $symbol
      }
    } else {
      $progress_bar = $progress_bar + ($symbol | str repeat $bar_increment)
    }
    
    if $count == $max {
      print ("\n")
    }
    
    return $progress_bar
  }

  ## using bar
  print -n (char cr) (
    bar {
      $"(($count / $max * 100) | into string -d 2 | fill -c 0 -a r -w 5)% ": {
        fraction: ($count / $max),
        color: {fg: "#000000", bg: "#FFFFFF"}
      }
    }
  )
}

# Print a multi-sectional bar
#
# Examples:
# `$ ui bar {foo: 0.5, bar: 0.5}`
# `$ ui bar {foo: {fraction: 0.4, color: lur}, bar: {fraction: 0.6, color: cr}}`
# `$ ui bar --width 10 {foo: 0.5, bar: 0.5}`
# `$ ui bar --normalize {foo: 0.1, bar: 0.1}`
# `$ ui bar {progress%: 0.4}`
export def bar [
  sections: record # A record containing bar components
  --width: int # Width to display the bar (default: terminal width)
  --normalize # Adjust bar to fit width exactly
] {
  let term_width = (term size).columns
  let width = ([($width | default $term_width) $term_width] | math min | into float)

  let normalize = if $normalize {
    1.0 / (
      $sections
      | values 
      | each {|entry|
        match ($entry | describe --detailed).type {
          "float" => $entry
          "record" => $entry.fraction
        }
      }
      | math sum
    )
  } else {
    1.0
  }

  # order that default colors are selected in - adjust to liking
  const COLORS = [
    wr lgr lrr lur lyr pr yr lcr mr lpr lmr cr wr dgrr
  ]
  
  let bar_sections = (
    $sections
    | transpose
    | rename title data
    | enumerate
    | each {|entry|
      let index = $entry.index
      let data = $entry.item.data
        let default_color = ($COLORS | get $index)
        let data = match ($entry.item.data | describe --detailed).type {
        "float" | "int" => {
          fraction: $entry.item.data
          color: $default_color
        }
        "record" => ($entry.item.data | default $default_color color)
      }
      
      let percent_width = $data.fraction * $width * $normalize
      let color = match ($data.color | describe --detailed).type {
        "string" => {ansi $data.color},
        "record" => {ansi --escape $data.color}
      }

      let title = ($entry.item.title | str substring 0..($percent_width | math ceil))
      let title_width = ($title | str length)
      let half_width = ([(($percent_width - $title_width) / 2) 0] | math max)

      let lhs = (" " | repeat ($half_width | math floor) | str join)
      let rhs = (" " | repeat ($half_width | math ceil) | str join)

      $color + $title + $lhs + $rhs
    }
    | str join
  )

  $bar_sections + (ansi reset)
}