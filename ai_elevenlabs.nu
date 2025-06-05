#elevenlabs text-to-speech wrapper
#
#English only
#
#Available models are: Eleven Multilingual v2, Eleven Multilingual v1, Eleven English v1 (default), Eleven Turbo v2
#
#Available voices are: alloy, echo, fable, onyx, nova, and shimmer
#
#Available formats are: mp3, opus, aac and flac
@category ai
@search-terms elevenlabs tts
export def "ai elevenlabs-tts" [
  prompt?:string                    #text to convert to speech
  --model(-m):string = "Eleven English v1" #model of the output
  --voice(-v):string = "Dorothy"    #voice selection
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
