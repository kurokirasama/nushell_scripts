#ai tools
export def "ai help" [] {
  # Updated list reflecting the commands in the provided script
  let commands_description = [
    { name: "ai help", description: "Show this help message" },
    { name: "token2word", description: "Calculate approximate words from token count" },
    { name: "chatpdf add", description: "Upload a PDF file to the chatpdf server" },
    { name: "chatpdf del", description: "Delete a file from the chatpdf server" },
    { name: "chatpdf ask", description: "Chat with a PDF via chatpdf" },
    { name: "askpdf", description: "Fast call to chatpdf ask with options" },
    { name: "chatpdf list", description: "List documents uploaded to chatpdf" },
    { name: "chat_gpt", description: "Single call wrapper for OpenAI ChatGPT models" },
    { name: "askai", description: "Fast call wrapper for ChatGPT, Gemini, Claude, and Ollama models" },
    { name: "bard", description: "Alias for 'askai -cGW 2' (chat with Gemini 1.5)" },
    { name: "ai git-push", description: "Generate a git commit message via AI and push changes" },
    { name: "ai audio2text", description: "Audio to text transcription via Whisper" },
    { name: "ai video2text", description: "Video to text transcription (extracts audio first)" },
    { name: "ai media-summary", description: "Get an AI summary of a video, audio, subtitle file, or YouTube URL" },
    { name: "ai transcription-summary", description: "Summarize transcription text using AI" },
    { name: "ai yt-get-transcription", description: "Get transcription of a YouTube video URL" },
    { name: "ai generate-subtitles", description: "Generate subtitles for a video file via Whisper and translation APIs" },
    { name: "ai generate-subtitles-pipe", description: "Pipe version of ai generate-subtitles" },
    { name: "dall_e", description: "Single call wrapper for OpenAI DALL-E models" },
    { name: "askaimage", description: "Fast call wrapper for DALL-E, Stable Diffusion, and Google image models" },
    { name: "ai openai-tts", description: "OpenAI text-to-speech wrapper" },
    { name: "ai elevenlabs-tts", description: "ElevenLabs text-to-speech wrapper" },
    { name: "tts", description: "Fast call to text-to-speech wrappers with defaults" },
    { name: "google_ai", description: "Single call wrapper for Google AI (Gemini/PaLM) models and chat mode" },
    { name: "ai gcal", description: "Interact with Google Calendar using natural language via AI" },
    { name: "g", description: "Alias for 'ai gcal -G' (uses Gemini)" },
    { name: "ai trans", description: "AI translation via GPT, Gemini, or Ollama APIs" },
    { name: "ai trans-sub", description: "Translate subtitle files using AI or MyMemory" },
    { name: "claude_ai", description: "Single call wrapper for Anthropic Claude AI models" },
    { name: "ai google_search-summary", description: "Summarize Google search results using AI" },
    { name: "ai debunk", description: "Debunk input text using AI analysis and web search" },
    { name: "ai analyze_paper", description: "Analyze and summarize a scientific paper using AI" },
    { name: "ai clean-text", description: "Clean and format raw text using AI" },
    { name: "ai analyze_religious_text", description: "Analyze religious text for claims, references, and message using AI" },
    { name: "o_llama", description: "Single call wrapper for local Ollama models (generate, chat, embed)" },
    { name: "ochat", description: "Alias for 'askai -con 2' (chat with Ollama)" },
    { name: "stable_diffusion", description: "Single call wrapper for Stability AI Stable Diffusion models" },
    { name: "google_aimage", description: "Single call wrapper for Google AI image generation models (Gemini/Imagen)" },
    { name: "run-private-gpt", description: "Run a local private-gpt instance" },
    { name: "private_gpt", description: "Interact with a running private-gpt instance (completions, summarize, chat)" },
    { name: "pchat", description: "Alias for 'private_gpt -c' (chat with private-gpt)" },
    { name: "private_gpt list", description: "List documents ingested by a private-gpt instance" },
    { name: "private_gpt delete", description: "Delete documents ingested by a private-gpt instance" },
    { name: "private_gpt ingest", description: "Ingest files into a private-gpt instance" },
  ] | sort-by name

  # Calculate the maximum length of the command names for padding
  let max_name_length = ($commands_description | get name | str length | math max)

  # Format the help text with padding and descriptions
  let help_text = $commands_description
    | each {|cmd|
        # Pad the command name to align descriptions
        let padded_name = ($cmd.name | fill -w ($max_name_length + 2) -a left)
        # Format the line: "command_name    # description"
        $"($padded_name)  # ($cmd.description)"
      }
    | prepend "AI Tools Help:\n" # Add a header

  # Print the formatted help text with syntax highlighting
  print ($help_text | str join "\n" | nu-highlight)
}

#calculate aprox words per tokens
#
#100 tokens about 60-80 words
@category ai
@search-terms token word
@example "Convert tokens to words" {token2word 1048000} --result [628800.0000 838400.0000]
export def token2word [
  tokens:int
  --min(-m):int = 60
  --max(-M):int = 80
  --rate(-r):int = 100
] {
  let token_units = $tokens / $rate
  math prod-list [$token_units $token_units] [$min $max]
}

