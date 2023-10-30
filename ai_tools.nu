#ai tools
export def "ai help" [] {
  print (
    echo "This set of tools need a few dependencies installed:\n
      ffmpeg\n
      whisper:\n
        pip install git+https://github.com/openai/whisper.git\n
      yt-dlp:\n 
        python3 -m pip install --force-reinstall https://github.com/yt-dlp/yt-dlp/archive/master.tar.gz\n
      METHODS\n
      - chat_gpt
      - askgpt
      - ai audio2text
      - ai video2text
      - ai screen2text
      - ai audio2summary
      - ai transcription-summary
      - ai yt-summary
      - ai media-summary
      - ai generate-subtitles
      - ai git-push\n"
    | nu-highlight
  ) 
}

#single call chatgpt wrapper
export def chat_gpt [
    prompt?: string                               # the query to Chat GPT
    --model(-m):string = "gpt-3.5-turbo"                 # the model gpt-3.5-turbo, gpt-4, etc
    --system(-s):string = "You are a helpful assistant." # system message
    --temp(-t): float = 0.9                       # the temperature of the model
    --list_system(-l)                             # select system message from list
    --pre_prompt(-p)                              # select pre-prompt from list
    --select_system: string                       # directly select system message    
    --select_preprompt: string                    # directly select pre_prompt
    --delim_with_backquotes(-d)                   # to delimit prompt (not pre-prompt) with triple backquotes (')
    --large_model(-k):bool = false                # use gpt-3.5-turbo-16k (gpt-4-32k) if model is gpt-3.5-turbo (gpt-4)
    #
    #Available models at https://platform.openai.com/docs/models, but some of them are:
    # - gpt-4 (8192 tokens)
    # - gpt-4-32k (32768 tokens)
    # - gpt-3.5-turbo (4096 tokens)
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
] {
  let prompt = if ($prompt | is-empty) {$in} else {$prompt}
  if ($prompt | is-empty) {
    return-error "Empty prompt!!!"
  }

  #define model
  let model = (
    if $large_model {
      if $model == "gpt-3.5-turbo" {
        "gpt-3.5-turbo-16k"
      } else if $model == "gpt-4" {
        "gpt-4-32k"
      } else {
        $model
      }
    } else {
      $model
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
  let header = [Authorization $"Bearer ($env.MY_ENV_VARS.api_keys.open_ai.api_key)"]
  let site = "https://api.openai.com/v1/chat/completions"
  let request = {
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
      ]
      temperature: $temp
  }

  let answer = (http post -t application/json -H $header $site $request)  
  return $answer.choices.0.message.content
}

#fast call to the chat_gpt wrapper
export def askgpt [
  prompt?:string          # string with the prompt, can be piped
  system?:string          # string with the system message. It has precedence over the system message flags
  --programmer(-p)        # use programmer system message with temp 0.7, else use assistant with temp 0.9
  --teacher(-s)           # use teacher (sensei) system message with temp 0.95, else use assistant with temp 0.9
  --engineer(-e)          # use prompt_engineer system message with temp 0.8, else use assistant with temp 0.9
  --rubb(-r)              # use rubb system message with temperature 0.5, else use assistant with temp 0.9
  --list_system(-l)       # select system message from list (takes precedence over flags)
  --list_preprompt(-b)    # select pre-prompt from list (pre-prompt + ''' + prompt + ''')
  --temperature(-t):float # takes precedence over the 0.7 and 0.9
  --gpt4(-g)              # use gpt-4 instead of gpt-3.5-turbo
  --large_model(-k)       # use gpt-3.5-turbo-16k (gpt-4-32k) if model is gpt-3.5-turbo (gpt-4)
  --fast(-f)              # get prompt from ~/Yandex.Disk/ChatGpt/prompt.md and save response to ~/Yandex.Disk/ChatGpt/answer.md
  #
  #Only one system message flag allowwed.
  #For more personalization use `chat_gpt`
] {
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
    match [$gpt4,$list_system,$list_preprompt] {
      [true,true,false] => {chat_gpt $prompt -t $temp -l -m gpt-4 -k $large_model},
      [true,false,false] => {chat_gpt $prompt -t $temp --select_system $system -m gpt-4 -k $large_model},
      [false,true,false] => {chat_gpt $prompt -t $temp -l -k $large_model},
      [false,false,false] => {chat_gpt $prompt -t $temp --select_system $system -k $large_model},
      [true,true,true] => {chat_gpt $prompt -t $temp -l -m gpt-4 -p -d -k $large_model},
      [true,false,true] => {chat_gpt $prompt -t $temp --select_system $system -m gpt-4 -p -d -k $large_model},
      [false,true,true] => {chat_gpt $prompt -t $temp -l -p -d -k $large_model},
      [false,false,true] => {chat_gpt $prompt -t $temp --select_system $system -p -d -k $large_model}
    }
  )

  if $fast {
    $answer | save -f ~/Yandex.Disk/ChatGpt/answer.md
  } else {
    return $answer  
  } 
}

