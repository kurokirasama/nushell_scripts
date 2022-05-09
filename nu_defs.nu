def cpwd [] {pwd | tr "\n" " " | sed "s/ //g" | xclip -sel clip}

def supgrade [] {
  echo "updating..."
  sudo aptitude update -y
  echo "upgrading..."
  sudo aptitude safe-upgrade -y
  echo "autoremoving..."
  sudo apt autoremove -y
}

def mcx [file] {
  do -i {mcomix $file} | ignore
}

def openf [file] {
  bash -c $'xdg-open "($file)" 2>/dev/null &'
}

def psn [name: string] {
  ps | find $name
}

def killn [name: string] {
  ps | find $name | each {kill -f $in.pid}
}

def nujd [] {
  jdown | lines | each { |line| $line | from nuon } | flatten | flatten
}

# Switch-case like instruction
# Example:
# let x = 3
# switch $x {
#   1: { echo "you chose one" },
#   2: { echo "you chose two" },
#   3: { echo "you chose three" }
# }
def switch [input, matchers: record] {
    echo $matchers | get $input | do $in
} 

#select column of a table (to table)
def column [n] { 
  transpose | select $n | transpose | select column1 | headers
}

#get column of a table (to list)
def column2 [n] { 
  transpose | get $n | transpose | get column1 | skip 1
}

#showt pwd
def pwd-short [] {
  $env.PWD | str replace $nu.home-path '~' -s
}

#string repeat
def "str repeat" [count: int] { 
  each {|it| let str = $it; echo 1..$count | each { echo $str } } 
}

#join 2 lists
def union [a: list, b: list] {
    $a | append $b | uniq
}

#nushell source files info
def 'nu-sloc' [] {
  let stats = (
    ls **/*.nu
      | select name
      | insert lines { |it| open $it.name | size | get lines }
      | insert blank {|s| $s.lines - (open $s.name | lines | find --regex '\S' | length) }
      | insert comments {|s| open $s.name | lines | find --regex '^\s*#' | length }
      | sort-by lines -r
  )

  let lines = ($stats | reduce -f 0 {|it, acc| $it.lines + $acc })
  let blank = ($stats | reduce -f 0 {|it, acc| $it.blank + $acc })
  let comments = ($stats | reduce -f 0 {|it, acc| $it.comments + $acc })
  let total = ($stats | length)
  let avg = ($lines / $total | math round)

  $'(char nl)(ansi pr) SLOC Summary for Nushell (ansi reset)(char nl)'
  print { 'Total Lines': $lines, 'Blank Lines': $blank, Comments: $comments, 'Total Nu Scripts': $total, 'Avg Lines/Script': $avg }
  $'(char nl)Source file stat detail:'
  print $stats
}

#go to dir (via pipe)
def-env goto [] {
    let input = $in
    cd (
        if ($input | path type) == file {
            ($input | path dirname)
        } else {
            $input
        }
    )
}

#cd to the folder where a binary is located
def-env which-cd [program] { 
  let dir = (which $program | get path | path dirname | str trim)
  cd $dir.0
}

#push to git
def git-push [m: string] {
  git add -A
  git status
  git commit -am $"($m)"
  git push origin main  
}

#get help for custom commands
def "help my-commands" [] {
  help commands | where is_custom == true
}

#web search in terminal
def gg [...search: string] {
  ddgr -n 5 ($search | str collect ' ')
}

#habitipy dailies done all
def hab-dailies-done [] {
  let to_do = (habitipy dailies | grep ✖ | awk {print $1} | tr '.\n' ' ' | split row ' ' | into int)
  habitipy dailies done $to_do 
}

#update aliases file from config.nu
def update-aliases [] {
  let nlines = (open $nu.config-path | lines | length)
 
  let from = ((grep "## aliases" $nu.config-path -n | split row ':').0 | into int)
  
  open $nu.config-path | lines | last ($nlines - $from + 1) | save /home/kira/Yandex.Disk/Backups/linux/nu_aliases.nu
}

#countdown alarm 
#needed termdown: https://github.com/trehn/termdown
def countdown [
  n: int # time in seconds
  ] {
    let BEEP = "/path/to/some/audio/file"
    let muted = (pacmd list-sinks | awk '/muted/ { print $2 }' | tr '\n' ' ' | split row ' ')

    if $muted == 'no' {
      termdown $n;mpv --no-terminal $BEEP  
    } else {
      termdown $n
      unmute
      mpv --no-terminal $BEEP
      mute
    }   
}