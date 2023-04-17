#ai tools
export def ai [] {
  print (
    echo "This set of tools need a few dependencies installed:\n
      whisper:\n
        pip install git+https://github.com/openai/whisper.git\n
      chatgpt-wrapper:\n
        pip install git+https://github.com/mmabrouk/chatgpt-wrapper\n
      METHODS\n
      - `ai audio2text`
      - `ai screen2text`
      - `ai transcription-summary`\n"
    | nu-highlight
  ) 
}

#audio to text transcription via whisper
export def "ai audio2text" [filename] {
  let file = ($filename | path parse | get stem)

  print (echo-g $"reproduce ($filename) and select start and end time for noise segment, leave empty if no noise..." )
  let start = (input "start? (hh:mm:ss): ")
  let end = (input "end? (hh:mm:ss): ")

  if ($start | is-empty) or ($end | is-empty) {
    print (echo-g "generating temp file...")
    if ($filename | path parse | get extension) =~ "wav" {
      cp $filename $"tmp($file)-clean.wav"
    } else {
      myffmpeg -loglevel 1 -i $"($filename)" -acodec pcm_s16le -ar 128k -vn $"tmp($file)-clean.wav"
    }
  } else {
    media remove-noise $filename $start $end 0.3 $"tmp($file)-clean.wav" --delete false
  }

  print (echo-g "transcribing to text...")
  whisper $"tmp($file)-clean.wav" --language Spanish --output_format txt --verbose False
}

#screen record to text transcription 
export def "ai screen2text" [
--transcribe = true #whether to transcribe or not. Default true, false means it just extracts audio
] {
  let file = (date now | date format "%Y%m%d_%H%M%S")

  if not ("~/Documents/Transcriptions" | path exists) {
    ^mkdir -p ~/Documents/Transcriptions 
  }

  cd ~/Documents/Transcriptions
  
  try {
    media screen-record $file
  }

  media extract-audio $"($file).mp4"

  ai audio2text $"($file).wav"

  if $transcribe {
    ai transcription-summary $"tmp($file | path parse | get stem)-clean.txt"
  }
}

#resume transcription text via gpt 
export def "ai transcription-summary" [
  file                #text file name with transcription text
  --gpt4(-g) = false  #whether to use gpt-4 (default false)
  --upload(-u) = true #whether to upload to gdrive (default true) 
] {
  let pre_prompt = (open ([$env.MY_ENV_VARS.credentials chagpt_prompt.json] | path join) | get prompt)

  let prompt = (
    $pre_prompt
    | str append "\n" 
    | str append (open $file)
  )

  let output = $"($file | path parse | get stem)_summary.md"

  print (echo-g "asking chatgpt for a summary of the transcription...")
  if $gpt4 {
    chatgpt -m gpt4 $prompt | save -f $output
  } else {
    chatgpt $prompt | save -f $output
  }

  let up_folder = $env.MY_ENV_VARS.gdriveTranscriptionSummaryDirectory
  let mounted = ($up_folder | path expand | path exists)

  if $upload {
    if not $mounted {
      print (echo-g "mounting gdrive...")
      mount-ubb
    }

    print (echo-g "uploading summary to gdrive...")
    cp $output $up_folder
  }
}

#audio 2 transcription summary via chatgpt
export def "media audio2summary" [
  filename
  --upload = true #whether to upload the summary to gdrive (dafault true)
] {
  ai audio2text $filename
  ai transcription-summary $"tmp($filename | path parse | get stem)-clean.txt" --upload $upload
}