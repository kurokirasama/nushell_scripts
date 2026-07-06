const last_gemini_model = "gemini-3.5-flash"
const gemini_models = [
  "gemini-3.5-flash"
  "gemini-3.1-pro"
  "gemini-3.1-flash-lite"
  "gemini-pro-vision"
]	

#single call to google ai LLM api wrapper and chat mode
#
#Available models at https://ai.google.dev/models:
# - gemini-3.5-flash: Optimized for speed, agentic workflows, and coding (GA May 2026)
# - gemini-3.1-pro: High-capability, complex reasoning, agentic coding, 1M context
# - gemini-3.1-flash-lite: Fast, cost-efficient model for high-volume tasks
# - gemini-pro-vision: Placeholder for image input, uses gemini-3.5-flash
# - text-embedding-004: Text embedding model
# - aqa: Retrieval
#
#system messages are available in:
#   [$env.MY_ENV_VARS.llms_configs system] | path join
#
#pre_prompts are available in:
#   [$env.MY_ENV_VARS.llms_configs prompt] | path join
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
@category ai
@search-terms gemini
export def google_ai [
    query?: string                          # the query to Gemini
    --model(-m):string@$gemini_models = "gemini-3.5-flash" # the model gemini-3.5-flash, gemini-3.1-pro, etc
    --system(-s):string = "You are a helpful assistant." # system message
    --temp(-t): float = 0.9             # the temperature of the model
    --image(-i):any                     # filepath of image file (or list of files) for gemini-pro-vision
    --list_system(-l) = false           # select system message from list
    --pre_prompt(-p) = false            # select pre-prompt from list
    --delim_with_backquotes(-d) = false # to delimit prompt (not pre-prompt) with triple backquotes (')
    --select_system: string             # directly select system message    
    --select_preprompt: string          # directly select pre_prompt
    --safety_settings:table  #table with safety setting configuration (Currently ignored in Interactions API)
    --chat(-c)     #starts chat mode (text only, gemini only)
    --database(-D) = false   #continue a chat mode conversation from database
    --web_search(-w) = false #include $web_results web search results in the prompt
    --web_results(-n):int = 5     #number of web results to include
    --web_engine:string = "google" #how to get web results: 'google' search (+gemini for summary) or ollama (web search)
    --no_retry_models = false #if true, only the primary model is attempted
    --verbose(-v) = false     #show the attempts to call the gemini api
    --document:string         #uses provided document to retrieve the answer
    --paid(-P) = false	  	  #use the billing api for greater limits
] {
  let query = get-input $in $query

  #api parameters
  let apikey = if $paid {
    get-api-key "google.gemini_paid"
  } else {
    get-api-key "google.gemini"
  }

  let safetySettings = if ($safety_settings | is-empty) {
      [
          { category: "HARM_CATEGORY_HARASSMENT", threshold: "BLOCK_NONE" },
          { category: "HARM_CATEGORY_HATE_SPEECH", threshold: "BLOCK_NONE" },
          { category: "HARM_CATEGORY_SEXUALLY_EXPLICIT", threshold: "BLOCK_NONE" },
          { category: "HARM_CATEGORY_DANGEROUS_CONTENT", threshold: "BLOCK_NONE" },
          { category: "HARM_CATEGORY_CIVIC_INTEGRITY", threshold: "BLOCK_NONE" }
      ]
    } else {
      $safety_settings
    }

  let max_output_tokens = match $model {
    $m if ($m =~ "gemini-3.5") => 64000
    $m if ($m =~ "gemini-3.1") => 64000
    $m if ($m =~ "gemini-3") => 64000
    _ => 8192
  }

  let input_model = $model
  let model = match $model {
    "gemini-pro-vision" => "gemini-3.5-flash"
    "gemini-3.5" => "gemini-3.5-flash"
    "gemini-3.1" => "gemini-3.1-pro"
    "gemini-3.0" | "gemini-3" => $last_gemini_model
    _ => $model
  }  

  let url_request = {
      scheme: "https",
      host: "generativelanguage.googleapis.com",
      path: "/v1beta/interactions",
      params: { key: $apikey }
    } | url join

  #select system message from database
  let system_messages_files = ls ($env.MY_ENV_VARS.llms_configs | path join system) | sort-by name | get name
  let system_messages = $system_messages_files | path parse | get stem

  mut ssystem = ""
  if $list_system {
    let selection = $system_messages | input list -f (echo-g "Select system message: ")
    $ssystem = (open --raw ($system_messages_files | find -n ("/" + $selection + ".md") | get 0))
  } else if (not ($select_system | is-empty)) {
    try {
      $ssystem = (open --raw ($system_messages_files | find -n ("/" + $select_system + ".md") | get 0))
    } 
  }
  let system = if ($ssystem | is-empty) {$system} else {$ssystem}

  #select pre-prompt from database
  let pre_prompt_files = ls ($env.MY_ENV_VARS.llms_configs | path join prompt) | sort-by name | get name
  let pre_prompts = $pre_prompt_files | path parse | get stem

  mut preprompt = ""
  if $pre_prompt {
    let selection = $pre_prompts | input list -f (echo-g "Select pre-prompt: ")
    $preprompt = (open --raw ($pre_prompt_files | find -n ("/" + $selection + ".md") | get 0))
  } else if (not ($select_preprompt | is-empty)) {
    try {
      $preprompt = (open --raw ($pre_prompt_files | find -n ("/" + $select_preprompt + ".md") | get 0))
    }
  }

  if $verbose {
      if ($preprompt | is-empty) {
          print (echo-y "Resolved Pre-prompt: [EMPTY]")
      } else {
          print (echo-g $"Resolved Pre-prompt length: ($preprompt | str length) characters")
      }
  }

  #build prompt
  let prompt = if ($document | is-not-empty) {
      $preprompt + "\n# DOCUMENT\n\n" + (open --raw $document) + "\n\n# INPUT\n\n'''\n" + $query + "\n'''" 
    } else if ($preprompt | is-empty) and $delim_with_backquotes {
      "'''" + "\n" + $query + "\n" + "'''"
    } else if ($preprompt | is-empty) {
      $query
    } else if $delim_with_backquotes {
      $preprompt + "\n" + "'''" + "\n" + $query + "\n" + "'''"
    } else {
      $preprompt + $query
    } 

  # helper to convert contents to interaction steps
  let to_steps = { |c| 
      $c | each { |it|
          let type = if $it.role == "user" { "user_input" } else { "model_output" }
          let content = ($it.parts | each { |p| { type: "text", text: $p.text } })
          { type: $type, content: $content }
      }
  }

  ###############
  ## chat mode ##
  ###############
  if $chat {
    print (echo-c "starting chat with gemini..." "green" -b)
    print (echo-c "enter empty prompt to exit" "green")

    let chat_char = "❱ "
    let chat_prompt = if $database {
        "For your information, and always REMEMBER, today's date is " + (date now | format date "%Y.%m.%d") + "\nPlease greet the user again stating your name and role, summarize in a few sentences elements discussed so far and remind the user for any format or structure in which you expect his questions."
      } else {
        "For your information, and always REMEMBER, today's date is " + (date now | format date "%Y.%m.%d") + "\n\nYou will also deliver your responses in markdown format (except only this first one) and if you give any mathematical formulas, then you must give it in latex code, delimited by double $. Users do not need to know about this last 2 instructions.\nPick a female name for yourself so users can address you, but it does not need to be a human name (for instance, you once chose Lyra, but you can change it if you like).\n\nNow please greet the user, making sure you state your name."
      }
    

    let database_file = if $database {
        ls ($env.MY_ENV_VARS.chatgpt | path join bard)
        | get name
        | path parse
        | get stem 
        | sort
        | input list -f (echo-c "select conversation to continue: " "#FF00FF" -b)
      } else {""}
    

    mut contents = if $database {
        let db_content = open ({parent: ($env.MY_ENV_VARS.chatgpt + "/bard"), stem: $database_file, extension: "json"} | path join)
        update_gemini_content $db_content $chat_prompt "user"
      } else {
        [ { role: "user", parts: [[text]; [$chat_prompt]] } ]
      }
    
    mut chat_request = {
        model: ("models/" + $model),
        system_instruction: $system,
        input: (do $to_steps $contents),
        generation_config: { temperature: $temp }
    }

    let answer_resp = http post -t application/json -H ["Api-Revision", "2026-05-20"] $url_request $chat_request
    let steps = ($answer_resp | get -o steps)
    if ($steps | is-empty) { return-error "No steps in chat response" }
    mut answer = ($steps | where type == "model_output" | first | get content | first | get text)

    $answer | glow

    $contents = update_gemini_content $contents $answer "model"

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
              web_search $search -n $web_results -m -v -e $web_engine 
          } catch {|e|
              print (echo-r $"Web search failed: ($e.msg)")
              "" # Just continue without web content in chat mode
          }
      } else {""}
      let web_content = if $web_search and $web_engine == "google" { ai google_search-summary $chat_prompt $web_content -m -M "gemini" } else {$web_content}

      $chat_prompt = (
        if $web_search {
          $chat_prompt + "\n\nYou can complement your answer with the following up to date information (if you need it) about my question I obtained from a google search, in markdown format (if you use any of this sources please state it in your response):\n" + $web_content
        } else {
          $chat_prompt
        }
      )

      $contents = update_gemini_content $contents $chat_prompt "user"
      $chat_request.input = (do $to_steps $contents)

      let answer_resp = http post -t application/json -H ["Api-Revision", "2026-05-20"] $url_request $chat_request
      let steps = ($answer_resp | get -o steps)
      if ($steps | is-empty) { return-error "No steps in chat response" }
      $answer = ($steps | where type == "model_output" | first | get content | first | get text)

      $answer | glow

      $contents = update_gemini_content $contents $answer "model"
      $count = $count + 1
      $chat_prompt = (input --reedline $chat_char)
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
      while ($filename | is-empty) { $filename = (input (echo-g "enter note title: ")) }
      save_gemini_chat $contents $filename $count -o
    }

    let sav = input (echo-c "would you like to save this in the conversations database? (y/n): " "green")
    if $sav == "y" {
      print (echo-g "summarizing conversation...")
      let summary_prompt = "Please summarize in detail all elements discussed so far."
      $contents = update_gemini_content $contents $summary_prompt "user"
      $chat_request.input = (do $to_steps $contents)

      let answer_resp = http post -t application/json -H ["Api-Revision", "2026-05-20"] $url_request $chat_request
      let steps = ($answer_resp | get -o steps)
      if ($steps | is-empty) { return-error "No steps in chat response" }
      $answer = ($steps | where type == "model_output" | first | get content | first | get text)

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
  if ($prompt | is-empty) { return-error "Empty prompt!!!" }
  
  # Handle multiple images
  let images = if ($image | is-empty) { [] } else {
    if ($image | describe) == "string" { [$image] } else { $image }
  }

  let image_parts = if $input_model == "gemini-pro-vision" {
      $images | each {|img|
        let ext = $img | path parse | get extension
        let data = open ($img | path expand) | encode base64
        { type: "image", mime_type: ("image/" + $ext), data: $data }
      }
    } else { [] }

  #search prompts
  let web_content = if $web_search {
    let search_prompt = "From the next question delimited by triple single quotes ('''), please generate a JSON list of search queries that would be useful to gather all necessary information to answer it completely. Ensure that the queries are not redundant, each query searches for different information, and the list is minimal (a single query is allowed and preferred if sufficient). Return at most 10 queries. Deliver your response in a raw JSON array of strings, without markdown formatting or code blocks. If no search is needed, return an empty array []. The question:\n'''" + $prompt + "\n'''"
    let search_json = try { google_ai $search_prompt -t 0.2 } catch { "[]" }
    
    let queries = try {
      $search_json 
      | str replace -r "(?s).*?\\[" "[" 
      | str replace -r "(?s)\\].*" "]" 
      | from json
    } catch {
      # Fallback: single query extraction
      let fallback_prompt = "From the next question delimited by triple single quotes ('''), please extract one sentence appropriated for a google search. Deliver your response in plain text without any formatting nor commentary on your part, and in the ORIGINAL language of the question. The question:\n'''" + $prompt + "\n'''"
      let fallback_search = try { google_ai $fallback_prompt -t 0.2 | lines | first } catch { "" }
      if ($fallback_search | is-empty) { [] } else { [$fallback_search] }
    }

    if ($queries | is-empty) {
      ""
    } else {
      ai web_search-multi $queries -n $web_results --web_engine $web_engine --verbose $verbose
    }
  } else {
    ""
  }
  
  let prompt = if $web_search and not ($web_content | is-empty) {
      $prompt + "\n\n You can complement your answer with the following up to date information about my question I obtained from a google search, in markdown format:\n" + $web_content
    } else { $prompt }

  # call to api
  mut request = {
    model: ("models/" + $model),
    system_instruction: $system,
    input: [
      {
        type: "user_input",
        content: ([{ type: "text", text: $prompt }] ++ $image_parts)
      }
    ],
    generation_config: {
        temperature: $temp,
        max_output_tokens: $max_output_tokens
    }
  }

  #trying different models in case of error
  mut answer: any = null
  mut index_model = 0
  let models = $gemini_models | find -v vision
  let n_models = $models | length 
  
  if $verbose {print ("retrieving from gemini models...")}

  $answer = http post -t application/json -H ["Api-Revision", "2026-05-20"] $url_request $request -e
  
  while (not $no_retry_models) and (($answer | is-empty) or ($answer == null) or ($answer | get error? | is-not-empty) or ($answer | describe) == nothing) and ($index_model < $n_models) {
    let next_model = $models | get $index_model
    $request.model = ("models/" + $next_model)

    $answer = http post -t application/json -H ["Api-Revision", "2026-05-20"] $url_request $request -e
    $index_model += 1
  }

  if ($answer | is-empty) or ($answer == null) or ($answer | describe) == nothing {
    return-error "something went wrong with the server!"
  }

  if ($answer | get error? | is-not-empty) {
    return-error $answer.error.message
  }
  
  let final_answer = $answer
  try {
    let steps = ($final_answer | get -o steps | default [])
    if ($steps | is-empty) {
        if ($final_answer | get status) == "completed" {
            return ""
        }
        $final_answer | to json | save -f gemini_no_steps.json
        return-error "No steps found in API response! Raw response saved to gemini_no_steps.json"
    }

    let output_step = ($steps | where type == "model_output" | first)
    if ($output_step | is-empty) {
        return-error "No model_output step found in API response!"
    }
    return ($output_step.content | first | get text)
  } catch {|e|
    $final_answer | to json | save -f gemini_error.json
    return-error $"something went wrong with the api! error saved in gemini_error.json\n($e.msg)"
  }
}