#fast call to the chat_gpt and gemini wrappers
#
#Only one system message flag allowed.
#
#--gpt and --gemini are mutually exclusive flags.
#
#Uses chatgpt by default
#
#if --force and --chat are used together, first prompt is taken from file
#
#For more personalization use `chat_gpt` or `google_ai`
@category ai
@search-terms chatgpt gemini claude ollama ask
export def askai [
  prompt?:string   # string with the prompt, can be piped
  system?:string   # string with the system message. It has precedence over the s.m. flags
  --programmer(-P) # use programmer s.m with temp 0.75, else use assistant with temp 0.9
  --nushell-programmer(-N) # use bash-nushell programmer s.m with temp 0.75, else use assistant with temp 0.9
  --teacher(-T)    # use school teacher s.m with temp 0.95, else use assistant with temp 0.9
  --rubb(-R)       # use rubb s.m. with temperature 0.65, else use assistant with temp 0.9
  --create-school-eval(-s) #use school teacer s.m with temp 0.95 and school evaluation preprompt
  --biblical(-B)   # use biblical assistant s.m with temp 0.78
  --math-teacher(-M) # use undergraduate and postgraduate math teacher s.m. with temp 0.95
  --google-assistant(-O) # use gOogle assistant (with web search) s.m with temp 0.7
  --engineer(-E)   # use prompt_engineer s.m. with temp 0.8 and its preprompt
  --writer(-W)       # use writing_expert s.m with temp 0.95
  --academic(-A)   # use academic writer improver s.m with temp 0.78, and its preprompt
  --fix-bug(-F)    # use programmer s.m. with temp 0.75 and fix_code_bug preprompt
  --summarizer(-S) #use simple summarizer s.m with temp 0.70 and its preprompt
  --linux-expert(-L) #use linux expert s.m with temp temp 0.85
  --curricular-designer(-U) #use curricular designer s.m. with temp 0.8
  --document(-d):string   # answer question from provided document
  --auxiliary-data(-a):string # include context file in the prompt
  --list-system(-l)       # select s.m from list (takes precedence over flags)
  --list-preprompt(-p)    # select pre-prompt from list (pre-prompt + ''' + prompt + ''')
  --delimit-with-quotes(-q) = true #add '''  before and after prompt
  --temperature(-t):float # takes precedence over the 0.7 and 0.9
  --gpt(-g)              # use gpt-5 instead of gpt-5-mini (default)
  --vision(-v)            # use gpt-4-vision/gemini-pro-vision
  --image(-i):string      # filepath of the image to prompt to vision models
  --fast(-f)   #get prompt from prompt.md file and save response to answer.md
  --gemini(-G) #use google gemini-2.5-flash instead of chatgpt. 
  --pro        # use google gemini-2.5-pro (paid version) (needs --gemini)
  --bison(-b)  #use google bison instead of chatgpt (needs --gemini)
  --chat(-c)   #use chat mode (text only). Only else valid flags: --gemini, --gpt
  --database(-D)   #load chat conversation from database
  --web-search(-w) #include web search results into the prompt
  --web-results(-n):int = 5 #how many web results to include
  --web-model:string = "ollama" #how to get web results: gemini (+ google search) or ollama (web search)
  --claude(-C)  #use anthropic claude sonnet-4-5
  --ollama(-o)  #use ollama models
  --ollama-model(-m):string #select ollama model to use
  --embed(-e) #make embedding instead of generate or chat
] {
  let prompt = if $fast {
      open ($env.MY_ENV_VARS.chatgpt | path join prompt.md) 
    } else {
      get-input $in $prompt
    }

  if ($auxiliary_data | is-not-empty ) and not ($auxiliary_data | path expand | path exists) {
    return-error "auxiliary data doesn't exists"
  }
  
  let prompt = if ($auxiliary_data | is-not-empty) {
      $prompt + "\n\n" + ($auxiliary_data | path expand | open)
    } else {
      $prompt
    } 

  if ($prompt | is-empty) and not $chat {
    return-error "no prompt provided!"
  }
  
  if $gpt and $gemini {
    return-error "Please select only one ai system!"
  }

  if $bison and (not $gemini) {
    return-error "--bison needs --gemini!"
  }
  
  if $vision and ($image | is-empty) {
    return-error "vision models need and image file!"
  }
  
  let temp = if ($temperature | is-empty) {
    if $programmer or $fix_bug or $nushell_programmer {
      0.75
    } else if $teacher or $math_teacher or $create_school_eval {
      0.95
    } else if $engineer or $curricular_designer {
      0.8
    } else if $rubb {
      0.65
    } else if $academic or $biblical {
      0.78
    } else if $linux_expert {
      0.85
    } else if $summarizer or $google_assistant {
      0.7
    } else if $gpt {
      1
    } else {
      0.9
    }
  } else {
    $temperature
  }
  
  let system = (
    if ($system | is-empty) {
      if $list_system {
        ""
      } else if $programmer or $fix_bug {
        "programmer"
      } else if $nushell_programmer {
        "bash_nushell_programmer_with_nushell_docs"
      } else if $teacher or $create_school_eval {
        "school_teacher"
      } else if $engineer {
        "prompt_engineer"
      } else if $rubb {
        "rubb_2024"
      } else if $academic {
        "academic_writer_improver"
      } else if $biblical {
        "biblical_assistant"
      } else if $summarizer {
        "simple_summarizer"
      } else if ($document | is-not-empty) {
        "document_expert"
      } else if $linux_expert {
        "linux_expert"
      } else if $math_teacher {
        "math_teacher"
      } else if $google_assistant {
        "google_assistant"
      } else if $curricular_designer {
        "curr_designer"
      } else {
        "assistant"
      }
    } else {
      $system
    }
  )

  let pre_prompt = (
    if $academic {
      "improve_academic_writing"
    } else if $summarizer {
      "simple_summary"
    } else if ($document | is-not-empty) {
      "document_answer"
    } else if $engineer {
      "meta_prompt"
    } else if $fix_bug {
      "fix_code_bug"
    } else if $create_school_eval {
      "create_school_evaluation"
    } else {
      "empty"
    }
  )

  let gemini_model = if $pro {"gemini-2.5-pro"} else {"gemini-2.5-flash"} 

  #chat mode
  if $chat {
    if $gemini {
      google_ai $prompt -c -D $database -t $temp --select_system $system -p $list_preprompt -l $list_system -d false -w $web_search -n $web_results --select_preprompt $pre_prompt --document $document --web_model $web_model -m $gemini_model
    } else if $ollama {
      o_llama $prompt -c -D $database -t $temp --select_system $system -p $list_preprompt -l $list_system -d false -w $web_search -n $web_results --select_preprompt $pre_prompt --document $document --web_model $web_model -m $ollama_model
    } else {
      # chat_gpt $prompt -c -D $database -t $temp --select_system $system -p $list_preprompt -l $list_system -d $delimit_with_quotes
      print (echo-g "in progress for chatgpt and claude")
    }
    return
  }

  # question mode
  #use google
  if $gemini {    
    let answer = (
      if $vision {
        google_ai $prompt -t $temp -l $list_system -m gemini-pro-vision -p $list_preprompt -d true -i $image --select_preprompt $pre_prompt --select_system $system 
      } else {
          match $bison {
          true => {google_ai $prompt -t $temp -l $list_system -p $list_preprompt -m text-bison-001 -d true -w $web_search -n $web_results --select_preprompt $pre_prompt --select_system $system --document $document --web_model $web_model},
          false => {google_ai $prompt -t $temp -l $list_system -p $list_preprompt -m $gemini_model -d true -w $web_search -n $web_results --select_preprompt $pre_prompt --select_system $system --document $document --web_model $web_model},
        }
      }
    )

    if $fast {
      $answer | save -f ($env.MY_ENV_VARS.chatgpt | path join answer.md)
      return
    } else {
      return $answer  
    } 
  }

  #use claude
  if $claude {
    let answer = (
      if $vision {
        claude_ai $prompt -t $temp -l $list_system -p $list_preprompt -m claude-vision -d true -i $image --select_preprompt $pre_prompt --select_system $system -w $web_search -n $web_results --web_model $web_model
      } else {
        claude_ai $prompt -t $temp -l $list_system -p $list_preprompt -m claude-sonnet-4-5 -d true  --select_preprompt $pre_prompt --select_system $system --document $document -w $web_search -n $web_results --web_model $web_model
      }
    )

    if $fast {
      $answer | save -f ($env.MY_ENV_VARS.chatgpt | path join answer.md)
      return
    } else {
      return $answer  
    } 
  }

  #use ollama
  if $ollama {
    let answer = (
      if $vision {
        o_llama $prompt -t $temp -l $list_system -p $list_preprompt -m $ollama_model -d true -i $image --select_preprompt $pre_prompt --select_system $system -w $web_search -n $web_results --web_model $web_model -e $embed
      } else {
        o_llama $prompt -t $temp -l $list_system -p $list_preprompt -m $ollama_model -d true  --select_preprompt $pre_prompt --select_system $system --document $document -w $web_search -n $web_results --web_model $web_model -e $embed
      }
    )

    if $fast {
      $answer | save -f ($env.MY_ENV_VARS.chatgpt | path join answer.md)
      return
    } else {
      return $answer  
    } 
  }

  #use chatgpt
  let answer = (
    if $vision {
      match [$list_system,$list_preprompt] {
        [true,true] => {chat_gpt $prompt -t $temp -l -m gpt-4-vision -p -d -i $image},
        [true,false] => {chat_gpt $prompt -t $temp -l -m gpt-4-vision -i $image},
        [false,true] => {chat_gpt $prompt -t $temp --select_system $system -m gpt-4-vision -p -d -i $image},
        [false,false] => {chat_gpt $prompt -t $temp --select_system $system -m gpt-4-vision -i $image},
      }
    } else {
      match [$gpt,$list_system,$list_preprompt] {
        [true,true,false] => {chat_gpt $prompt -t $temp -l -m gpt-5 --select_preprompt $pre_prompt -w $web_search -n $web_results --web_model $web_model},
        [true,false,false] => {chat_gpt $prompt -t $temp --select_system $system -m gpt-5 --select_preprompt $pre_prompt -w $web_search -n $web_results --web_model $web_model},
        [false,true,false] => {chat_gpt $prompt -t $temp -l --select_preprompt $pre_prompt -w $web_search -n $web_results --web_model $web_model},
        [false,false,false] => {chat_gpt $prompt -t $temp --select_system $system --select_preprompt $pre_prompt -w $web_search -n $web_results --web_model $web_model},
        [true,true,true] => {chat_gpt $prompt -t $temp -l -m gpt-5 -p -d -w $web_search -n $web_results},
        [true,false,true] => {chat_gpt $prompt -t $temp --select_system $system -m gpt-5 -p -d -w $web_search -n $web_results --web_model $web_model},
        [false,true,true] => {chat_gpt $prompt -t $temp -l -p -d -w $web_search -n $web_results --web_model $web_model},
        [false,false,true] => {chat_gpt $prompt -t $temp --select_system $system -p -d -w $web_search -n $web_results --web_model $web_model}
      }
    }
  )

  if $fast {
    $answer | save -f ($env.MY_ENV_VARS.chatgpt | path join answer.md)
    return
  } else {
    return $answer  
  } 
}

#alias for bard
export alias bard = askai -cGn 2

#alias for ollama chat
export alias ochat = askai -con 2

