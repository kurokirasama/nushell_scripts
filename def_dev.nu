#nushell source files info
export def nu-sloc [] {
  let stats = (
    ls **/*.nu
    | select name
    | insert lines { |it|
        open $it.name
        | size
        | get lines
      }
    | insert blank {|s|
        $s.lines - (open $s.name | lines | find --regex '\S' | length)
      }
    | insert comments {|s|
        open $s.name
        | lines
        | find --regex '^\s*#'
        | length
      }
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

#export nushell.github documentation
export def export-nushell-docs [] {
  if ("~/software/nushell.github.io" | path expand | path exists) {
    cd ~/software/nushell.github.io;git pull
    rm -rf nushell
  } else {
    cd ~/software
    git clone https://github.com/nushell/nushell.github.io.git
    cd nushell.github.io
  }

  mkdir nushell
  cd blog;join-text-files md blog;mv blog.md ../nushell;cd ..
  cd book;join-text-files md book;mv book.md ../nushell;cd ..
  cd commands/categories;join-text-files md categories;mv categories.md ..;cd ..
  cd docs;join-text-files md docs;mv docs.md ..;cd ..
  join-text-files md commands;mv commands.md ../nushell;cd ..
  cd cookbook;join-text-files md cookbook;mv cookbook.md ../nushell;cd ..
  cd lang-guide;join-text-files md lang-guide;mv lang-guide.md ../nushell;cd ..

  rm -rf ([$env.MY_ENV_VARS.ai_database nushell] | path join)
  mv -f nushell/ $env.MY_ENV_VARS.ai_database

  cd ~/software/nushell
  cp README.md ([$env.MY_ENV_VARS.ai_database nushell] | path join)
  cd ([$env.MY_ENV_VARS.ai_database nushell] | path join)

  join-text-files md all_nushell
  let system_message = (open ([$env.MY_ENV_VARS.chatgpt_config system bash_nushell_programmer.md] | path join)) ++ "\n\nPlease consider the following nushell documentation to elaborate your answer.\n\n"

  $system_message ++ (open all_nushell.md) | save -f ([$env.MY_ENV_VARS.chatgpt_config system bash_nushell_programmer_with_nushell_docs.md] | path join)
}

#generates nushell document for llm (gemini and claude)
export def generate-nushell-doc [] {
  cd ~/software/nushell.github.io
  git pull
  cd book/
  get-files | cp-pipe ~/temp

  cd ~/temp
  ["3rdpartyprompts.md" "installation.md" "design_notes.md" "background_task.md"] | each {|f|
    rm -f $f
  }

  cd ~/temp
  join-text-files md nushell_book

  let doc = open nushell_book.md

  cd ([$env.MY_ENV_VARS.chatgpt_config system] | path join)

  let index = open bash_nushell_programmer_with_nushell_docs.md | lines | find-index "NUSHELL DOCUMENTATION" | get 1 | into int

  let system_message = open bash_nushell_programmer_with_nushell_docs.md | lines | first ($index + 2) | to text

  $system_message + $doc | save -f bash_nushell_programmer_with_nushell_docs.md

  cd ~/temp
  rm *
}