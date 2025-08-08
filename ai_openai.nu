#single call chatgpt wrapper
#
#Available models at https://platform.openai.com/docs/models, but some of them are:
# - gpt-5 (400000 tokens)
# - gpt-5-mini (400000 tokens)
# - gpt-4.1 (1047576 tokens)
# - gpt-4.1-mini (1047576 tokens)
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
@category ai
@search-terms chatgpt
export def chat_gpt [
    query?: string                     # the query to Chat GPT
    --model(-m):string = "gpt-5-mini" # the model gpt-4o-mini, gpt-4o = gpt-4, etc
    --system(-s):string = "You are a helpful assistant." # system message
    --temp(-t): float = 0.9       # the temperature of the model
    --image(-i):string            # filepath of image file for gpt-4-vision
    --list_system(-l)             # select system message from list
    --pre_prompt(-p)              # select pre-prompt from list
    --delim_with_backquotes(-d)   # to delimit prompt (not pre-prompt) with triple backquotes (')
    --select_system: string       # directly select system message    
    --select_preprompt: string    # directly select pre_prompt
    --web_search(-w) = false #include $web_results web search results in the prompt
    --web_results(-n):int = 5     #number of web results to include
    --web_model:string = "gemini" #model to summarize web results
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

  #search prompts
  let search_prompt = "From the next question delimited by triple single quotes ('''), please extract one sentence appropriated for a google search. Deliver your response in plain text without any formatting nor commentary on your part, and in the ORIGINAL language of the question. The question:\n'''" + $prompt + "\n'''"
  
  let search = if $web_search {google_ai $search_prompt -t 0.2 | lines | first} else {""}
  let web_content = if $web_search {google_search $search -n $web_results -v} else {""}
  let web_content = if $web_search {ai google_search-summary $prompt $web_content -m -M $web_model} else {""}
  
  let prompt = (
    if $web_search {
      $prompt + "\n\n You can complement your answer with the following up to date information about my question I obtained from a google search, in markdown format:\n" + $web_content
    } else {
      $prompt
    }
  )

  # default models
  let model = if $model == "gpt-4" {"gpt-4.1"} else {$model}
  let model = if $model == "gpt-4-vision" {"gpt-4-turbo"} else {$model}
  let temp = if $model =~ "gpt-5" {1} else {$temp}

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
  $answer | save -f a.json
  return $answer.choices.0.message.content
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
@category ai
@search-terms imagen dalle dall-e
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
  if ($prompt | is-empty) and ($task like "generation|edit") {
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
        let english = google_ai --select_preprompt is_in_english $prompt | from json | get english | into bool
        let prompt = if $english {google_ai --select_preprompt translate_dalle_prompt -d $prompt} else {$prompt}

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

#openai text-to-speech wrapper
#
#Available models are: tts-1, tts-1-hd
#
#Available voices are: alloy, echo, fable, onyx, nova, and shimmer
#
#Available formats are: mp3, opus, aac and flac
@category ai
@search-terms openai tts
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
