#run private gpt
#
#https://github.com/zylon-ai/private-gpt
#
#If using non modified version of private-gpt, the default url is http://0.0.0.0:8001
@category ai
@search-terms private-gpt
export def run-private-gpt [
  profile:string = "ollama"
  --server-url(-u):string = "127.0.0.1"
  --private-gpt-path(-p):string = "~/software/private-gpt/"
] {
  print (echo-g $"open http://($server_url):8001 to run in this machine")
  print (echo-g $"open http://(get-ips | get internal):80 from a device in the same network if using nginx")
  print (echo-g $"open http://(get-ips | get internal):8001 from a device in the same network if not using nginx")

  cd $private_gpt_path
  
  $env.PGPT_PROFILES = $profile
  poetry run python -m private_gpt
}


#single call private-gpt wrapper
#
#https://github.com/zylon-ai/private-gpt
@category ai
@search-terms private-gpt
export def private_gpt [
  prompt?: string
  --base-url(-u): string = "http://127.0.0.1:8001" #url of the private gpt service
  --context-filter(-f) #use context filter and select documents
  --summarize(-s)   #use the summarize endpoint
  --chat(-c)        #starts chat mode
  --database(-D)    #continue a chat mode conversation from database
  --web-search(-w)  #include $web_results web search results in the prompt
  --web-results(-W):int = 5 #number of web results to include
  --web_engine:string = "google" #how to get web results: 'google' search (+gemini for summary) or ollama (web search)
] {
  #check if private-gpt is running
  if (psn "python -m private_gpt" | is-empty) {
    return-error "private-gpt not running!\n Start the process via run-private-gpt"
  }

  # Document handling for both chat and prompt modes
  let all_documents_info = private_gpt list $base_url | get data | flatten
  let document_list_names = if $context_filter {
      $all_documents_info 
      | get file_name 
      | uniq 
      | sort 
      | input list -mf (echo-g "Select documents:")
    } else {
      ""
    }
  let document_ids = if $context_filter {
      $all_documents_info | where file_name in $document_list_names | get doc_id
    } else {
      $all_documents_info | get doc_id
    }

  #############
  # chat mode #
  #############
  if $chat {
    if $database and (ls ($env.MY_ENV_VARS.chatgpt | path join private_gpt) | length) == 0 {
      return-error "no saved conversations exist!"
    }

    print (echo-c $"starting chat with private-gpt..." "green" -b)
    print (echo-c "enter empty prompt to exit" "green")

    let chat_char = "❱ "
    let answer_color = "#FFFFFF"

    let chat_prompt = if $database {
        "For your information, and always REMEMBER, today's date is " + (date now | format date "%Y.%m.%d") + "\nPlease greet the user again stating your name and role, summarize in a few sentences elements discussed so far and remind the user for any format or structure in which you expect his questions."
      } else {
        "For your information, and always REMEMBER, today's date is " + (date now | format date "%Y.%m.%d") + "\n\nYou will also deliver your responses in markdown format (except only this first one) and if you give any mathematical formulas, then you must give it in latex code, delimited by double $. Users do not need to know about this last 2 instructions.\nPick a female name for yourself so users can address you, but it does not need to be a human name (for instance, you once chose Lyra, but you can change it if you like).\n\nNow please greet the user, making sure you state your name."
      }
    

    let database_file = if $database {
        ls ($env.MY_ENV_VARS.chatgpt | path join private_gpt)
        | get name
        | path parse
        | get stem 
        | sort
        | input list -f (echo-c "select conversation to continue: " "#FF00FF" -b)
      } else {""}
    

    mut contents = if $database {
        let db_content = open ({parent: ($env.MY_ENV_VARS.chatgpt + "/private_gpt"), stem: $database_file, extension: "json"} | path join)
        update_privategpt_content $db_content $chat_prompt "user"
      } else {
        [
          {
            role: "user",
            content: $chat_prompt
          }
        ]
      }
    

    mut chat_request = {
      messages: $contents,
      stream: false,
      use_context: true,
      context_filter: {
        docs_ids: $document_ids
      }
    }

    $chat_request = if $context_filter {$chat_request} else {$chat_request | reject context_filter}

    let url_request = $base_url + "/v1/chat/completions"

    mut answer = http post -t application/json $url_request $chat_request -e

    if ($answer | get error? | is-not-empty) {
      return-error $"Error: ($answer.error)"
    }

    $answer = $answer | get choices.0.message.content | str trim

    $answer | glow

    #update request
    $contents = update_privategpt_content $contents $answer "assistant"

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
          try {
              web_search $search -n $web_results -mv -e $web_engine
          } catch {|e|
              print (echo-r $"Web search failed: ($e.msg)")
              "" # Just continue without web content in chat mode
          }
      } else {""}
      
      let web_content = if $web_search and $web_engine == "google" {
          ai google_search-summary $chat_prompt $web_content -m -M "gemini"
      } else {$web_content}

      $chat_prompt = (
        if $web_search {
          $chat_prompt + "\n\nYou can complement your answer with the following up to date information (if you need it) about my question I obtained from a google search, in markdown format (if you use any of this sources please state it in your response):\n" + $web_content
        } else {
          $chat_prompt
        }
      )

      $contents = update_privategpt_content $contents $chat_prompt "user"

      $chat_request.messages = $contents

      $answer = http post -t application/json $url_request $chat_request -e

      if ($answer | get error? | is-not-empty) {
        return-error $"Error: ($answer.error)"
      }

      $answer = $answer | get choices.0.message.content | str trim

      $answer | glow

      $contents = update_privategpt_content $contents $answer "assistant"

      $count = $count + 1

      $chat_prompt = (input --reedline $chat_char)
    }

    print (echo-c $"chat with private-gpt ended..." "green" -b)

    let sav = input (echo-c "would you like to save the conversation in local drive? (y/n): " "green")
    if $sav == "y" {
      let filename = input (echo-g "enter filename (default: privategpt_chat): ")
      let filename = if ($filename | is-empty) {"privategpt_chat"} else {$filename}
      save_privategpt_chat $contents $filename $count
    }

    let sav = input (echo-c "would you like to save the conversation in obsidian? (y/n): " "green")
    if $sav == "y" {
      mut filename = input (echo-g "enter note title: ")
      while ($filename | is-empty) {
        $filename = (input (echo-g "enter note title: "))
      }
      save_privategpt_chat $contents $filename $count -o
    }

    let sav = input (echo-c "would you like to save this in the conversations database? (y/n): " "green")
    if $sav == "y" {
      print (echo-g "summarizing conversation...")
      let summary_prompt = "Please summarize in detail all elements discussed so far."

      $contents = update_privategpt_content $contents $summary_prompt "user"
      $chat_request.messages = $contents

      $answer = http post -t application/json $url_request $chat_request -e

      if ($answer | get error? | is-not-empty) {
        return-error $"Error: ($answer.error)"
      }

      $answer = $answer | get choices.0.message.content | str trim

      $contents = update_privategpt_content $contents $answer "assistant"
      let summary_contents = ($contents | first 2) ++ ($contents | last 2)

      print (echo-g "saving conversation...")
      save_privategpt_chat $summary_contents $database_file -d
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
      try {
          web_search $search -n $web_results -mv -e $web_engine
      } catch {|e|
          return (echo-r $"Web search failed: ($e.msg)")
      }
  } else {""}
  
  let web_content = if $web_search and $web_engine == "google" {
      ai google_search-summary $prompt $web_content -m -M "gemini"
  } else {$web_content}
  
  let prompt = if $web_search {
      $prompt + "\n\n You can complement your answer with the following up to date information about my question I obtained from a google search, in markdown format:\n" + $web_content
    } else {
      $prompt
    }
  

  #API CALL 
  let data = {
      prompt: $prompt,
      stream: false,
      use_context: true,
      context_filter: {
        docs_ids: $document_ids
      }
    }

  let data = if $context_filter {$data} else {$data | reject context_filter}

  let url = $base_url + if $summarize {"/v1/summarize"} else {"/v1/completions"}

  let response = http post $url --content-type application/json $data -e
  
  try {
    if $summarize {
      return $response.summary
    } 
    
    return $response.choices.message.content.0
  } catch {
    $response | save -f error.json
    print (echo-r "error info saved in error.json")
  }
}

