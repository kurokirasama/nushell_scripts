#ai tools
export def "ai help" [] {
  print (
    echo ["This set of tools need a few dependencies installed:"
      "ffmpeg"
      "whisper:"
      "  pip install git+https://github.com/openai/whisper.git"
      "yt-dlp:" 
      "  python3 -m pip install --force-reinstall https://github.com/yt-dlp/yt-dlp/archive/master.tar.gz"
      "METHODS"
      "- chat_gpt"
      "- askgpt"
      "- ai audio2text"
      "- ai video2text"
      "- ai screen2text"
      "- ai audio2summary"
      "- ai transcription-summary"
      "- ai yt-summary"
      "- ai media-summary"
      "- ai generate-subtitles"
      "- ai git-push"
      "- dall_e" 
      "- askdalle"
      "- ai tts"
      "- tts"
    ]
    | str join "\n"
    | nu-highlight
  ) 
}

#upload a file to chatpdf server
export def "chatpdf add" [
  file:string   #filename with extension
  label?:string #label for the pdf (default is downcase filename with underscores as spaces)
  --notify(-n)  #notify to android via ntfy
] {
  let file = if ($file | is-empty) {$in | get name} else {$file}

  if ($file | path parse | get extension | str downcase) != pdf {
    return-error "wrong file type, it must be a pdf!"
  }

  let api_key = $env.MY_ENV_VARS.api_keys.chatpdf.api_key
  let database_file = ([$env.MY_ENV_VARS.chatgpt_config chatpdf_ids.json] | path join)
  let database = (open $database_file)

  let url = "https://api.chatpdf.com/v1/sources/add-file"

  let filename = ($file | path parse | get stem | str downcase | str replace -a " " "_")
  let filepath = ($file | path expand)

  if ($filename in ($database | columns)) {
    return-error "there is already a file with the same name already uploaded!"
  }

  if not ($label | is-empty) {
     if ($label in ($database | columns)) {
      return-error "there is already a file with the same label already uploaded!"
   }
  }

  let filename = if ($label | is-empty) {$filename} else {label}
        
  let header = $"x-api-key: ($api_key)"
  # let response = (http post $url -t application/octet-stream $data -H ["x-api-key", $api])
  let response = (curl -s -X POST $url -H $header -F $"file=@($filepath)" | from json)

  if ($response | is-empty) {
    return-error "empty response!"
  } else if ("sourceId" not-in ($response | columns) ) {
    return-error $response.message
  }

  let id = ($response | get sourceId)

  $database | upsert $filename $id | save -f $database_file
  if $notify {"upload finished!" | ntfy-send}
}

#delete a file from chatpdf server
export def "chatpdf del" [
] {
  let api_key = $env.MY_ENV_VARS.api_keys.chatpdf.api_key
  let database_file = ([$env.MY_ENV_VARS.chatgpt_config chatpdf_ids.json] | path join)
  let database = (open $database_file)

  let selection = ($database | columns | sort | input list -f (echo-g "Select file to delete:"))

  let url = "https://api.chatpdf.com/v1/sources/delete"
  let data = {"sources": [($database | get $selection)]}
  
  let header = ["x-api-key", ($api_key)] 
  let response = (http post $url -t application/json $data -H $header)
  
  $database | reject $selection | save -f $database_file
}

#chat with a pdf via chatpdf
export def "chatpdf ask" [
  prompt?:string            #question to the pdf
  --select_pdf(-s):string   #specify which book to ask via filename (without extension), otherwise select from list
] {
  let prompt = if ($prompt | is-empty) {$in} else {$prompt}

  let api_key = $env.MY_ENV_VARS.api_keys.chatpdf.api_key
  let database_file = ([$env.MY_ENV_VARS.chatgpt_config chatpdf_ids.json] | path join)
  let database = (open $database_file)

  let selection = (
    if ($select_pdf | is-empty) {
      $database 
      | columns 
      | sort 
      | input list -f (echo-g "Select pdf to ask a question:")
    } else {
      $select_pdf
      | str downcase 
      | str replace -a " " "_"
    }
  )

  if ($selection not-in ($database | columns)) {
    return-error "pdf not found in server!"
  }

  let url = "https://api.chatpdf.com/v1/chats/message"

  let header = ["x-api-key", ($api_key)]  
  let request = {
    "referenceSources": true,
    "sourceId": ($database | get $selection),
    "messages": [
      {
        "role": "user",
        "content": $prompt
      }
    ]
  }

  let answer = (http post -t application/json -H $header $url $request) 

  return $answer.content
}

#fast call to chatpdf ask
export def askpdf [
  prompt?     #question to ask to the pdf
  --rubb(-r)  #use rubb file, otherwhise select from list
  --btx(-b)   #use btx file, otherwhise select from list
  --fast(-f)  #get prompt from ~/Yandex.Disk/ChatGpt/prompt.md and save response to ~/Yandex.Disk/ChatGpt/answer.md
] {
  if $rubb and $btx {
    return-error "only one of these flags allowed!"
  }
  let prompt = (
    if not $fast {
      if ($prompt | is-empty) {$in} else {$prompt}
    } else {
      open ~/Yandex.Disk/ChatGpt/prompt.md
    }
  )

  let answer = (
    if $rubb {
      chatpdf ask $prompt -s rubb
    } else if $btx {
      chatpdf ask ($prompt + (open ([$env.MY_ENV_VARS.chatgpt_config chagpt_prompt.json] | path join) | get chatpdf_btx)) -s btx
    } else {
      chatpdf ask $prompt
    }
  )

  if $fast {
    $answer | save -f ~/Yandex.Disk/ChatGpt/answer.md
  } else {
    return $answer  
  } 
}

