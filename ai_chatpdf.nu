#upload a file to chatpdf server
@category ai
@search-terms chatpdf 
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
@category ai
@search-terms chatpdf
@example "Convert tokens to words" {token2word 1048000} --result [628800.0000 838400.0000]
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
@category ai
@search-terms chatpdf
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
@category ai
@search-terms chatpdf
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
@category ai
@search-terms chatpdf
export def "chatpdf list" [] {
  open ($env.MY_ENV_VARS.chatgpt_config | path join chatpdf_ids.json) | columns
}
