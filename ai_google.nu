#single call to google ai LLM api wrapper and chat mode
#
#Available models at https://ai.google.dev/models:
# - gemini-3-pro-preview
# - gemini-2.5-pro (paid version)
# - gemini-2.5-flash: Audio, images, video, and text -> text, 1048576 (tokens)
# - gemini-2.0-flash-exp-image-generation: images and text -> image and text
# - gemini-2.0-flash: Audio, images, video, and text -> Audio, images, and text, 1048576 (tokens), 10 RPM
# - gemini-2.0-flash-lite Audio, images, video, and text -> Audio, images, and text, 1048576 (tokens), 10 RPM
# - gemini-1.5-pro: Audio, images, video, and text -> text, 2097152 (tokens),  2 RPM
# - gemini-1.5-flash: Audio, images, video, and text -> text, 1048576 (tokens), 15 RPM
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
@category ai
@search-terms gemini
export def google_ai [
    query?: string                          # the query to Gemini
    --model(-m):string = "gemini-2.5-flash" # the model gemini-1.5-flash, gemini-pro-vision, gemini-2.0, etc
    --system(-s):string = "You are a helpful assistant." # system message
    --temp(-t): float = 0.9             # the temperature of the model
    --image(-i):string                  # filepath of image file for gemini-pro-vision
    --list_system(-l) = false           # select system message from list
    --pre_prompt(-p) = false            # select pre-prompt from list
    --delim_with_backquotes(-d) = false # to delimit prompt (not pre-prompt) with triple backquotes (')
    --select_system: string             # directly select system message    
    --select_preprompt: string          # directly select pre_prompt
    --safety_settings:table  #table with safety setting configuration (default all:BLOCK_NONE)
    --chat(-c)     #starts chat mode (text only, gemini only)
    --database(-D) = false   #continue a chat mode conversation from database
    --web_search(-w) = false #include $web_results web search results in the prompt
    --web_results(-n):int = 5     #number of web results to include
    --web_engine:string = "google" #how to get web results: 'google' search (+gemini for summary) or ollama (web search)
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
          },
          {
              category: "HARM_CATEGORY_CIVIC_INTEGRITY",
              threshold: "BLOCK_NONE",
          }
      ]
    } else {
      $safety_settings
    }
  )

  let for_bison_beta = if ($model like "bison") {"3"} else {""}
  let for_bison_gen = if ($model like "bison") {":generateText"} else {":generateContent"}

  let max_output_tokens = if $model =~ "gemini-2.5" {65536} else {8192}

  let input_model = $model
  let model = if $model == "gemini-pro-vision" {"gemini-2.0-flash"} else {$model}
  let model = if $model == "gemini-1.5" {"gemini-1.5-flash"} else {$model}
  let model = if $model == "gemini-2.0" {"gemini-2.0-flash"} else {$model}
  let model = if $model == "gemini-2.5" {"gemini-2.5-flash"} else {$model}
  let model = if $model == "gemini-3.0" {"gemini-3-pro-preview"} else {$model}  

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
    $ssystem = (($system_messages_files | find -n ("/" + $selection + ".md") | get 0))
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

  ###############
  ## chat mode ##
  ###############
  if $chat {
    if $model like "bison" {
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

    # print (echo-c ("\n" + $answer + "\n") $answer_color -b)
    $answer | glow

    #update request
    $contents = update_gemini_content $contents $answer "model"

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
          web_search $search -n $web_results -m -v -e $web_engine
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

      $contents = update_gemini_content $contents $chat_prompt "user"

      $chat_request.contents = $contents

      $answer = http post -t application/json $url_request $chat_request | get candidates.content.parts.0.text.0

      # print (echo-c ("\n" + $answer + "\n") $answer_color -b)
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
  
  let web_content = if $web_search {
      web_search $search -n $web_results -mv -e $web_engine
  } else {""}
  
  let web_content = if $web_search and $web_engine == "google" {
      ai google_search-summary $prompt $web_content -m -M "gemini"
  } else {$web_content}
  
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
    } else if ($model like "gemini") {
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
            maxOutputTokens: $max_output_tokens
        },
        safetySettings: $safetySettings
      }
    } else if ($model like "bison") {
      {
        prompt: { 
          text: $bison_prompt
        }
      }
    } else {
      print (echo-r "model not available or comming soon")
    } 
  )

  #trying different models in case of error
  mut answer = []
  mut index_model = 0
  let models = ["gemini-3-pro-preview" "gemini-2.5-flash" "gemini-1.5-pro" "gemini-2.0-flash" "gemini-2.0-flash-lite" "gemini-1.5-flash"]
  let n_models = $models | length 
  
  if $verbose {print ("retrieving from gemini models...")}

  $answer = http post -t application/json $url_request $request -e
  
  while (($answer | is-empty) or ($answer == null) or ($answer | get error? | is-not-empty) or ($answer | describe) == nothing) and ($index_model < $n_models) {
    let model = $models | get $index_model

    let url_request = {
      scheme: "https",
      host: "generativelanguage.googleapis.com",
      path: ("/v1beta" + $for_bison_beta +  "/models/" + $model + $for_bison_gen),
      params: {
          key: $apikey,
      }
    } | url join

    $answer = http post -t application/json $url_request $request -e

    $index_model += 1
  }

  if ($answer | is-empty) or ($answer == null) or ($answer | describe) == nothing {
    return-error "something went wrong with the server!"
  }

  if ($answer | get error? | is-not-empty) {
    return-error $answer.error
  }
  
  let answer = $answer
  if ($model like "gemini") {
    try {
      return $answer.candidates.content.parts.0.text.0
    } catch {|e|
      $answer | to json | save -f gemini_error.json
      return-error $"something went wrong with the api! error saved in gemini_error.json\n($e.msg)"
    }
  } else if ($model like "bison") {
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
        if $row.role like "model" {
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

#single call to google ai LLM image generations api wrapper
#
#Available models at https://ai.google.dev/models:
# - imagen-4.0-generate-preview-06-06: text -> image
# - imagen-4.0-ultra-generate-preview-06-06: text -> image
# - gemini-2.0-flash-exp-image-generation: images and text -> image and text
# - imagen-3.0-generate-002: text -> image (paid)
#
#- Gemini 2.0 excels in contextual image blending.
#- Imagen 3 prioritizes top-tier image quality and specialized editing capabilities. 
#- Imagen 4 is capable of generating highly detailed images with rich lighting, significantly better text rendering, and higher resolution output than previous models.
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
] {
  let prompt = get-input $in $query

  #api parameters
  let apikey = $env.MY_ENV_VARS.api_keys.google.gemini

  if ($number_of_images > 4) and ($model like "imagen") {
    return-error "Max. number of requested images is 4!!!"
  }

  if ($task like "edit") and ($model like "imagen") {
    return-error "Editing mode not available form Imagen model!"
  }

  let safetySettings = [
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
          },
          {
              category: "HARM_CATEGORY_CIVIC_INTEGRITY",
              threshold: "BLOCK_NONE",
          }
      ]

  let gen = if ($model like "imagen") {":predict"} else {":generateContent"}

  let input_model = $model
  let model = if $model == "gemini" {"gemini-2.0-flash-exp-image-generation"} else {$model}
  let model = if $model == "imagen3" {"imagen-3.0-generate-002"} else {$model}
  let model = if $model == "imagen4" {"imagen-4.0-generate-preview-06-06"} else {$model}
  let model = if $model == "imagen4ultra" {"imagen-4.0-ultra-generate-preview-06-06"} else {$model}

  let url_request = {
      scheme: "https",
      host: "generativelanguage.googleapis.com",
      path: ("/v1beta/models/" + $model + $gen),
      params: {
          key: $apikey,
      }
    } | url join

  let output = if ($output | is-empty) {
      (google_ai --select_preprompt dalle_image_name -d true $prompt | from json | get name) + "_G"
    } else {
      $output
    }

  #translate prompt if not in english
  let english = google_ai --select_preprompt is_in_english -d true $prompt | from json | get english | into bool
  let prompt = if $english and $task == "generation" {google_ai --select_system ai_art_creator --select_preprompt translate_dalle_prompt -d true $prompt} else {$prompt}
  let prompt = if $task == "generation" {
      google_ai --select_system ai_art_creator --select_preprompt improve_dalle_prompt -d true $prompt
    } else {
      $prompt
    }

  print (echo-g "improved prompt: ")
  print ($prompt)

  match $task {
    "generation" => {
        let request = if ($model like "imagen") {
          {
            instances: [
              {
                prompt: $prompt
              }
            ],
            parameters: {
              sampleCount: $number_of_images,
              aspect_ratio: $aspect_ratio,
              person_generation: $person_generation
            }
          }
        } else {
          {
            contents: [{
              parts: [
                {
                  text: $prompt
                }
              ]
            }],
            generationConfig:{
              responseModalities:["Text","Image"]
            },
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
                {
                  text: $prompt
                },
                {
                  inline_data: {
                    mime_type: "image/jpeg",
                    data: (open ($image | path expand) | encode base64)
                  }
                }
              ]
            }],
            generationConfig:{
              responseModalities:["Text","Image"]
            },
            safetySettings: $safetySettings
          }

        let answer = http post -t application/json $url_request $request

        $answer.candidates.content.parts.0.inlineData.data.0 
        | decode base64 
        | save -f ($output + ".png")
      },
    
    _ => {return-error $"$(task) not available!!!"}
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

  let prompt = (
    open ([$env.MY_ENV_VARS.chatgpt_config prompt summarize_html2text.md] | path join) 
    | str replace "<question>" $question 
  )

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
        google_ai $complete_prompt --select_system html2text_summarizer -m gemini-2.5-flash
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
        google_ai $complete_prompt --select_system html2text_summarizer -m gemini-2.5-flash
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
