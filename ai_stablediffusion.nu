#single call to stable diffusion models
#
#generation task (default):
# models: 
#   - ultra: 8 credits, 1MP output resolution, 1024x1024 (default)
#   - core: 3 credits, 1.5MP output resolution
#   - sd3, sd3.5: 1MP output resolution, 1024x1024
#     - SD 3.5 & 3.0 Large: 6.5 credits
#     - SD 3.5 & 3.0 Large Turbo: 4 credits
#     - SD 3.5 & 3.0 Medium: 3 credits
#
#upscale task:
# models: 
#   - conservative (just up-scaling): 25 credits, 64x64 to 1MP input, up to 4k 5MP output (default)
#   - creative (upscale and re-imagining): 25 credits, 64x64 to 1MP input, up to 4k 5MP output
#   - fast (just up-scaling): 1 credit, up to 4x but max 16 MP output, suitable for enhancing the quality of compressed images
@category ai
@search-terms stable-diffusion
export def stable_diffusion [
    prompt?: string                     #the query to the models
    --model(-m):string                  #the model to use, depending on the task
    --task(-t):string = "generate"      #the method to use: generation, 
    --output_format(-o):string = "png"  #image output format
    --aspect_ratio(-a):string = "1:1"   #image output aspect_ratio
    --negative_prompt(-n):string        #negative_prompt
    --image(-i):string                  #image path for up-scaling and editing
    --mask(-k):string                   #masked image for editing
] {
  let prompt = get-input $in $prompt
  let negative_prompt = get-input $env.MY_ENV_VARS.negative_prompt $negative_prompt

  let model = if ($model | is-empty) {
    match $task {
      "generate" => {"ultra"},
      "upscale" => {"conservative"},
      "edit" => {"ultra"}, #change
      "control" => {"ultra"} #change
    }
  } else {
    $model
  }

  let site = "https://api.stability.ai/v2beta/stable-image/" + $task + "/" + $model

  #error checking
  if ($prompt | is-empty) and ($task like "generation|upscale|edit") {
    return-error "Empty prompt!!!"
  }

  #translate prompt if not in english
  let english = google_ai --select_preprompt is_in_english -d true $prompt | from json | get english | into bool
  let prompt = if $english {google_ai --select_system ai_art_creator --select_preprompt translate_dalle_prompt -d true $prompt} else {$prompt}
  let prompt = google_ai --select_system ai_art_creator --select_preprompt improve_dalle_prompt -d true $prompt

  print (echo-g "improved prompt: ")
  print ($prompt)

  let output = (google_ai --select_preprompt dalle_image_name -d true $prompt | from json | get name) + "_SD"

  #methods
  let header = {authorization: $"Bearer ($env.MY_ENV_VARS.api_keys.stable_diffusion)", accept: "image/*"}

  match $task {
    "generate" => {
        if $model not-in ["ultra" "core" "sd3" "sd3.5"] {
          return-error "wrong model for generation task!"
        }

        let request = {
          prompt: $prompt,
          output_format: $output_format,
          aspect_ratio: $aspect_ratio
          negative_prompt: $negative_prompt
        }

        let response = http post -t multipart/form-data -H $header $site $request -ef

        if $response.status != 200 {
          return-error $"status: ($response.status)\n($response.body.name)\n($response.body.errors.0)"
        } 

        print (echo-g $"saving image in ($output).($output_format)")
        $response | get something? | save -f $"($output).($output_format)"
        return        
      },

    "upscale" => {
        if $model not-in ["conservative" "creative" "fast"] {
          return-error "wrong model for upscale task!"
        }

        if ($image | is-empty) {
          return-error "image needed for up-scaling!!!"
        }

        let request = {
          image: (open -r $image), #maybe add into binary
          prompt: $prompt,
          output_format: $output_format,
          negative_prompt: $negative_prompt
        }

        let response = http post -t multipart/form-data -H $header $site $request -ef

        if $response.status != 200 {
          return-error $"status: ($response.status)\n($response.body.name)\n($response.body.errors.0)"
        } 

        print (echo-g $"saving image in ($output).($output_format)")
        $response | get something? | save -f $"($output).($output_format)"
        return 

      },  

  #   "edit" => {
  #       if $model == "dall-e-3" {
  #         return-error "Dall-e-3 doesn't allow edits!!!"
  #       }

  #       if ($image | is-empty) or ($mask | is-empty) {
  #         return-error "image and mask needed for editing!!!"
  #       }

  #       let header = $"Authorization: Bearer ($env.MY_ENV_VARS.api_keys.open_ai.api_key)"

  #       let image = media crop-image $image --name        
  #       let mask = media crop-image $mask --name

  #       #translate prompt if not in english
  #       let english = google_ai --select_preprompt is_in_english $prompt | from json | get english | into bool
  #       let prompt = if $english {google_ai --select_preprompt translate_dalle_prompt -d $prompt} else {$prompt}

  #       let site = "https://api.openai.com/v1/images/edits"

  #       let answer = bash -c ("curl -s " + $site + " -H '" + $header + "' -F model='" + $model + "' -F n=" + ($number | into string) + " -F size='" + $size + "' -F image='@" + $image + "' -F mask='@" + $mask + "' -F prompt='" + $prompt + "'")

  #       $answer
  #       | from json
  #       | get data.url
  #       | enumerate
  #       | each {|img| 
  #           print (echo-g $"downloading image ($img.index | into string)...")
  #           http get $img.item | save -f $"($output)_($img.index).png"
  #         }
  #     },

  #   "variation" => {
  #       if $model == "dall-e-3" {
  #         return-error "Dall-e-3 doesn't allow variations!!!"
  #       }

  #       if ($image | is-empty) {
  #         return-error "image needed for variation!!!"
  #       }

  #       let header = $"Authorization: Bearer ($env.MY_ENV_VARS.api_keys.open_ai.api_key)"

  #       let image = media crop-image $image --name        

  #       let site = "https://api.openai.com/v1/images/variations"

  #       let answer = bash -c ("curl -s " + $site + " -H '" + $header + "' -F model='" + $model + "' -F n=" + ($number | into string) + " -F size='" + $size + "' -F image='@" + $image + "'")

  #       $answer
  #       | from json
  #       | get data.url
  #       | enumerate
  #       | each {|img| 
  #           print (echo-g $"downloading image ($img.index | into string)...")
  #           http get $img.item | save -f $"($output)_($img.index).png"
  #         }
  #     },
    
  #   _ => {return-error $"$(task) not available!!!"}
  }
}
