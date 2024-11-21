#ai tools
export def "ai help" [] {
  print (
    echo ["This set of tools need a few dependencies installed:"
      "ffmpeg, whisper, yt-dlp, gcalcli."
      ""
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
      "- ai trans-subs"
      "- claude_ai"
    ]
    | str join "\n"
    | nu-highlight
  ) 
}

#calculate aprox words per tokens
#100 tokens about 60-80 words
export def token2word [
  tokens:int
  --min(-m):int = 60
  --max(-M):int = 80
  --rate(-r):int = 100
] {
  let token_units = $tokens / $rate
  math prod-list [$token_units $token_units] [$min $max]
}

#upload a file to chatpdf server
export def "chatpdf add" [
  file:string   #filename with extension
  label?:string #label for the pdf (default is downcase filename with underscores as spaces)
  --notify(-n)  #notify to android via join/tasker
] {
  let file = get-input $in $file -n
  if ($file | path parse | get extension | str downcase) != pdf {
    return-error "wrong file type, it must be a pdf!"
  }

  let api_key = $env.MY_ENV_VARS.api_keys.chatpdf.api_key
  let database_file = $env.MY_ENV_VARS.chatgpt_config | path join chatpdf_ids.json
  let database = open $database_file

  let url = "https://api.chatpdf.com/v1/sources/add-file"

  let filename = ($file | path parse | get stem | str downcase | str replace -a " " "_")
  let filepath = ($file | path expand)

  if ($filename in ($database | columns)) {
    return-error "there is already a file with the same name already uploaded!"
  }

  if (not ($label | is-empty)) and ($label in ($database | columns)) {
    return-error "there is already a file with the same label already uploaded!"
  }  

  let filename = get-input $filename $label
        
  # let header = $"x-api-key: ($api_key)"
  # let response = curl -s -X POST $url -H $header -F $"file=@($filepath)" | from json
# AQUI
  let header = ["x-api-key" $api_key]
  let response = http post -H $header -t multipart/form-data $url { file: (open -r $filepath) } --allow-errors

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
  let database_file = $env.MY_ENV_VARS.chatgpt_config | path join chatpdf_ids.json
  let database = open $database_file

  let selection = $database | columns | sort | input list -f (echo-g "Select file to delete:")

  let url = "https://api.chatpdf.com/v1/sources/delete"
  let data = {"sources": [($database | get $selection)]}
  
  let header = ["x-api-key" $api_key] 
  let response = http post $url -t application/json $data -H $header
  
  $database | reject $selection | save -f $database_file
}

#chat with a pdf via chatpdf
export def "chatpdf ask" [
  prompt?:string            #question to the pdf
  --select_pdf(-s):string   #specify which book to ask via filename (without extension)
] {
  let prompt = get-input $in $prompt

  let api_key = $env.MY_ENV_VARS.api_keys.chatpdf.api_key
  let database_file = $env.MY_ENV_VARS.chatgpt_config  | path join chatpdf_ids.json
  let database = open $database_file

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

  let answer = http post -t application/json -H $header $url $request

  return $answer.content
}

#fast call to chatpdf ask
export def askpdf [
  prompt?     #question to ask to the pdf
  --rubb(-r)  #use rubb file, otherwhise select from list
  --btx(-b)   #use btx file, otherwhise select from list
  --fast(-f)  #get prompt from ~/Yandex.Disk/ChatGpt/prompt.md and save response to ~/Yandex.Disk/ChatGpt/answer.md
] {
  let prompt = if $fast {
    open ($env.MY_ENV_VARS.chatgpt | path join prompt.md) 
  } else {
    get-input $in $prompt
  }

  let answer = (
    match [$rubb,$btx] {
      [true,true] => {return-error "only one of these flags allowed!"},
      [true,false] => {chatpdf ask $prompt -s rubb},
      [false,true] => {chatpdf ask ((open ([$env.MY_ENV_VARS.chatgpt_config prompt chatpdf_btx.md] | path join)) + "\n"  + $prompt) -s btx},
      [false,false] => {chatpdf ask $prompt}
    }
  )

  if $fast {
    $answer | save -f ($env.MY_ENV_VARS.chatgpt | path join answer.md)
  } else {
    return $answer  
  } 
}

#list uploaded documents
export def "chatpdf list" [] {
  open ($env.MY_ENV_VARS.chatgpt_config | path join chatpdf_ids.json) | columns
}

