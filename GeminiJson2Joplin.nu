#!/usr/bin/env nu

export def main [tags?:string = "AI,ai_notes,bard"] {
  joplin use "AI_GeminiVoiceChat"

  let files = ls ~/Dropbox/Aplicaciones/Gmail/* | find joplin
  
  if ($files | length) == 0 {return}

  $files
  | each {|file|
      let json = open ($file.name | ansi strip)
      let title = $json.title
      let content = $json.body

      joplin mknote $title

      $tags
      | split row ","
      | each {|tag|
          joplin tag add $tag $title
          sleep 0.1sec
        }

      joplin set $title body $"'($content)'"

      rm -f $file.name
    }

  joplin sync
}