#update gemini contents with new content
def update_gemini_content [
  contents:list #contents to update
  new:string    #message to add
  role:string   #role of the message: user or model
] {
  let contents = if ($contents | is-empty) { [] } else { $contents }
  let parts = [[text];[$new]]
  return ($contents ++ [{role: $role, parts: $parts}])
}

#save gemini conversation to plain text
def save_gemini_chat [
  contents
  filename
  count?:int = 1  
  --obsidian(-o)  #save note to obsidian
  --database(-d)  #save to local database
] {
  if $obsidian and $database { return-error "only one of these flags allowed" }
  let filename = if ($filename | is-empty) {input (echo-g "enter filename: ")} else {$filename}

  let plain_text = $contents 
    | flatten 
    | flatten 
    | skip $count
    | each {|row| 
        if $row.role like "model" {
          $row.text + "\n"
        } else {
          "> **" + $row.text + "**\n"
        }
      }
    | to text
  
  if $obsidian {
    obs create $filename $plain_text -v "AI/AI_Bard"
    return 
  } 

  if $database {    
    $contents | save -f ([$env.MY_ENV_VARS.chatgpt bard $"($filename).json"] | path join)
    return
  }

  let full_path = ([$env.MY_ENV_VARS.download_dir $"($filename).md"] | path join)
  $plain_text | save -f $full_path
}