#generate a git commit message via chatgpt and push the changes
export def "ai git-push" [
  --gpt4(-g)        # use gpt-4 instead of gpt-3.5-turbo
  --large_model(-k) # use gpt-3.5-turbo-16k (gpt-4-32k) if model is gpt-3.5-turbo (gpt-4)
  #
  #Inspired by https://github.com/zurawiki/gptcommit
] {
  let max_words = (
    if $large_model {
      if $gpt4 {15400} else {7400}
    } else {
      if $gpt4 {3400} else {1400}
    }
  )

  let max_words_short = (
    if $large_model {
      if $gpt4 {15930} else {7930}
    } else {
      if $gpt4 {3930} else {1930}
    }
  )

  print (echo-g "asking chatgpt to summarize the differences in the repository...")
  let question = (git diff | str replace "\"" "'" -a)
  let prompt = ($question | ^awk ("'BEGIN{total=0} {total+=NF; if(total<=(" + $"($max_words)" + ")) print; else exit}'"))
  let prompt_short = ($question | ^awk ("'BEGIN{total=0} {total+=NF; if(total<=(" + $"($max_words_short)" + ")) print; else exit}'"))

  let commit = (
    try {
      match $gpt4 {
        true => {
          try {
            chat_gpt $question -t 0.5 --select_system get_diff_summarizer --select_preprompt summarize_git_diff -d -m "gpt-4" -k $large_model
          } catch {
            try {
              chat_gpt $prompt -t 0.5 --select_system get_diff_summarizer --select_preprompt summarize_git_diff -d -m "gpt-4" -k $large_model
            } catch {
            chat_gpt $prompt_short -t 0.5 --select_system get_diff_summarizer --select_preprompt summarize_git_diff_short -d -m "gpt-4" -k $large_model
            }
          }
        },
        false => {
          try {
            chat_gpt $question -t 0.5 --select_system get_diff_summarizer --select_preprompt summarize_git_diff -d -k $large_model
          } catch {
            try {
              chat_gpt $prompt -t 0.5 --select_system get_diff_summarizer --select_preprompt summarize_git_diff -d -k $large_model
            } catch {
            chat_gpt $prompt_short -t 0.5 --select_system get_diff_summarizer --select_preprompt summarize_git_diff_short -d -k $large_model
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

  print (echo-g "updating deb files to gdrive...")
  let mounted = ($env.MY_ENV_VARS.gdrive_debs | path expand | path exists)

  if not $mounted {
    print (echo-g "mounting gdrive...")
    mount-ubb
  }

  let old_deb_date = ls ([$env.MY_ENV_VARS.gdrive_debs debs.7z] | path join) | get modified | get 0

  let last_deb_date = ls $env.MY_ENV_VARS.debs | sort-by modified | last | get modified 

  if $last_deb_date > $old_deb_date {
    cd $env.MY_ENV_VARS.debs; cd ..
    7z max debs debs/
    mv -f debs.7z $env.MY_ENV_VARS.gdrive_debs
  }
}

#audio to text transcription via whisper
export def "ai audio2text" [
  filename                    #audio file input
  --language(-l) = "Spanish"  #language of audio file
  --output_format(-o) = "txt" #output format: txt (default), vtt, srt, tsv, json, all
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
  whisper $"($file)-clean.mp3" --language $language --output_format $output_format --verbose False --fp16 False

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
  --summary(-s):bool = true        #whether to transcribe or not. Default true, false means it just extracts audio
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
  --gpt4(-g) = false  #whether to use gpt-4 (default false)
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
  let max_words = if $gpt4 {4000} else {2000}
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
      chat_gpt $prompt -t 0.5 --select_system meeting_summarizer --select_preprompt consolidate_transcription -d -m "gpt-4" | save -f $output
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
    chat_gpt $prompt -t 0.5 --select_system meeting_summarizer --select_preprompt summarize_transcription -d -m "gpt-4" | save -f $output
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
export def "ai generate-subtitles" [
  file                               #input video file
  --language(-l) = "en-US/English"   #language of input video file, mymmemory/whisper (default en-US/English)
  --translate(-t) = false            #to translate to spanish
  --notify(-n)                       #notify to android via ntfy
  #
  #`? trans` and `whisper --help` for more info on languages
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
export def "ai generate-subtitles-pipe" [
  --language(-l) = "en-US/English"   #language of input video file, mymmemory/whisper (default en-US/English)
  --translate(-t)                    #to translate to spanish
  #
  #`? trans` and `whisper --help` for more info on languages
] {
  $in
  | get name 
  | each {|file| 
      ai generate-subtitles ($file | ansi strip) -l $language -t $translate
    }
}

#get a summary of a youtube video via chatgpt
export def "ai yt-summary" [
  url?:string       # video url
  --lang = "en"     # language of the summary (default english: en)
  --gpt4(-g)        # to use gpt4 instead of gpt-3.5
  --notify(-n)      # notify to android via ntfy
  #
  #Two characters words for languages
  #es: spanish
  #fr: french
] {
  #example sans subs https://www.youtube.com/watch?v=wa6dpyBu2gE
  #example with subs https://www.youtube.com/watch?v=MciOgsEOHZM
  
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
  let max_words = if $gpt4 {3500} else {1500}
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
      chat_gpt $prompt -t 0.5 --select_system ytvideo_summarizer --select_preprompt consolidate_ytvideo -d -m "gpt-4" | save -f $output
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
    chat_gpt $prompt -t 0.5 --select_system ytvideo_summarizer --select_preprompt summarize_ytvideo -d -m "gpt-4" | save -f $output_file
  } else {
    chat_gpt $prompt -t 0.5 --select_system ytvideo_summarizer --select_preprompt summarize_ytvideo -d | save -f $output_file
  }
  if $notify {"summary finished!" | ntfy-send}
}

#get a summary of a video or audio via chatgpt
export def "ai media-summary" [
  file:string            # video, audio or subtitle file (vtt, srt) file name with extension
  --lang(-l) = "Spanish" # language of the summary
  --gpt4(-g)             # to use gpt4 instead of gpt-3.5
  --notify(-n)           # notify to android via ntfy
  #
  #Two characters words for languages
  #es: spanish
  #fr: french
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
  let max_words = if $gpt4 {3500} else {1500}
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
      chat_gpt $prompt -t 0.5 --select_system ytvideo_summarizer --select_preprompt consolidate_ytvideo -d -m "gpt-4" | save -f $output
    } else {
      chat_gpt $prompt -t 0.5 --select_system ytvideo_summarizer --select_preprompt consolidate_ytvideo -d | save -f $output
    }

    if $notify {"summary finished!" | ntfy-send}
    return
  }
  
  ai yt-transcription-summary (open $the_subtitle) $output -g $gpt4
  if $notify {"summary finished!" | ntfy-send}
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
  # let response = (curl -s -X POST $url -H 'Content-Type: application/json' -H $"x-api-key: ($api_key)" -d $data | from json)

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