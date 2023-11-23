#text progress bar
#
#Example:
# def test_progress_bar [
# ] {
#     let max = 1000
#     mut t = text_progress_bar 0 $max
#     mut progress = $t.progress
#     mut progress_bar = $t.progress_bar
#     for i in 1..($max) {
#         $t = (text_progress_bar $i $max $progress $progress_bar )
#         $progress = $t.progress
#         $progress_bar = $t.progress_bar
#         sleep 0.1sec
#     }
# }
export def text_progress_bar [
    count:int 
    max:int 
    progress?:int
    progress_bar?:string
    --symbol(-s):string = "█"
    --color(-c):string = "#FFFFFF"
] {
    let term_length = (term size).columns
    let bar_pieces = [100 $term_length * 100 / 160 | math ceil] | math min
    let bar_increment = $max / $bar_pieces

    mut progress_bar = if ($progress_bar | is-empty) {$symbol} else {$progress_bar}
    let progress = if ($progress | is-empty) {0} else {$progress}

    print -n (
        [
            (ansi -e { fg: $color })
            $"\r(($count / $max * 100) | into string -d 2 | fill -c 0 -a r -w 5)% " 
            ($progress_bar)
            (ansi reset)
        ] 
        | str join
    )

    if $count / $max * 100 - $progress > $bar_increment {
        $progress_bar = $progress_bar + $symbol
    }
    
    let progress = $count / $max * 100
    return ({progress: $progress, progress_bar: $progress_bar})
}
#progress bar
export def progress_bar [] {
  let pb_len = 50
  let bg_fill = "▒"  # Fill up to $pb_len
  let blocks = ["▏" "▎" "▍" "▌" "▋" "▊" "▉" "█"]

  # Turn off the cursor
  ansi cursor_off
  # Move cursor all the way to the left
  print -n $"(ansi -e '1000D')"
  # Draw the background for the progress bar
  print -n ($bg_fill | fill -c $bg_fill -w $pb_len -a r)

  1..<$pb_len 
  | each { |cur_progress|
        0..7 
        | each { |tick|
            let cur_idx = $tick mod 8
            let cur_block = $blocks | get $cur_idx
            print -n (
                [
                    (ansi -e '1000D')
                    ($cur_block | fill -c $blocks.7 -w $cur_progress -a r)
                ]
                | str join
            )
            sleep 20ms
        }
        print -n $"(ansi -e '1000D')"
    }

  # Fill in the last background block
  print $"($blocks.7 | fill -c $blocks.7 -w $pb_len -a r)"
  
  ansi cursor_on
}

def loading [] {
    print -n $"Loading (char newline)"
    0..100 | each { |tick|
        sleep 50ms
        # I believe '1000D' means move the cursor to the left 1000 columns
        print -n $"(ansi -e '1000D')($tick)%"
    }
    #show_cursor
}

def show_cursor [] {
    print $"(ansi -e '?25h')"
}

def hide_cursor [] {
    print $"(ansi -e '?25l')"
}

export def demo_percent_meter [] {
    hide_cursor
    loading
    show_cursor
}

def "fill float" [
    number?
    --width:int = 3
    ] {
    $number | math round -p $width | fill -a -l -c '0' -w $width
}