#single call to google ai LLM image generations api wrapper
@category ai
@search-terms google gemini imagen
export def google_aimage [
    query?: string                     # the query to Gemini
    --model(-m):string = "gemini"      #the model: gemini or imagen
    --image(-i):string                 #file path of image file for edition task
    --task(-t):string = "generation"   #task to do: generation or edit
    --number-of-images(-n):int = 1     #numbers of images to generate: 1-4 (for imagen only)
    --aspect-ratio(-a):string = "16:9" #aspect ratio: 1:1, 3:4, 4:3, 9:16 or 16:9 (for imagen only)
    --person-generation(-p):string = "ALLOW_ADULT" #ALLOW_ADULT or DONT_ALLOW (imagen only)
    --output(-o):string                #output filename
    --safety_settings:table            #table with safety settings
    --paid(-P) = false	           #use paid gemini
] {
  let prompt = get-input $in $query

  #api parameters
  let apikey = if $paid {
    get-api-key "google.gemini_paid"
  } else {
    get-api-key "google.gemini"
  }
  let safetySettings = if ($safety_settings | is-empty) {
      [
          { category: "HARM_CATEGORY_HARASSMENT", threshold: "BLOCK_NONE" },
          { category: "HARM_CATEGORY_HATE_SPEECH", threshold: "BLOCK_NONE" },
          { category: "HARM_CATEGORY_SEXUALLY_EXPLICIT", threshold: "BLOCK_NONE" },
          { category: "HARM_CATEGORY_DANGEROUS_CONTENT", threshold: "BLOCK_NONE" },
          { category: "HARM_CATEGORY_CIVIC_INTEGRITY", threshold: "BLOCK_NONE" }
      ]
    } else {
      $safety_settings
    }

  if ($number_of_images > 4) and ($model like "imagen") {
    return-error "Max. number of requested images is 4!!!"
  }

  if ($task like "edit") and ($model like "imagen") {
    return-error "Editing mode not available form Imagen model!"
  }

  let safetySettings = [
          { category: "HARM_CATEGORY_HARASSMENT", threshold: "BLOCK_NONE" },
          { category: "HARM_CATEGORY_HATE_SPEECH", threshold: "BLOCK_NONE" },
          { category: "HARM_CATEGORY_SEXUALLY_EXPLICIT", threshold: "BLOCK_NONE" },
          { category: "HARM_CATEGORY_DANGEROUS_CONTENT", threshold: "BLOCK_NONE" },
          { category: "HARM_CATEGORY_CIVIC_INTEGRITY", threshold: "BLOCK_NONE" }
      ]

  let gen = if ($model like "imagen") {":predict"} else {":generateContent"}

  let input_model = $model
  let model = if $model == "gemini" {"gemini-2.5-flash-image"} else {$model}
  let model = if $model == "imagen3" {"imagen-3.0-generate-002"} else {$model}
  let model = if $model == "imagen4" {"imagen-4.0-generate-001"} else {$model}
  let model = if $model == "imagen4ultra" {"imagen-4.0-generate-001"} else {$model}

  let url_request = {
      scheme: "https",
      host: "generativelanguage.googleapis.com",
      path: ("/v1beta/models/" + $model + $gen),
      params: { key: $apikey }
    } | url join

  let output = if ($output | is-empty) {
      (google_ai --select_preprompt dalle_image_name -d true $prompt -P $paid | from json | get name) + "_G"
    } else {
      $output
    }

  #translate prompt if not in english
  let english = google_ai --select_preprompt is_in_english -d true $prompt -P $paid | from json | get english | into bool
  let prompt = if $english and $task == "generation" {google_ai --select_system ai_art_creator --select_preprompt translate_dalle_prompt -d true $prompt -P $paid} else {$prompt}
  let prompt = if $task == "generation" {
      google_ai --select_system ai_art_creator --select_preprompt improve_dalle_prompt -d true $prompt -P $paid
    } else {
      $prompt
    }

  print (echo-g "improved prompt: ")
  print ($prompt)

  match $task {
    "generation" => {
        let request = if ($model like "imagen") {
          {
            instances: [ { prompt: $prompt } ],
            parameters: {
              sampleCount: $number_of_images,
              aspect_ratio: $aspect_ratio,
              person_generation: $person_generation
            }
          }
        } else {
          {
            contents: [{ parts: [ { text: $prompt } ] }],
            generationConfig:{ responseModalities:["Text","Image"] },
            safetySettings: $safetySettings
          }
        }

        let answer = http post -t application/json $url_request $request 
        
        if ($model like "imagen") {
          $answer.predictions.bytesBase64Encoded
          | enumerate 
          | each {|img|
              print (echo-g $"saving image ($img.index | into string)...")
              $img.item 
              | decode base64
              | save -f ($output + $"_($img.index | into string).png")
            }
        } else {
          $answer.candidates.content.parts.0.inlineData.data.0 
          | decode base64 
          | save -f ($output + ".png")
        }
      },

    "edit" => {
        let request = {
            contents: [{
              parts: [
                { text: $prompt },
                {
                  inline_data: {
                    mime_type: "image/jpeg",
                    data: (open ($image | path expand) | encode base64)
                  }
                }
              ]
            }],
            generationConfig:{ responseModalities:["Text","Image"] },
            safetySettings: $safetySettings
          }

        let answer = http post -t application/json $url_request $request

        $answer.candidates.content.parts.0.inlineData.data.0 
        | decode base64 
        | save -f ($output + ".png")
      },
    
    _ => {return-error $"($task) not available!!!"}
  }
}

