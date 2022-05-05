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

#posteo a #announcements in discord
def ubb_announce [message] {
  let content = $"{\"content\": \"($message)\"}"

  let weburl = "https://discord.com/api/webhooks/970172248004644924/Onj5lpPWK_n70jde7Uf4WVOiivsVG7kUCdTh6cEknPpJ1tiluG2OksjqdPUEJvyJNi-g"

  post $weburl $content --content-type "application/json"
}  

def nu_up2ubb [] {
  up2ubb

  let fecha = (date format %d/%m/%y)
  let message = $"Se han subido a drive los videos de clases al dia de hoy: ($fecha)."

  ubb_announce $message 
}

#posteo a #medicos in discord
def med_discord [message] {
  let content = $"{\"content\": \"($message).\"}"

  let weburl = "https://discord.com/api/webhooks/970202588869967892/-ruTpHWejr8pTXeqHmY-w2dFUOrV-PS8-3u3D-KGzBZUuezmXHhA_xInRcLTouDQxNLB"

  post $weburl $content --content-type "application/json"
}  

#get column of a table
def column [n] { 
  transpose | select $n | transpose | select column1 | headers
}

#get column of a table
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

# cd to the folder where a binary is located
def-env which-cd [program] { 
  let dir = (which $program | get path | path dirname | str trim)
  cd $dir.0
}