#list uploaded documents
export def "chatpdf list" [] {
  open ([$env.MY_ENV_VARS.chatgpt_config chatpdf_ids.json] | path join) | columns
}

#single call chatgpt wrapper
#
#Available models at https://platform.openai.com/docs/models, but some of them are:
# - gpt-4 (8192 tokens)
# - gpt-4-1106-preview (128000 tokens), gpt-4-turbo for short
# - gpt-4-vision-preview (128000 tokens) 
# - gpt-4-32k (32768 tokens)
# - gpt-3.5-turbo (4096 tokens)
# - gpt-3.5-turbo-1106 (16385 tokens)
# - gpt-3.5-turbo-16k (16384 tokens)
# - text-davinci-003 (4097 tokens)
#
#Available system messages are:
# - assistant
# - psychologist
# - programer
# - get_diff_summarizer
# - meeting_summarizer
# - ytvideo_summarizer
# - teacher
# - spanish_translator
# - html_parser
# - rubb
#
#Available pre_prompts are:
# - empty
# - recreate_text
# - summarize_transcription
# - consolidate_transcription
# - trans_to_spanish
# - summarize_git_diff
# - summarize_git_diff_short
# - summarize_ytvideo
# - consolidate_ytvideo
# - parse_html
# - elaborate_idea
#
#Note that:
# - --select_system > --list_system > --system
# - --select_preprompt > --pre_prompt
export def chat_gpt [
    prompt?: string                               # the query to Chat GPT
    --model(-m):string = "gpt-3.5-turbo-1106"     # the model gpt-3.5-turbo, gpt-4, etc
    --system(-s):string = "You are a helpful assistant." # system message
    --temp(-t): float = 0.9                       # the temperature of the model
    --image(-i):string                        # filepath of image file for gpt-4-vision-preview
    --list_system(-l)                             # select system message from list
    --pre_prompt(-p)                              # select pre-prompt from list
    --delim_with_backquotes(-d)   # to delimit prompt (not pre-prompt) with triple backquotes (')
    --select_system: string                       # directly select system message    
    --select_preprompt: string                    # directly select pre_prompt
] {
  let prompt = if ($prompt | is-empty) {$in} else {$prompt}
  if ($prompt | is-empty) {
    return-error "Empty prompt!!!"
  }
  
  if ($model == "gpt-4-vision-preview") and ($image | is-empty) {
    return-error "gpt-4-vision needs and image file!"
  }

  if ($model == "gpt-4-vision-preview") and (not ($image | path expand | path exists)) {
    return-error "image file not found!" 
  }

  let extension = (
    if $model == "gpt-4-vision-preview" {
      $image | path parse | get extension
    } else {
      ""
    }
  )

  let image = (
    if $model == "gpt-4-vision-preview" {
      open ($image | path expand) | encode base64
    } else {
      ""
    }
  )

  #select system message
  let system_messages = (open ([$env.MY_ENV_VARS.chatgpt_config chagpt_systemmessages.json] | path join))

  mut ssystem = ""
  if ($list_system and ($select_system | is-empty)) {
    let selection = ($system_messages | columns | input list -f (echo-g "Select system message: "))
    $ssystem = ($system_messages | get $selection)
  } else if (not ($select_system | is-empty)) {
    try {
      $ssystem = ($system_messages | get $select_system)
    } 
  }
  let system = if ($ssystem | is-empty) {$system} else {$ssystem}

  #select pre-prompt
  let pre_prompts = (open ([$env.MY_ENV_VARS.chatgpt_config chagpt_prompt.json] | path join))

  mut preprompt = ""
  if ($pre_prompt and ($select_preprompt | is-empty)) {
    let selection = ($pre_prompts | columns | input list -f (echo-g "Select pre-prompt: "))
    $preprompt = ($pre_prompts | get $selection)
  } else if (not ($select_preprompt | is-empty)) {
    try {
      $preprompt = ($pre_prompts | get $select_preprompt)
    }
  }

  let prompt = (
    if ($preprompt | is-empty) and $delim_with_backquotes {
      "'''" + "\n" + $prompt + "\n" + "'''"
    } else if ($preprompt | is-empty) {
      $prompt
    } else if $delim_with_backquotes {
      $preprompt + "\n" + "'''" + "\n" + $prompt + "\n" + "'''"
    } else {
      $preprompt + $prompt
    } 
  )

  # call to api
  let model = if $model == "gpt-4-turbo" {"gpt-4-1106-preview"} else {$model}
  let header = [Authorization $"Bearer ($env.MY_ENV_VARS.api_keys.open_ai.api_key)"]
  let site = "https://api.openai.com/v1/chat/completions"
  let image_url = ("data:image/" + $extension + ";base64," + $image)
  
  let request = (
    if $model == "gpt-4-vision-preview" {
      {
        model: $model,
        messages: [
          {
            role: "system"
            content: $system
          },
          {
            role: "user"
            content: [
              {
                "type": "text",
                "text": $prompt
              },
              {
                "type": "image_url",
                "image_url": 
                  {
                    "url": $image_url
                  }
              }
            ]
          }
        ],
        temperature: $temp,
        max_tokens: 4000
      }
    } else {
      {
        model: $model,
        messages: [
          {
            role: "system"
            content: $system
          },
          {
            role: "user"
            content: $prompt
          }
        ],
        temperature: $temp
      }
    }
  )

  let answer = http post -t application/json -H $header $site $request  
  return $answer.choices.0.message.content
}