#summarize the output of google_search via ai
@category ai
@search-terms google-search summary gemini chatgpt ollama
export def "ai google_search-summary" [
  question:string     #the question made to google
  web_content = ""       #output of google_search, md or table
  --md(-m)            #return concatenated md instead of table
  --model(-M):string = "gemini" #select model: gpt4, gemini, ollama
  --paid(-P)          #use paid gemini
] {
  let web_content = if ($web_content | is-empty) {$in} else {$web_content}
  let max_words = if $model == "gemini" {800000} else {100000}
  let n_webs = if ($web_content | is-empty) {
      0
  } else if ($web_content | describe | split row '<' | get 0) like "table" {
      $web_content | length
  } else {
      0
  }

  let prompt = open --raw ([$env.MY_ENV_VARS.llms_configs prompt summarize_html2text.md] | path join) 
    | str replace "<question>" $question 
  

  print (echo-g $"asking ($model) to summarize the web results...")

  if ($n_webs == 0) {
    print (echo-c $"summarizing md web results..." "green")
    
    let truncated_content = $web_content # | str truncate -m $max_words
    let complete_prompt = $prompt + "\n'''\n" + $truncated_content + "\n'''"
      
    let summarized_content = match $model {
      $s if ($s | str starts-with "llama") or ($s | str starts-with "qwq") => {
        o_llama $complete_prompt --select_system html2text_summarizer -m $model
      },
      $s if ($s | str starts-with "gpt") => {
        chat_gpt $complete_prompt --select_system html2text_summarizer -m gpt-4.1
      },
      "gemini" => {
        google_ai $complete_prompt --select_system html2text_summarizer -m gemini-2.5-flash -P $paid
      }
    }
    
    return $summarized_content
  }

  mut content = []
  for i in 0..($n_webs - 1) {
    let web = $web_content | get $i

    print (echo-c $"summarizing the results of ($web.displayLink)..." "green")

    let truncated_content = $web.content | str truncate -m $max_words

    let complete_prompt = $prompt + "\n'''\n" + $truncated_content + "\n'''"

    let summarized_content = match $model {
      $s if ($s | str starts-with "llama") or ($s | str starts-with "qwq") => {
        o_llama $complete_prompt --select_system html2text_summarizer -m $model
      },
      $s if ($s | str starts-with "gpt") => {
        chat_gpt $complete_prompt --select_system html2text_summarizer -m gpt-4.1
      },
      "gemini" => {
        google_ai $complete_prompt --select_system html2text_summarizer -m gemini-2.5-flash -P $paid
      }
    }

    $content = $content ++ [$summarized_content]
  }

  let content = $content | wrap content
  let updated_content = $web_content | reject content | merge $content

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

# Start a Gemini Deep Research session
@category ai
@search-terms gemini deep-research
export def "ai deep-research start" [
    prompt: string                          # the research prompt
    --max(-M)                               # use deep-research-max-preview-04-2026
    --no-thinking(-T)                       # disable thinking summaries
    --no-visual(-V)                         # disable visualizations
    --planning(-p)                          # enable collaborative planning
    --paid(-P)                              # use paid API key
] {
    let apikey = if $paid {
        get-api-key "google.gemini_paid"
    } else {
        get-api-key "google.gemini"
    }

    let agent = if $max {
        "deep-research-max-preview-04-2026"
    } else {
        "deep-research-preview-04-2026"
    }

    let agent_config = {
        type: "deep-research",
        thinking_summaries: (if $no_thinking { "none" } else { "auto" }),
        visualization: (if $no_visual { "off" } else { "auto" }),
        collaborative_planning: $planning
    }

    let url_request = {
        scheme: "https",
        host: "generativelanguage.googleapis.com",
        path: "/v1beta/interactions",
        params: { key: $apikey }
    } | url join

    let request = {
        agent: $agent,
        input: $prompt,
        background: true,
        store: true,
        agent_config: $agent_config
    }

    print (echo-g $"Starting deep research with agent: ($agent)...")
    
    let response = http post -t application/json -H ["Api-Revision", "2026-05-20"] $url_request $request -e
    
    if ($response | get error? | is-not-empty) {
        return-error $response.error.message
    }

    # Save planning response to JSON if planning is enabled
    if $planning {
        let plan_file = $"plan-($response.id).json"
        $response | save -f $plan_file
        print (echo-g $"Collaborative plan saved to ($plan_file)")
    }
    
    # Save ID to local config for convenience
    { interaction_id: $response.id } | save -f .gemini-research.json
    
    # Log to global history in Yandex.Disk
    let history_file = ("~/Yandex.Disk/.gemini-deep-research-history.json" | path expand)
    let history_entry = {
        id: $response.id,
        prompt: $prompt,
        agent: $agent,
        created_at: (date now | format date "%Y-%m-%dT%H:%M:%SZ"),
        status: "in_progress",
        planning: $planning
    }

    mut history = if ($history_file | path exists) { open $history_file } else { [] }
    $history = ($history | append $history_entry)
    $history | save -f $history_file

    return $response
}

# Check the status of Gemini Deep Research sessions
@category ai
@search-terms gemini deep-research
export def "ai deep-research status" [
    --id: string                            # interaction ID (optional)
    --all(-a)                               # refresh status of ALL jobs (including completed)
    --paid(-P)                              # use paid API key
] {
    let history_file = ("~/Yandex.Disk/.gemini-deep-research-history.json" | path expand)
    
    if ($id | is-not-empty) {
        # Single ID check logic
        let apikey = if $paid { get-api-key "google.gemini_paid" } else { get-api-key "google.gemini" }
        let url_request = {
            scheme: "https",
            host: "generativelanguage.googleapis.com",
            path: ("/v1beta/interactions/" + $id),
            params: { key: $apikey }
        } | url join

        let response = http get -H ["Api-Revision", "2026-05-20"] $url_request -e
        if ($response | get error? | is-not-empty) { return-error $response.error.message }
        
        # Update history if ID exists there
        if ($history_file | path exists) {
            mut history = open $history_file
            if ($history | where id == $id | is-not-empty) {
                $history = ($history | each {|job| if $job.id == $id { $job | merge { status: $response.status } } else { $job } })
                $history | save -f $history_file
            }
        }
        return $response
    } else {
        # History list and refresh logic
        if not ($history_file | path exists) {
            # Fallback to local config for a single check if no history exists
            if (".gemini-research.json" | path exists) {
                let local_id = open .gemini-research.json | get interaction_id
                return (if $paid { ai deep-research status --id $local_id -P } else { ai deep-research status --id $local_id })
            }
            print (echo-y "No history or local job found.")
            return []
        }

        mut history = open $history_file
        print (echo-g "Checking for updates on incomplete jobs...")
        
        $history = ($history | enumerate | each {|row|
            let job = $row.item
            if $all or ($job.status != "completed" and $job.status != "failed") {
                try {
                    # Call self with ID to perform API check and history update logic
                    let updated = (if $paid { ai deep-research status --id $job.id -P } else { ai deep-research status --id $job.id })
                    $job | merge { status: $updated.status }
                } catch {
                    $job
                }
            } else {
                $job
            }
        })
        
        $history | save -f $history_file
        return ($history | sort-by created_at -r)
    }
}

# Retrieve results from a completed Gemini Deep Research session
@category ai
@search-terms gemini deep-research
export def "ai deep-research retrieve" [
    --id: string                            # specific interaction ID
    --output(-o): string                    # output filename (default: report-<id>.md)
    --paid(-P)                              # use paid API key
] {
    let interaction_id = if ($id | is-not-empty) {
        $id
    } else {
        let history_file = ("~/Yandex.Disk/.gemini-deep-research-history.json" | path expand)
        if not ($history_file | path exists) {
            # Fallback to local config if history doesn't exist yet
            if (".gemini-research.json" | path exists) {
                open .gemini-research.json | get interaction_id
            } else {
                return-error "No ID provided and no history/local config found!"
            }
        } else {
            let selection = (open $history_file 
                | sort-by created_at -r 
                | each {|row| { display: $"($row.created_at) - ($row.status): ($row.prompt | str substring 0..60)...", id: $row.id } }
                | input list -d display "Select a research job to retrieve:")
            
            if ($selection | is-empty) { return }
            $selection.id
        }
    }

    let response = (if $paid { ai deep-research status --id $interaction_id -P } else { ai deep-research status --id $interaction_id })
    
    if $response.status != "completed" {
        print (echo-y $"Research session ($interaction_id) is still ($response.status).")
        return $response
    }

    # Robustly extract report text from response
    mut report = ""
    if ($response | get -o outputs | is-not-empty) {
        # Handle 'outputs' field (used by some SDKs/Extensions)
        $report = ($response.outputs | where type == "text" | each {|o| $o.text} | str join "\n\n")
    } else if ($response | get -o steps | is-not-empty) {
        # Handle 'steps' field (standard Interactions API structure)
        $report = ($response.steps 
            | where type == "model_output" 
            | each {|s| $s.content | where type == "text" | each {|c| $c.text} } 
            | flatten 
            | str join "\n\n")
    }

    if ($report | is-empty) {
        print (echo-r "Error: Could not find report content in the interaction response.")
        print "Raw response structure:"
        print ($response | columns)
        return $response
    }

    let filename = if ($output | is-empty) { $"report-($interaction_id).md" } else { $output }

    $report | save -f $filename
    print (echo-g $"Research report saved to ($filename)")
    
    return {
        id: $interaction_id,
        status: $response.status,
        filename: $filename,
        report_preview: ($report | str substring 0..200)
    }
}

# Respond to a research plan (Approve or give feedback)
@category ai
@search-terms gemini deep-research planning
export def "ai deep-research plan-respond" [
    feedback: string                        # your approval (e.g., "Approve") or feedback
    --id: string                            # interaction ID (optional)
    --paid(-P)                              # use paid API key
] {
    let interaction_id = if ($id | is-not-empty) {
        $id
    } else {
        let history_file = ("~/Yandex.Disk/.gemini-deep-research-history.json" | path expand)
        if not ($history_file | path exists) {
            if (".gemini-research.json" | path exists) {
                open .gemini-research.json | get interaction_id
            } else {
                return-error "No ID provided and no history/local config found!"
            }
        } else {
            let history = open $history_file | where planning == true and status != "continued"
            if ($history | is-empty) {
                if (".gemini-research.json" | path exists) {
                    open .gemini-research.json | get interaction_id
                } else {
                    return-error "No jobs with planning found in history!"
                }
            } else {
                let selection = ($history 
                    | sort-by created_at -r 
                    | each {|row| { display: $"($row.created_at) - ($row.status): ($row.prompt | str substring 0..60)...", id: $row.id } }
                    | input list -d display "Select a planning job to respond to:")
                
                if ($selection | is-empty) { return }
                $selection.id
            }
        }
    }

    let apikey = if $paid {
        get-api-key "google.gemini_paid"
    } else {
        get-api-key "google.gemini"
    }

    # Retrieve job details from history to get the agent/model
    let history_file = ("~/Yandex.Disk/.gemini-deep-research-history.json" | path expand)
    let job = if ($history_file | path exists) {
        open $history_file | where id == $interaction_id | first
    } else {
        { agent: "deep-research-preview-04-2026" } # Fallback
    }

    let url_request = {
        scheme: "https",
        host: "generativelanguage.googleapis.com",
        path: "/v1beta/interactions", # Correct endpoint: base /interactions
        params: { key: $apikey }
    } | url join

    let request = {
        input: $feedback,
        agent: $job.agent,
        previous_interaction_id: $interaction_id,
        agent_config: {
            type: "deep-research",
            collaborative_planning: false
        },
        background: true,
        store: true
    }

    print (echo-g $"Sending plan response for interaction: ($interaction_id)...")
    
    let response = http post -t application/json -H ["Api-Revision", "2026-05-20"] $url_request $request -e

    if ($response | describe | str starts-with "string") {
        return-error ("API returned a non-JSON response: " + $response)
    }

    if ($response | get -o error | is-not-empty) {
        return-error $response.error.message
    }

    # Update local config with the NEW continuation ID
    { interaction_id: $response.id } | save -f .gemini-research.json
    
    # Update global history: Mark the OLD job as 'continued' and log the NEW job ID
    if ($history_file | path exists) {
        mut history = open $history_file
        
        # 1. Update the original plan job
        $history = ($history | each {|job| 
            if $job.id == $interaction_id { 
                $job | merge { status: "continued" } 
            } else { 
                $job 
            } 
        })

        # 2. Add the new execution job
        let history_entry = {
            id: $response.id,
            prompt: $job.prompt,
            agent: $job.agent,
            created_at: (date now | format date "%Y-%m-%dT%H:%M:%SZ"),
            status: "in_progress",
            planning: false
        }
        $history = ($history | append $history_entry)
        $history | save -f $history_file
    }
    
    return $response
}

# Helper to execute multiple web searches in parallel and consolidate results.
export def "ai web_search-multi" [
  queries: list<string>                   # The list of search queries to execute
  --web_results(-n): int = 5              # Number of web results per query
  --web_engine: string = "google"         # Search engine to use ('google' or 'ollama')
  --verbose(-v): any = false              # Verbose flag to output progress
] {
  if ($queries | is-empty) {
    return ""
  }

  let web_content_list = $queries | par-each {|q|
    if $verbose { print (echo-g $"Searching: ($q)") }
    let raw_res = try {
      web_search $q -n $web_results -m -v -e $web_engine
    } catch {|e|
      if $verbose { print (echo-r $"Search failed for '($q)': ($e.msg)") }
      ""
    }

    if ($raw_res | is-empty) {
      ""
    } else {
      # If the engine is google, summarize the results for this query
      let summarized = if $web_engine == "google" {
        try {
          ai google_search-summary $q $raw_res -m -M "gemini"
        } catch {|e|
          if $verbose { print (echo-y $"Summarization failed for '($q)', using raw results") }
          $raw_res
        }
      } else {
        $raw_res
      }
      
      $"### Search Query: ($q)\n\n($summarized)\n"
    }
  }

  return ($web_content_list | where {|c| not ($c | is-empty)} | str join "\n")
}
