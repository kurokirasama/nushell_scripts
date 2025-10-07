#single call ollama wrapper
@category ai
@search-terms ollama
export def o_llama [
  query?: string
  --model(-m):string
  --system(-s):string = "You are a helpful assistant." # system message
  --temp(-t): float = 0.9             # the temperature of the model
  --image(-i):string                  # filepath of image file for gemini-pro-vision
  --list_system(-l) = false           # select system message from list
  --pre_prompt(-p) = false            # select pre-prompt from list
  --delim_with_backquotes(-d) = false # to delimit prompt (not pre-prompt) with triple backquotes (')
  --select_system: string             # directly select system message    
  --select_preprompt: string          # directly select pre_prompt
  --chat(-c)             #starts chat mode (text only, gemini only)
  --database(-D) = false #continue a chat mode conversation from database
  --web_search(-w) = false  #include $web_results web search results in the prompt
  --web_results(-n):int = 5 #number of web results to include
  --web_model:string = "gemini" #model to summarize web results
  --verbose(-v) = false #show the attempts to call the gemini api
  --document:string     #uses provided document to retrieve the answer
  --embed(-e) = false   #make embedding instead of generate or chat
] {
  let model = if ($model | is-empty) {
      ollama list | detect columns  | get NAME | input list -f (echo-g "Select model:")
    } else if ($model not-like "cloud") {
      ollama list | detect columns | where NAME like $model | get NAME.0
    } else {
        $model
    }

  let embed = if ($model like "embed") {true} else {$embed}

  #select system message from database
  let system_messages_files = ls ($env.MY_ENV_VARS.chatgpt_config | path join system) | sort-by name | get name
  let system_messages = $system_messages_files | path parse | get stem

  mut ssystem = ""
  if $list_system {
    let selection = ($system_messages | input list -f (echo-g "Select system message: "))
    $ssystem = (open ($system_messages_files | find -n ("/" + $selection + ".md") | get 0))
  } else if (not ($select_system | is-empty)) {
    try {
      $ssystem = (open ($system_messages_files | find -n ("/" + $select_system + ".md") | get 0))
    } 
  }
  let system = if ($ssystem | is-empty) {$system} else {$ssystem}

  #select pre-prompt from database
  let pre_prompt_files = ls ($env.MY_ENV_VARS.chatgpt_config | path join prompt) | sort-by name | get name
  let pre_prompts = $pre_prompt_files | path parse | get stem

  mut preprompt = ""
  if $pre_prompt {
    let selection = ($pre_prompts | input list -f (echo-g "Select pre-prompt: "))
    $preprompt = (open ($pre_prompt_files | find -n ("/" + $selection + ".md") | get 0))
  } else if (not ($select_preprompt | is-empty)) {
    try {
      $preprompt = (open ($pre_prompt_files | find -n ("/" + $select_preprompt + ".md") | get 0))
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

  #############
  # chat mode #
  #############
  if $chat {
    if $database and (ls ($env.MY_ENV_VARS.chatgpt | path join ollama) | length) == 0 {
      return-error "no saved conversations exist!"
    }

    print (echo-c $"starting chat with ollama-($model)..." "green" -b)
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
        ls ($env.MY_ENV_VARS.chatgpt | path join ollama)
        | get name
        | path parse
        | get stem 
        | sort
        | input list -f (echo-c "select conversation to continue: " "#FF00FF" -b)
      } else {""}
    )

    mut contents = (
      if $database {
        open ({parent: ($env.MY_ENV_VARS.chatgpt + "/ollama"), stem: $database_file, extension: "json"} | path join)
        | update_ollama_content $in $chat_prompt "user"
      } else {
        [
          {
            role: "user",
            content: $chat_prompt
          }
        ]
      }
    )

    mut chat_request = {
      model: $model,
      system: $system,
      messages: $contents,
      stream: false,
      options: {
        temperature: $temp
      }
    }

    let url_request = "http://localhost:11434/api/chat"

    mut answer = http post -t application/json $url_request $chat_request -e 

    if ($answer | get error? | is-not-empty) {
      return-error $"Error: ($answer.error)"
    } 

    $answer = $answer | get message.content | str trim

    # print (echo-c ("\n" + $answer + "\n") $answer_color -b)
    $answer | glow

    #update request
    $contents = update_ollama_content $contents $answer "assistant"

    #first question
    if not ($prompt | is-empty) {
      print (echo-c ($chat_char + $prompt + "\n") "white")
    }
    mut chat_prompt = if ($prompt | is-empty) {input --reedline $chat_char} else {$prompt}

    mut count = ($contents | length) - 1
    while not ($chat_prompt | is-empty) {
      let search_prompt = "From the next question delimited by triple single quotes ('''), please extract one sentence appropriate for a google search. Deliver your response in plain text without any formatting nor commentary on your part, and in the ORIGINAL language of the question. The question:\n'''" + $chat_prompt + "\n'''"

      let search = if $web_search {google_ai $search_prompt -t 0.2 | lines | first} else {""}
      
      let web_content = if $web_search {
          if $web_model == "ollama" {
              ollama_search $search -n $web_results -mv
          } else {
              google_search $search -n $web_results -v
          }
      } else {""}
            
      let web_content = if $web_search and $web_model == "gemini" {
          ai google_search-summary $chat_prompt $web_content -m -M $web_model
      } else {$web_content}

      $chat_prompt = (
        if $web_search {
          $chat_prompt + "\n\nYou can complement your answer with the following up to date information (if you need it) about my question I obtained from a google search, in markdown format (if you use any of this sources please state it in your response):\n" + $web_content
        } else {
          $chat_prompt
        }
      )

      $contents = update_ollama_content $contents $chat_prompt "user"

      $chat_request.messages = $contents

      $answer = http post -t application/json $url_request $chat_request | get message.content | str trim

      # print (echo-c ("\n" + $answer + "\n") $answer_color -b)
      $answer | glow

      $contents = update_ollama_content $contents $answer "assistant"

      $count = $count + 1

      $chat_prompt = (input --reedline $chat_char)
    }

    print (echo-c $"chat with ollama-($model) ended..." "green" -b)

    let sav = input (echo-c "would you like to save the conversation in local drive? (y/n): " "green")
    if $sav == "y" {
      let filename = input (echo-g "enter filename (default: ollama_chat): ")
      let filename = if ($filename | is-empty) {"ollama_chat"} else {$filename}
      save_ollama_chat $contents $filename $count
    }

    let sav = input (echo-c "would you like to save the conversation in obsidian? (y/n): " "green")
    if $sav == "y" {
      mut filename = input (echo-g "enter note title: ")
      while ($filename | is-empty) {
        $filename = (input (echo-g "enter note title: "))
      }
      save_ollama_chat $contents $filename $count -o
    }

    let sav = input (echo-c "would you like to save this in the conversations database? (y/n): " "green")
    if $sav == "y" {
      print (echo-g "summarizing conversation...")
      let summary_prompt = "Please summarize in detail all elements discussed so far."

      $contents = update_ollama_content $contents $summary_prompt "user"
      $chat_request.messages = $contents

      $answer = http post -t application/json $url_request $chat_request | get message.content | str trim

      $contents = update_ollama_content $contents $answer "assistant"
      let summary_contents = ($contents | first 2) ++ ($contents | last 2)

      print (echo-g "saving conversation...")
      save_ollama_chat $summary_contents $database_file -d
    }
    return
  }

  ###############
  # prompt mode #
  ###############
  let prompt = if ($prompt | is-empty) {$in} else {$prompt}
  if ($prompt | is-empty) {
    return-error "Empty prompt!!!"
  }

  #search prompts
  let search_prompt = "From the next question delimited by triple single quotes ('''), please extract one sentence appropriated for a google search. Deliver your response in plain text without any formatting nor commentary on your part, and in the ORIGINAL language of the question. The question:\n'''" + $prompt + "\n'''"
  
  let search = if $web_search {google_ai $search_prompt -t 0.2 | lines | first} else {""}
  
  let web_content = if $web_search {
      if $web_model == "ollama" {
          ollama_search $search -n $web_results -mv
      } else {
          google_search $search -n $web_results -v
      }
  } else {""}
              
  let web_content = if $web_search and $web_model == "gemini" {
      ai google_search-summary $prompt $web_content -m -M $web_model
  } else {$web_content}
  
  let prompt = (
    if $web_search {
      $prompt + "\n\n You can complement your answer with the following up to date information about my question I obtained from a google search, in markdown format:\n" + $web_content
    } else {
      $prompt
    }
  )

  #API CALL (pending vision)
  let data = if $embed {
    {
      model: $model,
      input: $prompt
    }
  } else {
    {
      model: $model,
      system: $system,
      prompt: $prompt,
      stream: false,
      options: {
        temperature: $temp
      }
    }
  }
  
  let endpoint = if $embed {"embed"} else {"generate"}
  let url = "http://localhost:11434/api/" + $endpoint

  let response = http post $url --content-type application/json $data -e 
    
  if ($response | get error? | is-not-empty) {
    return-error $"Error: ($response.error)"
  } 

  if $embed {
    return $response.embeddings.0
  }

  return $response.response
}

#update ollama contents with new content
def update_ollama_content [
  contents:list #contents to update
  new:string    #message to add
  role:string   #role of the message: user or assistant
] {
  let contents = if ($contents | is-empty) {$in} else {$contents}
  return ($contents ++ [{role: $role, content: $new}])
}

#save gemini conversation to plain text
def save_ollama_chat [
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
        if $row.role like "assistant" {
          $row.content + "\n"
        } else {
          "> **" + $row.content + "**\n"
        }
      }
    | to text
  )
  
  if $obsidian {
    obs create $filename $plain_text -v "AI/AI_Ollama"
    return 
  } 

  if $database {    
    $contents | save -f ([$env.MY_ENV_VARS.chatgpt ollama $"($filename).json"] | path join)

    return
  }

  $plain_text | save -f ([$env.MY_ENV_VARS.download_dir $"($filename).txt"] | path join)
  
  mv -f ([$env.MY_ENV_VARS.download_dir $"($filename).txt"] | path join) ([$env.MY_ENV_VARS.download_dir $"($filename).md"] | path join)
}