#fast call to the chat_gpt wrapper
#
#Only one system message flag allowed.
#For more personalization use `chat_gpt`
export def askgpt [
  prompt?:string  # string with the prompt, can be piped
  system?:string  # string with the system message. It has precedence over the s.m. flags
  --programmer(-p) # use programmer s.m with temp 0.7, else use assistant with temp 0.9
  --teacher(-s) # use teacher (sensei) s.m with temp 0.95, else use assistant with temp 0.9
  --engineer(-e) # use prompt_engineer s.m. with temp 0.8, else use assistant with temp 0.9
  --rubb(-r)     # use rubb s.m. with temperature 0.5, else use assistant with temp 0.9
  --list_system(-l)       # select s.m from list (takes precedence over flags)
  --list_preprompt(-b)    # select pre-prompt from list (pre-prompt + ''' + prompt + ''')
  --temperature(-t):float # takes precedence over the 0.7 and 0.9
  --gpt4(-g)              # use gpt-4-1106-preview instead of gpt-3.5-turbo-1106 (default)
  --vision(-v)            # use gpt-4-vision-preview
  --image(-i):string      # filepath of the image to prompt to gpt-4-vision-preview
  --fast(-f) # get prompt from ~/Yandex.Disk/ChatGpt/prompt.md and save response to ~/Yandex.Disk/ChatGpt/answer.md
] {
  if $vision and ($image | is-empty) {
    return-error "gpt-4 vision needs and image file!"
  }

  let prompt = (
    if not $fast {
      if ($prompt | is-empty) {$in} else {$prompt}
    } else {
      open ~/Yandex.Disk/ChatGpt/prompt.md
    }
  )
    
  let temp = (
    if ($temperature | is-empty) {
      match [$programmer, $teacher, $engineer, $rubb] {
        [true,false,false,false] => 0.7,
        [false,true,false,false] => 0.95,
        [false,false,false,true] => 0.5,
        [false,false,true,false] => 0.8,
        [false,false,false,false] => 0.9
        _ => {return-error "only one system message flag allowed"},
      }
   } else {
    $temperature
   }
  )

  let system = (
    if ($system | is-empty) {
      if $list_system {
        ""
      } else if $programmer {
        "programmer"
      } else if $teacher {
        "teacher"
      } else if $engineer {
        "prompt_engineer"
      } else if $rubb {
        "rubb"
      } else {
        "assistant"
      }
    } else {
      $system
    }
  )

  let answer = (
    if $vision {
      match [$list_system,$list_preprompt] {
        [true,true] => {chat_gpt $prompt -t $temp -l -m gpt-4-vision-preview -p -d -i $image},
        [true,false] => {chat_gpt $prompt -t $temp -l -m gpt-4-vision-preview -i $image},
        [false,true] => {chat_gpt $prompt -t $temp --select_system $system -m gpt-4-vision-preview -p -d -i $image},
        [false,false] => {chat_gpt $prompt -t $temp --select_system $system -m gpt-4-vision-preview -i $image},
      }
    } else {
      match [$gpt4,$list_system,$list_preprompt] {
        [true,true,false] => {chat_gpt $prompt -t $temp -l -m gpt-4-1106-preview},
        [true,false,false] => {chat_gpt $prompt -t $temp --select_system $system -m gpt-4-1106-preview},
        [false,true,false] => {chat_gpt $prompt -t $temp -l},
        [false,false,false] => {chat_gpt $prompt -t $temp --select_system $system},
        [true,true,true] => {chat_gpt $prompt -t $temp -l -m gpt-4-1106-preview -p -d},
        [true,false,true] => {chat_gpt $prompt -t $temp --select_system $system -m gpt-4-1106-preview -p -d},
        [false,true,true] => {chat_gpt $prompt -t $temp -l -p -d},
        [false,false,true] => {chat_gpt $prompt -t $temp --select_system $system -p -d}
      }
    }
  )

  if $fast {
    $answer | save -f ~/Yandex.Disk/ChatGpt/answer.md
  } else {
    return $answer  
  } 
}

#generate a git commit message via chatgpt and push the changes
#
#Inspired by https://github.com/zurawiki/gptcommit
export def "ai git-push" [
  --gpt4(-g) # use gpt-4-1106-preview instead of gpt-3.5-turbo-1106
] {
  let max_words = if $gpt4 {85000} else {10000}
  let max_words_short = if $gpt4 {85000} else {10000}

  print (echo-g "asking chatgpt to summarize the differences in the repository...")
  let question = (git diff | str replace "\"" "'" -a)
  let prompt = ($question | ^awk ("'BEGIN{total=0} {total+=NF; if(total<=(" + $"($max_words)" + ")) print; else exit}'"))
  let prompt_short = ($question | ^awk ("'BEGIN{total=0} {total+=NF; if(total<=(" + $"($max_words_short)" + ")) print; else exit}'"))

  let commit = (
    try {
      match $gpt4 {
        true => {
          try {
            chat_gpt $question -t 0.5 --select_system get_diff_summarizer --select_preprompt summarize_git_diff -d -m "gpt-4-turbo"
          } catch {
            try {
              chat_gpt $prompt -t 0.5 --select_system get_diff_summarizer --select_preprompt summarize_git_diff -d -m "gpt-4-turbo"
            } catch {
            chat_gpt $prompt_short -t 0.5 --select_system get_diff_summarizer --select_preprompt summarize_git_diff_short -d -m "gpt-4-turbo"
            }
          }
        },
        false => {
          try {
            chat_gpt $question -t 0.5 --select_system get_diff_summarizer --select_preprompt summarize_git_diff -d
          } catch {
            try {
              chat_gpt $prompt -t 0.5 --select_system get_diff_summarizer --select_preprompt summarize_git_diff -d
            } catch {
            chat_gpt $prompt_short -t 0.5 --select_system get_diff_summarizer --select_preprompt summarize_git_diff_short -d
            }
          }
        }
      }
    } catch {
      input (echo-g "Something happened with chatgpt. Enter your commit message or leave empty to stop: ")
    }
  )

  if ($commit | is-empty) {
    return-error "Execution stopped by the user!"
  }

  print (echo-g "resulting commit message:")
  print (echo $commit)
  print (echo-g "pushing the changes with that commit message...\n")
  git add -A
  git status
  git commit -am $commit
  git push origin main

  #updating deb files to gdrive
  let mounted = ($env.MY_ENV_VARS.gdrive_debs | path expand | path exists)
  if not $mounted {
    print (echo-g "mounting gdrive...")
    mount-ubb
  }

  let old_deb_date = ls ([$env.MY_ENV_VARS.gdrive_debs debs.7z] | path join) | get modified | get 0

  let last_deb_date = ls $env.MY_ENV_VARS.debs | sort-by modified | last | get modified 

  if $last_deb_date > $old_deb_date {   
    print (echo-g "updating deb files to gdrive...") 
    cd $env.MY_ENV_VARS.debs; cd ..
    7z max debs debs/
    mv -f debs.7z $env.MY_ENV_VARS.gdrive_debs
  }
}

