#backup sublime settings
export def "subl backup" [] {
  cd $env.MY_ENV_VARS.linux_backup

  let source_dir = "~/.config/sublime-text"
  
  7z max sublime-Packages.7z ([$source_dir "Packages"] | path join | path expand)
  7z max sublime-installedPackages.7z ([$source_dir "Installed Packages"] | path join | path expand)
}

#restore sublime settings
export def "subl restore" [] {
  cd $env.MY_ENV_VARS.linux_backup
  
  7z x sublime-installedPackages.7z -o/home/kira/.config/sublime-text/
  7z x sublime-Packages.7z -o/home/kira/.config/sublime-text/
}

#backup nchat settings
export def "nchat backup" [] {
  cd $env.MY_ENV_VARS.linux_backup

  let source_dir = ("~/.nchat" | path expand)
  
  7z max nchat_config.7z ($source_dir + "/*.conf")
}

#restore nchat settings
export def "nchat restore" [] {
  cd $env.MY_ENV_VARS.linux_backup

  7z x nchat_config.7z -o/home/kira/.nchat
}

#backup gnome extensions settings
export def "gnome-settings backup" [] {
  dconf dump /org/gnome/shell/extensions/ 
  | save -f ([$env.MY_ENV_VARS.linux_backup extensions/gnome_shell_extensions_backup.txt] | path join)
}

#restore gnome extensions settings
export def "gnome-settings restore" [] {
  bash -c $"dconf load /org/gnome/shell/extensions/ < ([$env.MY_ENV_VARS.linux_backup extensions/gnome_shell_extensions_backup.txt] | path join)"
}

#backup libre office settings
export def "libreoff backup" [] {
  cp -r ~/.config/libreoffice/* ([$env.MY_ENV_VARS.linux_backup libreoffice] | path join)
}

#restore libre office settings
export def "libreoff restore" [] {
  cp -r ($env.MY_ENV_VARS.linux_backup + "/libreoffice/*") ~/.config/libreoffice/
}

#update nushell sublime syntax
export def "nushell-syntax-2-sublime" [
 --push(-p) #push changes in submile syntax repo
] {
  let builtin = (
      scope commands 
      | where is_builtin == true and is_keyword == false
      | get name 
      | each {|com| 
          $com 
          | split row " " 
          | get 0
        } 
      | flatten
      | uniq
      | str join " | "
  )

  let plugins = (
      scope commands 
      | where is_plugin == true
      | get name 
      | each {|com| 
          $com 
          | split row " "
          | get 0
        } 
      | flatten
      | uniq
      | str join " | "
  )

  let custom = (
      scope commands 
      | where is_custom == true
      | get name 
      | each {|com| 
          $com 
          | split row " " 
          | get 0
        } 
      | flatten
      | uniq
      | str join " | "
  )  

  let keywords = (
      scope commands 
      | where is_keyword == true
      | get name 
      | each {|com| 
          $com 
          | split row " " 
          | get 0
        } 
      | flatten
      | uniq
      | str join " | "
  ) 

  let aliases = (
      scope aliases 
      | get name 
      | uniq
      | str join " | "
  )   

  let personal_external = (
    $env.PATH 
    | find bash & nushell 
    | get 0 
    | ls $in 
    | find -v Readme 
    | get name 
    | path parse 
    | get stem
    | str join " | "
  )

  let extra_builtin = " | else | catch"
  let builtin = "    (?x: " + $builtin + $extra_builtin + ")"
  let plugins = "    (?x: " + $plugins + ")"
  let custom = "    (?x: " + $custom + ")"
  let keywords = "    (?x: " + $keywords + ")"
  let aliases = "    (?x: " + $aliases + ")"
  let personal_external = "    (?x: " + $personal_external + ")"
  let operators = "    (?x: and | or | mod | in | not-in | not | xor | bit-or | bit-xor | bit-and | bit-shl | bit-shr | starts-with | ends-with)"

  let new_commands = [] ++ $builtin ++ $custom ++ $plugins ++ $keywords ++ $aliases ++ $personal_external ++ $operators
 
  mut file = open ~/.config/sublime-text/Packages/User/nushell.sublime-syntax | lines
  let idx = $file | indexify | find '(?x:' | get index | drop

  for -n i in $idx {
    $file = ($file | upsert $i.item ($new_commands | get $i.index))
  }
  
  $file | save -f ~/.config/sublime-text/Packages/User/nushell.sublime-syntax

  cp ~/.config/sublime-text/Packages/User/nushell.sublime-syntax ~/Dropbox/Development/linux/sublime/nushell_sublime_syntax/

  if $push {
    cd ~/Dropbox/Development/linux/sublime/nushell_sublime_syntax/
    ai git-push -g
  }
}

#backup nushell history
export def "history backup" [
  output?:string = "hist" #output filename
] {
  open $nu.history-path | query db $"vacuum main into '($output).db'" 
}

#export rclone config
export def "rclone export" [] {
  cd ~/.config/rclone  
  nu-crypt -e -n rclone.conf
  mv rclone.conf.asc $env.MY_ENV_VARS.linux_backup
}

#import rclone config
export def "rclone import" [] {
  cd $env.MY_ENV_VARS.linux_backup
  nu-crypt -d -n rclone.conf.asc
  mv -f rclone.conf ~/.config/rclone  
  rclone listremotes
}