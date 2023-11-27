#ping with plot
export def png-plot [ip?] {
  let ip = if ($ip | is-empty) {"1.1.1.1"} else {$ip}

  bash -c $"ping ($ip) | sed -u 's/^.*time=//g; s/ ms//g' | ttyplot -t \'ping to ($ip)\' -u ms"
}

#plot download-upload speed
export def speedtest-plot [] {
  echo "fast --single-line --upload |  stdbuf -o0 awk '{print $2 \" \" $6}' | ttyplot -2 -t 'Download/Upload speed' -u Mbps" | bash 
}

#plot data table using gnuplot
#
#Example: If $x is a table with 2 columns
#$x | gnu-plot
#($x | column 0) | gnu-plot
#($x | column 1) | gnu-plot
#($x | column 0) | gnu-plot --title "My Title"
#gnu-plot $x --title "My Title"
export def gnu-plot [
  data?           #1 or 2 column table
  --title:string  #title
] {
  let x = if ($data | is-empty) {$in} else {$data}
  let n_cols = ($x | transpose | length)
  let name_cols = ($x | transpose | column2 0)

  let ylabel = if $n_cols == 1 {$name_cols | get 0} else {$name_cols | get 1}
  let xlabel = if $n_cols == 1 {""} else {$name_cols | get 0}

  let title = if ($title | is-empty) {
    if $n_cols == 1 {
      $ylabel | str upcase
    } else {
      $"($ylabel) vs ($xlabel)"
    }
  } else {
    $title
  }

  $x | to tsv | save -f data0.txt
  sed 1d data0.txt | save -f data.txt -f
  
  gnuplot -e $"set terminal dumb; unset key;set title '($title)';plot 'data.txt' w l lt 0;"

 rm -f data*.txt
} 

#plot data table using plot plugin
#
#Example:
export def plot-table [
  data?          #a table with only the y values of the plots
  --type = "l"   #type of plot (bars (b), steps (s), points (p), line (l) default)
  --title = ""   #title
  --width:number
] {
  let x = (if ($data | is-empty) {$in} else {$data} | reject index?)
  let n_cols = ($x | transpose | length)
  let name_cols = ($x | transpose | column2 0)

  mut list = []
  for col in ($x | columns) {
    $list = ($list | append [($x | get $col)])
  }

  if ($width | is-empty) {
    match $type {
      "l" => {$list | plot -l -t $title},
      "b" => {$list | plot -bl -t $title},
      "s" => {$list | plot -sl -t $title},
      "p" => {$list | plot -pl -t $title},
    }
  } else {
    match $type {
      "l" => {$list | plot -l -t $title --width $width},
      "b" => {$list | plot -bl -t $title --width $width},
      "s" => {$list | plot -sl -t $title --width $width},
      "p" => {$list | plot -pl -t $title --width $width},
    }
  } 
}