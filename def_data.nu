#compact with empty strings and nulls
export def scompact [
    ...columns: string # the columns to compactify
    --invert(-i) # select the opposite
] {
  mut out = $in
  for column in $columns {
    if $invert {
      $out = ($out | upsert $column {|row| if not ($row | get $column | is-empty) {null} else {$row | get $column}} | compact $column  )
      } else {
        $out = ($out | upsert $column {|row| if ($row | get $column | is-empty) {null} else {$row | get $column}} | compact $column  )
      }
  }
  return $out
}

#flatten a record keys
#
#Example:
# flatten-keys $env.config '$env.config'
def flatten-keys [rec: record, root: string] {
  $rec | columns | each {|key|
    let is_record = (
      $rec | get $key | describe --detailed | get type | $in == record
    )

    # Recusively return each key plus its subkeys
    [$'($root).($key)'] ++  match $is_record {
      true  => (flatten-keys ($rec | get $key) $'($root).($key)')
      false => []
    }
   } | flatten
}

# Check if date is further in the past than specified duration
export def older-than [
  date: duration
]: datetime -> bool {
  $in < ((date now) - $date)
}

# Check if date is closer to the present than specified duration
export def newer-than [
  date: duration
]: datetime -> bool {
  $in > ((date now) - $date)
}

#Calculates a past datetime by subtracting a duration from the current time.
export def ago []: [ duration -> datetime ] {
  (date now) - $in
}