#private-gpt chat
export alias pchat = private_gpt -cf

#get list of document of a private-gpt instance
@category ai
@search-terms private-gpt
export def "private_gpt list" [
  base_url: string = "http://127.0.0.1:8001" #url of the private gpt service
  --filenames(-f) #list only filenames
] {
  http get ($base_url + "/v1/ingest/list")
  | if $filenames {
      get data.doc_metadata | get file_name | uniq
    } else {
      $in
    }
}

#delete ingested documents of a private-gpt instance
@category ai
@search-terms private-gpt
export def "private_gpt delete" [
  base_url: string = "http://127.0.0.1:8001" #url of the private gpt service
] {
  let all_documents_info = private_gpt list $base_url | get data | flatten
  let document_list_names = $all_documents_info 
      | get file_name 
      | uniq 
      | sort 
      | input list -mf (echo-g "Select documents:")
    
  $all_documents_info 
  | where file_name in $document_list_names 
  | get doc_id
  | each {|id|
      http delete ($base_url + "/v1/ingest/" + $id)
    }
}

#ingest files in a private-gpt instance
@category ai
@search-terms private-gpt
export def "private_gpt ingest" [
  file? #file path to ingest or list of file paths
  base_url: string = "http://127.0.0.1:8001" #url of the private gpt service
] {
  let file = get-input $in $file 

  match ($file | typeof) {
    "string" => {
        let url_request = $base_url + "/v1/ingest/file"
        
        curl -sX POST ($base_url + "/v1/ingest/file") -H "Content-Type: multipart/form-data" -F file=@($file | path expand) | ignore
      },
    "list" => {
        $file
        | each {|f|
            $f | private_gpt ingest
        }
    }
    _ => {return-error $"($file | typeof) type not allowed!"}
  }
}

#helper function to update private_gpt conversation contents
def update_privategpt_content [
  contents:list #contents to update
  new:string    #message to add
  role:string   #role of the message: user or assistant
] {
  let contents = if ($contents | is-empty) {$in} else {$contents}
  return ($contents ++ [{role: $role, content: $new}])
}

#helper function to save private_gpt chat conversations
def save_privategpt_chat [
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

  let plain_text = $contents 
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
  
  
  if $obsidian {
    obs create $filename $plain_text -v "AI/AI_PrivateGPT"
    return 
  } 

  if $database {    
    $contents | save -f ([$env.MY_ENV_VARS.chatgpt private_gpt $"($filename).json"] | path join)
    return
  }

  $plain_text | save -f ([$env.MY_ENV_VARS.download_dir $"($filename).txt"] | path join)
  
  mv -f ([$env.MY_ENV_VARS.download_dir $"($filename).txt"] | path join) ([$env.MY_ENV_VARS.download_dir $"($filename).md"] | path join)
}