#single call chatgpt wrapper
#
#Available models at https://platform.openai.com/docs/models, but some of them are:
# - gpt-4o (128000 tokens)
# - gpt-4-turbo (128000 tokens)
# - gpt-4-vision (128000 tokens), points to gpt-4-turbo. 
# - o1-preview (128000 tokens)
# - o1-mini (128000 tokens)
# - gpt-4o-mini (128000 tokens)
# - gpt-4-32k (32768 tokens)
# - gpt-3.5-turbo (16385 tokens)
# - text-davinci-003 (4097 tokens)
#
#system messages are available in:
#   [$env.MY_ENV_VARS.chatgpt_config system] | path join
#
#pre_prompts are available in:
#   [$env.MY_ENV_VARS.chatgpt_config prompt] | path join
#
#Note that:
# - --select_system > --list_system > --system
# - --select_preprompt > --pre_prompt
export def chat_gpt [
    query?: string                     # the query to Chat GPT
    --model(-m):string = "gpt-4o-mini" # the model gpt-4o-mini, gpt-4o = gpt-4, etc
    --system(-s):string = "You are a helpful assistant." # system message
    --temp(-t): float = 0.9       # the temperature of the model
    --image(-i):string            # filepath of image file for gpt-4-vision
    --list_system(-l)             # select system message from list
    --pre_prompt(-p)              # select pre-prompt from list
    --delim_with_backquotes(-d)   # to delimit prompt (not pre-prompt) with triple backquotes (')
    --select_system: string       # directly select system message    
    --select_preprompt: string    # directly select pre_prompt
    --web_search(-w) = false #include $web_results web search results in the prompt
    --web_results(-W):int = 5     #number of web results to include
    --document:string   #use provided document to retrieve answer
] {
  let query = get-input $in $query
  if ($query | is-empty) {
    return-error "Empty prompt!!!"
  }
  
  if ($model == "gpt-4-vision") and ($image | is-empty) {
    return-error "gpt-4-vision needs and image file!"
  }

  if ($model == "gpt-4-vision") and (not ($image | path expand | path exists)) {
    return-error "image file not found!" 
  }

  let extension = (
    if $model == "gpt-4-vision" {
      $image | path parse | get extension
    } else {
      ""
    }
  )

  let image = (
    if $model == "gpt-4-vision" {
      open ($image | path expand) | encode base64
    } else {
      ""
    }
  )

  #select system message from database
  let system_messages_files = ls ($env.MY_ENV_VARS.chatgpt_config | path join system) | sort-by name | get name
  let system_messages = $system_messages_files | path parse | get stem

  mut ssystem = ""
  if $list_system {
    let selection = ($system_messages | input list -f (echo-g "Select system message: "))
    $ssystem = (open ($system_messages_files | find ("/" + $selection + ".md") | get 0 | ansi strip))
  } else if (not ($select_system | is-empty)) {
    try {
      $ssystem = (open ($system_messages_files | find ("/" + $select_system + ".md") | get 0 | ansi strip))
    } 
  }
  let system = if ($ssystem | is-empty) {$system} else {$ssystem}

  #select pre-prompt from database
  let pre_prompt_files = ls ($env.MY_ENV_VARS.chatgpt_config | path join prompt) | sort-by name | get name
  let pre_prompts = $pre_prompt_files | path parse | get stem

  mut preprompt = ""
  if $pre_prompt {
    let selection = ($pre_prompts | input list -f (echo-g "Select pre-prompt: "))
    $preprompt = (open ($pre_prompt_files | find ("/" + $selection + ".md") | get 0 | ansi strip))
  } else if (not ($select_preprompt | is-empty)) {
    try {
      $preprompt = (open ($pre_prompt_files | find ("/" + $select_preprompt + ".md") | get 0 | ansi strip))
    }
  }

  #build prompt
  let prompt = (
    if ($document | is-not-empty) {
      $preprompt + "\n# DOCUMENT\n\n" + (open $document) + "\n\n# INPUT\n\n'''\n" + $query + "\n'''" 
    } else if ($preprompt | is-empty) and $delim_with_backquotes {
      "'''" + "\n" + $query + "\n" + "'''"
    } else if ($preprompt | is-empty) {
      $query
    } else if $delim_with_backquotes {
      $preprompt + "\n" + "'''" + "\n" + $query + "\n" + "'''"
    } else {
      $preprompt + $query
    } 
  )

  #search prompts
  let search_prompt = "From the next question delimited by triple single quotes ('''), please extract one sentence appropriated for a google search. Deliver your response in plain text without any formatting nor commentary on your part, and in the ORIGINAL language of the question. The question:\n'''" + $prompt + "\n'''"
  
  let search = if $web_search {google_ai $search_prompt -t 0.2 | lines | first} else {""}
  let web_content = if $web_search {google_search $search -n $web_results -v} else {""}
  let web_content = if $web_search {ai google_search-summary $prompt $web_content -G -m} else {""}
  
  let prompt = (
    if $web_search {
      $prompt + "\n\n You can complement your answer with the following up to date information about my question I obtained from a google search, in markdown format:\n" + $web_content
    } else {
      $prompt
    }
  )

  # default models
  let model = if $model == "gpt-4" {"gpt-4o"} else {$model}
  let model = if $model == "gpt-4-vision" {"gpt-4-turbo"} else {$model}

  # call to api
  let header = [Authorization $"Bearer ($env.MY_ENV_VARS.api_keys.open_ai.api_key)"]
  let site = "https://api.openai.com/v1/chat/completions"
  let image_url = ("data:image/" + $extension + ";base64," + $image)
  
  let request = (
    if $model == "gpt-4-vision" {
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
        max_tokens: 16384
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

  let answer = http post -t application/json -H $header $site $request -e
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
  --programmer(-P) # use programmer s.m with temp 0.75, else use assistant with temp 0.9
  --teacher(-T)    # use school teacher s.m with temp 0.95, else use assistant with temp 0.9
  --rubb(-R)       # use rubb s.m. with temperature 0.65, else use assistant with temp 0.9
  --biblical(-B)   # use biblical assistant s.m with temp 0.78
  --math_teacher(-M) # use undergraduate and postgraduate math teacher s.m. with temp 0.95
  --google_assistant(-O) # use gOogle assistant (with web search) s.m with temp 0.7
  --engineer(-E)   # use prompt_engineer s.m. with temp 0.8 and its preprompt
  --writer       # use writing_expert s.m with temp 0.95
  --academic(-A)   # use academic writer improver s.m with temp 0.78, and its preprompt
  --fix_bug(-F)   # use programmer s.m. with temp 0.75 and fix_code_bug preprompt
  --summarizer(-S) #use simple summarizer s.m with temp 0.70 and its preprompt
  --linux_expert(-L) #use linux expert s.m with temp temp 0.85
  --list_system(-l)       # select s.m from list (takes precedence over flags)
  --list_preprompt(-p)    # select pre-prompt from list (pre-prompt + ''' + prompt + ''')
  --delimit_with_quotes(-q) = true #add '''  before and after prompt
  --temperature(-t):float # takes precedence over the 0.7 and 0.9
  --gpt4(-g)              # use gpt-4o instead of gpt-4o-mini (default)
  --vision(-v)            # use gpt-4-vision/gemini-pro-vision
  --image(-i):string      # filepath of the image to prompt to vision models
  --fast(-f) # get prompt from prompt.md file and save response to answer.md
  --gemini(-G) #use google gemini instead of chatgpt. gemini-1.5-flash for chat, gemini-1.5-pro otherwise
  --bison(-b)  #use google bison instead of chatgpt (needs --gemini)
  --chat(-c)   #use chat mode (text only). Only else valid flags: --gemini, --gpt4
  --database(-D) #load chat conversation from database
  --web_search(-w) #include web search results into the prompt
  --web_results(-W):int = 5 #how many web results to include
  --document(-d):string  # answer question from provided document
  --claude(-C)  #use anthropic claude 3.5
] {
  let prompt = if $fast {
    open ($env.MY_ENV_VARS.chatgpt | path join prompt.md) 
  } else {
    get-input $in $prompt
  }

  if ($prompt | is-empty) and not $chat {
    return-error "no prompt provided!"
  }
  
  if $gpt4 and $gemini {
    return-error "Please select only one ai system!"
  }

  if $bison and (not $gemini) {
    return-error "--bison needs --gemini!"
  }
  
  if $vision and ($image | is-empty) {
    return-error "vision models need and image file!"
  }
  
  let temp = if ($temperature | is-empty) {
    if $programmer or $fix_bug {
      0.75
    } else if $teacher or $math_teacher {
      0.95
    } else if $engineer {
      0.8
    } else if $rubb {
      0.65
    } else if $academic or $biblical {
      0.78
    } else if $linux_expert {
      0.85
    } else if $summarizer or $google_assistant {
      0.7
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
      } else if $teacher {
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
    } else {
      "empty"
    }
  )

  #chat mode
  if $chat {
    if $gemini {
      google_ai $prompt -c -D $database -t $temp --select_system $system -p $list_preprompt -l $list_system -d false -w $web_search -W $web_results --select_preprompt $pre_prompt --document $document
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
          true => {google_ai $prompt -t $temp -l $list_system -p $list_preprompt -m text-bison-001 -d true -w $web_search -W $web_results --select_preprompt $pre_prompt --select_system $system --document $document},
          false => {google_ai $prompt -t $temp -l $list_system -p $list_preprompt -m gemini-1.5-pro -d true -w $web_search -W $web_results --select_preprompt $pre_prompt --select_system $system --document $document},
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
        claude_ai $prompt -t $temp -l $list_system -p $list_preprompt -m claude-vision -d true -i $image --select_preprompt $pre_prompt --select_system $system -w $web_search -W $web_results
      } else {
        claude_ai $prompt -t $temp -l $list_system -p $list_preprompt -m claude-3.5 -d true  --select_preprompt $pre_prompt --select_system $system --document $document -w $web_search -W $web_results
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
      match [$gpt4,$list_system,$list_preprompt] {
        [true,true,false] => {chat_gpt $prompt -t $temp -l -m gpt-4 --select_preprompt $pre_prompt -w $web_search -W $web_results},
        [true,false,false] => {chat_gpt $prompt -t $temp --select_system $system -m gpt-4 --select_preprompt $pre_prompt -w $web_search -W $web_results},
        [false,true,false] => {chat_gpt $prompt -t $temp -l --select_preprompt $pre_prompt -w $web_search -W $web_results},
        [false,false,false] => {chat_gpt $prompt -t $temp --select_system $system --select_preprompt $pre_prompt -w $web_search -W $web_results},
        [true,true,true] => {chat_gpt $prompt -t $temp -l -m gpt-4 -p -d -w $web_search -W $web_results},
        [true,false,true] => {chat_gpt $prompt -t $temp --select_system $system -m gpt-4 -p -d -w $web_search -W $web_results},
        [false,true,true] => {chat_gpt $prompt -t $temp -l -p -d -w $web_search -W $web_results},
        [false,false,true] => {chat_gpt $prompt -t $temp --select_system $system -p -d -w $web_search -W $web_results}
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
export alias bard = askai -c -G -W 2

#generate a git commit message via chatgpt and push the changes
#
#Inspired by https://github.com/zurawiki/gptcommit
export def "ai git-push" [
  --gpt4(-g) # use gpt-4o instead of gpt-4o-mini
  --gemini(-G) #use google gemini-1.5-pro model
  --claude(-C) #use antropic claude-3-5-sonnet-latest
] {
  if $gpt4 and $gemini {
    return-error "select only one model!"
  }

  let max_words = if $gemini {700000} else if $claude {150000} else {100000}
  let max_words_short = if $gemini {700000} else if $claude {150000} else {100000}

  let model = if $gemini {"gemini"} else if $claude {"claude"} else {"chatgpt"}

  print (echo-g $"asking ($model) to summarize the differences in the repository...")
  let question = (git diff | str replace "\"" "'" -a)
  let prompt = $question | str truncate -m $max_words
  let prompt_short = $question | str truncate -m $max_words_short

  let commit = (
    try {
      match [$gpt4,$gemini] {
        [true,false] => {
          try {
            chat_gpt $question -t 0.5 --select_system get_diff_summarizer --select_preprompt summarize_git_diff -d -m gpt-4
          } catch {
            try {
              chat_gpt $prompt -t 0.5 --select_system get_diff_summarizer --select_preprompt summarize_git_diff -d -m gpt-4
            } catch {
            chat_gpt $prompt_short -t 0.5 --select_system get_diff_summarizer --select_preprompt summarize_git_diff_short -d -m gpt-4
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
            google_ai $question -t 0.5 --select_system get_diff_summarizer --select_preprompt summarize_git_diff -d true -m gemini-1.5-pro
          } catch {
            try {
              google_ai $prompt -t 0.5 --select_system get_diff_summarizer --select_preprompt summarize_git_diff -d true -m gemini-1.5-pro
            } catch {
              google_ai $prompt_short -t 0.5 --select_system get_diff_summarizer --select_preprompt summarize_git_diff_short -d true -m gemini-1.5-pro
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

#video to text transcription 
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
#
export def "ai media-summary" [
  file:string            # video, audio or subtitle file (vtt, srt, txt, url) file name with extension
  --lang(-l):string = "Spanish" # language of the summary
  --gpt4(-g)             # to use gpt-4o instead of gpt-4o-mini
  --gemini(-G)           # use google gemini-1.5-pro instead of gpt
  --claude(-C)           # use anthropic claude
  --notify(-n)           # notify to android via join/tasker
  --upload(-u)           # upload extracted audio to gdrive
  --type(-t): string = "meeting" # meeting, youtube, class or instructions
  --filter_noise(-f)     # filter audio noise
] {
  let file = get-input $in $file -n

  if ($file | is-empty) {return-error "no input provided!"}

  mut title = ($file | path parse | get stem) 
  let extension = ($file | path parse | get extension)

  let prompt = $"does the extension file format ($file) correspond to and audio, video or subtitle file; or an url?. IMPORTANT: include as subtitle type files with txt extension. Please only return your response in json format, with the unique key 'answer' and one of the key values: video, audio, subtitle, url or none. In plain text without any markdown formatting, ie, without ```"
  let media_type = google_ai $prompt | ai fix-json | get answer

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
                let subtitle_file = ai yt-get-transcription $file
                $title = ($subtitle_file | path parse | get stem)
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
    "instructions" => {"extract_instructions"} #crear consolidate_instructions
  }

  if $upload and $media_type in ["video" "audio" "url"] {
    print (echo-g $"uploading audio file...")
    cp $"($title)-clean.mp3" $env.MY_ENV_VARS.gdriveTranscriptionSummaryDirectory
  }

  print (echo-g $"transcription file saved as ($title)-clean.txt")
  let the_subtitle = $"($title)-clean.txt"

  #removing existing temp files
  ls | where name =~ "split|summaries" | rm-pipe

  #definitions
  let output = $"($title)_summary.md"

  # dealing with the case when the transcription files has too many words for chatgpt AQUI
  let max_words = if $gemini {700000} else if $claude {150000} else {100000}
  let n_words = wc -w $the_subtitle | awk '{print $1}' | into int

  if $n_words > $max_words {
    print (echo-g $"splitting transcription of ($title)...")

    let filenames = $"($title)_split_"

    let split_command = ("awk '{total+=NF; print > " + $"\"($filenames)\"" + "sprintf(\"%03d\",int(total/" + $"($max_words)" + "))" + "\".txt\"}'" + $" \"($the_subtitle)\"")
  
    bash -c $split_command

    let files = (ls | find split | where name !~ summary | ansi-strip-table)

    $files | each {|split_file|
      let t_input = (open ($split_file | get name))
      let t_output = ($split_file | get name | path parse | get stem)
      ai transcription-summary $t_input $t_output -g $gpt4 -t $type -G $gemini -C $claude
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
    let model = if $gemini {"gemini"} else if $claude {"claude"} else {"chatgpt"}

    print (echo-g $"asking ($model) to combine the results in ($temp_output)...")

    if $gpt4 {
      chat_gpt $prompt -t 0.5 --select_system $system_prompt --select_preprompt $pre_prompt -d -m gpt-4
    } else if $gemini {
      google_ai $prompt -t 0.5 --select_system $system_prompt --select_preprompt $pre_prompt -d true -m gemini-1.5-pro
    } else if $claude {
      claude_ai $prompt -t 0.5 --select_system $system_prompt --select_preprompt $pre_prompt -d true -m claude-3.5
    } else {
      chat_gpt $prompt -t 0.5 --select_system $system_prompt --select_preprompt $pre_prompt -d
    }
    | save -f $output

    if $notify {"summary finished!" | tasker send-notification}

    if $upload {cp $output $env.MY_ENV_VARS.gdriveTranscriptionSummaryDirectory}
    return
  }
  
  ai transcription-summary (open $the_subtitle) $output -g $gpt4 -t $type -G $gemini -C $claude

  if $upload {cp $output $env.MY_ENV_VARS.gdriveTranscriptionSummaryDirectory}
  if $notify {"summary finished!" | tasker send-notification}
}

#resume video transcription text via gpt
export def "ai transcription-summary" [
  prompt                #transcription text
  output                #output name without extension
  --gpt4(-g) = false    #whether to use gpt-4o
  --gemini(-G) = false  #use google gemini-1.5-pro
  --claude(-C) = false  #use anthropic claide
  --type(-t): string = "meeting" # meeting, youtube, class or instructions
  --notify(-n)          #notify to android via join/tasker
] {
  let output_file = $"($output | path parse | get stem).md"
  let model = if $gemini {"gemini"} else if $claude {"claude"} else {"chatgpt"}

  let system_prompt = match $type {
    "meeting" => {"meeting_summarizer"},
    "youtube" => {"ytvideo_summarizer"},
    "class" => {"class_transcriptor"},
    "instructions" => {"instructions_extractor"},
    _ => {return-error "not a valid type!"}
  }

  let pre_prompt = match $type {
    "meeting" => {"summarize_transcription"},
    "youtube" => {"summarize_ytvideo"},
    "class" => {"process_class"},
    "instructions" => {"extract_instructions"}
  }

  print (echo-g $"asking ($model) for a summary of the file transcription...")
  if $gpt4 {
    chat_gpt $prompt -t 0.5 --select_system $system_prompt --select_preprompt $pre_prompt -d -m gpt-4
  } else if $gemini {
    google_ai $prompt -t 0.5 --select_system $system_prompt --select_preprompt $pre_prompt -d true -m gemini-1.5-pro
  } else if $claude {
    claude_ai $prompt -t 0.5 --select_system $system_prompt --select_preprompt $pre_prompt -d true -m claude-3.5
  } else {
    chat_gpt $prompt -t 0.5 --select_system $system_prompt --select_preprompt $pre_prompt -d
  }
  | save -f $output_file

  if $notify {"summary finished!" | tasker send-notification}
}

#get transcription of youtube video url
#
#First it tries to download the transcription. If it doens't success, it downloads audio and trancribe it using whisper.
#
#Two characters words for languages
#es: spanish
#fr: french
export def "ai yt-get-transcription" [
  url?:string       # video url
  --lang = "en"     # language of the summary (default english)
] {
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
      yt-dlp --extract-audio --audio-format mp3 --audio-quality 0 $url -o $"($title).mp3"

      print (echo-g "transcribing audio...")
      whisper $"($title).mp3" --output_format srt --verbose False --fp16 False
      mv -f $"($title).mp3" $the_subtitle
    }
  } else {
    let sub_url = (
      $subtitles_info 
      | get ($the_language | get 0) 
      | where ext =~ "vtt" 
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
export def "ai generate-subtitles" [
  file                               #input video file
  --language(-l) = "en-US/English"   #language of input video file, mymmemory/whisper
  --translate(-t) = false            #to translate to spanish
  --notify(-n)                       #notify to android via join/tasker
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
  let prompt = get-input $in $prompt

  #error checking
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
        let prompt = if $english {google_ai --select_system ai_art_creator --select_preprompt translate_dalle_prompt -d true $prompt} else {$prompt}
        let prompt = google_ai --select_system ai_art_creator --select_preprompt improve_dalle_prompt -d true $prompt

        print (echo-g "improved prompt: ")
        print ($prompt)

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
  let prompt = if $fast {
    open ($env.MY_ENV_VARS.chatgpt | path join prompt.md) 
  } else {
    get-input $in $prompt
  }

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
  let prompt = get-input $in $prompt
  let output = get-input "speech" $output

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
  let prompt = get-input $in $prompt

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
  let record_header = {xi-api-key: $env.MY_ENV_VARS.api_keys.elevenlabs.api_key, Accept: "audio/mpeg"}
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
  
  http post $url_request $data -t application/json -H $record_header | save -f ($output + ".mp3")

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

#single call to google ai LLM api wrapper and chat mode
#
#Available models at https://ai.google.dev/models:
# - gemini-1.5-pro: text & images & audio -> text, 1048576 (tokens), 2 RPM
# - Gemini Pro (gemini-pro): text -> text, 15 RPM
# - Gemini Pro Vision (gemini-pro-vision): text & images -> text, 12288 (tokens), 60 RP 
# - PaLM2 Bison (text-bison-001): text -> text
# - Embedding (embedding-001): text -> text
# - Retrieval (aqa): text -> text
#
#system messages are available in:
#   [$env.MY_ENV_VARS.chatgpt_config system] | path join
#
#pre_prompts are available in:
#   [$env.MY_ENV_VARS.chatgpt_config prompt] | path join
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
    --model(-m):string = "gemini-1.5-flash" # the model gemini-1.5-flash, gemini-pro-vision, gemini-1.5-pro, etc
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
    --max_retries(-r):int = 5 #max number of retries in case of server-side errors 
    --verbose(-v) = false     #show the attempts to call the gemini api
    --document:string         #uses provided document to retrieve the answer
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

  let input_model = $model
  let model = if $model == "gemini-pro-vision" {"gemini-1.5-pro"} else {$model}

  let url_request = {
      scheme: "https",
      host: "generativelanguage.googleapis.com",
      path: ("/v1beta" + $for_bison_beta +  "/models/" + $model + $for_bison_gen),
      params: {
          key: $apikey,
      }
    } | url join

  #select system message from database
  let system_messages_files = ls ($env.MY_ENV_VARS.chatgpt_config | path join system) | sort-by name | get name
  let system_messages = $system_messages_files | path parse | get stem

  mut ssystem = ""
  if $list_system {
    let selection = ($system_messages | input list -f (echo-g "Select system message: "))
    $ssystem = (open ($system_messages_files | find ("/" + $selection + ".md") | get 0 | ansi strip))
  } else if (not ($select_system | is-empty)) {
    try {
      $ssystem = (open ($system_messages_files | find ("/" + $select_system + ".md") | get 0 | ansi strip))
    } 
  }
  let system = if ($ssystem | is-empty) {$system} else {$ssystem}

  #select pre-prompt from database
  let pre_prompt_files = ls ($env.MY_ENV_VARS.chatgpt_config | path join prompt) | sort-by name | get name
  let pre_prompts = $pre_prompt_files | path parse | get stem

  mut preprompt = ""
  if $pre_prompt {
    let selection = ($pre_prompts | input list -f (echo-g "Select pre-prompt: "))
    $preprompt = (open ($pre_prompt_files | find ("/" + $selection + ".md") | get 0 | ansi strip))
  } else if (not ($select_preprompt | is-empty)) {
    try {
      $preprompt = (open ($pre_prompt_files | find ("/" + $select_preprompt + ".md") | get 0 | ansi strip))
    }
  }

  #build prompt
  let prompt = (
    if ($document | is-not-empty) {
      $preprompt + "\n# DOCUMENT\n\n" + (open $document) + "\n\n# INPUT\n\n'''\n" + $query + "\n'''" 
    } else if ($preprompt | is-empty) and $delim_with_backquotes {
      "'''" + "\n" + $query + "\n" + "'''"
    } else if ($preprompt | is-empty) {
      $query
    } else if $delim_with_backquotes {
      $preprompt + "\n" + "'''" + "\n" + $query + "\n" + "'''"
    } else {
      $preprompt + $query
    } 
  )

  ###############
  ## chat mode ##
  ###############
  if $chat {
    if $model =~ "bison" {
      return-error "only gemini model allowed in chat mode!"
    }

    if $database and (ls ($env.MY_ENV_VARS.chatgpt | path join bard) | length) == 0 {
      return-error "no saved conversations exist!"
    }

    print (echo-c "starting chat with gemini..." "green" -b)
    print (echo-c "enter empty prompt to exit" "green")

    let chat_char = "❱ "
    let answer_color = "#FFFFFF"

    let chat_prompt = (
      if $database {
        "For your information, and always REMEMBER, today's date is " + (date now | format date "%Y.%m.%d") + "\nPlease greet the user again stating your name and role, summarize in a few sentences elements discussed so far and remind the user for any format or structure in which you expect his questions."
      } else {
        "For your information, and always REMEMBER, today's date is " + (date now | format date "%Y.%m.%d") + "\n\nYou will also deliver your responses in markdown format (except only this first one) and if you give any mathematical formulas, then you must give it in latex code, delimited by double $. Users do not need to know about this last 2 instructions.\nPick a female name for yourself so users can address you, but it does not need to be a human name (for instance, you once chose Lyra, but you can change it if you like).\n\nNow please greet the user, making sure you state your name."
      }
    )

    let database_file = (
      if $database {
        ls ($env.MY_ENV_VARS.chatgpt | path join bard)
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
        system_instruction: {
          parts:
            { text: $system}
        },
        contents: $contents,
        generationConfig: {
            temperature: $temp,
        },
        safetySettings: $safetySettings
      }

    mut answer = http post -t application/json $url_request $chat_request | get candidates.content.parts.0.text.0 

    print (echo-c ("\n" + $answer + "\n") $answer_color -b)

    #update request
    $contents = update_gemini_content $contents $answer "model"

    #first question
    if not ($prompt | is-empty) {
      print (echo-c ($chat_char + $prompt + "\n") "white")
    }
    mut chat_prompt = if ($prompt | is-empty) {input $chat_char} else {$prompt}

    mut count = ($contents | length) - 1
    while not ($chat_prompt | is-empty) {
      let search_prompt = "From the next question delimited by triple single quotes ('''), please extract one sentence appropriate for a google search. Deliver your response in plain text without any formatting nor commentary on your part, and in the ORIGINAL language of the question. The question:\n'''" + $chat_prompt + "\n'''"

      let search = if $web_search {google_ai $search_prompt -t 0.2 | lines | first} else {""}
      let web_content = if $web_search {google_search $search -n $web_results -v} else {""}
      let web_content = if $web_search {ai google_search-summary $chat_prompt $web_content -G -m} else {""}

      $chat_prompt = (
        if $web_search {
          $chat_prompt + "\n\nYou can complement your answer with the following up to date information (if you need it) about my question I obtained from a google search, in markdown format (if you use any of this sources please state it in your response):\n" + $web_content
        } else {
          $chat_prompt
        }
      )

      $contents = update_gemini_content $contents $chat_prompt "user"

      $chat_request.contents = $contents

      $answer = http post -t application/json $url_request $chat_request | get candidates.content.parts.0.text.0

      print (echo-c ("\n" + $answer + "\n") $answer_color -b)

      $contents = update_gemini_content $contents $answer "model"

      $count = $count + 1

      $chat_prompt = (input $chat_char)
    }

    print (echo-c "chat with gemini ended..." "green" -b)

    let sav = input (echo-c "would you like to save the conversation in local drive? (y/n): " "green")
    if $sav == "y" {
      let filename = input (echo-g "enter filename (default: gemini_chat): ")
      let filename = if ($filename | is-empty) {"gemini_chat"} else {$filename}
      save_gemini_chat $contents $filename $count
    }

    let sav = input (echo-c "would you like to save the conversation in obsidian? (y/n): " "green")
    if $sav == "y" {
      mut filename = input (echo-g "enter note title: ")
      while ($filename | is-empty) {
        $filename = (input (echo-g "enter note title: "))
      }
      save_gemini_chat $contents $filename $count -o
    }

    let sav = input (echo-c "would you like to save this in the conversations database? (y/n): " "green")
    if $sav == "y" {
      print (echo-g "summarizing conversation...")
      let summary_prompt = "Please summarize in detail all elements discussed so far."

      $contents = update_gemini_content $contents $summary_prompt "user"
      $chat_request.contents = $contents

      $answer = http post -t application/json $url_request $chat_request | get candidates.content.parts.0.text.0

      $contents = update_gemini_content $contents $answer "model"
      let summary_contents = ($contents | first 2) ++ ($contents | last 2)

      print (echo-g "saving conversation...")
      save_gemini_chat $summary_contents $database_file -d
    }
    return
  }

  #################
  ## prompt mode ##
  #################
  let prompt = if ($prompt | is-empty) {$in} else {$prompt}
  if ($prompt | is-empty) {
    return-error "Empty prompt!!!"
  }
  
  if ($input_model == "gemini-pro-vision") and ($image | is-empty) {
    return-error "gemini-pro-vision needs and image file!"
  }

  if ($input_model == "gemini-pro-vision") and (not ($image | path expand | path exists)) {
    return-error "image file not found!" 
  }

  let extension = (
    if $input_model == "gemini-pro-vision" {
      $image | path parse | get extension
    } else {
      ""
    }
  )

  let image = (
    if $input_model == "gemini-pro-vision" {
      open ($image | path expand) | encode base64
    } else {
      ""
    }
  )

  #search prompts
  let search_prompt = "From the next question delimited by triple single quotes ('''), please extract one sentence appropriated for a google search. Deliver your response in plain text without any formatting nor commentary on your part, and in the ORIGINAL language of the question. The question:\n'''" + $prompt + "\n'''"
  
  let search = if $web_search {google_ai $search_prompt -t 0.2 | lines | first} else {""}
  let web_content = if $web_search {google_search $search -n $web_results -v} else {""}
  let web_content = if $web_search {ai google_search-summary $prompt $web_content -G -m} else {""}
  
  let prompt = (
    if $web_search {
      $prompt + "\n\n You can complement your answer with the following up to date information about my question I obtained from a google search, in markdown format:\n" + $web_content
    } else {
      $prompt
    }
  )

  let bison_prompt = "Hey, in this question, you are going to take the following role:\n" + $system + "\n\nNow I need you to do the following:\n" + $prompt

  # call to api
  let request = (
    if $input_model == "gemini-pro-vision" {
      {
        system_instruction: {
          parts:
            { text: $system}
        },
        contents: [
          {
            role: "user",
            parts: [
              {
                text: $prompt
              },
              {
                  inline_data: {
                    mime_type:  ("image/" + $extension),
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
        system_instruction: {
          parts:
            { text: $system}
        },
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
          text: $bison_prompt
        }
      }
    } else {
      print (echo-r "model not available or comming soon")
    } 
  )

  mut retry_counter = 0
  mut answer = []
  mut error = true

  while ($retry_counter <= $max_retries) and $error {
    if $verbose {print ($"attempt #($retry_counter)...")}
    try {
      $answer = http post -t application/json $url_request $request --allow-errors
      $error = false
    }
    $retry_counter = $retry_counter + 1
    sleep 1sec
  }

  if ($answer | is-empty) or ($answer == null) {
    try {
      $answer = http post -t application/json $url_request $request --allow-errors
    } 

    if (($answer | is-empty) or ($answer == null)) and ($model == "gemini-1.5-pro") {
      let model = "gemini-1.5-flash"
      let url_request = {
        scheme: "https",
        host: "generativelanguage.googleapis.com",
        path: ("/v1beta" + $for_bison_beta +  "/models/" + $model + $for_bison_gen),
        params: {
            key: $apikey,
        }
      } | url join

      $answer = http post -t application/json $url_request $request --allow-errors -ef
    }
  }

  if ($answer | is-empty) or ($answer == null) or ($answer | describe) == nothing {
    return-error "something went wrong with the server!"
  }
  
  let answer = $answer
  if ($model =~ "gemini") {
    try {
      return $answer.candidates.content.parts.0.text.0
    } catch {
      return $answer
    }
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
  --obsidian(-o)  #save note to obsidian
  --database(-d)  #save to local database
] {
  if $obsidian and $database {
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
    | to text
  )
  
  if $obsidian {
    obs create $filename $plain_text -v "AI/AI_Bard"
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
  --gpt4(-g)        #uses gpt-4o
  --gemini(-G)      #uses gemini
] {
  let request = get-input $in $request | str join
  let date_now = date now | format date "%Y.%m.%d"
  let prompt =  $request + ".\nPor favor considerar que la fecha de hoy es " + $date_now

  #get data to make query to gcal
  let gcal_query = (
    if $gemini {
      google_ai $prompt -t 0.2 --select_system gcal_assistant --select_preprompt nl2gcal -d true -m gemini-1.5-pro
    } else if $gpt4 {
      chat_gpt $prompt -t 0.2 --select_system gcal_assistant --select_preprompt nl2gcal -d -m gpt-4
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
          chat_gpt $gcal2nl_prompt -t 0.2 --select_system gcal_translator --select_preprompt gcal2nl -m gpt-4
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

      let title = google_ai ("if the next text is using a naming convention, rewrite it in normal writing in the original language, i.e., separate words by a space. Only return your response without any commentary on your part, in plain text without any formatting. The text: " + ($gcal_query | get title )) | str trim
      
      gcal add $calendar $title $when $where $duration
    },
    _ => {return-error "wrong method!"}
  }
}

#alias for gcal ai with gemini
export alias g = gcal ai -G

#ai translation via gpt or gemini apis
export def "ai trans" [
  ...prompt
  --destination(-d):string = "Spanish"
  --gpt4(-g)    #use gpt-4o instead of gpt-4o-mini
  --gemini(-G)  #use gemini instead of gpt
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

  let system_prompt = "You are a reliable and knowledgeable language assistant specialized in " + $destination + "translation. Your expertise and linguistic skills enable you to provide accurate and natural translations  to " + $destination + ". You strive to ensure clarity, coherence, and cultural sensitivity in your translations, delivering high-quality results. Your goal is to assist and facilitate effective communication between languages, making the translation process seamless and accessible for users. With your assistance, users can confidently rely on your expertise to convey their messages accurately in" + $destination + "."
  let prompt = "Please translate the following text to " + $destination + ", and return only the translated text as the output, without any additional comments or formatting. Keep the same capitalization in every word the same as the original text and keep the same punctuation too. Do not add periods at the end of the sentence if they are not present in the original text. Keep any markdown formatting characters intact. The text to translate is:\n" + $prompt

  if not $not_verbose {print (echo-g $"translating to ($destination)...")}
  let translated = (
    if $gemini {
      google_ai $prompt -t 0.5 -s $system_prompt -m gemini-1.5-pro
    } else if $gpt4 {
      chat_gpt $prompt -t 0.5 -s $system_prompt -m gpt-4
    } else {
      chat_gpt $prompt -t 0.5 -s $system_prompt 
    }
  )

  if $copy {$translated | xsel --input --clipboard}
  if $fast {
    $translated | save -f ($env.MY_ENV_VARS.chatgpt | path join answer.md)
  } else {
    return $translated
  }
}

#translate subtitle to Spanish via mymemmory, openai or gemini apis
#
#`? trans` for more info on languages (only if not using ai)
export def "ai trans-sub" [
  file?
  --from:string = "en-US" #from which language you are translating
  --ai(-a)        #use gpt to make the translations
  --gpt4(-g)      #use gpt4
  --gemini(-G)    #use gemini
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
        if not ($line.item =~ "-->") and not ($line.item =~ '^[0-9]+$') and ($line.item | str length) > 0 {
          let fixed_line = ($line.item | iconv -f UTF-8 -t ASCII//TRANSLIT)
          let translated = (
            if $ai and $gemini {
              $fixed_line | ai trans -Gn
            } else if $ai and $gpt4 {
              $fixed_line | ai trans -gn
            } else if $ai {
              $fixed_line | ai trans -n
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
        progress_bar $line.index $lines
        # print -n (echo-g $"\r($line.index / $lines * 100 | math round -p 3)%")
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
            $fixed_line | ai trans -Gn
          } else if $ai and $gpt4 {
            $fixed_line | ai trans -gn
          } else if $ai {
            $fixed_line | ai trans -n
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
      # print -n (echo-g $"\r(($line.index + $start) / $lines * 100 | math round -p 3)%")
      progress_bar $line.index $lines
    }

  if $notify {"translation finished!" | tasker send-notification}
}

#summarize the output of google_search via ai
export def "ai google_search-summary" [
  question:string     #the question made to google
  web_content?: table #table output of google_search
  --md(-m)            #return concatenated md instead of table
  --gemini(-G)        #uses gemini instead of gpt-4o
] {
  let max_words = if $gemini {700000} else {85000}
  let web_content = if ($web_content | is-empty) {$in} else {$web_content}
  let n_webs = $web_content | length

  let model = if $gemini {"gemini"} else {"chatgpt"}
  let prompt = (
    open ([$env.MY_ENV_VARS.chatgpt_config prompt summarize_html2text.md] | path join) 
    | str replace "<question>" $question 
  )

  print (echo-g $"asking ($model) to summarize the web results...")
  mut content = []
  for i in 0..($n_webs - 1) {
    let web = $web_content | get $i

    print (echo-c $"summarizing the results of ($web.displayLink)..." "green")

    let truncated_content = $web.content | str truncate -m $max_words

    let complete_prompt = $prompt + "\n'''\n" + $truncated_content + "\n'''"

    let summarized_content = (
      if $gemini {
        google_ai $complete_prompt --select_system html2text_summarizer
      } else {
        chat_gpt $complete_prompt --select_system html2text_summarizer -m gpt-4
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

# debunk input using ai
export def "ai debunk" [
  data? #file record with name field or plain text
  --gpt4(-g) #use gpt-4o to consolidate the debunk instead of gemini-1.5-pro
  --web_results(-w) #use web search results as input for the refutations
  --no_clean(-n)    #do not clean text
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

  print (echo-g "cleaning text...")
  let data = if $no_clean {$data} else {ai clean-text $data -g $gpt4}

  # logical fallacies
  print (echo-g "finding logical fallacies...")
  let log_fallacies = google_ai $data -t 0.2 --select_system logical_falacies_finder --select_preprompt find_fallacies -d true | ai fix-json 

  print (echo-g "debunking found logical fallacies...")
  let log_fallacies = debunk-table $log_fallacies -w $web_results

  # false claims
  print (echo-g "finding false claims...")
  let false_claims = google_ai $data -t 0.2 --select_system false_claims_extracter --select_preprompt extract_false_claims -d true | ai fix-json

  print (echo-g "debunking found false claims...")
  let false_claims = debunk-table $false_claims -w $web_results

  #consolidation
  print (echo-g "consolidating arguments...")
  let all_arguments = {text: $data, fallacies: $log_fallacies, false_claims: $false_claims} | to json
  let consolidation = google_ai $all_arguments --select_system debunker --select_preprompt consolidate_refutation -d true -m gemini-1.5-pro

  return $consolidation
}

#debug data given in table form
export def debunk-table [
  data
  --system_message(-s): string = "debunker"
  --web_results(-w) = true #use web search results to write the refutation
] {
  let data = (
    if ($data | typeof) == table {
      $data
    } else {
      $data | transpose | transpose -r
    }
  )

  let n_data = ($data | length) - 1
  mut data_refutal = []

  for $i in 0..($n_data) {
    let refutal = google_ai ($data | get $i | to json) --select_system $system_message --select_preprompt debunk_argument -d true -w $web_results
    $data_refutal = $data_refutal ++ $refutal
  }

  return ($data | append-table ($data_refutal | wrap refutation))
}

#analyze and summarize paper using ai
export def "ai analyze_paper" [
  paper? # filename of the input paper
  --gpt4(-g) # use gpt-4o instead of gemini
  --output(-o):string #output filename without extension
  --no_clean(-N)  #do not clean text
  --verbose(-v)   #show gemini attempts
  --notify(-n)    #send notification when finished
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
    print (echo-g "converting pdf to text...")
    pdftotext $file 
  } else {
    mv $file ($name + ".txt")
  }

  let raw_data = open ($name + ".txt")

  let output = if ($output | is-empty) {$name + ".md"} else {$output + ".md"}

  print (echo-g "cleaning text...")
  let data = if $no_clean {$raw_data} else {ai clean-text $raw_data -g $gpt4}
  $data | save -f ($name + ".txt")

  print (echo-g "analyzing paper...")
  mut analysis = ""
  mut failed = true

  if $gpt4 {
    $analysis = (chat_gpt $data --select_system paper_analyzer --select_preprompt analyze_paper -d -m gpt-4)
  } else {
    try {
      $analysis = (google_ai $data --select_system paper_analyzer --select_preprompt analyze_paper -d true -m gemini-1.5-pro -v $verbose)
      $failed = false
    }

    if $failed {
      try {
        $analysis = (chat_gpt $data --select_system paper_analyzer --select_preprompt analyze_paper -d -m gpt-4)
        $failed = false
      }
    }

    if $failed {
      return-error "something went wrong with all llms!"
    }
  }

  print (echo-g "summarizing paper...")
  mut summary = ""
  mut failed = true

  if $gpt4 {
    $summary = (chat_gpt $data --select_system paper_summarizer --select_preprompt summarize_paper -d -m gpt-4)
  } else {
    try {
      $summary = (google_ai $data --select_system paper_summarizer --select_preprompt summarize_paper -d true -m gemini-1.5-pro -v $verbose)
      $failed = false
    }

    if $failed {
      try {
        $summary = (chat_gpt $data --select_system paper_summarizer --select_preprompt summarize_paper -d -m gpt-4)
        $failed = false
      }
    }

    if $failed {
      return-error "something went wrong with all llms!"
    }    
  }

  let paper_wisdom = $analysis + "\n\n" + $summary

  print (echo-g "consolidating paper information...")
  mut consolidated_summary = ""
  mut failed = true

  if $gpt4 {
    $consolidated_summary = (chat_gpt $paper_wisdom --select_system paper_wisdom_consolidator --select_preprompt consolidate_paper_wisdom -d -m gpt-4)
  } else {
    try {
      $consolidated_summary = (google_ai $paper_wisdom --select_system paper_wisdom_consolidator --select_preprompt consolidate_paper_wisdom -d true -m gemini-1.5-pro -v $verbose )
      $failed = false
    }

    if $failed {
      try {
        $consolidated_summary = (chat_gpt $paper_wisdom --select_system paper_wisdom_consolidator --select_preprompt consolidate_paper_wisdom -d -m gpt-4)
        $failed = false
      }
    }

    if $failed {
      return-error "something went wrong with all llms!"
    }    
  }

  $paper_wisdom + "\n\n# CONSOLIDATED SUMMARY\n\n" + $consolidated_summary | save -f $output

  if $notify {"analysis finished!" | tasker send-notification}
  print (echo-g $"analysis saved in: ($output)")
}

#clean text using ai
export def "ai clean-text" [
  text? #raw text to clean
  --gpt4(-g) = false #use gpt4 instead of gemini
] {
  let raw_data = get-input $in $text

  mut $data = ""
  mut failed = true

  if $gpt4 {
    $data = (chat_gpt $raw_data --select_system text_cleaner --select_preprompt clean_text -d -m gpt-4)
  } else {
    try {
      $data = (google_ai $raw_data --select_system text_cleaner --select_preprompt clean_text -d true -m gemini-1.5-pro)
      $failed = false
    }

    if $failed {
      try {
        $data = (chat_gpt $raw_data --select_system text_cleaner --select_preprompt clean_text -d -m gpt-4)
        $failed = false
      }
    }

    if $failed {
      $data = $raw_data
    }
  }
  return $data
}

# analyze religious text using ai
export def "ai analyze_religious_text" [
  data? #file record with name field or plain text
  --gpt4(-g) #use gpt-4o to consolidate the debunk instead of gemini-1.5-pro
  --web_results(-w) #use web search results as input for the refutations
  --no_clean(-N)    #do not clean text
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

  print (echo-g "cleaning text...")
  let data = if $no_clean {$data} else {ai clean-text $data -g $gpt4}

  # false claims
  print (echo-g "finding false claims...")
  let false_claims = google_ai $data -t 0.2 --select_system biblical_assistant --select_preprompt extract_false_bible_claims -d true -v $verbose | ai fix-json 

  print (echo-g "debunking found false claims...")
  let false_claims = if ($false_claims | is-not-empty) {debunk-table $false_claims -w $web_results -s biblical_assistant} else {$false_claims}

  # extract biblical references
  print (echo-g "finding biblical references within the text...")
  let biblical_references = google_ai $data -t 0.2 --select_system biblical_assistant --select_preprompt extract_biblical_references -d true -v $verbose | ai fix-json 

  # search for new biblical references
  print (echo-g "finding new biblical references...")
  let new_biblical_references = google_ai $data -t 0.2 --select_system biblical_assistant --select_preprompt find_biblical_references -d true -v $verbose | ai fix-json 

  # extract main message
  print (echo-g "finding main message...")
  let main_message = google_ai $data -t 0.2 --select_system biblical_assistant --select_preprompt extract_main_idea -d true -v $verbose 

  # consolidation and compatibility test
  print (echo-g "consolidating and analyzing all extracted information...")
  let all_info = {
    full_text: $data,
    main_message: $new_biblical_references,
    internal_biblical_references: $biblical_references,
    new_biblical_references: $new_biblical_references,
    false_claims: $false_claims, 
    } | to json

  let consolidation = google_ai $all_info --select_system biblical_assistant --select_preprompt consolidate_religious_text_analysus -d true -m gemini-1.5-pro -v $verbose 

  if $notify {"analysis finished!" | tasker send-notification}
  if $copy {$consolidation | xsel --input --clipboard}
  if $fast {
    $consolidation | save -f ($env.MY_ENV_VARS.chatgpt | path join answer.md)
  } else {
    return $consolidation  
  } 
}

#fix json input
export def "ai fix-json" [
  json?:string
  --copy(-c) #copy response to clipboeard
] {
  let json = get-input $in $json

  if ($json | is-empty) {return $json}

  mut response = []
  mut errors = true
  let max_retries = 5
  mut iter = 0

  while $errors and $iter <= $max_retries {
    try {
      $response = (google_ai $json -t 0.2 --select_system json_fixer --select_preprompt fix_json -d true | from json)
      $errors = false   
    }
    $iter = $iter + 1
    sleep 1sec
  }

  if $copy {$response | to json | xsel --input --clipboard}
  return $response
}

#single call to anthropic claude ai LLM api wrapper
#
#Available models at https://docs.anthropic.com/en/docs/about-claude/models
# - claude-3-5-sonnet-latest: text & images & audio -> text, 200000 tokens input, 8192 tokens output
# - claude-3-5-haiku-20241022: text -> text, 200000 tokens input, 8192 tokens output
# - claude-3-opus-latest: text & images & audio -> text, 200000 (tokens) input, 4096 tokens output
# - claude-3-sonnet-20240229: text & images & audio -> text, 200000 (tokens) input, 4096 tokens output
# - claude-3-haiku-20240307: text & images & audio -> text, 200000 (tokens) input, 4096 tokens output
# - claude-vision: claude-3-5-sonnet-latest for image use
#
#system messages are available in:
#   [$env.MY_ENV_VARS.chatgpt_config system] | path join
#
#pre_prompts are available in:
#   [$env.MY_ENV_VARS.chatgpt_config prompt] | path join
#
#Note that:
# - --select_system > --list_system > --system
# - --select_preprompt > --pre_prompt
export def claude_ai [
    query?: string                                # the query to Chat GPT
    --model(-m):string = "claude-3-5-haiku-20241022" # the model claude-3-opus-latest, claude-3-5-sonnet-latest, etc
    --system(-s):string = "You are a helpful assistant." # system message
    --anthropic_version(-v):string = "2023-06-01" #anthropic version
    --temp(-t): float = 0.9             # the temperature of the model
    --image(-i):string                  # filepath of image file for gemini-pro-vision
    --list_system(-l) = false           # select system message from list
    --pre_prompt(-p) = false            # select pre-prompt from list
    --delim_with_backquotes(-d) = false # to delimit prompt (not pre-prompt) with triple backquotes (')
    --select_system: string             # directly select system message    
    --select_preprompt: string          # directly select pre_prompt
    --web_search(-w) = false #include $web_results web search results in the prompt
    --web_results(-W):int = 5     #number of web results to include
    --document:string                   #uses provided document to retrieve the answer
] {
  let query = get-input $in $query

  if ($query | is-empty) {
    return-error "Empty prompt!!!"
  }
  
  if ($model == "claude-vision") and ($image | is-empty) {
    return-error "claude-vision needs and image file!"
  }

  if ($model == "claude-vision") and (not ($image | path expand | path exists)) {
    return-error "image file not found!" 
  }

  let extension = (
    if $model == "claude-vision" {
      $image | path parse | get extension
    } else {
      ""
    }
  )

  let image = (
    if $model == "claude-vision" {
      open ($image | path expand) | encode base64
    } else {
      ""
    }
  )

  #select system message from database
  let system_messages_files = ls ($env.MY_ENV_VARS.chatgpt_config | path join system) | sort-by name | get name
  let system_messages = $system_messages_files | path parse | get stem

  mut ssystem = ""
  if $list_system {
    let selection = ($system_messages | input list -f (echo-g "Select system message: "))
    $ssystem = (open ($system_messages_files | find ("/" + $selection + ".md") | get 0 | ansi strip))
  } else if (not ($select_system | is-empty)) {
    try {
      $ssystem = (open ($system_messages_files | find ("/" + $select_system + ".md") | get 0 | ansi strip))
    } 
  }
  let system = if ($ssystem | is-empty) {$system} else {$ssystem}

  #select pre-prompt from database
  let pre_prompt_files = ls ($env.MY_ENV_VARS.chatgpt_config | path join prompt) | sort-by name | get name
  let pre_prompts = $pre_prompt_files | path parse | get stem

  mut preprompt = ""
  if $pre_prompt {
    let selection = ($pre_prompts | input list -f (echo-g "Select pre-prompt: "))
    $preprompt = (open ($pre_prompt_files | find ("/" + $selection + ".md") | get 0 | ansi strip))
  } else if (not ($select_preprompt | is-empty)) {
    try {
      $preprompt = (open ($pre_prompt_files | find ("/" + $select_preprompt + ".md") | get 0 | ansi strip))
    }
  }

  #build prompt
  let prompt = (
    if ($document | is-not-empty) {
      $preprompt + "\n# DOCUMENT\n\n" + (open $document) + "\n\n# INPUT\n\n'''\n" + $query + "\n'''" 
    } else if ($preprompt | is-empty) and $delim_with_backquotes {
      "'''" + "\n" + $query + "\n" + "'''"
    } else if ($preprompt | is-empty) {
      $query
    } else if $delim_with_backquotes {
      $preprompt + "\n" + "'''" + "\n" + $query + "\n" + "'''"
    } else {
      $preprompt + $query
    } 
  )

  #search prompts
  let search_prompt = "From the next question delimited by triple single quotes ('''), please extract one sentence appropriated for a google search. Deliver your response in plain text without any formatting nor commentary on your part, and in the ORIGINAL language of the question. The question:\n'''" + $prompt + "\n'''"
  
  let search = if $web_search {google_ai $search_prompt -t 0.2 | lines | first} else {""}
  let web_content = if $web_search {google_search $search -n $web_results -v} else {""}
  let web_content = if $web_search {ai google_search-summary $prompt $web_content -G -m} else {""}
  
  let prompt = (
    if $web_search {
      $prompt + "\n\n You can complement your answer with the following up to date information about my question I obtained from a google search, in markdown format:\n" + $web_content
    } else {
      $prompt
    }
  )

  # default models
  let input_model = $model
  let model = if $model == "claude-3.5" {"claude-3-5-sonnet-latest"} else {$model}
  let model = if $model == "claude-vision" {"claude-3-5-sonnet-latest"} else {$model}

  let max_tokens = if $model =~ "claude-3-5" {8192} else {4096}

  # call to api
  let header = {x-api-key: $env.MY_ENV_VARS.api_keys.anthropic.api_key, anthropic-version: $anthropic_version}
  let site = "https://api.anthropic.com/v1/messages"
  
  let request = (
    if $input_model == "claude-vision" {
      {
        model: $model,
        messages: [
          {
            role: "user",
            content: [
              {
                type: "image",
                source: {
                  type: "base64",
                  media_type: ("image/" + $extension),
                  data: $image,
                }
              },
              {
                type: "text", 
                text: $prompt
              }
            ]
          }
        ],
        max_tokens: $max_tokens,
        system: $system,
        temperature: $temp
      }
    } else {
      {
        model: $model,
        messages: [
          {
            role: "user",
            content: $prompt
          }
        ],
        max_tokens: $max_tokens,
        system: $system,
        temperature: $temp
      }
    }
  )

  try {
    let answer = http post -t application/json -H $header $site $request
    return $answer.content.text.0
  } catch {
    return (http post -t application/json -H $header $site $request -e)
  }
}