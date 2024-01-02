#!/usr/bin/env nu

export def main [tags?:string = "AI,ai_notes,bard"] {
  joplin use "AI_GeminiVoiceChat"

  ls ~/Dropbox/Aplicaciones/Gmail/joplin*.json
  | each {|file|
      let json = open $file.name
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