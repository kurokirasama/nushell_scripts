#single call to anthropic claude ai LLM api wrapper
#
#Available models at https://docs.anthropic.com/en/docs/about-claude/models
# - claude-sonnet-4-5
# - claude-opus-4-20250514
# - claude-sonnet-4-20250514
# - claude-3-7-sonnet-latest: text & images & audio -> text, 200000 tokens input, 8192 tokens output
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
@category ai
@search-terms claude
export def claude_ai [
    query?: string                                 # the query to Chat GPT
    --model(-m):string = "claude-3-5-haiku-latest" # the model claude-3-opus-latest, claude-3-5-sonnet-latest, etc
    --system(-s):string = "You are a helpful assistant." # system message
    --anthropic_version(-v):string = "2023-06-01"        #anthropic version
    --temp(-t): float = 0.9             # the temperature of the model
    --image(-i):string                  # filepath of image file for gemini-pro-vision
    --list_system(-l) = false           # select system message from list
    --pre_prompt(-p) = false            # select pre-prompt from list
    --delim_with_backquotes(-d) = false # to delimit prompt (not pre-prompt) with triple backquotes (')
    --select_system: string             # directly select system message    
    --select_preprompt: string          # directly select pre_prompt
    --web_search(-w) = false      #include $web_results web search results in the prompt
    --web_results(-n):int = 5     #number of web results to include
    --web_model:string = "gemini" #model to summarize web results
    --document:string             #uses provided document to retrieve the answer
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

  # default models
  let input_model = $model
  let model = if $model == "claude-4" {"claude-sonnet-4-20250514"} else {$model}
  let model = if $model == "claude-3.7" {"claude-3-7-sonnet-latest"} else {$model}
  let model = if $model == "claude-3.5" {"claude-3-5-sonnet-latest"} else {$model}
  let model = if $model == "claude-vision" {"claude-3-5-sonnet-latest"} else {$model}

  let max_tokens = if $model like "claude-4-" {32000} else if $model like "claude-3-7" {64000} else if $model like "claude-3-5" {8192} else {4096}

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
