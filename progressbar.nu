#progress bar
export def progress_bar [] {
  let pb_len = 25
  let bg_fill = "▒"  # Fill up to $pb_len
  let blocks = ["▏" "▎" "▍" "▌" "▋" "▊" "▉" "█"]

  # Turn off the cursor
  ansi cursor_off
  # Move cursor all the way to the left
  print -n $"(ansi -e '1000D')"
  # Draw the background for the progress bar
  print -n ($bg_fill | fill -c $bg_fill -w $pb_len -a r)

  1..<$pb_len | each { |cur_progress|
    0..7 | each { |tick|
        let cur_idx = ($tick mod 8)
        let cur_block = (echo $blocks | get $cur_idx)
        print -n $"(ansi -e '1000D')($cur_block | fill -c $blocks.7 -w $cur_progress -a r)"
        sleep 20ms
    }
    print -n $"(ansi -e '1000D')"
  }
  # Fill in the last background block
  print $"($blocks.7 | fill -c $blocks.7 -w $pb_len -a r)"
  "Done"
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