#audio to text transcription via whisper
export def "ai audio2text" [
  filename                    #audio file input
  --language(-l) = "Spanish"  #language of audio file
  --output_format(-o) = "txt" #output format: txt, vtt, srt, tsv, json, all
  --translate(-t)             #translate audio to english
  --notify(-n)                #notify to android via ntfy
] {
  let file = ($filename | path parse | get stem)

  print (echo-g $"reproduce ($filename) and select start and end time for noise segment, leave empty if no noise..." )
  let start = (input "start? (hh:mm:ss): ")
  let end = (input "end? (hh:mm:ss): ")

  if ($start | is-empty) or ($end | is-empty) {
    print (echo-g "generating temp file...")
    if ($filename | path parse | get extension) =~ "mp3" {
      cp $filename $"($file)-clean.mp3"
    } else {
      ffmpeg -loglevel 1 -i $"($filename)" -acodec libmp3lame -ab 128k -vn $"($file)-clean.mp3"
    }
  } else {
    media remove-noise $filename $start $end 0.2 $"($file)-clean" -d false -E mp3
  }

  print (echo-g "transcribing to text...")
  match $translate {
    false => {whisper $"($file)-clean.mp3" --language $language --output_format $output_format --verbose False --fp16 False},
    true => {whisper $"($file)-clean.mp3" --language $language --output_format $output_format --verbose False --fp16 False --task translate}
  }

  if $notify {"transcription finished!" | ntfy-send}
}

#screen record to text transcription 
export def "ai screen2text" [
  --summary(-s) = true #whether to summarize the transcription. false means it just extracts audio
  --notify(-n)         #notify to android via ntfy
] {
  let file = (date now | format date "%Y%m%d_%H%M%S")

  if not ("~/Documents/Transcriptions" | path exists) {
    ^mkdir -p ~/Documents/Transcriptions 
  }

  cd ~/Documents/Transcriptions
  
  try {
    media screen-record $file
  }

  media extract-audio $"($file).mp4"

  ai audio2text $"($file).mp3"

  if $notify {"audio extracted!" | ntfy-send}

  if $summary {
    ai transcription-summary $"($file | path parse | get stem)-clean.txt"
    if $notify {"summary finished!" | ntfy-send}
  }
}

#video to text transcription 
export def "ai video2text" [
  file?:string                #video file name with extension
  --language(-l):string = "Spanish"  #language of audio file
  --summary(-s):bool = true   #whether to transcribe or not. False means it just extracts audio
  --notify(-n)                #notify to android via ntfy
] {
  let file = if ($file | is-empty) {$in} else {$file}
  
  media extract-audio $file

  ai audio2text $"($file | path parse | get stem).mp3" -l $language

  if $notify {"audio extracted!" | ntfy-send}

  if $summary {
    ai transcription-summary $"($file | path parse | get stem)-clean.txt"
    if $notify {"summary finished!" | ntfy-send}
  }
}

