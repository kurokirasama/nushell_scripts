#geeknote wrapper for accesing evernote
export def geek [] {}

#geeknote find
export def "geek find" [
  search:string  #search term in title
  ...rest:string #extra flags for geeknote
  #
  #Example
  #geek find ssh
  #geek find ssh "--tag linux"
] {
  let result = if ($rest | is-empty) {
      do -i {geeknote find --search $search} 
      | complete 
      | get stdout
    } else {
      let command = (build-string "geeknote find --search " $search " " ($rest | str collect ' '))
      do -i {nu -c $command} 
      | complete 
      | get stdout
    }

  $result
  | lines 
  | drop nth 1 
  | str replace ': 2' '¬ 2' 
  | each {|it| 
      $it | split row '¬' | last
    }
}

#geeknote show
export def "geek show" [
  item:int       #search term in title
  ...rest:string #extra flags for geeknote show (--raw)
  #
  #Example (after a geek find)
  #geek show 1
  #geek show 1 "--raw"
] {
  let result = if ($rest | is-empty) {
      do -i {geeknote show $item} 
      | complete 
      | get stdout
    } else {
      let command = (build-string "geeknote show " ($item | into string) " " ($rest | str collect ' '))
      do -i {nu -c $command} 
      | complete 
      | get stdout
    }

  $result 
  | nu-highlight 
  | lines 
}

#geeknote edit
export def "geek edit" [
  item:int       #search term in title
  ...rest:string #extra flags for geeknote show (--raw)
  #
  #Example (after a geek find)
  #geek edit 1
  #geek edit 1 "--tag new_tag"
] {
  if ($rest | is-empty) {
    geeknote edit $item
  } else {
    let command = (build-string "geeknote edit " ($item | into string) " " ($rest | str collect ' '))
    nu -c $command
  }
}

#geeknote create
export def "geek create" [
  commands:string #list of commands to create a note
  #
  #Example 
  #geek create "--title 'a note'"
  #geek create "--title 'a note' --tag linux --content 'the content'"
] {
  nu -c (build-string "geeknote create" " " $commands)
}