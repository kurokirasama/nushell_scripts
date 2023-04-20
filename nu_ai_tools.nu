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
      - `ai transcription-summary`
      - `ai audio2summary`\n"
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
    if ($filename | path parse | get extension) =~ "mp3" {
      cp $filename $"($file)-clean.mp3"
    } else {
      myffmpeg -loglevel 1 -i $"($filename)" -acodec libmp3lame -ab 128k -vn $"($file)-clean.mp3"
    }
  } else {
    media remove-noise $filename $start $end 0.2 $"($file)-clean.wav" --delete false
  }

  print (echo-g "transcribing to text...")
  whisper $"($file)-clean.mp3" --language Spanish --output_format txt --verbose False
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
  let up_folder = $env.MY_ENV_VARS.gdriveTranscriptionSummaryDirectory
  let mounted = ($up_folder | path expand | path exists)
  let output = $"($file | path parse | get stem)_summary.md"

  # dealing with the case when the transcription files has too many words for chatgpt
  let max_words = 2500
  let n_words = (wc -w $file | awk '{print $1}' | into int)

  if $n_words > $max_words {
    print (echo-g $"splitting input file ($file)...")

    let words_per_line = (awk '{ total += NF } END { print total/NR }' $file | into decimal | math round)
    let n_lines_per_part = (($max_words / $words_per_line) | math round)
    let n_lines = (open $file | lines | length)
    mut n_parts = (($n_lines / $n_lines_per_part) | math ceil)

    let filenames = $"($file | path parse | get stem)_"
  
    ^split -d -l $n_lines_per_part $file $filenames --additional-suffix=.txt

    # combining the last 2 if the last one is too short
    let last_file = (open $"($filenames)($n_parts - 1 |  fill -a r -c '0' -w 2).txt")
    if ($last_file | lines | length) < ($n_lines_per_part / 5) {
      $last_file | save --append $"($filenames)($n_parts - 2 | fill -a r -c '0' -w 2).txt"
      rm $"($filenames)($n_parts - 1 |  fill -a r -c '0' -w 2).txt"

      $n_parts = ($n_parts - 1)
    }

    for i in 0..($n_parts - 1) {
      let this_file = $"($filenames)($i | fill -a r -c '0' -w 2).txt"
      ai transcription-summary-single $this_file -u false -g $gpt4
    }

    let temp_output = $"($file | path parse | get stem)_summaries.md"
    print (echo-g "combining the results into ($temp_output)...")
    touch $temp_output

    for i in 0..($n_parts - 1) {
      echo "Part ($i):\n" | save --append $temp_output
      open $"($filenames)($i | fill -a r -c '0' -w 2)_summary.txt" | save --append $temp_output
      echo "\n" | save --append $temp_output
    }

    let pre_prompt = (open ([$env.MY_ENV_VARS.credentials chagpt_prompt.json] | path join) | get prompt2)

    let prompt = (
      $pre_prompt
      | str append "\n" 
      | str append (open $temp_output)
    )

    print (echo-g $"asking chatgpt to combine the results in ($temp_output)...")
    if $gpt4 {
      chatgpt -m gpt4 $prompt | save -f $output
    } else {
      chatgpt $prompt | save -f $output
    }

    if $upload {
      if not $mounted {
        print (echo-g "mounting gdrive...")
        mount-ubb
      }

      print (echo-g "uploading summary to gdrive...")
      cp $output $up_folder
    }

    return
  }
  
  ai transcription-summary-single $file -u $upload -g $gpt4 
}

#resume transcription via gpt in one go
export def "ai transcription-summary-single" [
  file                #text file name with transcription text
  --gpt4(-g) = false  #whether to use gpt-4 (default false)
  --upload(-u) = true #whether to upload to gdrive (default true) 
] {
  let up_folder = $env.MY_ENV_VARS.gdriveTranscriptionSummaryDirectory
  let mounted = ($up_folder | path expand | path exists)
  let output = $"($file | path parse | get stem)_summary.md"

  let pre_prompt = (open ([$env.MY_ENV_VARS.credentials chagpt_prompt.json] | path join) | get prompt1)

  let prompt = (
    $pre_prompt
    | str append "\n" 
    | str append (open $file)
  )

  print (echo-g $"asking chatgpt for a summary of the file ($file)...")
  if $gpt4 {
    chatgpt -m gpt4 $prompt | save -f $output
  } else {
    chatgpt $prompt | save -f $output
  }

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
export def "ai audio2summary" [
  filename
  --upload = true #whether to upload the summary to gdrive (dafault true)
] {
  ai audio2text $filename
  ai transcription-summary $"tmp($filename | path parse | get stem)-clean.txt" --upload $upload
}