#resume transcription text via gpt 
export def "ai transcription-summary" [
  file                #text file name with transcription text
  --gpt4(-g) = false  #whether to use gpt-4-turbo (default false)
  --upload(-u) = true #whether to upload to gdrive (default true) 
  --notify(-n)        #notify to android via ntfy
] {
  #removing existing temp files
  ls | where name =~ "split|summaries" | rm-pipe

  #definitions
  let up_folder = $env.MY_ENV_VARS.gdriveTranscriptionSummaryDirectory
  let mounted = ($up_folder | path expand | path exists)
  let output = $"($file | path parse | get stem)_summary.md"

  # dealing with the case when the transcription files has too many words for chatgpt
  let max_words = if $gpt4 {85000} else {10000}
  let n_words = (wc -w $file | awk '{print $1}' | into int)

  if $n_words > $max_words {
    print (echo-g $"splitting input file ($file)...")

    let filenames = $"($file | path parse | get stem)_split_"

    let split_command = ("awk '{total+=NF; print > " + $"\"($filenames)\"" + "sprintf(\"%03d\",int(total/" + $"($max_words)" + "))" + "\".txt\"}'" + $" \"($file)\"")
  
    bash -c $split_command

    let files = (ls | find split | where name !~ summary)

    $files | each {|split_file|
      ai transcription-summary-single ($split_file | get name | ansi strip) -u false -g $gpt4
    }

    let temp_output = $"($file | path parse | get stem)_summaries.md"
    print (echo-g $"combining the results into ($temp_output)...")
    touch $temp_output

    let files = (ls | find split | find summary | enumerate)

    $files | each {|split_file|
      echo $"\n\nParte ($split_file.index):\n\n" | save --append $temp_output
      open ($split_file.item.name | ansi strip) | save --append $temp_output
      echo "\n" | save --append $temp_output
    }

    let prompt = (open $temp_output)

    print (echo-g $"asking chatgpt to combine the results in ($temp_output)...")
    if $gpt4 {
      chat_gpt $prompt -t 0.5 --select_system meeting_summarizer --select_preprompt consolidate_transcription -d -m "gpt-4-turbo" | save -f $output
    } else {
      chat_gpt $prompt -t 0.5 --select_system meeting_summarizer --select_preprompt consolidate_transcription -d | save -f $output
    }

    if $upload {
      if not $mounted {
        print (echo-g "mounting gdrive...")
        mount-ubb
      }

      print (echo-g "uploading summary to gdrive...")
      cp $output $up_folder
    }

    if $notify {"summary finished!" | ntfy-send}
    return
  }
  
  ai transcription-summary-single $file -u $upload -g $gpt4 
  if $notify {"summary finished!" | ntfy-send}
}

#resume transcription via gpt in one go
export def "ai transcription-summary-single" [
  file                #text file name with transcription text
  --gpt4(-g) = false  #whether to use gpt-4 (default false)
  --upload(-u) = true #whether to upload to gdrive (default true) 
] {
  let up_folder = $env.MY_ENV_VARS.gdriveTranscriptionSummaryDirectory
  let mounted = ($up_folder | path expand | path exists)
  let output = $"($file | path parse | get stem)_summary.md"

  let prompt = (open $file)

  print (echo-g $"asking chatgpt for a summary of the file ($file)...")
  if $gpt4 {
    chat_gpt $prompt -t 0.5 --select_system meeting_summarizer --select_preprompt summarize_transcription -d -m "gpt-4-turbo" | save -f $output
  } else {
    chat_gpt $prompt -t 0.5 --select_system meeting_summarizer --select_preprompt summarize_transcription -d | save -f $output
  }

  if $upload {
    if not $mounted {
      print (echo-g "mounting gdrive...")
      mount-ubb
    }

    print (echo-g "uploading summary to gdrive...")
    cp $output $up_folder
  }
}

#audio 2 transcription summary via chatgpt
export def "ai audio2summary" [
  file
  --gpt4(-g)          #whether to use gpt-4 (default false)
  --upload(-u) = true #whether to upload the summary and audio to gdrive (dafault true)
  --notify(-n)        #notify to android via ntfy
] {
  ai audio2text $file
  ai transcription-summary $"($file | path parse | get stem)-clean.txt" -u $upload -g $gpt4
  if $upload {
    print (echo-g $"uploading ($file)...")
    cp $"($file | path parse | get stem)-clean.mp3" ($env.MY_ENV_VARS.gdriveTranscriptionSummaryDirectory)
  }
  if $notify {"summary finished!" | ntfy-send}
}

#generate subtitles of video file via whisper and mymemmory/openai api
#
#`? trans` and `whisper --help` for more info on languages
export def "ai generate-subtitles" [
  file                               #input video file
  --language(-l) = "en-US/English"   #language of input video file, mymmemory/whisper
  --translate(-t) = false            #to translate to spanish
  --notify(-n)                       #notify to android via ntfy
] {
  let filename = ($file | path parse | get stem)

  media extract-audio $file 
  ai audio2text $"($filename).mp3" -o srt -l ($language | split row "/" | get 1)

  if $notify {"subtitle generated!" | ntfy-send}

  if $translate {
    media trans-sub $"($filename).srt" --from ($language | split row "/" | get 0)
    if $notify {"subtitle translated!" | ntfy-send}
  }
}

#generate subtitles of video file via whisper and mymemmory api for piping
#
#`? trans` and `whisper --help` for more info on languages
export def "ai generate-subtitles-pipe" [
  --language(-l) = "en-US/English"   #language of input video file, mymmemory/whisper
  --translate(-t)                    #to translate to spanish
] {
  $in
  | get name 
  | each {|file| 
      ai generate-subtitles ($file | ansi strip) -l $language -t $translate
    }
}