#generate a git commit message via chatgpt and push the changes
#
#Inspired by https://github.com/zurawiki/gptcommit
@category ai
@search-terms git chatgpt gemini claude
export def "ai git-push" [
  --gpt(-g)   #use gpt-5 instead of gpt-5-mini
  --gemini(-G) #use google gemini-2.5 model
  --claude(-C) #use antropic claude-sonnet-4-5
] {
  if $gpt and $gemini {
    return-error "select only one model!"
  }

  let max_words = if $gemini {800000} else if $claude {150000} else {300000}
  let max_words_short = if $gemini {800000} else if $claude {150000} else {300000}

  let model = if $gemini {"gemini"} else if $claude {"claude"} else {"chatgpt"}

  print (echo-g $"asking ($model) to summarize the differences in the repository...")
  let question = (git diff | str replace "\"" "'" -a)
  let prompt = $question | str truncate -m $max_words
  let prompt_short = $question | str truncate -m $max_words_short

  let commit = (
    try {
      match [$gpt,$gemini] {
        [true,false] => {
          try {
            chat_gpt $question -t 0.5 --select_system get_diff_summarizer --select_preprompt summarize_git_diff -d -m gpt-5
          } catch {
            try {
              chat_gpt $prompt -t 0.5 --select_system get_diff_summarizer --select_preprompt summarize_git_diff -d -m gpt-5
            } catch {
              chat_gpt $prompt_short -t 0.5 --select_system get_diff_summarizer --select_preprompt summarize_git_diff_short -d -m gpt-5
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
            google_ai $question -t 0.5 --select_system get_diff_summarizer --select_preprompt summarize_git_diff -d true -m gemini-2.5
          } catch {
            try {
              google_ai $prompt -t 0.5 --select_system get_diff_summarizer --select_preprompt summarize_git_diff -d true -m gemini-2.5
            } catch {
              google_ai $prompt_short -t 0.5 --select_system get_diff_summarizer --select_preprompt summarize_git_diff_short -d true -m gemini-2.5
            }
          }
        }
      }
    } catch {
      input (echo-g $"Something happened with ($model). Enter your commit message or leave empty to stop: ")
    }
  )

  if ($commit | is-empty) {
    return-error "Execution stopped by the user!"
  }

  #errors now give a record instead of empty string
  if ($commit | typeof) != "string" {
    input (echo-g $"Something happened with ($model). Enter your commit message or leave empty to stop: ")
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
@category ai
@search-terms audio text transcription whisper
export def "ai audio2text" [
  filename                    #audio file input
  --language(-l) = "Spanish"  #language of audio file
  --output_format(-o) = "txt" #output format: txt, vtt, srt, tsv, json, all
  --translate(-t)             #translate audio to english
  --filter_noise(-f) = false  #filter noise
  --notify(-n)                #notify to android via join/tasker
] {
  let file = $filename | path parse | get stem

  mut start = ""
  mut end = ""

  if $filter_noise {
    print (echo-g $"reproduce ($filename) and select start and end time for noise segment, leave empty if no noise..." )
    $start = (input "start? (hh:mm:ss): ")
    $end = (input "end? (hh:mm:ss): ")
  }

  if ($start | is-empty) or ($end | is-empty) {
    print (echo-g "generating temp file...")
    if ($filename | path parse | get extension) like "mp3" {
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

#video to text transcription 
@category ai
@search-terms video text transcription whisper
export def "ai video2text" [
  file?:string                #video file name with extension
  --language(-l):string = "Spanish"  #language of audio file
  --filter_noise(-f) = false  #filter audio noise
  --notify(-n)                #notify to android via join/tasker
] {
  let file = get-input $in $file

  media extract-audio $file

  ai audio2text $"($file | path parse | get stem).mp3" -l $language -f $filter_noise

  if $notify {"audio extracted!" | tasker send-notification}
}

#get a summary of a video, audio, subtitle file or youtube video url via ai
@category ai
@search-terms media summary chatgpt gemini claude ollama
export def "ai media-summary" [
  file:string            # video, audio or subtitle file (vtt, srt, txt, url) file name with extension
  --lang(-l):string = "Spanish" # language of the summary
  --gpt(-g)             # to use gpt-5 instead of gpt-5-mini
  --gemini(-G)           # use google gemini-2.5 instead of gpt
  --pro(-p)             # use gemini-2.5-pro (paid version)
  --claude(-C)           # use anthropic claude
  --ollama(-o)           # use ollama
  --ollama_model(-m):string #ollama model to use
  --notify(-n)           # notify to android via join/tasker
  --upload(-u)           # upload extracted audio to gdrive
  --type(-t): string = "meeting" # meeting, youtube, class or instructions
  --complete(-c):string  #use complete preprompt with input file as the incomplete summary
  --filter_noise(-f)     # filter audio noise
] {
  let file = get-input $in $file -n

  if ($file | is-empty) {return-error "no input provided!"}

  mut title = ($file | path parse | get stem) 
  let extension = ($file | path parse | get extension)

  let prompt = $"does the extension file format ($file) correspond to and audio, video or subtitle file; or an url?. IMPORTANT: include as subtitle type files with txt extension. Please only return your response in json format, with the unique key 'answer' and one of the key values: video, audio, subtitle, url or none. In plain text without any markdown formatting, ie, without ```"
  let media_type = google_ai $prompt | remove-code-blocks | from json | get answer
  match $media_type {
    "video" => {ai video2text $file -l $lang -f $filter_noise},
    "audio" => {ai audio2text $file -l $lang -f $filter_noise},
    "subtitle" => {
      match $extension {
        "vtt" => {ffmpeg -i $file -f srt $"($title)-clean.txt"},
        "srt" => {mv -f $file $"($title)-clean.txt"},
        "txt" => {mv -f $file $"($title)-clean.txt"},
        _ => {return-error "input not supported!"}
      }
    },
    "url" =>  {
                let subtitle_file = ai yt-get-transcription $file --language $lang --force-mp3
                $title = $subtitle_file | path parse | get stem
                mv -f $subtitle_file $"($title)-clean.txt"
              }
    _ => {return-error $"wrong media type: ($file)"}
  }

  let system_prompt = match $type {
    "meeting" => {"meeting_summarizer"},
    "youtube" => {"ytvideo_summarizer"},
    "class" => {"class_transcriptor"},
    "instructions" => {"instructions_extractor"},
    _ => {return-error "not a valid type!"}
  }

  let pre_prompt = match $type {
    "meeting" => {"consolidate_transcription"},
    "youtube" => {"consolidate_ytvideo"},
    "class" => {"consolidate_class"},
    "instructions" => {"consolidate_instructions"}
  }

  if $upload and $media_type in ["video" "audio" "url"] {
    print (echo-g $"uploading audio file...")
    cp $"($title)-clean.mp3" $env.MY_ENV_VARS.gdriveTranscriptionSummaryDirectory
  }

  print (echo-g $"transcription file saved as ($title)-clean.txt")
  let the_subtitle = $"($title)-clean.txt"

  #removing existing temp files
  ls | where name like "split|summaries" | rm-pipe

  #definitions
  let output = $"($title)_summary.md"

  # dealing with the case when the transcription files has too many words for chatgpt
  let max_words = if $gemini {800000} else if $claude {150000} else {100000}
  let n_words = wc -w $the_subtitle | awk '{print $1}' | into int

  if $n_words > $max_words {
    print (echo-g $"splitting transcription of ($title)...")

    let filenames = $"($title)_split_"

    let split_command = ("awk '{total+=NF; print > " + $"\"($filenames)\"" + "sprintf(\"%03d\",int(total/" + $"($max_words)" + "))" + "\".txt\"}'" + $" \"($the_subtitle)\"")
  
    bash -c $split_command

    let files = ls | find -n split | where name not-like summary

    $files | each {|split_file|
      let t_input = open ($split_file | get name)
      let t_output = $split_file | get name | path parse | get stem
      ai transcription-summary $t_input $t_output -g $gpt -t $type -G $gemini -C $claude -o $ollama -m $ollama_model -p $pro
    }

    let temp_output = $"($title)_summaries.md"
    print (echo-g $"combining the results into ($temp_output)...")
    touch $temp_output

    let files = (ls | find -n split | find summary | enumerate)

    $files | each {|split_file|
      echo $"\n\nResumen de la parte ($split_file.index):\n\n" | save --append $temp_output
      open $split_file.item.name | save --append $temp_output
      echo "\n" | save --append $temp_output
    }

    let prompt = (open $temp_output)
    let model = if $gemini {"gemini"} else if $claude {"claude"} else if $ollama {"ollama"} else {"chatgpt"}
    let gemini_model = if $pro {"gemini-2.5-pro"} else {"gemini-2.5"}

    print (echo-g $"asking ($model) to combine the results in ($temp_output)...")

    if $gpt {
      chat_gpt $prompt -t 0.5 --select_system $system_prompt --select_preprompt $pre_prompt -d -m gpt-5
    } else if $gemini {
      google_ai $prompt -t 0.5 --select_system $system_prompt --select_preprompt $pre_prompt -d true -m $gemini_model
    } else if $claude {
      claude_ai $prompt -t 0.5 --select_system $system_prompt --select_preprompt $pre_prompt -d true -m claude-sonnet-4-5
    } else if $ollama {
      o_llama $prompt -t 0.5 --select_system $system_prompt --select_preprompt $pre_prompt -d true -m $ollama_model
    } else {
      chat_gpt $prompt -t 0.5 --select_system $system_prompt --select_preprompt $pre_prompt -d
    }
    | save -f $output

    if $notify {"summary finished!" | tasker send-notification}

    if $upload {cp $output $env.MY_ENV_VARS.gdriveTranscriptionSummaryDirectory}
    return
  }
  
  ai transcription-summary (open $the_subtitle) $output -g $gpt -t $type -G $gemini -C $claude -o $ollama -m $ollama_model -c $complete -p $pro

  if $upload {cp $output $env.MY_ENV_VARS.gdriveTranscriptionSummaryDirectory}
  if $notify {"summary finished!" | tasker send-notification}
}

export alias aimsy = ai media-summary -Gt youtube
export alias aimsc = ai media-summary -Gt class

#resume video transcription text via gpt
@category ai
@search-terms transcription summary chagpt gemini claude ollama
export def "ai transcription-summary" [
  prompt                #transcription text
  output                #output name without extension
  --complete(-c):string #use complete preprompt with input file as the incomplete summary
  --gpt(-g) = false     #whether to use gpt-5
  --gemini(-G) = false  #use google gemini-2.5
  --pro(-p) = false    #use gemini-2.5-pro (paid)
  --claude(-C) = false  #use anthropic claide
  --ollama(-o) = false  #use ollama
  --ollama_model(-m):string #ollama model to use
  --type(-t): string = "meeting" # meeting, youtube, class or instructions
  --notify(-n)          #notify to android via join/tasker
] {
  let output_file = $"($output | path parse | get stem).md"
  let model = if $gemini {"gemini"} else if $claude {"claude"} else {"chatgpt"}
  let gemini_model = if $pro {"gemini-2.5-pro"} else {"gemini-2.5"}
  let complete_flag = $complete | is-not-empty

  if $complete_flag and not ($complete | path expand | path exists) {
    return-error $"($complete) doesn't exists!"
  }

  let system_prompt = match $type {
    "meeting" => {"meeting_summarizer"},
    "youtube" => {"ytvideo_summarizer"},
    "class" => {"class_transcriptor"},
    "instructions" => {"instructions_extractor"},
    _ => {return-error "not a valid type!"}
  }

  let pre_prompt = if not $complete_flag {
    match $type {
      "meeting" => {"summarize_transcription"},
      "youtube" => {"summarize_ytvideo"},
      "class" => {"process_class"},
      "instructions" => {"extract_instructions"}
    }
  } else {
    match $type {
      "meeting" => {"complete_transcription"},
      "youtube" => {"complete_ytvideo"},
      "class" => {"complete_class"},
      "instructions" => {"complete_instructions"}
    }
  }

  let prompt = if not $complete_flag {
    $prompt
  } else {
    (open ($complete | path expand)) + "\n\n# INPUT TRANSCRIPTIONn\n" + $prompt
  }

  print (echo-g $"asking ($model) for a summary of the file transcription...")
  if $gpt {
    chat_gpt $prompt -t 0.5 --select_system $system_prompt --select_preprompt $pre_prompt -d -m gpt-5
  } else if $gemini {
    google_ai $prompt -t 0.5 --select_system $system_prompt --select_preprompt $pre_prompt -d true -m $gemini_model
  } else if $claude {
    claude_ai $prompt -t 0.5 --select_system $system_prompt --select_preprompt $pre_prompt -d true -m claude-sonnet-4-5
  } else if $ollama {
    o_llama $prompt -t 0.5 --select_system $system_prompt --select_preprompt $pre_prompt -d true -m $ollama_model
  } else {
    chat_gpt $prompt -t 0.5 --select_system $system_prompt --select_preprompt $pre_prompt -d
  }
  | if $complete_flag {save -a $output_file} else {save -f $output_file}

  if $notify {"summary finished!" | tasker send-notification}
}

#get transcription of youtube video url
#
#First it tries to download the transcription. If it doens't success, it downloads audio and trancribe it using whisper.
#
#Two characters words for languages
#es: spanish
#fr: french
@category ai
@search-terms youtube transcription 
export def "ai yt-get-transcription" [
  url?:string   #video url
  --language = "English" #language of the summary (default english)
  --force-mp3
] {
  let lang = match $language {
    "English" => {"en"},
    "Spanish" => {"es"},
    "French" => {"fr"},
    _ => {return-error "Unsupported language"}
  }
  
  if $force_mp3 {
      let filename = yt-dlp --print filename $url | path parse | get stem | str append ".mp3"
      
      print (echo-g "downloading audio...")
      yt-dlp --no-warnings -t mp3 $url -o $filename
      
      print (echo-g "transcribing audio...")
      whisper $filename --language $language --output_format "txt" --verbose False --fp16 False
      
      return ($filename | str replace ".mp3" ".txt")
  }
  
  #deleting previous temp file
  if ((ls | find yt_temp | length) > 0) {rm yt_temp* | ignore}
  
  #getting the subtitle
  yt-dlp -N 10 --write-info-json $url --output yt_temp --skip-download

  let video_info = (open yt_temp.info.json)
  let title = ($video_info | get title)
  let subtitles_info = ($video_info | get subtitles?)
  let languages = ($subtitles_info | columns)
  let the_language = ($languages | find $lang)
  let the_subtitle = $"($title).txt"

  if ($the_language | is-empty) {
    #first try auto-subs then whisper
    yt-dlp -N 10 --write-auto-subs $url --output yt_temp --skip-download

    if ((ls | find yt_temp | find vtt | length) > 0) {
      ffmpeg -i (ls yt_temp*.vtt | get 0 | get name) -f srt $the_subtitle
    } else {
      print (echo-g "downloading audio...")
      yt-dlp -t mp3 $url -o $"($title).mp3"

      print (echo-g "transcribing audio...")
      whisper $"($title).mp3" --output_format srt --verbose False --fp16 False
      mv -f $"($title).srt" $the_subtitle
    }
  } else {
    let sub_url = (
      $subtitles_info 
      | get ($the_language | get 0) 
      | where ext like "vtt" 
      | get url 
      | get 0
    )
    http get $sub_url | save -f $the_subtitle

    ffmpeg -i $"($title).vtt" -f srt $the_subtitle
  }
  print (echo-g $"transcription file saved as ($the_subtitle)")

  ls | find yt_temp | rm-pipe
  return $the_subtitle
}

#generate subtitles of video file via whisper and mymemmory/openai api
#
#`? trans` and `whisper --help` for more info on languages
@category ai
@search-terms subtitles whisper
export def "ai generate-subtitles" [
  file                             #input video file
  --language(-l) = "en-US/English" #language of input video file, mymmemory/whisper
  --translate(-t) = false          #to translate to spanish
  --notify(-n)                     #notify to android via join/tasker
] {
  let filename = $file | path parse | get stem

  media extract-audio $file 
  ai audio2text $"($filename).mp3" -o srt -l ($language | split row "/" | get 1)

  if $notify {"subtitle generated!" | tasker send-notification}

  if $translate {
    ai trans-sub $"($filename).srt" --from ($language | split row "/" | get 0)
    if $notify {"subtitle translated!" | tasker send-notification}
  }
}

#generate subtitles of video file via whisper and mymemmory api for piping
#
#`? trans` and `whisper --help` for more info on languages
@category ai
@search-terms subtitles whisper
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

#fast call to the dall-e and stable diffusion wrapper
#
#For more personalization and help check `? dall_e` or `? stable_diffusion`
@category ai
@search-terms imagen dalle dall-e stable-diffusion
export def askaimage [
  prompt?:string  #string with the prompt, can be piped
  --dalle3(-d)    #use dall-e-3 instead of dall-e-2 (default)
  --stable-diffusion(-s) #use stable diffusion models instead of openai's
  --google-models(-g):string #use google image generation models: gemini (free), imagen3, imagen4 or imagen4ultra (paid)
  --edit(-e)      #use edition mode instead of generation
  --variation(-v) #use variation mode instead of generation (dalle only)
  --upscale(-u)   #use up scaling mode instead of generation (stable diffusion only)
  --fast(-f)      #get prompt from ~/Yandex.Disk/ChatGpt/prompt.md
  --image(-i):string #image to use in edition, variation or up-scaling tasks
  --mask(-k):string  #mask to use in edition mode
  --output(-o):string #filename for output images, default used if not present
  --number(-n):int = 1 #number of images to generate (dalle only)
  --size(-S):string = "1792x1024"   #size of the output image (dalle only)
  --quality(-q):string = "standard" #quality of the output image: standard or hd (dalle only)
] {
  let prompt = if $fast {
    open ($env.MY_ENV_VARS.chatgpt | path join prompt.md) 
  } else {
    get-input $in $prompt
  }

  #stable diffusion
  if ($google_models | is-not-empty) {
    if $edit {
      google_aimage $prompt -m $google_models -i $image -t edit
      return
    } 

    google_aimage $prompt -m $google_models -n $number
    return
  }
    
  #stable diffusion
  if $stable_diffusion {
    print (echo-r "work in progress!")
    return
  }

  #dalle
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

#fast call to `ai tts`'s with most parameters as default
@category ai
@search-terms tts openai elevenlabs
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
@category ai
@search-terms google-calendar gcal chatgpt gemini ollama
export def "ai gcal" [
  ...request:string #query to gcal
  --gpt(-g)        #uses gpt-5
  --gemini(-G)      #uses gemini-2.5
  --ollama(-o)      #use ollama
  --ollama_model(-m):string #ollama model to use
] {
  let request = get-input $in $request | str join
  let date_now = date now | format date "%Y.%m.%d"
  let prompt =  $request + ".\nPor favor considerar que la fecha de hoy es " + $date_now

  #get data to make query to gcal
  let gcal_query = (
    if $ollama {
      o_llama $prompt -t 0.2 --select_system gcal_assistant --select_preprompt nl2gcal -d true -m $ollama_model
    } else if $gpt {
      chat_gpt $prompt -t 0.2 --select_system gcal_assistant --select_preprompt nl2gcal -d -m gpt-5
    } else if $gemini {
      google_ai $prompt -t 0.2 --select_system gcal_assistant --select_preprompt nl2gcal -d true -m gemini-2.5
    } else {
      chat_gpt $prompt -t 0.2 --select_system gcal_assistant --select_preprompt nl2gcal -d
    }
    | remove-code-blocks | from json
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
        if $ollama {
          o_llama $gcal2nl_prompt -t 0.2 --select_system gcal_translator --select_preprompt gcal2nl -d true -m $ollama_model
        } else if $gpt {
          chat_gpt $gcal2nl_prompt -t 0.2 --select_system gcal_translator --select_preprompt gcal2nl -m gpt-5
        } else if $gemini {
          google_ai $gcal2nl_prompt -t 0.2 --select_system gcal_translator --select_preprompt gcal2nl -d false -m gemini-2.5
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
      
      let prompt = "if the next text is using a naming convention, rewrite it in normal writing in the original language, i.e., separate words by a space. Only return your response without any commentary on your part, in plain text without any formatting. The text: " + ($gcal_query | get title)

      let title = if $gemini {
        google_ai $prompt -m gemini-2.5
      } else if $gpt {
         chat_gpt -m gpt-5
      } else if $ollama {
        o_llama $prompt -m $ollama_model
      } else {
        chat_gpt $prompt
      } | str trim
      
      gcal add $calendar $title $when $where $duration
    },
    _ => {return-error "wrong method!"}
  }
}

#alias for ai gcal with gemini
export alias g = ai gcal -G

#ai translation via gpt or gemini apis
@category ai
@search-terms translation chatgpt gemini ollama
export def "ai trans" [
  ...prompt
  --destination(-t):string = "Spanish"
  --gpt(-g)    #use gpt-5 instead of gpt-5-mini
  --gemini(-G)  #use gemini instead of gpt
  --deepl(-d)   #use deepl for translation
  --ollama(-o)  #use ollama models
  --ollama_model(-m):string #ollama model to use
  --copy(-c)    #copy output to clipboard
  --fast(-f)    #use prompt.md and answer.md to read question and write answer
  --not_verbose(-n) #do not show translating message
] {
  let prompt = if $fast {
    open ($env.MY_ENV_VARS.chatgpt | path join prompt.md) 
  } else if ($prompt | is-empty) {
    $in
  } else {
    $prompt | str join " "
  }

  if not $not_verbose {print (echo-g $"translating to ($destination)...")}
  
  let translated = if $deepl {
    let deepl_dest = get-deepl-lang-code ($destination | str title-case)
    deep_l $prompt --target-lang $deepl_dest
  } else {
    let system_prompt = "You are a reliable and knowledgeable language assistant specialized in " + $destination + "translation. Your expertise and linguistic skills enable you to provide accurate and natural translations  to " + $destination + ". You strive to ensure clarity, coherence, and cultural sensitivity in your translations, delivering high-quality results. Your goal is to assist and facilitate effective communication between languages, making the translation process seamless and accessible for users. With your assistance, users can confidently rely on your expertise to convey their messages accurately in" + $destination + "."
    let prompt = "Please translate the following text to " + $destination + ", and return only the translated text as the output, without any additional comments or formatting. Keep the same capitalization in every word the same as the original text and keep the same punctuation too. Do not add periods at the end of the sentence if they are not present in the original text. Keep any markdown formatting characters intact. The text to translate is:\n" + $prompt

    if $ollama {
      o_llama $prompt -t 0.5 -s $system_prompt -m $ollama_model
    } else if $gemini {
      google_ai $prompt -t 0.5 -s $system_prompt -m gemini-2.5
    } else if $gpt {
      chat_gpt $prompt -t 0.5 -s $system_prompt -m gpt-5
    } else {
      chat_gpt $prompt -t 0.5 -s $system_prompt
    }
  }

  if $copy {$translated | copy}
  if $fast {
    $translated | save -f ($env.MY_ENV_VARS.chatgpt | path join answer.md)
    return
  }
  return $translated
}

# Helper function to get DeepL language code from common language names
export def "get-deepl-lang-code" [
    lang_name: string # The human-readable language name (e.g., "Spanish", "English (American)")
] {
    match $lang_name {
        "Arabic" => "AR",
        "Bulgarian" => "BG",
        "Czech" => "CS",
        "Danish" => "DA",
        "German" => "DE",
        "Greek" => "EL",
        "English" => "EN", # Generic English, though EN-GB/EN-US are preferred
        "English (British)" => "EN-GB",
        "English (American)" => "EN-US",
        "Spanish" => "ES",
        "Estonian" => "ET",
        "Finnish" => "FI",
        "French" => "FR",
        "Hebrew" => "HE",
        "Hungarian" => "HU",
        "Indonesian" => "ID",
        "Italian" => "IT",
        "Japanese" => "JA",
        "Korean" => "KO",
        "Lithuanian" => "LT",
        "Latvian" => "LV",
        "Norwegian Bokmål" => "NB",
        "Dutch" => "NL",
        "Polish" => "PL",
        "Portuguese" => "PT", # Generic Portuguese
        "Portuguese (Brazilian)" => "PT-BR",
        "Portuguese (Portugal)" => "PT-PT",
        "Romanian" => "RO",
        "Russian" => "RU",
        "Slovak" => "SK",
        "Slovenian" => "SL",
        "Swedish" => "SV",
        "Thai" => "TH",
        "Turkish" => "TR",
        "Ukrainian" => "UK",
        "Vietnamese" => "VI",
        "Chinese" => "ZH", # Generic Chinese
        "Chinese (simplified)" => "ZH-HANS",
        "Chinese (traditional)" => "ZH-HANT",
        _ => {
            # If no direct match, return the original string, assuming it might be a valid code already
            $lang_name
        }
    }
}

#translate subtitle to Spanish via mymemmory, openai or gemini apis
#
#`? trans` for more info on languages (only if not using ai)
@category ai
@search-terms tranlation subtitles chatgpt gemini ollama MyMemory
export def "ai trans-sub" [
  file?
  --from:string = "en-US" #from which language you are translating
  --ai(-a)        #use gpt to make the translations
  --gpt(-g)      #use gpt4
  --gemini(-G)    #use gemini
  --ollama(-o)    #use ollama
  --ollama_model(-m):string #ollama model to use
  --notify(-n)    #notify to android via join/tasker
] {
  let file = get-input $in $file -n

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
        if not ($line.item like "-->") and not ($line.item like '^[0-9]+$') and ($line.item | str length) > 0 {
          let fixed_line = $line.item # | iconv -f UTF-8 -t ASCII//TRANSLIT
          let translated = (
            if $ai and $ollama {
              $fixed_line | ai trans -onm $ollama_model
            } else if $ai and $gemini {
              $fixed_line | ai trans -Gn
            } else if $ai and $gpt {
              $fixed_line | ai trans -gn
            } else if $ai {
              $fixed_line | ai trans -n
            } else {
              $fixed_line | trans --from $from
            }
          )

          if ($translated | is-empty) or ($translated like "error:") {
            return-error $"error while translating: ($translated)"
          } 

          # print (echo ($line.item + "\ntranslated to\n" + $translated))
          $translated | ansi strip | save --append $new_file
          "\n" | save --append $new_file
        } else {
          $line.item | save --append $new_file
          "\n" | save --append $new_file
        }
        progress_bar $line.index $lines
        # print -n (echo-g $"\r($line.index / $lines * 100 | math round -p 3)%")
      }

    return 
  } 

  let start = cat $new_file | decode utf-8 | lines | length

  $file_content
  | last ($lines - $start)
  | enumerate
  | each {|line|
      if not ($line.item like "-->") and not ($line.item like '^[0-9]+$') and ($line.item | str length) > 0 {
        let fixed_line = ($line.item | iconv -f UTF-8 -t ASCII//TRANSLIT)
        let translated = (
          if $ai and $ollama {
            $fixed_line | ai trans -onm $ollama_model
          } else if $ai and $gemini {
            $fixed_line | ai trans -Gn
          } else if $ai and $gpt {
            $fixed_line | ai trans -gn
          } else if $ai {
            $fixed_line | ai trans -n
          } else {
            $fixed_line | trans --from $from
          }
        )

        if $translated like "error:" {
          return-error $"error while translating: ($translated)"
        } 

        # print (echo ($line.item + "\ntranslated to\n" + $translated))

        $translated | ansi strip | save --append $new_file
        "\n" | save --append $new_file
      } else {
        $line.item | save --append $new_file
        "\n" | save --append $new_file
      }
      # print -n (echo-g $"\r(($line.index + $start) / $lines * 100 | math round -p 3)%")
      progress_bar $line.index $lines
    }

  if $notify {"translation finished!" | tasker send-notification}
}

# debunk input using ai
@category ai
@search-terms ai-tool debunk gemini ollama
export def "ai debunk" [
  data?        #file record with name field or plain text
  --ollama(-o) #use ollama model instead of gemini
  --ollama_model(-m):string #ollama model to use
  --web_results(-w) #use web search results as input for the refutations
  --clean(-c)    #clean text
] {
  let data = get-input $in $data
  let data = (
    if ($data | typeof) == "table" {
      open ($data | get name.0)
    } else if ($data | typeof) == "record" {
      open ($data | get name)
    } else {
      $data
    }
  )

  if $clean {print (echo-g "cleaning text...")}
  let data = if $clean {ai clean-text $data} else {$data}
  
  # logical fallacies
  print (echo-g "finding logical fallacies...")
  let log_fallacies = if $ollama {
    o_llama $data -t 0.2 --select_system logical_falacies_finder --select_preprompt find_fallacies -d true -m $ollama_model
    } else {
      google_ai $data -t 0.2 --select_system logical_falacies_finder --select_preprompt find_fallacies -d true -m gemini-2.5
    } | remove-code-blocks | from json 

  print (echo-g "debunking found logical fallacies...")
  let log_fallacies = debunk-table $log_fallacies -w $web_results -o $ollama -m $ollama_model

  # false claims
  print (echo-g "finding false claims...")
  let false_claims = if $ollama {
    o_llama $data -t 0.2 --select_system false_claims_extracter --select_preprompt extract_false_claims -d true -m $ollama_model
  } else {
    google_ai $data -t 0.2 --select_system false_claims_extracter --select_preprompt extract_false_claims -d true -m gemini-2.5
  } | remove-code-blocks | from json

  print (echo-g "debunking found false claims...")
  let false_claims = debunk-table $false_claims -w $web_results -o $ollama -m $ollama_model

  #consolidation
  print (echo-g "consolidating arguments...")
  let all_arguments = {text: $data, fallacies: $log_fallacies, false_claims: $false_claims} | to json
  let consolidation = if $ollama {
    o_llama $all_arguments --select_system debunker --select_preprompt consolidate_refutation -d true -m $ollama_model
  } else {
    google_ai $all_arguments --select_system debunker --select_preprompt consolidate_refutation -d true -m gemini-2.5
  }

  return $consolidation
}

#debug data given in table form
export def debunk-table [
  data
  --system_message(-s): string = "debunker"
  --web_results(-w) = true  #use web search results to write the refutation
  --ollama(-o) = false      #use ollama model
  --ollama_model(-m):string #ollama model to use
] {
  let data = (
    if ($data | describe | split row '<' | get 0) == table {
      $data
    } else {
      $data | transpose | transpose -r
    }
  )
  
  if ($data | is-empty) {
    return []
  }
  
  let n_data = ($data | length) - 1
  mut data_refutal = []

  for $i in 0..($n_data) {
    let refutal = if $ollama {
      o_llama ($data | get $i | to json) --select_system $system_message --select_preprompt debunk_argument -d true -w $web_results -m $ollama_model
    } else {
      google_ai ($data | get $i | to json) --select_system $system_message --select_preprompt debunk_argument -d true -w $web_results -m gemini-2.5
    }
    $data_refutal = $data_refutal ++ [$refutal]
  }

  return ($data | merge ($data_refutal | wrap refutation))
}

#analyze and summarize paper using ai
@category ai
@search-terms ai-tool paper analyze chatgpt gemini ollama
export def "ai analyze_paper" [
  paper?       #filename of the input paper
  --gpt(-g)   #use gpt-5 instead of gemini
  --ollama(-o) #use ollama instead of gemini
  --ollama_model(-m):string #ollama model to use
  --output(-o):string       #output filename without extension
  --clean(-c)   #clean text
  --verbose(-v) #show gemini attempts
  --notify(-n)  #send notification when finished
] {
  let paper = get-input $in $paper

  let file = (
    if ($paper | typeof) == "table" {
      $paper | get name.0 
    } else if ($paper | typeof) == "record" {
      $paper | get name
    } else {
      $paper
    }
    | ansi strip
  )

  let name = $file | path parse | get stem 
  let exte = $file | path parse | get extension

  print (echo-g $"starting analysis of ($file)...")

  if $exte == "pdf" {
    print (echo-c "converting pdf to text..." "green")
    pdftotext $file 
  } else if $exte != "txt" {
    mv -f $file ($name + ".txt")
  }

  let raw_data = open ($name + ".txt")

  let output = if ($output | is-empty) {$name + ".md"} else {$output + ".md"}

  if $clean {print (echo-c "cleaning text..." "green")}
  let data = if not $clean {$raw_data} else {ai clean-text $raw_data -g $gpt -o $ollama -m $ollama_model}
  $data | save -f ($name + ".txt")

  print (echo-c "analyzing paper..." "green")
 
  let analysis = if $gpt {
      chat_gpt $data --select_system paper_analyzer --select_preprompt analyze_paper -d -m gpt-5
    } else if $ollama {
      o_llama $data --select_system paper_analyzer --select_preprompt analyze_paper -d true -m $ollama_model -v $verbose
    } else {
      google_ai $data --select_system paper_analyzer --select_preprompt analyze_paper -d true -m gemini-2.5 -v $verbose
    }

  print (echo-c "summarizing paper..." "green")

  let summary =  if $gpt {
      chat_gpt $data --select_system paper_summarizer --select_preprompt summarize_paper -d -m gpt-5
    } else if $ollama {
      o_llama $data --select_system paper_summarizer --select_preprompt summarize_paper -d true -m $ollama_model -v $verbose
    } else {
      google_ai $data --select_system paper_summarizer --select_preprompt summarize_paper -d true -m gemini-2.5 -v $verbose 
  }

  let paper_wisdom = $analysis + "\n\n" + $summary

  print (echo-c "consolidating paper information..." "green")
  
  let consolidated_summary = if $gpt {
      chat_gpt $paper_wisdom --select_system paper_wisdom_consolidator --select_preprompt consolidate_paper_wisdom -d -m gpt-5
  } else if $ollama {
    o_llama $paper_wisdom --select_system paper_wisdom_consolidator --select_preprompt consolidate_paper_wisdom -d true -m $ollama_model -v $verbose 
  } else {
    google_ai $paper_wisdom --select_system paper_wisdom_consolidator --select_preprompt consolidate_paper_wisdom -d true -m gemini-2.5 -v $verbose    
  }

  $paper_wisdom + "\n\n# CONSOLIDATED SUMMARY\n\n" + $consolidated_summary | save -f $output

  if $notify {"analysis finished!" | tasker send-notification}
  print (echo-g $"analysis saved in: ($output)")
}

#remove code blocks from text
@category tool
@search-terms remove
export def remove-code-blocks []: [string -> string] {
    $in
    | str replace --all --regex --multiline '(?m)^```[a-zA-Z]*\n' ''  # Remove opening ```
    | str replace --all --regex --multiline '(?m)^```\s*$' ''         # Remove closing ```
    | str replace --all --regex --multiline '(?m)^    (.*)$' '$1'     # Remove 4-space indentation
    | str trim                                                        # Clean up whitespace
}

# Batch analyze papers and generate a single, consolidated research review document via gemini
@category ai
@search-terms ai-tool gemini analyze summarize
export def "ai batch-paper-analyser" [
    main_topic:string    #Main topic of the research review
    --skip-summaries(-s) #skip summary generation if already exists
    --only-summaries(-o) #only generate summaries, skip full analysis
] {
  # 1. Iterate through files and analyze them
  if not $skip_summaries {
    ls | where type == file | each { |file|
      ai analyze_paper $file.name
      sleep 1sec 
    }
  }
  
  if $only_summaries {
    return
  }

  # 2. Consolidate summaries and store full content
  let summaries = ls *.md | sort-by name | enumerate | each { |it|
    let file = $it.item
    let id = $it.index
    print (echo-g $"extracting summary, year, and full content from ($file.name)...")
    let content = open $file.name
    let summary = $content | lines | skip until {|l| $l | str contains "CONSOLIDATED SUMMARY"} | skip 1 | to text
    
    let year_prompt = "From the following text, extract the publication year. Respond with the four-digit year, and nothing else. If you can't find a year, respond with 'no-year'. Text:\n" + $content
    
    let reference_year = google_ai $year_prompt -m gemini-2.5
    sleep 1sec
    
    { id: $id, year: $reference_year, summary: $summary, full_content: $content }
  } | sort-by year

  # 3. AI-driven topic classification for the expert review
  print (echo-g "asking gemini to classify summaries into sub-topics for expert review...")
  let summaries_for_classification = $summaries | select id summary full_content
  let summaries_json = $summaries_for_classification | to json
  
  let classification_system_prompt = "You are a meticulous research analyst specializing in thematic analysis and data categorization. Your primary skill is identifying underlying themes in complex information and organizing it logically."
  let classification_user_prompt = $"Your task is to classify a list of research papers into a set of 1-5 relevant sub-topics, considering that the main topic is ($main_topic). First, read all the summaries and full content to understand the full scope of the research. Then, for each paper, assign a topic. You will be given a JSON array of objects, where each object has an 'id', a 'summary', and 'full_content'. Your output must be a single, valid JSON array of objects, where each object contains only the original id in the key 'id' and the assigned topic in the key 'topic'. It's totally fine to return a single topic for all the papers. Do not add any commentary. The input JSON is:\n($summaries_json)"
  
  let classified_topics = google_ai $classification_user_prompt --system $classification_system_prompt -m gemini-2.5 |  remove-code-blocks | from json
  
  let classified_summaries = $summaries | join $classified_topics id
  
  # 4. Generate the expert bibliography review in a variable
  print (echo-g "generating expert review content...")
  let grouped_summaries = $classified_summaries | group-by topic
  mut expert_output = "# Bibliographical review\n\n"
  
  for topic in ($grouped_summaries | columns) {
    let sorted_rows = $grouped_summaries | get $topic | sort-by year
    
    $expert_output = $expert_output + $"## ($topic)\n\n"
    
    let summaries_text = $sorted_rows | get summary | str join "\n\n"
    
    $expert_output = ($expert_output + $summaries_text + "\n\n")
  }
  
  # 5. Generate the public-facing review in a variable
  print (echo-g "generating public-facing narrative content...")
  let all_full_content = $classified_summaries | get full_content | str join "\n\n---\n\n"
  
  let public_review_system_prompt = "You are a gifted science communicator and journalist, writing for a prestigious publication known for making complex topics accessible and engaging, like 'Quanta Magazine' or 'The Atlantic'. Your strength is weaving a compelling narrative from technical data."
  let public_review_user_prompt = $"Your task is to synthesize the information from the following collection of research paper analyses into a single, engaging article for a non-expert audience. Your article should have a clear, cohesive, and coherent narrative. Identify the main, overarching topic and explain the key findings and their collective significance in an accessible way. Avoid jargon. Keep in mind that the main topic of the research is ($main_topic). Your output should be only the article text. The collected analyses are delimited by triple hyphens:\n\n---\n($all_full_content)\n---"
  
  let public_review_body = google_ai $public_review_user_prompt --system $public_review_system_prompt -m gemini-2.5
  let public_review_with_title = "# A Narrative Synthesis\n\n" + $public_review_body
  
  # 6. Generate the final conclusion in a variable
  print (echo-g "generating conclusion content...")
  let conclusion_system_prompt = "You are a senior research analyst and strategist. Your role is to distill complex information from multiple sources into a high-level, authoritative conclusion. You focus on the 'so what?' – the strategic implications and the definitive takeaway."
  let conclusion_user_prompt = $"Your task is to write a final, conclusive summary based on the two provided documents delimited by XML tags. Synthesize the information from both to craft a robust conclusion, considering that the main topic of the research is ($main_topic). Your conclusion must: 1. Address the overall objective or research question that unifies the papers. 2. Extract and clearly explain the most critical insights and key findings. 3. Discuss the significance and potential implications of these findings. 4. Provide a final, authoritative statement that encapsulates the core takeaway from the entire body of research. Your output should be only the conclusion text.\n\n<expert_review>\n($expert_output)\n</expert_review>\n\n<public_review>\n($public_review_with_title)\n</public_review>"
  
  let conclusion_body = google_ai $conclusion_user_prompt --system $conclusion_system_prompt -m gemini-2.5
  let conclusion_with_title = "# Conclusion\n\n" + $conclusion_body
  
  # 7. Generate the introduction in a variable
  print (echo-g "generating introduction content...")
  let introduction_system_prompt = "You are the lead author of a multi-faceted research document. Your role is to provide a clear and compelling introduction that frames the entire work for the reader. You must set the stage, explain the document's structure, and present the core thesis with clarity and authority."
  let introduction_user_prompt = $"Based on the three provided documents delimited by XML tags, write a compelling introduction, considering that the main topic of the research is ($main_topic) Your introduction should: 1. Start with a strong hook to grab the reader's attention. 2. Clearly state the central topic and why it is important. 3. Briefly describe the scope of the research covered. 4. Outline the structure of the document you are introducing, mentioning the different sections like the technical review, the narrative synthesis, and the conclusion. 5. End with a clear thesis statement that presents the main argument or takeaway of the entire review. Your output should be only the introduction text.\n\n<public_review>\n($public_review_with_title)\n</public_review>\n\n<expert_review>\n($expert_output)\n</expert_review>\n\n<conclusion>\n($conclusion_with_title)\n</conclusion>"
  
  let introduction_body = google_ai $introduction_user_prompt --system $introduction_system_prompt -m gemini-2.5
  let introduction_with_title = "# Introduction\n\n" + $introduction_body

  # 8. Generate the final title in a variable
  print (echo-g "generating the final title...")
  let title_system_prompt = "You are an expert academic editor specializing in creating concise and impactful titles."
  let title_user_prompt = $"Based on the following four documents, generate a single, descriptive title for the entire collection, considering that the main topic of the research is ($main_topic). The title must be no more than 5 words. Return only the title and nothing else.\n\n<introduction>\n($introduction_with_title)\n</introduction>\n\n<public_review>\n($public_review_with_title)\n</public_review>\n\n<expert_review>\n($expert_output)\n</expert_review>\n\n<conclusion>\n($conclusion_with_title)\n</conclusion>"
  
  let title = google_ai $title_user_prompt --system $title_system_prompt -m gemini-2.5

  # 9. Compile and save the final document
  print (echo-g "compiling the final document...")
  let final_filename = ($title | str replace " " "_" | str downcase) + ".md"
  let final_content = $"($title)\n\n($introduction_with_title)\n\n($public_review_with_title)\n\n($expert_output)\n\n($conclusion_with_title)"
  
  $final_content | save -f $final_filename

  print (echo-g $"final document saved as: ($final_filename)")
}

#analyze ai generated text using ai
@category ai
@search-terms ai-tool chatgpt gemini ollama analyze summarize
export def "ai analyze_ai_generated_text" [
  text?        #input text
  --style(-s):string #style of the text, like professional, casual, academic, etc.
  --gpt(-g)   #use gpt-5 instead of gemini
  --ollama(-o) #use ollama instead of gemini
  --ollama_model(-m):string #ollama model to use
  --correct-text(-c)  #fix the input text 
  --fast(-f)    #use prompt file and save response to answer file
  --notify(-n)  #send notification when finished
] {
  let text = get-input $in $text
  let text = if $fast {open ($env.MY_ENV_VARS.chatgpt | path join prompt.md)} else {$text}

  print (echo-g $"starting analysis of the input text...")

  let analysis = if $gpt {
      chat_gpt $text --select_system ai_generated_text_detector --select_preprompt analize_ai_generated_text -d -m gpt-5 -t 0.1
    } else if $ollama {
      o_llama $text --select_system ai_generated_text_detector --select_preprompt analize_ai_generated_text -d true -m $ollama_model -t 0.1
    } else {
      google_ai $text --select_system ai_generated_text_detector --select_preprompt analize_ai_generated_text -d true -m gemini-2.5 -t 0.1
    }

  if not $correct_text {
    if $fast {
      $analysis | save -f ($env.MY_ENV_VARS.chatgpt | path join answer.md)
      return
    }
    return $analysis
  }

  print (echo-g $"starting correction of the analyzed input text...")
  let prompt = if ($style | is-not-empty) {
    "# REPORT\n\n" + $analysis + "\n\n# INPUT \n\n" + $text + "\n\n# STYLE \n\nUse the following style: " + $style + "\n\n# CORRECTED TEXT \n\n"
  } else {
    "# REPORT\n\n" + $analysis + "\n\n# INPUT \n\n" + $text + "\n\n# CORRECTED TEXT \n\n"
  }

  let fixed = if $gpt {
      chat_gpt $prompt --select_system ai_generated_text_corrector --select_preprompt correct_ai_generated_text -m gpt-5 -t 0.9
    } else if $ollama {
      o_llama $prompt --select_system ai_generated_text_corrector --select_preprompt correct_ai_generated_text -d false -m $ollama_model -t 0.9
    } else {
      google_ai $prompt --select_system ai_generated_text_corrector --select_preprompt correct_ai_generated_text -d false -m gemini-2.5 -t 0.9
    }

  let response = "# REPORT\n\n" + $analysis + "\n\n# CORRECTED TEXT \n\n" + $fixed

  if $fast {
    $response | save -f ($env.MY_ENV_VARS.chatgpt | path join answer.md)
    return
  }

  $response
}

#clean text using ai
@category ai
@search-terms chathpt gemini ollama
export def "ai clean-text" [
  text?                #raw text to clean
  --gpt(-g) = false   #use gpt5 instead of gemini
  --ollama(-o) = false #use ollama instead of gemini
  --ollama_model(-m):string #ollama model to use
] {
  let raw_data = get-input $in $text

  if $gpt {
    chat_gpt $raw_data --select_system text_cleaner --select_preprompt clean_text -d -m gpt-5
  } else if $ollama {
    o_llama $raw_data --select_system text_cleaner --select_preprompt clean_text -d true -m $ollama_model
  } else {
    google_ai $raw_data --select_system text_cleaner --select_preprompt clean_text -d true -m gemini-2.5
  }
}

# analyze religious text using ai
@category ai
@search-terms chatgpt gemini ollama
export def "ai analyze_religious_text" [
  data?        #file record with name field or plain text
  --gpt(-g)   #use gpt-5 to consolidate the debunk instead of gemini-2.5
  --ollama(-o) #usa ollama model
  --ollama_model(-m):string #ollama model to use
  --web_results(-w) #use web search results as input for the refutations
  --clean(-C)    #do not clean text
  --copy(-c)        #copy response to clipboard
  --verbose(-v)     #show gemini attempts
  --fast(-f)
  --notify(-n)      #send notification when finished
] {
  let data = if ($data | is-empty) and not $fast {
    $in
  } else if $fast {
    open ($env.MY_ENV_VARS.chatgpt | path join prompt.md)
  } else {
    $data
  }

  let data = (
    if ($data | typeof) == "table" {
      open ($data | get name.0)
    } else if ($data | typeof) == "record" {
      open ($data | get name)
    } else {
      $data
    }
  )

  if $clean {print (echo-g "cleaning text...")}
  let data = if not $clean {$data} else {ai clean-text $data -g $gpt -o $ollama -m $ollama_model}

  # false claims
  print (echo-g "finding false claims...")
  let false_claims = if $gpt {
    chat_gpt $data -t 0.2 --select_system biblical_assistant --select_preprompt extract_false_bible_claims -d -m gpt-5
  } else if $ollama {
    o_llama $data -t 0.2 --select_system biblical_assistant --select_preprompt extract_false_bible_claims -d true -v $verbose -m $ollama_model
  } else {
    google_ai $data -t 0.2 --select_system biblical_assistant --select_preprompt extract_false_bible_claims -d true -v $verbose -m gemini-2.5
  } | remove-code-blocks | from json 

  print (echo-g "debunking found false claims...")
  let false_claims = if ($false_claims | is-not-empty) {debunk-table $false_claims -w $web_results -s biblical_assistant -o $ollama -m $ollama_model} else {$false_claims}

  # extract biblical references
  print (echo-g "finding biblical references within the text...")
  let biblical_references = if $gpt {
    chat_gpt $data -t 0.2 --select_system biblical_assistant --select_preprompt extract_biblical_references -d -m gpt-5
  } else if $ollama {
    o_llama $data -t 0.2 --select_system biblical_assistant --select_preprompt extract_biblical_references -d true -v $verbose -m $ollama_model
  } else {
    google_ai $data -t 0.2 --select_system biblical_assistant --select_preprompt extract_biblical_references -d true -v $verbose -m gemini-2.5
  } | remove-code-blocks | from json 

  # search for new biblical references
  print (echo-g "finding new biblical references...")
  let new_biblical_references = if $gpt {
    chat_gpt $data -t 0.2 --select_system biblical_assistant --select_preprompt find_biblical_references -d -m gpt-5
  } else if $ollama {
    o_llama $data -t 0.2 --select_system biblical_assistant --select_preprompt find_biblical_references -d true -v $verbose -m $ollama_model
  } else {
    google_ai $data -t 0.2 --select_system biblical_assistant --select_preprompt find_biblical_references -d true -v $verbose -m gemini-2.5
  } | remove-code-blocks | from json 

  # extract main message
  print (echo-g "finding main message...")
  let main_message = if $gpt {
    chat_gpt $data -t 0.2 --select_system biblical_assistant --select_preprompt extract_main_idea -d -m gpt-5
  } else if $ollama {
    o_llama $data -t 0.2 --select_system biblical_assistant --select_preprompt extract_main_idea -d true -v $verbose -m $ollama_model
  } else {
    google_ai $data -t 0.2 --select_system biblical_assistant --select_preprompt extract_main_idea -d true -v $verbose -m gemini-2.5
  } 

  # consolidation and compatibility test
  print (echo-g "consolidating and analyzing all extracted information...")
  let all_info = {
    full_text: $data,
    main_message: $main_message,
    internal_biblical_references: $biblical_references,
    new_biblical_references: $new_biblical_references,
    false_claims: $false_claims, 
    } | to json

  let consolidation = if $gpt {
    chat_gpt $data -t 0.2 --select_system biblical_assistant --select_preprompt consolidate_religious_text_analysus -d -m gpt-5
  } else if $ollama {
    o_llama $all_info --select_system biblical_assistant --select_preprompt consolidate_religious_text_analysus -d true -m $ollama_model -v $verbose
  } else {
    google_ai $all_info --select_system biblical_assistant --select_preprompt consolidate_religious_text_analysus -d true -m gemini-2.5 -v $verbose 
  }

  if $notify {"analysis finished!" | tasker send-notification}
  if $copy {$consolidation | copy}
  if $fast {
    $consolidation | save -f ($env.MY_ENV_VARS.chatgpt | path join answer.md)
  } else {
    return $consolidation  
  } 
}
