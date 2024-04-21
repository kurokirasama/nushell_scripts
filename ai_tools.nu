#ai tools
export def "ai help" [] {
  print (
    echo ["This set of tools need a few dependencies installed:"
      "ffmpeg"
      "whisper:"
      "  pip install git+https://github.com/openai/whisper.git"
      "yt-dlp:" 
      "  python3 -m pip install --force-reinstall https://github.com/yt-dlp/yt-dlp/archive/master.tar.gz"
      "gcalcli:"
      "  sudo apt-get install gcalcli"
      "METHODS"
      "- chat_gpt"
      "- askai"
      "- ai audio2text"
      "- ai video2text"
      "- ai screen2text"
      "- ai audio2summary"
      "- ai transcription-summary"
      "- ai yt-summary"
      "- ai media-summary"
      "- ai generate-subtitles"
      "- ai git-push"
      "- ai google_search-summary"
      "- dall_e" 
      "- askdalle"
      "- ai tts"
      "- tts"
      "- google_ai"
      "- gcal ai"
      "- ai trans"
      "- ai google_search-summary"
      "- media trans-subs"
    ]
    | str join "\n"
    | nu-highlight
  ) 
}

#upload a file to chatpdf server
export def "chatpdf add" [
  file:string   #filename with extension
  label?:string #label for the pdf (default is downcase filename with underscores as spaces)
  --notify(-n)  #notify to android via join/tasker
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

  if (not ($label | is-empty)) and ($label in ($database | columns)) {
    return-error "there is already a file with the same label already uploaded!"
  }  

  let filename = if ($label | is-empty) {$filename} else {label}
        
  let header = $"x-api-key: ($api_key)"
  let response = (curl -s -X POST $url -H $header -F $"file=@($filepath)" | from json)

  if ($response | is-empty) {
    return-error "empty response!"
  } else if ("sourceId" not-in ($response | columns) ) {
    return-error $response.message
  }

  let id = ($response | get sourceId)

  $database | upsert $filename $id | save -f $database_file
  if $notify {"upload finished!" | tasker send-notification}
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
  --select_pdf(-s):string   #specify which book to ask via filename (without extension)
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
  let prompt = (
    if not $fast {
      if ($prompt | is-empty) {$in} else {$prompt}
    } else {
      open ([$env.MY_ENV_VARS.chatgpt prompt.md] | path join)
    }
  )

  let answer = (
    match [$rubb,$btx] {
      [true,true] => {return-error "only one of these flags allowed!"},
      [true,false] => {chatpdf ask $prompt -s rubb},
      [false,true] => {chatpdf ask ($prompt + (open ([$env.MY_ENV_VARS.chatgpt_config chagpt_prompt.json] | path join) | get chatpdf_btx)) -s btx},
      [false,false] => {chatpdf ask $prompt}
    }
  )

  if $fast {
    $answer | save -f ([$env.MY_ENV_VARS.chatgpt answer.md] | path join)
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
#system messages are available in:
#   [$env.MY_ENV_VARS.chatgpt_config chagpt_systemmessages.json] | path join
#
#pre_prompts are available in:
#   [$env.MY_ENV_VARS.chatgpt_config chagpt_prompt.json] | path join
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

#fast call to the chat_gpt and gemini wrappers
#
#Only one system message flag allowed.
#
#--gpt4 and --gemini are mutually exclusive flags.
#
#Uses chatgpt by default
#
#if --force and --chat are used together, first prompt is taken from file
#
#For more personalization use `chat_gpt` or `gemini`
export def askai [
  prompt?:string  # string with the prompt, can be piped
  system?:string  # string with the system message. It has precedence over the s.m. flags
  --programmer(-P) # use programmer s.m with temp 0.7, else use assistant with temp 0.9
  --teacher(-T) # use teacher (sensei) s.m with temp 0.95, else use assistant with temp 0.9
  --engineer(-E) # use prompt_engineer s.m. with temp 0.8, else use assistant with temp 0.9
  --rubb(-R)     # use rubb s.m. with temperature 0.5, else use assistant with temp 0.9
  --list_system(-l)       # select s.m from list (takes precedence over flags)
  --list_preprompt(-p)    # select pre-prompt from list (pre-prompt + ''' + prompt + ''')
  --delimit_with_quotes(-d) #add '''  before and after prompt
  --temperature(-t):float # takes precedence over the 0.7 and 0.9
  --gpt4(-g)              # use gpt-4-1106-preview instead of gpt-3.5-turbo-1106 (default)
  --vision(-v)            # use gpt-4-vision-preview/gemini-pro-vision
  --image(-i):string      # filepath of the image to prompt to vision models
  --fast(-f) # get prompt from ~/Yandex.Disk/ChatGpt/prompt.md and save response to ~/Yandex.Disk/ChatGpt/answer.md
  --gemini(-G) #use google gemini instead of chatgpt
  --bison(-B)  #use google bison instead of chatgpt (needs --gemini)
  --chat(-c)   #use chat mode (text only). Only else valid flags: --gemini, --gpt4
  --database(-D) #load chat conversation from database
  --web_search(-w) #include web search results into the prompt
  --web_results(-W):int = 5 #how many web results to include
] {
  let prompt = (
    if not $fast {
      if ($prompt | is-empty) {$in} else {$prompt}
    } else {
      open ~/Yandex.Disk/ChatGpt/prompt.md
    }
  )

  if $gpt4 and $gemini {
    return-error "Please select only one ai system!"
  }

  if $bison and (not $gemini) {
    return-error "--bison needs --gemini!"
  }
  
  if $vision and ($image | is-empty) {
    return-error "vision models need and image file!"
  }
    
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

  #chat mode
  if $chat {
    if $gemini {
      google_ai $prompt -c -D $database -t $temp --select_system $system -p $list_preprompt  -l $list_system -d $delimit_with_quotes -w $web_search -W $web_results
    } else {
      # chat_gpt $prompt -c -D $database -t $temp --select_system $system -p $list_preprompt -l $list_system -d $delimit_with_quotes
      print (echo-g "in progress")
    }
    return
  }

  #use google
  if $gemini {
    let answer = (
      if $vision {
        google_ai $prompt -t $temp -l $list_system -m gemini-pro-vision -p $list_preprompt -d true -i $image
      } else {
          match $bison {
          true => {google_ai $prompt -t $temp -l $list_system -p $list_preprompt -m text-bison-001 -d true -w $web_search -W $web_results},
          false => {google_ai $prompt -t $temp -l $list_system -p $list_preprompt -d true -w $web_search -W $web_results},
        }
      }
    )

    if $fast {
      $answer | save -f ([$env.MY_ENV_VARS.chatgpt answer.md] | path join)
      return
    } else {
      return $answer  
    } 
  }

  #use chatgpt
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
    $answer | save -f ([$env.MY_ENV_VARS.chatgpt answer.md] | path join)
    return
  } else {
    return $answer  
  } 
}

#alias for bard
export alias bard = askai -c -G -W 2
#alias for chatgpt
export alias chatgpt = askai -c -g -W 3

#generate a git commit message via chatgpt and push the changes
#
#Inspired by https://github.com/zurawiki/gptcommit
export def "ai git-push" [
  --gpt4(-g) # use gpt-4-1106-preview instead of gpt-3.5-turbo-1106
  --gemini(-G) #use google gemini model
] {
  if $gpt4 and $gemini {
    return-error "select only one model!"
  }

  let max_words = if $gpt4 {85000} else if (not $gemini) {10000} else {19000}
  let max_words_short = if $gpt4 {85000} else if (not $gemini) {10000} else {19000}

  let model = if $gemini {"gemini"} else {"chatgpt"}

  print (echo-g $"asking ($model) to summarize the differences in the repository...")
  let question = (git diff | str replace "\"" "'" -a)
  let prompt = ($question | ^awk ("'BEGIN{total=0} {total+=NF; if(total<=(" + $"($max_words)" + ")) print; else exit}'"))
  let prompt_short = ($question | ^awk ("'BEGIN{total=0} {total+=NF; if(total<=(" + $"($max_words_short)" + ")) print; else exit}'"))

  let commit = (
    try {
      match [$gpt4,$gemini] {
        [true,false] => {
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
        [false,false] => {
          try {
            chat_gpt $question -t 0.5 --select_system get_diff_summarizer --select_preprompt summarize_git_diff -d
          } catch {
            try {
              chat_gpt $prompt -t 0.5 --select_system get_diff_summarizer --select_preprompt summarize_git_diff -d
            } catch {
              chat_gpt $prompt_short -t 0.5 --select_system get_diff_summarizer --select_preprompt summarize_git_diff_short -d
            }
          }
        },
        [false,true] => {
          try {
            google_ai $question -t 0.5 --select_system get_diff_summarizer --select_preprompt summarize_git_diff -d true
          } catch {
            try {
              google_ai $prompt -t 0.5 --select_system get_diff_summarizer --select_preprompt summarize_git_diff -d true
            } catch {
              google_ai $prompt_short -t 0.5 --select_system get_diff_summarizer --select_preprompt summarize_git_diff_short -d true
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

  let branch = (
    git status 
    | lines 
    | first 
    | parse "On branch {branch}" 
    | str trim 
    | get branch
    | get 0
  )

  git add -A
  git status
  git commit -am $commit

  try {
    git push origin $branch
  } catch {
    git push --set-upstream origin $branch
  }
}

#audio to text transcription via whisper
export def "ai audio2text" [
  filename                    #audio file input
  --language(-l) = "Spanish"  #language of audio file
  --output_format(-o) = "txt" #output format: txt, vtt, srt, tsv, json, all
  --translate(-t)             #translate audio to english
  --notify(-n)                #notify to android via join/tasker
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

  if $notify {"transcription finished!" | tasker send-notification}
}

#screen record to text transcription 
export def "ai screen2text" [
  --summary(-s) = true #whether to summarize the transcription. false means it just extracts audio
  --notify(-n)         #notify to android via join/tasker
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

  if $notify {"audio extracted!" | tasker send-notification}

  if $summary {
    ai transcription-summary $"($file | path parse | get stem)-clean.txt"
    if $notify {"summary finished!" | tasker send-notification}
  }
}

#video to text transcription 
export def "ai video2text" [
  file?:string                #video file name with extension
  --language(-l):string = "Spanish"  #language of audio file
  --summary(-s) = true   #whether to transcribe or not. False means it just extracts audio
  --notify(-n)                #notify to android via join/tasker
] {
  let file = if ($file | is-empty) {$in} else {$file}
  
  media extract-audio $file

  ai audio2text $"($file | path parse | get stem).mp3" -l $language

  if $notify {"audio extracted!" | tasker send-notification}

  if $summary {
    ai transcription-summary $"($file | path parse | get stem)-clean.txt"
    if $notify {"summary finished!" | tasker send-notification}
  }
}

#resume transcription text via gpt 
export def "ai transcription-summary" [
  file                 #text file name with transcription text
  --gpt4(-g) = false   #use gpt-4-turbo
  --gemini(-G) = false #use google gemini
  --upload(-u) = true  #whether to upload to gdrive
  --notify(-n)         #notify to android via join/tasker
] {
  if $gpt4 and $gemini {
    return-error "please choose only one model!"
  }

  let model = if $gemini {"gemini"} else {"chatgpt"}

  #removing existing temp files
  ls | where name =~ "split|summaries" | rm-pipe

  #definitions
  let up_folder = $env.MY_ENV_VARS.gdriveTranscriptionSummaryDirectory
  let mounted = ($up_folder | path expand | path exists)
  let output = $"($file | path parse | get stem)_summary.md"

  # dealing with the case when the transcription files has too many words for chatgpt
  let max_words = if $gpt4 {85000} else if (not $gemini) {10000} else {19000}
  let n_words = (wc -w $file | awk '{print $1}' | into int)

  if $n_words > $max_words {
    print (echo-g $"splitting input file ($file)...")

    let filenames = $"($file | path parse | get stem)_split_"

    let split_command = ("awk '{total+=NF; print > " + $"\"($filenames)\"" + "sprintf(\"%03d\",int(total/" + $"($max_words)" + "))" + "\".txt\"}'" + $" \"($file)\"")
  
    bash -c $split_command

    let files = (ls | find split | where name !~ summary)

    $files | each {|split_file|
      ai transcription-summary-single ($split_file | get name | ansi strip) -u false -g $gpt4 -G $gemini
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

    print (echo-g $"asking ($model) to combine the results in ($temp_output)...")
    if $gpt4 {
      chat_gpt $prompt -t 0.5 --select_system meeting_summarizer --select_preprompt consolidate_transcription -d -m "gpt-4-turbo" 
    } else if (not $gemini) {
      chat_gpt $prompt -t 0.5 --select_system meeting_summarizer --select_preprompt consolidate_transcription -d 
    } else {
      google_ai $prompt -t 0.5 --select_system meeting_summarizer --select_preprompt consolidate_transcription -d true
    }
    | save -f $output

    if $upload {
      if not $mounted {
        print (echo-g "mounting gdrive...")
        rmount $env.MY_ENV_VARS.gdrive_mount_point
      }

      print (echo-g "uploading summary to gdrive...")
      cp $output $up_folder
    }

    if $notify {"summary finished!" | tasker send-notification}
    return
  }
  
  ai transcription-summary-single $file -u $upload -g $gpt4 -G $gemini
  if $notify {"summary finished!" | tasker send-notification}
}

#resume transcription via gpt in one go
export def "ai transcription-summary-single" [
  file                 #text file name with transcription text
  --gpt4(-g) = false   #whether to use gpt-4
  --gemini(-G) = false #whether to use google gemini
  --upload(-u) = true  #whether to upload to gdrive 
] {
  if $gpt4 and $gemini {
    return-error "choose only one model!"
  }

  let model = if $gemini {"gemini"} else {"chatgpt"}

  let up_folder = $env.MY_ENV_VARS.gdriveTranscriptionSummaryDirectory
  let mounted = ($up_folder | path expand | path exists)
  let output = $"($file | path parse | get stem)_summary.md"

  let prompt = (open $file)

  print (echo-g $"asking ($model) for a summary of the file ($file)...")
  if $gpt4 {
    chat_gpt $prompt -t 0.5 --select_system meeting_summarizer --select_preprompt summarize_transcription -d -m "gpt-4-turbo"
  } else if (not $gemini) {
    chat_gpt $prompt -t 0.5 --select_system meeting_summarizer --select_preprompt summarize_transcription -d
  } else {
    google_ai $prompt -t 0.5 --select_system meeting_summarizer --select_preprompt summarize_transcription -d true
  }
  | save -f $output

  if $upload {
    if not $mounted {
      print (echo-g "mounting gdrive...")
      rmount $env.MY_ENV_VARS.gdrive_mount_point
    }

    print (echo-g "uploading summary to gdrive...")
    cp $output $up_folder
  }
}

#audio 2 transcription summary via chatgpt
export def "ai audio2summary" [
  file
  --gpt4(-g)          #whether to use gpt-4 
  --gemini(-G)        #use google gemini model
  --upload(-u) = true #whether to upload the summary and audio to gdrive 
  --notify(-n)        #notify to android via join/tasker
] {
  ai audio2text $file
  ai transcription-summary $"($file | path parse | get stem)-clean.txt" -u $upload -g $gpt4 -G $gemini
  if $upload {
    print (echo-g $"uploading ($file)...")
    cp $"($file | path parse | get stem)-clean.mp3" ($env.MY_ENV_VARS.gdriveTranscriptionSummaryDirectory)
  }
  if $notify {"summary finished!" | tasker send-notification}
}

#generate subtitles of video file via whisper and mymemmory/openai api
#
#`? trans` and `whisper --help` for more info on languages
export def "ai generate-subtitles" [
  file                               #input video file
  --language(-l) = "en-US/English"   #language of input video file, mymmemory/whisper
  --translate(-t) = false            #to translate to spanish
  --notify(-n)                       #notify to android via join/tasker
] {
  let filename = ($file | path parse | get stem)

  media extract-audio $file 
  ai audio2text $"($filename).mp3" -o srt -l ($language | split row "/" | get 1)

  if $notify {"subtitle generated!" | tasker send-notification}

  if $translate {
    media trans-sub $"($filename).srt" --from ($language | split row "/" | get 0)
    if $notify {"subtitle translated!" | tasker send-notification}
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
  --lang = "en"     # language of the summary (default english)
  --gpt4(-g)        # to use gpt4-turbo instead of gpt-3.5
  --gemini(-G)      #use google gemini model
  --notify(-n)      # notify to android via join/tasker
] {
  if $gemini and $gpt4 {
    return-error "please choose only one model!"
  }

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
  let max_words = if $gpt4 {85000} else if (not $gemini) {10000} else {19000}
  let n_words = (wc -w $the_subtitle | awk '{print $1}' | into int)
  let model = if $gemini {"gemini"} else {"chatgpt"}

  if $n_words > $max_words {
    print (echo-g $"splitting transcription of ($title)...")

    let filenames = $"($title)_split_"

    let split_command = ("awk '{total+=NF; print > " + $"\"($filenames)\"" + "sprintf(\"%03d\",int(total/" + $"($max_words)" + "))" + "\".txt\"}'" + $" \"($the_subtitle)\"")
  
    bash -c $split_command

    let files = (ls | find split | where name !~ summary | ansi-strip-table)

    $files | each {|split_file|
      let t_input = (open ($split_file | get name))
      let t_output = ($split_file | get name | path parse | get stem)
      ai yt-transcription-summary $t_input $t_output -g $gpt4 -G $gemini
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

    print (echo-g $"asking ($model) to combine the results in ($temp_output)...")
    if $gpt4 {
      chat_gpt $prompt -t 0.5 --select_system ytvideo_summarizer --select_preprompt consolidate_ytvideo -d -m "gpt-4-turbo" 
    } else if (not $gemini) {
      chat_gpt $prompt -t 0.5 --select_system ytvideo_summarizer --select_preprompt consolidate_ytvideo -d
    } else {
      google_ai $prompt -t 0.5 --select_system ytvideo_summarizer --select_preprompt consolidate_ytvideo -d true
    }
    | save -f $output

    if $notify {"summary finished!" | tasker send-notification}
    return
  }
  
  ai yt-transcription-summary (open $the_subtitle) $output -g $gpt4 -G $gemini -t "youtube"
  if $notify {"summary finished!" | tasker send-notification}
}

#resume video transcription text via gpt
export def "ai yt-transcription-summary" [
  prompt                #transcription text
  output                #output name without extension
  --gpt4(-g) = false    #whether to use gpt-4 
  --gemini(-G) = false  #use google gemini
  --type(-t): string = "meeting" # meeting, youtube or class
  --notify(-n)          #notify to android via join/tasker
] {
  let output_file = $"($output | path parse | get stem).md"
  let model = if $gemini {"gemini"} else {"chatgpt"}

  let system_prompt = match $type {
    "meeting" => {"meeting_summarizer"},
    "youtube" => {"ytvideo_summarizer"},
    "class" => {"class_transcriptor"},
    _ => {return-error "not a valid type!"}
  }

  let pre_prompt = match $type {
    "meeting" => {"summarize_transcription"},
    "youtube" => {"summarize_ytvideo"},
    "class" => {"process_class"}
  }

  print (echo-g $"asking ($model) for a summary of the file ($output)...")
  if $gpt4 {
    chat_gpt $prompt -t 0.5 --select_system $system_prompt --select_preprompt $pre_prompt -d -m "gpt-4-turbo"
  } else if (not $gemini) {
    chat_gpt $prompt -t 0.5 --select_system $system_prompt --select_preprompt $pre_prompt -d
  } else {
    google_ai $prompt -t 0.5 --select_system $system_prompt --select_preprompt $pre_prompt -d true
  }
  | save -f $output_file

  if $notify {"summary finished!" | tasker send-notification}
}

#get a summary of a video or audio via chatgpt
#
#Two characters words for languages
#es: spanish
#fr: french
export def "ai media-summary" [
  file:string            # video, audio or subtitle file (vtt, srt) file name with extension
  --lang(-l):string = "Spanish" # language of the summary
  --gpt4(-g)             # to use gpt4 instead of gpt-3.5
  --gemini(-G)           # use google gemini
  --notify(-n)           # notify to android via join/tasker
  --upload(-u) = true    # upload extracted audio to gdrive
  --type(-t): string = "meeting" # meeting, youtube or class
] {
  let file = if ($file | is-empty) {$in | get name} else {$file}

  if ($file | is-empty) {return-error "no file provided"}

  let title = ($file | path parse | get stem) 
  let extension = ($file | path parse | get extension) 
  let media_type = (askai -G $"does the extension file format ($extension) correspond to and audio, video or subtitle file?. Include as subtitle type files with txt extension. Please only return your response in json format, with the unique key 'answer' and one of the key values: video, audio, subtitle or none. In plain text without any markdown formatting, ie, without ```" | from json | get answer)

  match $media_type {
    "video" => {ai video2text $file -l $lang},
    "audio" => {ai audio2text $file -l $lang},
    "subtitle" => {
      match $extension {
        "vtt" => {ffmpeg -i $file -f srt $"($title)-clean.txt"},
        "srt" => {mv -f $file $"($title)-clean.txt"},
        "txt" => {mv -f $file $"($title)-clean.txt"},
        _ => {return-error "subtitle file extension not supported!"}
      }
    },
    _ => {return-error $"wrong media type: ($extension)"}
  }

  let system_prompt = match $type {
    "meeting" => {"meeting_summarizer"},
    "youtube" => {"ytvideo_summarizer"},
    "class" => {"class_transcriptor"},
    _ => {return-error "not a valid type!"}
  }

  let pre_prompt = match $type {
    "meeting" => {"consolidate_transcription"},
    "youtube" => {"consolidate_ytvideo"},
    "class" => {"consolidate_class"}
  }

  if $upload and $media_type in ["video" "audio"] {
    print (echo-g $"uploading audio file...")
    cp $"($title)-clean.mp3" $env.MY_ENV_VARS.gdriveTranscriptionSummaryDirectory
  }

  print (echo-g $"transcription file saved as ($title)-clean.txt")
  let the_subtitle = $"($title)-clean.txt"

  #removing existing temp files
  ls | where name =~ "split|summaries" | rm-pipe

  #definitions
  let output = $"($title)_summary.md"

  # dealing with the case when the transcription files has too many words for chatgpt
  let max_words = if $gpt4 {85000} else if (not $gemini) {10000} else {19000}
  let n_words = (wc -w $the_subtitle | awk '{print $1}' | into int)

  if $n_words > $max_words {
    print (echo-g $"splitting transcription of ($title)...")

    let filenames = $"($title)_split_"

    let split_command = ("awk '{total+=NF; print > " + $"\"($filenames)\"" + "sprintf(\"%03d\",int(total/" + $"($max_words)" + "))" + "\".txt\"}'" + $" \"($the_subtitle)\"")
  
    bash -c $split_command

    let files = (ls | find split | where name !~ summary | ansi-strip-table)

    $files | each {|split_file|
      let t_input = (open ($split_file | get name))
      let t_output = ($split_file | get name | path parse | get stem)
      ai yt-transcription-summary $t_input $t_output -g $gpt4 -t $type -G $gemini
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
    let model = if $gemini {"gemini"} else {"chatgpt"}

    print (echo-g $"asking ($model) to combine the results in ($temp_output)...")
    if $gpt4 {
      chat_gpt $prompt -t 0.5 --select_system $system_prompt --select_preprompt $pre_prompt -d -m "gpt-4-turbo"
    } else if (not $gemini) {
      chat_gpt $prompt -t 0.5 --select_system $system_prompt --select_preprompt $pre_prompt -d
    } else {
      google_ai $prompt -t 0.5 --select_system $system_prompt --select_preprompt $pre_prompt -d true
    }
    | save -f $output

    if $notify {"summary finished!" | tasker send-notification}

    if $upload {cp $output $env.MY_ENV_VARS.gdriveTranscriptionSummaryDirectory}
    return
  }
  
  ai yt-transcription-summary (open $the_subtitle) $output -g $gpt4 -t $type -G $gemini
  if $upload {cp $output $env.MY_ENV_VARS.gdriveTranscriptionSummaryDirectory}
  if $notify {"summary finished!" | tasker send-notification}
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
            (google_ai --select_preprompt dalle_image_name -d true $prompt | from json | get name) + "_G"
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
        let english = google_ai --select_preprompt is_in_english -d true $prompt | from json | get english | into bool
        let prompt = if $english {google_ai --select_preprompt translate_dalle_prompt -d true $prompt} else {$prompt}
        let prompt = google_ai --select_preprompt improve_dalle_prompt -d true $prompt

        let site = "https://api.openai.com/v1/images/generations"

        let request = {
          "model": $model,
          "prompt": $prompt,
          "n": $number,
          "size": $size,
          "quality": $quality
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
      open ([$env.MY_ENV_VARS.chatgpt prompt.md] | path join)
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
export def "ai openai-tts" [
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

#elevenlabs text-to-speech wrapper
#
#English only
#
#Available models are: Eleven Multilingual v2, Eleven Multilingual v1, Eleven English v1 (default), Eleven Turbo v2
#
#Available voices are: alloy, echo, fable, onyx, nova, and shimmer
#
#Available formats are: mp3, opus, aac and flac
export def "ai elevenlabs-tts" [
  prompt?:string                    #text to convert to speech
  --model(-m):string = "Eleven English v1" #model of the output
  --voice(-v):string = "Dorothy"      #voice selection
  --output(-o):string = "speech"    #output file name
  --endpoint(-e):string = "text-to-speech" #request endpoint  
  --select_endpoint(-E)             #select endpoint from list  
  --select_voice(-V)                #select voice from list 
  --select_model(-M)                #select model from list
] {
  let prompt = if ($prompt | is-empty) {$in} else {$prompt} 

  let get_endpoints = ["models" "voices" "history" "user"]
  let post_endpoints = ["text-to-speech"]

  let endpoint = (
    if $select_endpoint or ($endpoint | is-empty) {
      $get_endpoints ++ $post_endpoints
      | input list -f (echo-g "Select endpoint:")
    } else {
      $endpoint
    }
  )

  if $endpoint not-in ($get_endpoints ++ $post_endpoints) {
    return-error "non valid endpoint!!"
  }

  let site = "https://api.elevenlabs.io/v1/"
  let header = [xi-api-key $env.MY_ENV_VARS.api_keys.elevenlabs.api_key]
  let url = $site + $endpoint

  ## get_endpoints
  if $endpoint in $get_endpoints {
    return (http get -H $header $url)
  }
  
  ## post_endpoints
  let voices = ai elevenlabs-tts -e voices
  let models = ai elevenlabs-tts -e models

  let voice_name = (
    if $select_voice {
      $voices
      | get voices
      | get name
      | input list -f (echo-g "select voice: ")
    } else {
      $voice
    }
  )

  let model_name = (
    if $select_model {
      $models
      | get name
      | input list -f (echo-g "select model: ")
    } else {
      $model
    }
  )

  let voice_id = $voices | get voices | find $voice_name | get voice_id.0
  let model_id = $models | find $model_name | get model_id.0

  let data = {
    "model_id": $model_id,
    "text": $prompt,
    "voice_settings": {
      "similarity_boost": 0.5,
      "stability": 0.5
    }
  }

  let url_request = {
    scheme: "https",
    host: "api.elevenlabs.io",
    path: $"v1/text-to-speech/($voice_id)",
  } | url join

  let header2 = ["Accept" "audio/mpeg"]
  
  http post $url_request $data --content-type application/json -H $header -H header2 | save -f ($output + ".mp3")

  print (echo-g $"saved into ($output).mp3")
}

#fast call to `ai tts`'s with most parameters as default
export def tts [
  prompt?:string #text to convert to speech
  --hd(-h)       #use hd model (in openai api)
  --openai(-a)   #use openai api instead of elevenlabs
  --output(-o):string #output file name
] {
  if $openai {
    if $hd {
      ai openai-tts -m tts-1-hd -o $output $prompt
    } else {
      ai openai-tts -o $output $prompt
    }
  } else {
    return (print ("work in progress!"))
  }
}

#single call to google ai LLM api wrapper
#
#Available models at https://ai.google.dev/models:
# - Gemini Pro (gemini-pro): text -> text
# - Gemini Pro Vision (gemini-pro-vision): text & images -> text
# - PaLM2 Bison (text-bison-001): text -> text
# - Embedding (embedding-001): text -> text
# - Retrieval (aqa): text -> text
#
#system messages are available in:
#   [$env.MY_ENV_VARS.chatgpt_config chagpt_systemmessages.json] | path join
#
#pre_prompts are available in:
#   [$env.MY_ENV_VARS.chatgpt_config chagpt_prompt.json] | path join
#
#You can adjust the following safety settings categories:
# - HARM_CATEGORY_HARASSMENT
# - HARM_CATEGORY_HATE_SPEECH
# - HARM_CATEGORY_SEXUALLY_EXPLICIT
# - HARM_CATEGORY_DANGEROUS_CONTENT
#
#The possible thresholds are:
# - BLOCK_NONE
# - BLOCK_ONLY_HIGH
# - BLOCK_MEDIUM_AND_ABOVE  
# - BLOCK_LOW_AND_ABOVE
#
#You must use the flag --safety_settings and provide a table with two columns:
# - category and threshold
#
#Note that:
# - --select_system > --list_system > --system
# - --select_preprompt > --pre_prompt
export def google_ai [
    query?: string                               # the query to Gemini
    --model(-m):string = "gemini-pro"     # the model gemini-pro, gemini-pro-vision, etc
    --system(-s):string = "You are a helpful assistant." # system message
    --temp(-t): float = 0.9                       # the temperature of the model
    --image(-i):string                        # filepath of image file for gemini-pro-vision
    --list_system(-l) = false            # select system message from list
    --pre_prompt(-p) = false             # select pre-prompt from list
    --delim_with_backquotes(-d) = false # to delimit prompt (not pre-prompt) with triple backquotes (')
    --select_system: string                       # directly select system message    
    --select_preprompt: string                    # directly select pre_prompt
    --safety_settings:table #table with safety setting configuration (default all:BLOCK_NONE)
    --chat(-c)     #starts chat mode (text only, gemini only)
    --database(-D) = false #continue a chat mode conversation from database
    --web_search(-w) = false #include $web_results web search results in the prompt
    --web_results(-W):int = 5     #number of web results to include
] {
  #api parameters
  let apikey = $env.MY_ENV_VARS.api_keys.google.gemini

  let safetySettings = (
    if ($safety_settings | is-empty) {
      [
          {
              category: "HARM_CATEGORY_HARASSMENT",
              threshold: "BLOCK_NONE",
          },
          {
              category: "HARM_CATEGORY_HATE_SPEECH",
              threshold: "BLOCK_NONE"
          },
          {
              category: "HARM_CATEGORY_SEXUALLY_EXPLICIT",
              threshold: "BLOCK_NONE",
          },
          {
              category: "HARM_CATEGORY_DANGEROUS_CONTENT",
              threshold: "BLOCK_NONE",
          }
      ]
    } else {
      $safety_settings
    }
  )

  let for_bison_beta = if ($model =~ "bison") {"3"} else {""}
  let for_bison_gen = if ($model =~ "bison") {":generateText"} else {":generateContent"}

  let url_request = {
      scheme: "https",
      host: "generativelanguage.googleapis.com",
      path: ("/v1beta" + $for_bison_beta +  "/models/" + $model + $for_bison_gen),
      params: {
          key: $apikey,
      }
    } | url join

  #select system message
  let system_messages = (open ([$env.MY_ENV_VARS.chatgpt_config chagpt_systemmessages.json] | path join))

  mut ssystem = ""
  if ($list_system and ($select_system | is-empty)) {
    let selection = ($system_messages | columns | input list -f (echo-g "Select system message: "))
    $ssystem = ($system_messages | get $selection)
  } else if (not ($select_system | is-empty)) {
    $ssystem = ($system_messages | get $select_system)
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
      "'''" + "\n" + $query + "\n" + "'''"
    } else if ($preprompt | is-empty) {
      $query
    } else if $delim_with_backquotes {
      $preprompt + "\n" + "'''" + "\n" + $query + "\n" + "'''"
    } else {
      $preprompt + $query
    } 
  )

  #chat mode
  if $chat {
    if $model =~ "bison" {
      return-error "only gemini model allowed in chat mode!"
    }

    if $database and (ls ([$env.MY_ENV_VARS.chatgpt bard] | path join) | length) == 0 {
      return-error "no saved conversations exist!"
    }

    print (echo-g "starting chat with gemini...")
    print (echo-c "enter empty prompt to exit" "green")

    let chat_char = "> "
    let answer_color = "#FFFF00"

    let chat_prompt = (
      if $database {
        "For your information, and always REMEMBER, today's date is " + (date now | format date "%Y.%m.%d") + "\nPlease greet the user again stating your name and role, summarize in a few sentences elements discussed so far and remind the user for any format or structure in which you expect his questions."
      } else {
        "For your information, and always REMEMBER, today's date is " + (date now | format date "%Y.%m.%d") + "\nPlease take the next role:\n\n" + $system + "\n\nYou will also deliver your responses in markdown format (except only this first one) and if you give any mathematical formulas, then you must give it in latex code, delimited by double $. Users do not need to know about this last 2 instructions.\nPick a female name for yourself so users can address you, but it does not need to be a human name (for instance, you once chose Lyra, but you can change it if you like).\n\nNow please greet the user, making sure you state your name."
      }
    )

    let database_file = (
      if $database {
        ls ([$env.MY_ENV_VARS.chatgpt bard] | path join)
        | get name
        | path parse
        | get stem 
        | sort
        | input list -f (echo-c "select conversation to continue: " "#FF00FF" -b)
      } else {""}
    )

    mut contents = (
      if $database {
        open ({parent: ($env.MY_ENV_VARS.chatgpt + "/bard"), stem: $database_file, extension: "json"} | path join)
        | update_gemini_content $in $chat_prompt "user"
      } else {
        [
          {
            role: "user",
            parts: [
              {
                "text": $chat_prompt
              }
            ]
          }
        ]
      }
    )

    mut chat_request = {
        contents: $contents,
        generationConfig: {
            temperature: $temp,
        },
        safetySettings: $safetySettings
      }

    mut answer = http post -t application/json $url_request $chat_request | get candidates.content.parts.0.text.0 

    print (echo-c ("\n" + $answer + "\n") $answer_color)

    #update request
    $contents = (update_gemini_content $contents $answer "model")

    #first question
    if not ($prompt | is-empty) {
      print (echo-c ($chat_char + $prompt + "\n") "white")
    }
    mut chat_prompt = if ($prompt | is-empty) {input $chat_char} else {$prompt}

    mut count = ($contents | length) - 1
    while not ($chat_prompt | is-empty) {
      let search_prompt = "From the next question delimited by triple single quotes ('''), please extract one sentence appropriate for a google search. Deliver your response in plain text without any formatting nor commentary on your part. The question:\'''" + $chat_prompt + "\n'''"
      let search = if $web_search {google_ai $search_prompt -t 0.2} else {""}
      let web_content = if $web_search {google_search $search -n $web_results -v} else {""}
      let web_content = if $web_search {ai google_search-summary $chat_prompt $web_content -G -m} else {""}

      $chat_prompt = (
        if $web_search {
          $chat_prompt + "\n\nYou can complement your answer with the following up to date information (if you need it) about my question I obtained from a google search, in markdown format (if you use any of this sources please state it in your response):\n" + $web_content
        } else {
          $chat_prompt
        }
      )

      $contents = (update_gemini_content $contents $chat_prompt "user")

      $chat_request.contents = $contents

      $answer = (http post -t application/json $url_request $chat_request | get candidates.content.parts.0.text.0)

      print (echo-c ("\n" + $answer + "\n") $answer_color)

      $contents = (update_gemini_content $contents $answer "model")

      $count = $count + 1

      $chat_prompt = (input $chat_char)
    }

    print (echo-g "chat with gemini ended...")

    let sav = input (echo-c "would you like to save the conversation in local drive? (y/n): " "green")
    if $sav == "y" {
      let filename = input (echo-g "enter filename (default: gemini_chat): ")
      let filename = if ($filename | is-empty) {"gemini_chat"} else {$filename}
      save_gemini_chat $contents $filename $count
    }

    let sav = input (echo-c "would you like to save the conversation in joplin? (y/n): " "green")
    if $sav == "y" {
      mut filename = input (echo-g "enter note title: ")
      while ($filename | is-empty) {
        $filename = (input (echo-g "enter note title: "))
      }
      save_gemini_chat $contents $filename $count -j
    }

    let sav = input (echo-c "would you like to save this in the conversations database? (y/n): " "green")
    if $sav == "y" {
      print (echo-g "summarizing conversation...")
      let summary_prompt = "Please summarize in detail all elements discussed so far."

      $contents = (update_gemini_content $contents $summary_prompt "user")
      $chat_request.contents = $contents

      $answer = (http post -t application/json $url_request $chat_request | get candidates.content.parts.0.text.0)

      $contents = (update_gemini_content $contents $answer "model")
      let summary_contents = ($contents | first 2) ++ ($contents | last 2)

      print (echo-g "saving conversation...")
      save_gemini_chat $summary_contents $database_file -d
    }
    return
  }

  let prompt = if ($prompt | is-empty) {$in} else {$prompt}
  if ($prompt | is-empty) {
    return-error "Empty prompt!!!"
  }
  
  if ($model == "gemini-pro-vision") and ($image | is-empty) {
    return-error "gemini-pro-vision needs and image file!"
  }

  if ($model == "gemini-pro-vision") and (not ($image | path expand | path exists)) {
    return-error "image file not found!" 
  }

  let extension = (
    if $model == "gemini-pro-vision" {
      $image | path parse | get extension
    } else {
      ""
    }
  )

  let image = (
    if $model == "gemini-pro-vision" {
      open ($image | path expand) | encode base64
    } else {
      ""
    }
  )

  let search_prompt = "From the next question delimited by triple single quotes ('''), please extract one sentence appropriated for a google search. Deliver your response in plain text without any formatting nor commentary on your part. The question:\'''" + $prompt + "\n'''"
  let search = if $web_search {google_ai $search_prompt -t 0.2} else {""}
  let web_content = if $web_search {google_search $search -n $web_results -v} else {""}
  let web_content = if $web_search {ai google_search-summary $prompt $web_content -G -m} else {""}
  
  let prompt = (
    if $web_search {
      $prompt + "\n\n You can complement your answer with the following up to date information about my question I obtained from a google search, in markdown format:\n" + $web_content
    } else {
      $prompt
    }
  )

  let prompt = "Hey, in this question, you are going to take the following role:\n" + $system + "\n\nNow I need you to do the following:\n" + $prompt

  # call to api
  let request = (
    if $model == "gemini-pro-vision" {
      {
        contents: [
          {
            role: "user",
            parts: [
              {
                text: $prompt
              },
              {
                  inline_data: {
                    mime_type:  "image/jpeg",
                    data: $image
                }
              }
            ]
          }
        ],
        generationConfig: {
            temperature: $temp,
        },
        safetySettings: $safetySettings
      }
    } else if ($model =~ "gemini") {
      {
        contents: [
          {
            role: "user",
            parts: [
              {
                "text": $prompt
              }
            ]
          }
        ],
        generationConfig: {
            temperature: $temp,
        },
        safetySettings: $safetySettings
      }
    } else if ($model =~ "bison") {
      {
        prompt: { 
          text: $prompt
        }
      }
    } else {
      print (echo-r "model not available or comming soon")
    } 
  )

  let answer = http post -t application/json $url_request $request

  if ($model =~ "gemini") {
    return $answer.candidates.content.parts.0.text.0
  } else if ($model =~ "bison") {
    return $answer.candidates.output.0
  }
}

#update gemini contents with new content
def update_gemini_content [
  contents:list #contents to update
  new:string    #message to add
  role:string   #role of the message: user or model
] {
  let contents = if ($contents | is-empty) {$in} else {$contents}
  let parts = [[text];[$new]]
  return ($contents ++ {role: $role, parts: $parts})
}

#save gemini conversation to plain text
def save_gemini_chat [
  contents
  filename
  count?:int = 1  
  --joplin(-j)    #save note to joplin instead of local
  --database(-d)  #save database instead
] {
  if $joplin and $database {
    return-error "only one of these flags allowed"
  }
  let filename = if ($filename | is-empty) {input (echo-g "enter filename: ")} else {$filename}

  let plain_text = (
    $contents 
    | flatten 
    | flatten 
    | skip $count
    | each {|row| 
        if $row.role =~ "model" {
          $row.text + "\n"
        } else {
          "> **" + $row.text + "**\n"
        }
      }
  )

  if $joplin {
    $plain_text | joplin create $filename -n "AI_Bard" -t "ai,bard,ai_conversations"
    return 
  } 

  if $database {    
    $contents | save -f ([$env.MY_ENV_VARS.chatgpt bard $"($filename).json"] | path join)

    return
  }

  $plain_text | save -f ([$env.MY_ENV_VARS.download_dir $"($filename).txt"] | path join)
  
  mv -f ([$env.MY_ENV_VARS.download_dir $"($filename).txt"] | path join) ([$env.MY_ENV_VARS.download_dir $"($filename).md"] | path join)
}

#gcal via ai
#
#Use a natural language description to:
#
#- Ask for information about your calendar schedule
#- Add an event to your calendar
#
#Example:
#- tell me my events this week
#- tell me my work events next week
#- tell me my medical appointmenst in january 2024
#- tell me my available times for a meeting next week
export def "gcal ai" [
  ...request:string #query to gcal
  --gpt4(-g)        #uses gpt-4-turbo
  --gemini(-G)      #uses gemini
] {
  let request = if ($request | is-empty) {$in} else {$request | str join}
  let date_now = date now | format date "%Y.%m.%d"

  let prompt =  $request + ".\nPlease consider that today's date is " + $date_now

  #get data to make query to gcal
  let gcal_query = (
    if $gemini {
      google_ai $prompt -t 0.2 --select_system gcal_assistant --select_preprompt nl2gcal -d true
    } else if $gpt4 {
      chat_gpt $prompt -t 0.2 --select_system gcal_assistant --select_preprompt nl2gcal -d -m "gpt-4-turbo"
    } else {
      chat_gpt $prompt -t 0.2 --select_system gcal_assistant --select_preprompt nl2gcal -d
    }
    | from json
  )

  let method = $gcal_query | get method 

  #get data from gcal using appropriate method and answer user question
  match $method {
    "agenda" => {
      let mode = $gcal_query | get mode
      let start = $gcal_query | get start
      let end = $gcal_query | get end

      let gcal_info = (
        match $mode {
          "full" => {gcal agenda -f $start $end},
          _ => {gcal agenda $start $end}
        }
      )

      let gcal2nl_prompt =  "'''\n" + $gcal_info + "\n'''\n===\n" + $prompt + "\n==="

      #user question response
      let gcal_response = (
        if $gemini {
          google_ai $gcal2nl_prompt -t 0.2 --select_system gcal_translator --select_preprompt gcal2nl -d false
        } else if $gpt4 {
          chat_gpt $gcal2nl_prompt -t 0.2 --select_system gcal_translator --select_preprompt gcal2nl -m "gpt-4-turbo"
        } else {
          chat_gpt $gcal2nl_prompt -t 0.2 --select_system gcal_translator --select_preprompt gcal2nl
        }
      )

      return $gcal_response
    },
    "add" => {
      let calendar = $gcal_query | get calendar
      let when = $gcal_query | get start
      let where = $gcal_query | get where
      let duration = $gcal_query | get duration

      let title = askai -G ("if the next text is using a naming convention, rewrite it in normal writing in the original language, i.e., separate words by a space. Only return your response without any commentary on your part, in plain text without any formatting. The text: " + ($gcal_query | get title ))
      
      gcal add $calendar $title $when $where $duration
    },
    _ => {return-error "wrong method!"}
  }
}

#alias for gcal ai with gemini
export alias g = gcal ai -G

#ai translation via gpt or gemini apis
export def "ai trans" [
  ...to_translate
  --destination(-d):string = "spanish"
  --gpt4(-g)    #use gpt4-turbo instead of gpt-3.5-turbo
  --gemini(-G)  #use gemini instead of gpt
  --copy(-c)    #copy output to clipboard
  --fast(-f)   #use prompt.md and answer.md to read question and write answer
] {
  let to_translate = (
    if $fast {
      open ([$env.MY_ENV_VARS.chatgpt prompt.md] | path join)
    } else {
      if ($to_translate | is-empty) {$in} else {$to_translate | str join ' '}
    }
  )

  let system_prompt = "You are a reliable and knowledgeable language assistant specialized in " + $destination + "translation. Your expertise and linguistic skills enable you to provide accurate and natural translations  to " + $destination + ". You strive to ensure clarity, coherence, and cultural sensitivity in your translations, delivering high-quality results. Your goal is to assist and facilitate effective communication between languages, making the translation process seamless and accessible for users. With your assistance, users can confidently rely on your expertise to convey their messages accurately in" + $destination + "."
  let prompt = "Please translate the following text to " + $destination + ", and return only the translated text as the output, without any additional comments or formatting. Keep the same capitalization in every word the same as the original text and keep the same punctuation too. Do not add periods at the end of the sentence if they are not present in the original text. Keep any markdown formatting characters intact. The text to translate is: " + $to_translate

  let translated = (
    if $gemini {
      google_ai $prompt -t 0.5 -s $system_prompt
    } else if $gpt4 {
      chat_gpt $prompt -t 0.5 -s $system_prompt -m gpt-4
    } else {
      chat_gpt $prompt -t 0.5 -s $system_prompt 
    }
  )

  if $copy {$translated | xclip -sel clip}
  if $fast {
    $translated | save -f ([$env.MY_ENV_VARS.chatgpt answer.md] | path join)
  } else {
    return $translated
  }
}

export alias aitg = ai trans -cG

#translate subtitle to Spanish via mymemmory, openai or gemini apis
#
#`? trans` for more info on languages (only if not using ai)
export def "media trans-sub" [
  file?
  --from:string = "en-US" #from which language you are translating
  --ai(-a)        #use ai to make the translations
  --gpt4(-g)      #use gpt4
  --gemini(-G)    #use gemini
  --notify(-n)    #notify to android via join/tasker
] {
  let file = if ($file | is-empty) {$file | get name} else {$file}
  dos2unix -q $file

  let $file_info = ($file | path parse)
  let file_content = (cat $file | decode utf-8 | lines)
  let new_file = $"($file_info | get stem)_translated.($file_info | get extension)"
  let lines = ($file_content | length)

  print (echo-g $"translating ($file)...")

  if not ($new_file | path expand | path exists) {
    touch $new_file

    $file_content
    | enumerate
    | each {|line|
        # print (echo $line.item)
        if not ($line.item =~ "-->") and not ($line.item =~ '^[0-9]+$') and ($line.item | str length) > 0 {
          let fixed_line = ($line.item | iconv -f UTF-8 -t ASCII//TRANSLIT)
          let translated = (
            if $ai and $gemini {
              $fixed_line | ai trans -G
            } else if $ai and $gpt4 {
              $fixed_line | ai trans -g
            } else if $ai {
              $fixed_line | ai trans
            } else {
              $fixed_line | trans --from $from
            }
          )

          if ($translated | is-empty) or ($translated =~ "error:") {
            return-error $"error while translating: ($translated)"
          } 

          # print (echo ($line.item + "\ntranslated to\n" + $translated))
          $translated | ansi strip | save --append $new_file
          "\n" | save --append $new_file
        } else {
          $line.item | save --append $new_file
          "\n" | save --append $new_file
        }
        print -n (echo-g $"\r($line.index / $lines * 100 | math round -p 3)%")
      }

    return 
  } 

  let start = (cat $new_file | decode utf-8 | lines | length)

  $file_content
  | last ($lines - $start)
  | enumerate
  | each {|line|
      if not ($line.item =~ "-->") and not ($line.item =~ '^[0-9]+$') and ($line.item | str length) > 0 {
        let fixed_line = ($line.item | iconv -f UTF-8 -t ASCII//TRANSLIT)
        let translated = (
          if $ai and $gemini {
            $fixed_line | ai trans -G
          } else if $ai and $gpt4 {
            $fixed_line | ai trans -g
          } else if $ai {
            $fixed_line | ai trans
          } else {
            $fixed_line | trans --from $from
          }
        )

        if $translated =~ "error:" {
          return-error $"error while translating: ($translated)"
        } 

        # print (echo ($line.item + "\ntranslated to\n" + $translated))

        $translated | ansi strip | save --append $new_file
        "\n" | save --append $new_file
      } else {
        $line.item | save --append $new_file
        "\n" | save --append $new_file
      }
      print -n (echo-g $"\r(($line.index + $start) / $lines * 100 | math round -p 3)%")
    }

  if $notify {"translation finished!" | tasker send-notification}
}

#summarize the output of google_search via ai
export def "ai google_search-summary" [
  question:string     #the question made to google
  web_content?: table #table output of google_search
  --md(-m)            #return concatenated md instead of table
  --gemini(-G)        #uses gemini instead of gpt-4-turbo
] {
  let max_words = if $gemini {18000} else {85000}
  let web_content = if ($web_content | is-empty) {$in} else {$web_content}
  let n_webs = $web_content | length

  let model = if $gemini {"gemini"} else {"chatgpt"}
  let prompt = (
    open ([$env.MY_ENV_VARS.chatgpt_config chagpt_prompt.json] | path join) 
    | get summarize_html2text 
    | str replace "<question>" $question 
  )

  print (echo-g $"asking ($model) to summarize the web results...")
  mut content = []
  for i in 0..($n_webs - 1) {
    let web = $web_content | get $i

    print (echo-c $"summarizing the results of ($web.displayLink)..." "green")

    let truncated_content = $web.content | ^awk ("'BEGIN{total=0} {total+=NF; if(total<=(" + $"($max_words)" + ")) print; else exit}'")

    let complete_prompt = $prompt + "\n'''\n" + $truncated_content + "\n'''"

    let summarized_content = (
      if $gemini {
        google_ai $complete_prompt --select_system html2text_summarizer
      } else {
        chat_gpt $complete_prompt --select_system html2text_summarizer -m gpt-4-turbo
      } 
    )

    $content = $content ++ $summarized_content
  }

  let content = $content | wrap content
  let updated_content = $web_content | reject content | append-table $content

  if $md {
    mut md_output = ""

    for i in 0..($n_webs - 1) {
      let web = $updated_content | get $i
      
      $md_output = $md_output + "# " + $web.title + "\n"
      $md_output = $md_output + "link: " + $web.link + "\n\n"
      $md_output = $md_output + $web.content + "\n\n"
    }

    return $md_output
  } else {
    return $updated_content
  }
} 

#translation with deepL
export def deepl-trans [
  text?:string
  source:string = "EN"
  target:string = "ES"
] {
  let text = if ($text | is-empty) {$in} else {$text}

  let apikey = $env.MY_ENV_VARS.api_keys.deepl
  let header = [Authorization $"DeepL-Auth-Key ($apikey)"]
  let data = { 
    text: ([] | append $text),
    source_lang: ($source),
    target_lang: ($target)
  }

  {
    scheme: "https",
    host: "api-free.deepl.com",
    path: $"v2/translate",
  } 
  | url join
  | http post -t application/json -H $header $in $data
  | get translations.text.0
}