#get a summary of a youtube video via chatgpt
#
#Two characters words for languages
#es: spanish
#fr: french
export def "ai yt-summary" [
  url?:string       # video url
  --lang = "en"     # language of the summary (default english: en)
  --gpt4(-g)        # to use gpt4-turbo instead of gpt-3.5
  --notify(-n)      # notify to android via ntfy
] {
  #deleting previous temp file
  if ((ls | find yt_temp | length) > 0) {rm yt_temp* | ignore}
  
  #getting the subtitle
  yt-dlp -N 10 --write-info-json $url --output yt_temp

  let video_info = (open yt_temp.info.json)
  let title = ($video_info | get title)
  let subtitles_info = ($video_info | get subtitles?)
  let languages = ($subtitles_info | columns)
  let the_language = ($languages | find $lang)

  if ($the_language | is-empty) {
    #first try auto-subs then whisper
    yt-dlp -N 10 --write-auto-subs $url --output yt_temp

    if ((ls | find yt_temp | find vtt | length) > 0) {
      ffmpeg -i (ls yt_temp*.vtt | get 0 | get name) $"($title).srt"
    } else {
      print (echo-g "downloading audio...")
      yt-dlp --extract-audio --audio-format mp3 --audio-quality 0 $url -o $"($title).mp3"

      print (echo-g "transcribing audio...")
      whisper $"($title).mp3" --output_format srt --verbose False --fp16 False
    }
  } else {
    let sub_url = (
      $subtitles_info 
      | get ($the_language | get 0) 
      | where ext =~ "srt|vtt" 
      | get url 
      | get 0
    )
    http get $sub_url | save -f $"($title).srt"
  }
  print (echo-g $"transcription file saved as ($title).srt")
  let the_subtitle = $"($title).srt"

  #removing existing temp files
  ls | where name =~ "split|summaries" | rm-pipe

  #definitions
  let output = $"($title)_summary.md"

  # dealing with the case when the transcription files has too many words for chatgpt
  let max_words = if $gpt4 {85000} else {10000}
  let n_words = (wc -w $the_subtitle | awk '{print $1}' | into int)

  if $n_words > $max_words {
    print (echo-g $"splitting transcription of ($title)...")

    let filenames = $"($title)_split_"

    let split_command = ("awk '{total+=NF; print > " + $"\"($filenames)\"" + "sprintf(\"%03d\",int(total/" + $"($max_words)" + "))" + "\".txt\"}'" + $" \"($the_subtitle)\"")
  
    bash -c $split_command

    let files = (ls | find split | where name !~ summary | ansi strip-table)

    $files | each {|split_file|
      let t_input = (open ($split_file | get name))
      let t_output = ($split_file | get name | path parse | get stem)
      ai yt-transcription-summary $t_input $t_output -g $gpt4
    }

    let temp_output = $"($title)_summaries.md"
    print (echo-g $"combining the results into ($temp_output)...")
    touch $temp_output

    let files = (ls | find split | find summary | enumerate)

    $files | each {|split_file|
      echo $"\n\nResumen de la parte ($split_file.index):\n\n" | save --append $temp_output
      open ($split_file.item.name | ansi strip) | save --append $temp_output
      echo "\n" | save --append $temp_output
    }

    let prompt = (open $temp_output)

    print (echo-g $"asking chatgpt to combine the results in ($temp_output)...")
    if $gpt4 {
      chat_gpt $prompt -t 0.5 --select_system ytvideo_summarizer --select_preprompt consolidate_ytvideo -d -m "gpt-4-turbo" | save -f $output
    } else {
      chat_gpt $prompt -t 0.5 --select_system ytvideo_summarizer --select_preprompt consolidate_ytvideo -d | save -f $output
    }

    if $notify {"summary finished!" | ntfy-send}
    return
  }
  
  ai yt-transcription-summary (open $the_subtitle) $output -g $gpt4
  if $notify {"summary finished!" | ntfy-send}
}

#resume youtube video transcription text via gpt
export def "ai yt-transcription-summary" [
  prompt              #transcription text
  output              #output name without extension
  --gpt4(-g) = false  #whether to use gpt-4 (default false)
  --notify(-n)        #notify to android via ntfy
] {
  let output_file = $"($output)_summary.md"

  print (echo-g $"asking chatgpt for a summary of the file ($output)...")
  if $gpt4 {
    chat_gpt $prompt -t 0.5 --select_system ytvideo_summarizer --select_preprompt summarize_ytvideo -d -m "gpt-4-turbo" | save -f $output_file
  } else {
    chat_gpt $prompt -t 0.5 --select_system ytvideo_summarizer --select_preprompt summarize_ytvideo -d | save -f $output_file
  }
  if $notify {"summary finished!" | ntfy-send}
}

#get a summary of a video or audio via chatgpt
#
#Two characters words for languages
#es: spanish
#fr: french
export def "ai media-summary" [
  file:string            # video, audio or subtitle file (vtt, srt) file name with extension
  --lang(-l) = "Spanish" # language of the summary
  --gpt4(-g)             # to use gpt4 instead of gpt-3.5
  --notify(-n)           # notify to android via ntfy
] {
  let file = if ($file | is-empty) {$in | get name} else {$file}
  let title = ($file | path parse | get stem) 
  let extension = ($file | path parse | get extension) 
  let media_type = (askgpt $"does the extension file format ($extension) correspond to and audio, video or subtitle file? Please only return your response in json format, with the unique key 'answer' and one of the key values: video, audio, subtitle or none." | from json | get answer)

  if $media_type =~ video {
    ai video2text $file -l $lang
  } else if $media_type =~ audio {
    ai audio2text $file -l $lang
  } else if $media_type =~ subtitle {
    if $extension !~ "vtt|srt" {
      return-error "subtitle file extension not supported!"
    }
    if $extension =~ vtt {
      ffmpeg -i $file -f srt $"($title)-clean.txt"
    } else {
      mv -f $file $"($title)-clean.txt"
    }
  } else {
    return-error $"wrong media type: ($extension)"
  }

  print (echo-g $"transcription file saved as ($title)-clean.txt")
  let the_subtitle = $"($title)-clean.txt"

  #removing existing temp files
  ls | where name =~ "split|summaries" | rm-pipe

  #definitions
  let output = $"($title)_summary.md"

  # dealing with the case when the transcription files has too many words for chatgpt
  let max_words = if $gpt4 {85000} else {10000}
  let n_words = (wc -w $the_subtitle | awk '{print $1}' | into int)

  if $n_words > $max_words {
    print (echo-g $"splitting transcription of ($title)...")

    let filenames = $"($title)_split_"

    let split_command = ("awk '{total+=NF; print > " + $"\"($filenames)\"" + "sprintf(\"%03d\",int(total/" + $"($max_words)" + "))" + "\".txt\"}'" + $" \"($the_subtitle)\"")
  
    bash -c $split_command

    let files = (ls | find split | where name !~ summary | ansi strip-table)

    $files | each {|split_file|
      let t_input = (open ($split_file | get name))
      let t_output = ($split_file | get name | path parse | get stem)
      ai yt-transcription-summary $t_input $t_output -g $gpt4
    }

    let temp_output = $"($title)_summaries.md"
    print (echo-g $"combining the results into ($temp_output)...")
    touch $temp_output

    let files = (ls | find split | find summary | enumerate)

    $files | each {|split_file|
      echo $"\n\nResumen de la parte ($split_file.index):\n\n" | save --append $temp_output
      open ($split_file.item.name | ansi strip) | save --append $temp_output
      echo "\n" | save --append $temp_output
    }

    let prompt = (open $temp_output)

    print (echo-g $"asking chatgpt to combine the results in ($temp_output)...")
    if $gpt4 {
      chat_gpt $prompt -t 0.5 --select_system ytvideo_summarizer --select_preprompt consolidate_ytvideo -d -m "gpt-4-turbo" | save -f $output
    } else {
      chat_gpt $prompt -t 0.5 --select_system ytvideo_summarizer --select_preprompt consolidate_ytvideo -d | save -f $output
    }

    if $notify {"summary finished!" | ntfy-send}
    return
  }
  
  ai yt-transcription-summary (open $the_subtitle) $output -g $gpt4
  if $notify {"summary finished!" | ntfy-send}
}

