export def o_llama [
  prompt?: string
  --model(-m): string
] {
  let prompt = if ($prompt | is-empty) {$in} else {$prompt}
  let model = if ($model | is-empty) {ollama list | detect columns  | get NAME | input list -f (echo-g "Select model:")} else {$model}

  let data = {
    model: $model,
    prompt: $prompt,
    stream: false
  }
  
  let url = "http://localhost:11434/api/generate"
  let response = http post $url --content-type application/json $data
  
  if ($response | get error? | is-empty) {
    $response | get response
  } else {
    return-error $"Error: ($response | get error)"
  }
}