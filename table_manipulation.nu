#range to list
export def range2list [] {
  collect {$in}
}

#ansi strip table
export def "ansi-strip-table" [] {
  update cells {|cell|
    if ($cell | describe) == string { 
      $cell | ansi strip
    } else {
      $cell
    }
  }
}

#add a hidden column with the content of the # column
export def indexify [
  column_name?: string = 'index' #export default: index
  ] { 
  enumerate 
  | upsert $column_name {|el| 
      $el.index
    } 
  | flatten
}

#returns a filtered table that has distinct values in the specified column
export def uniq-by [
  column: string  #the column to scan for duplicate values
] {
  reduce { |item, acc|
    if ($acc | any { |storedItem|
      ($storedItem | get $column) == ($item | get $column)
    }) {
      $acc
    } else {
      $acc | append $item
    }
  }
}

#get total sizes of ls output
export def sum-size [] {
  get size | math sum
}

#table to record
export def table2record [] {
  transpose -r -d 
}

#calculates elements that are in list a but not in list b
export def setdiff [a,b] {
  $a 
  | each {|n| 
    if $n not-in $b {$n} 
  }
}

#find index of a search term
export def "find-index" [name: string,default? = -1] {
  $in
  | indexify
  | find $name
  | try {
      get index
    } catch {
      $default 
    }
}

#select column of a table (to table)
export def column [n] { 
  transpose 
  | select $n 
  | transpose 
  | select column1 
  | headers
}

#get column of a table (to list)
export def column2 [n] { 
  transpose 
  | get $n 
  | transpose 
  | get column1 
  | skip 1
}

#join 2 lists
export def union [a: list, b: list] {
  $a 
  | append $b 
  | uniq
}

#intersection between two lists
export def intersect [a:list, b:list] {
  let a = $a | uniq | sort 
  let b = $b | uniq | sort
  let n_a = $a | length 
  let n_b = $b | length 
  mut i = 0
  mut j = 0
  mut c = []

  while ($i < $n_a and $j < $n_b) {
    if ($a | get $i) < ($b | get $j) {
      $i = $i + 1
    } else if ($b | get $j) < ($a | get $i) {
      $j = $j + 1
    } else {
      $c = $c ++ ($b | get $j)
      $i = $i + 1
      $j = $j + 1
    }
  }
  return $c
}

#select rows in a table from list of ints
export def get-rows [rows:list] {
  $in
  | enumerate
  | where $it.index in $rows
  | get item 
}

# interactively select columns from a table
export def iselect [] {
    let tgt = $in
    let cols = ($tgt | columns)

    let choices = ($cols | input list -m "Pick columns to get: ")
    $tgt | select $choices
}

#default a whole table
export def default-table [value: any = null] {
    mut input = $in
    let cols = $input | columns

    for $col in $cols {
        $input = ($input | default $value $col)
    }

    $input
}

# table diff
export def table-diff [
  $left: list<any>,
  $right: list<any>,
  --keys (-k): list<string> = [],
] {
  let left = if ($left | describe) !~ '^table' { $left | wrap value } else { $left }
  let right = if ($right | describe) !~ '^table' { $right | wrap value } else { $right }
  let left_selected = ($left | select ...$keys)
  let right_selected = ($right | select ...$keys)
  let left_not_in_right = (
    $left |
    filter { |row| not (($row | select ...$keys) in $right_selected) }
  )
  let right_not_in_left = (
    $right |
    filter { |row| not (($row | select ...$keys) in $left_selected) }
  )
  (
    $left_not_in_right | insert side '<='
  ) ++ (
    $right_not_in_left | insert side '=>'
  )
}

# filter by multiple where conditions simultaneous
# Example:
#
# ls | multiwhere { name: .txt, type: file }
export def multiwhere [maps: record]: table -> table {
    let inp = $in

    if ($inp | is-empty) {
        return $inp
    }

    $maps
    | items {|key, val| { col: $key, val: $val } }
    | reduce --fold $inp {|map, acc|
        $acc | filter {|x| ($x | get $map.col) =~ $map.val}
    }
}

# sum lists of numbers
# Example:
# let a = [1 2 3]
#
# list-sum $a $a
# list-sum $a $a $a
export def list-sum [
  ...rest # list of lists of numbers
] {
  let n = ($rest | length) - 1
  mut sum = $rest.0 | zip $rest.1 | each {$in.0 + $in.1} 
  
  if $n < 2 {return $sum}

  for i in 2..$n {
    $sum = ($sum | (zip ($rest | get $i)) | each {$in.0 + $in.1} )
  }

  return $sum
}

# difference between 2 lists of numbers
# Example:
# let a = [1 2 3]
#
# list-sum $a $a
export def list-diff [
  ...rest # list of lists of numbers
] {
$rest.0 | zip $rest.1 | each {$in.0 - $in.1} 
}

# group list
# Example:
# [1 1 2 2 3 4] | group list {$in mod 2 == 0}
export def group-list [cond: closure] {
  zip ($in | each $cond)
  | prepend [null]
  | window 2
  | each {|i|
      let prev = ($i.0 | default $i.1)
      let next = $i.1
      if $prev.1 != $next.1 {
        [null $next.0]
      } else {
        $next.0
      }
    }
  | flatten
  | split list null
}

#simple pivoting of a table without aggregation
#It's a process of summarizing data from a table into a new table by grouping values from one or more columns into new columns and then applying an aggregation function to the values in other columns.
#
#For instance:
#
#table_1:
#YEAR,ITEM,VALUE
#2000,case1,10
#2000,case2,20
#2000,case3,20
#2001,case1,20
#2001,case2,10
#2001,case3,50
#2003,case2,30
#2003,case1,50
#2004,case3,10
#2004,case2,39
#
#converts to table_2:
#ITEM,2000,2001,2003,2004
#case1,10,20,50,
#case2,20,10,30,39
#case3,20,50,,10
#
#via:
#
#$table_1 | pivot-table --columns [YEAR] --index [ITEM] --values [VALUE]
export def pivot-table [
  table_1? #table to pivot
  --columns(-c):list #column names for pivoting (new columns)
  --index(-i):list   #index names for pivoting (first new column)
  --values(-v):list  #values for pivoting (values in the new columns)
] {
  let table_1 = if ($table_1 | is-empty) {$in} else {$table_1}

  $table_1 | polars into-df | polars pivot -o $columns -i $index -v $values
}