#single call to openai dall-e models
#
#For dall-e-2 the only available size is 1024x1024 that is sent by default.
#
#The mask is and additional image whose fully transparent areas (e.g. where alpha is zero) indicate where the image should be edited. The prompt should describe the full new image, not just the erased area.
#
#When editing/variating images, consider that the uploaded image and mask must both be square PNG images less than 4MB in size, and also must have the same dimensions as each other. The non-transparent areas of the mask are not used when generating the output, so they don’t necessarily need to match the original image like the example above. 
#
#For generation, available sizes are; 1024x1024, 1024x1792, 1792x1024 (default).
#For editing/variation, available sizes are: 256x256, 512x512, 1024x1024 (default).
export def dall_e [
    prompt?: string                     # the query to dall-e
    --output(-o):string                 # png output image file name
    --model(-m):string = "dall-e-2"     # the model: dall-e-2, dall-e-3
    --task(-t):string = "generation"    # the method to use: generation, edit, variation
    --number(-n):int = 1                # number of images to generate. Dall-e 3 = 1
    --size(-s):string                   # size of output image
    --quality(-q):string = "standard"   # quality of output image: standard, hd (only dall-e-3)
    --image(-i):string                  # image base for editing and variation
    --mask(-k):string                   # masked image for editing
] {
  #error checking
  let prompt = if ($prompt | is-empty) {$in} else {$prompt}
  if ($prompt | is-empty) and ($task =~ "generation|edit") {
    return-error "Empty prompt!!!"
  }

  if $model not-in ["dall-e-2","dall-e-3"] {
    return-error "Wrong model!!!"
  }

  #methods
  let header = [Authorization $"Bearer ($env.MY_ENV_VARS.api_keys.open_ai.api_key)"]

  match $task {
    "generation" => {
        let output = (
          if ($output | is-empty) {
            (chat_gpt --select_preprompt dalle_image_name -d $prompt | from json | get name) + "_G"
          } else {
            $output
          }
        )

        let size = if ($size | is-empty) {"1792x1024"} else {$size}

        if $size not-in ["1024x1024", "1024x1792", "1792x1024"] {
          return-error "Requested image sizes not available!!!" 
        }

        let size = if $model == "dall-e-2" {"1024x1024"} else {$size}
        let number = if $model == "dall-e-3" {1} else {$number}
        let quality = if $model == "dall-e-2" {"standard"} else {$quality}

        if $number > 10 {
          return-error "Max. number of requested images is 10!!!"
        }

        #translate prompt if not in english
        let english = chat_gpt --select_preprompt is_in_english -d $prompt | from json | get english | into bool
        let prompt = if $english {chat_gpt --select_preprompt translate_dalle_prompt -d $prompt} else {$prompt}

        let site = "https://api.openai.com/v1/images/generations"

        let request = {
          "model": $model,
          "prompt": $prompt,
          "n": $number,
          "size": $size
        }

        let answer = http post -t application/json -H $header $site $request 

        $answer.data.url 
        | enumerate
        | each {|img| 
            print (echo-g $"downloading image ($img.index | into string)...")
            http get $img.item | save -f $"($output)_($img.index).png"
          }
      },

    "edit" => {
        let output = if ($output | is-empty) {($image | path parse | get stem) + "_E"} else {$output}
        let size = if ($size | is-empty) {"1024x1024"} else {$size}

        if $size not-in ["1024x1024", "512x512", "256x256"] {
          return-error "Requested image sizes not available!!!" 
        }

        if $model == "dall-e-3" {
          return-error "Dall-e-3 doesn't allow edits!!!"
        }

        if ($image | is-empty) or ($mask | is-empty) {
          return-error "image and mask needed for editing!!!"
        }

        let header = $"Authorization: Bearer ($env.MY_ENV_VARS.api_keys.open_ai.api_key)"

        let image = media crop-image $image --name        
        let mask = media crop-image $mask --name

        #translate prompt if not in english
        let english = chat_gpt --select_preprompt is_in_english $prompt | from json | get english | into bool
        let prompt = if $english {chat_gpt --select_preprompt translate_dalle_prompt -d $prompt} else {$prompt}

        let site = "https://api.openai.com/v1/images/edits"

        # let answer = http post -t application/x-www-form-urlencoded -H $header $site $request 
        let answer = bash -c ("curl -s " + $site + " -H '" + $header + "' -F model='" + $model + "' -F n=" + ($number | into string) + " -F size='" + $size + "' -F image='@" + $image + "' -F mask='@" + $mask + "' -F prompt='" + $prompt + "'")

        $answer
        | from json
        | get data.url
        | enumerate
        | each {|img| 
            print (echo-g $"downloading image ($img.index | into string)...")
            http get $img.item | save -f $"($output)_($img.index).png"
          }
      },

    "variation" => {
        let output = if ($output | is-empty) {($image | path parse | get stem) + "_V"} else {$output}
        let size = if ($size | is-empty) {"1024x1024"} else {$size}

        if $size not-in ["1024x1024", "512x512", "256x256"] {
          return-error "Requested image sizes not available!!!" 
        }

        if $model == "dall-e-3" {
          return-error "Dall-e-3 doesn't allow variations!!!"
        }

        if ($image | is-empty) {
          return-error "image needed for variation!!!"
        }

        let header = $"Authorization: Bearer ($env.MY_ENV_VARS.api_keys.open_ai.api_key)"

        let image = media crop-image $image --name        

        let site = "https://api.openai.com/v1/images/variations"

        # let answer = http post -t application/x-www-form-urlencoded -H $header $site $request 
        let answer = bash -c ("curl -s " + $site + " -H '" + $header + "' -F model='" + $model + "' -F n=" + ($number | into string) + " -F size='" + $size + "' -F image='@" + $image + "'")

        $answer
        | from json
        | get data.url
        | enumerate
        | each {|img| 
            print (echo-g $"downloading image ($img.index | into string)...")
            http get $img.item | save -f $"($output)_($img.index).png"
          }
      },
    
    _ => {return-error $"$(task) not available!!!"}
  }
}

#fast call to the dall-e wrapper
#
#For more personalization and help check `? dall_e`
export def askdalle [
  prompt?:string  #string with the prompt, can be piped
  --dalle3(-d)    #use dall-e-3 instead of dall-e-2 (default)
  --edit(-e)      #use edition mode instead of generation
  --variation(-v) #use variation mode instead of generation
  --fast(-f)      #get prompt from ~/Yandex.Disk/ChatGpt/prompt.md
  --image(-i):string #image to use in edition mode or variation
  --mask(-k):string  #mask to use in edition mode
  --output(-o):string #filename for output images, default used if not present
  --number(-n):int = 1 #number of images to generate
  --size(-s):string = "1792x1024" #size of the output image
  --quality(-q):string = "standard" #quality of the output image: standard or hd
] {
  let prompt = (
    if not $fast {
      if ($prompt | is-empty) {$in} else {$prompt}
    } else {
      open ~/Yandex.Disk/ChatGpt/prompt.md
    }
  )

  match [$dalle3,$edit,$variation] {
    [true,false,false]  => {
        dall_e $prompt -o $output -m "dall-e-3" -t "generation" -n $number -s $size -q $quality -i $image -k $mask
      },
    [false,false,false]  => {
        dall_e $prompt -o $output -t "generation" -n $number -s $size -q $quality -i $image -k $mask
      },
    [true,true,false]  => {
        dall_e $prompt -o $output -m "dall-e-3" -t "edit" -n $number -s $size -q $quality -i $image -k $mask
        },
    [false,true,false]  => {
        dall_e $prompt -o $output -t "edit" -n $number -s $size -q $quality -i $image -k $mask
      },
    [true,false,true]  => {
        dall_e $prompt -o $output -m "dall-e-3" -t "variation" -n $number -s $size -q $quality -i $image -k $mask
      },
    [false,false,true]  => {
        dall_e $prompt -o $output -t "variation" -n $number -s $size -q $quality -i $image -k $mask
      },
    _ => {return-error "Combination of flags not allowed!"}
  }
}

#openai text-to-speech wrapper
#
#Available models are: tts-1, tts-1-hd
#
#Available voices are: alloy, echo, fable, onyx, nova, and shimmer
#
#Available formats are: mp3, opus, aac and flac
export def "ai tts" [
  prompt?:string                  #text to convert to speech
  --model(-m):string = "tts-1"    #model of the output
  --voice(-v):string = "nova"     #voice selection
  --output(-o):string = "speech"  #output file name
  --format(-f):string = "mp3"     #output file format
] {
  let prompt = if ($prompt | is-empty) {$in} else {$prompt}
  let output = if ($output | is-empty) {"speech"} else {$output}

  let header = [Authorization $"Bearer ($env.MY_ENV_VARS.api_keys.open_ai.api_key)"]

  let url = "https://api.openai.com/v1/audio/speech"

  let request = {
    "model": $model,
    "input": $prompt,
    "voice": $voice
  }

  http post -t application/json -H $header $url $request | save -f $"($output).($format)"
} 

#fast call to `ai tts` with most parameters as default
export def tts [
  prompt?:string #text to convert to speech
  --hd(-h)       #use hd model
  --output(-o):string #output file name    
] {
  if $hd {
    ai tts -m tts-1-hd -o $output $prompt
  } else {
    ai tts -o $output $prompt
  }
}