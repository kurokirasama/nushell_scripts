#tools to deal with media files
export def "media help" [] {
  print (
    echo "media manipulation and visualization tools: ffmpeg, sox, subsync and mpv required.\n
      METHODS\n
      - media video-info
      - media mpv-info
      - media trans-sub
      - media sub-sync
      - media remove-noise
      - media remove-audio-noise
      - media screen-record
      - media remove-audio
      - media cut-video
      - media split-video
      - media cut-audio
      - media extract-audio
      - media merge-videos
      - media merge-videos-auto
      - media compress-video
      - media delete-non-compressed
      - media find
      - media myt
      - media delete-mps
      - mpv (alias)
      - media to\n"
    | nu-highlight
  ) 
}

#video info
export def "media video-info" [file?] {
  let video = if ($file | is-empty) {$in | get name} else {$file}
  ffprobe -v quiet -print_format json -show_format -show_streams $video | from json
}

#video info via mpv
export def "media mpv-info" [file?] {
  let video = if ($file | is-empty) {$in | get name} else {$file}
  ^mpv -vo null -ao null -frames 0 $video
}

#translate subtitle to spanish via mymemmory api
export def "media trans-sub" [
  file?
  --from = "en-US" #from which language you are translating
  --open_ai        #use openai api to make the translations
  --notify(-n)     #notify to android via ntfy
  #
  #`? trans` for more info on languages
] {
  let file = if ($file | is-empty) {$file | get name} else {$file}
  dos2unix -q $file

  let $file_info = ($file | path parse)
  let file_content = (cat $file | decode utf-8 | lines)
  let new_file = $"($file_info | get stem)_translated.($file_info | get extension)"
  let lines = ($file_content | length)

  echo $"translating ($file)..."

  if not ($new_file | path expand | path exists) {
    touch $new_file

    $file_content
    | enumerate
    | each {|line|
        # print (echo $line.item)
        if (not $line.item =~ "-->") and (not $line.item =~ '^[0-9]+$') and ($line.item | str length) > 0 {
          let fixed_line = ($line.item | iconv -f UTF-8 -t ASCII//TRANSLIT)
          let translated = ($fixed_line | trans --from $from --openai $open_ai)

          if ($translated | is-empty) or ($translated =~ "error:") {
            return-error $"error while translating: ($translated)"
            return
          } else {
            # print (echo ($line.item + "\ntranslated to\n" + $translated))

            $translated | ansi strip | save --append $new_file
            "\n" | save --append $new_file
          }
        } else {
          $line.item | save --append $new_file
          "\n" | save --append $new_file
        }
        print -n (echo-g $"\r($line.index / $lines * 100 | math round -p 3)%")
      } 
  } else {
    let start = (cat $new_file | decode utf-8 | lines | length)

    $file_content
    | last ($lines - $start)
    | enumerate
    | each {|line|
        if (not $line.item =~ "-->") and (not $line.item =~ '^[0-9]+$') and ($line.item | str length) > 0 {
          let fixed_line = ($line.item | iconv -f UTF-8 -t ASCII//TRANSLIT)
          let translated = ($fixed_line | trans --from $from --openai $open_ai)

          if $translated =~ "error:" {
            return-error $"error while translating: ($translated)"
            return
          } else {
            print (echo ($line.item + "\ntranslated to\n" + $translated))

            $translated | ansi strip | save --append $new_file
            "\n" | save --append $new_file
          }
        } else {
          $line.item | save --append $new_file
          "\n" | save --append $new_file
        }
        # print -n (echo-g $"\r(($line.index + $start) / $lines * 100 | math round -p 3)%")
      } 
  } 
  if $notify {"translation finished!" | ntfy-send}
}

#sync subtitles
export def "media sub-sync" [
  file:string      #subtitle file name to process
  d1:string        #delay at the beginning or at time specified by t1 (<0 adelantar, >0 retrasar)
  --t1:string      #time position of delay d1 (hh:mm:ss)
  --d2:string      #delay at the end or at time specified by t2
  --t2:string      #time position of delay d2 (hh:mm:ss)t
  --no_backup:int  #whether to not backup $file or yes (export default no:0, ie, it will backup)
  #
  #Examples
  #sub-sync file.srt "-4"
  #sub-sync file.srt "-4" --t1 00:02:33
  #sub-sync file.srt "-4" --no_backup 1
] {

  let file_exist = (($env.PWD) | path join $file | path exists)
  
  if $file_exist {
    if ($no_backup | is-empty) or $no_backup == 0 {
      cp $file $"($file).backup"
    }

    let t1 = if ($t1 | is-empty) {"@"} else {$t1}  
    let d2 = if ($d2 | is-empty) {""} else {$d2}
    let t2 = if ($d2 | is-empty) {""} else {if ($t2 | is-empty) {"@"} else {$t2}}
  
    bash -c $"subsync -e latin1 ($t1)($d1) ($t2)($d2) < \"($file)\" > output.srt; cp output.srt \"($file)\""

    rm output.srt | ignore
  } else {
    return-error $"subtitle file ($file) doesn't exist in (pwd-short)"
  }
}

#remove audio noise 
export def "media remove-noise" [
  file                 #audio file name with extension
  start                #start (hh:mm:ss) of audio noise (no speaker)
  end                  #end (hh:mm:ss) of audio noise (no speaker)
  noiseLevel           #level reduction adjustment (0.2-0.3)
  output?              #output file name without extension, wav or mp3 produced
  --delete(-d) = true  #whether to delete existing tmp files or not
  --outExt(-E) = "wav" #output format, mp3 or wav
  --notify(-n)         #notify to android via ntfy
] {
  if $delete {
    try {
      ls ([$env.PWD tmp*] | path join) | rm-pipe
    }
  }

  let filename = ($file | path parse | get stem)
  let ext = ($file | path parse | get extension)

  if $ext !~ "wav" {
    print (echo-g "converting input file to wav format...")
    myffmpeg -loglevel 1 -i $file $"($filename).wav"
  }

  let output = (
    if ($output | is-empty) {
      $"($filename)-clean.wav"
    } else {
      $"($output).wav"
    }
  ) 

  print (echo-g "extracting noise segment...")
  myffmpeg -loglevel 1 -i $"($filename).wav" -acodec pcm_s16le -ar 128k -vn -ss $start -t $end $"tmpSeg($filename).wav"

  print (echo-g "creating noise profile...")
  sox $"tmpSeg($filename).wav" -n noiseprof $"tmp($filename).prof"

  print (echo-g "cleaning noise from audio file...")
  sox $"($filename).wav" $output noisered $"tmp($filename).prof" $noiseLevel

  if $outExt =~ "mp3" {
    print (echo-g "converting output file to mp3 format...")
    ffmpeg -loglevel 1 -i $output -acodec libmp3lame -ab 128k -vn $"($output | path parse | get stem).mp3"

    mv $output $"tmp($output)"
  }

  if $ext !~ "wav" {
    mv $"($filename).wav" $"tmp($filename).wav"
  }

  notify-send "noise removal done!"
  if $notify {"noise removal finished!" | ntfy-send}
}

#remove audio noise from video
export def "media remove-audio-noise" [
  file            #video file name with extension
  start           #start (hh:mm:ss) of audio noise (no speaker)
  end             #end (hh:mm:ss) of audio noise (no speaker)
  noiseLevel      #level reduction adjustment (0.2-0.3)
  output?         #output file name with extension (same extension as $file)
  --merge = true  #whether to merge clean audio with video
  --notify(-n)    #notifua to android via ntfy
] {
  try {
    ls ([$env.PWD tmp*] | path join) | rm-pipe
  }

  let filename = ($file | path parse | get stem)
  let ext = ($file | path parse | get extension)

  let output = (
    if ($output | is-empty) {
      $"($filename)-clean.($ext)"
    } else {
      $output
    }
  ) 

  let outputA = $"tmp($filename)-clean.wav"

  print (echo-g "extracting video...")
  myffmpeg -loglevel 1 -i $"($file)" -vcodec copy -an $"tmp($file)"

  print (echo-g "extracting audio...")
  myffmpeg -loglevel 1 -i $"($file)" -acodec pcm_s16le -ar 128k -vn $"tmp($filename).wav"

  media remove-noise $"tmp($filename).wav" $start $end $noiseLevel $outputA --delete false

  if $merge {
    print (echo-g "merging clean audio with video file...")
    myffmpeg -loglevel 1 -i $file -i $outputA -map 0:v -map 1:a -c:v copy -c:a aac -b:a 128k $output
  }

  print (echo-g "done!")
  notify-send "noise removal done!"
  if $notify {"noise removal finished!" | ntfy-send}
}

#screen record
export def "media screen-record" [
  file = "video"  #output filename without extension
  --audio = true  #whether to record with audio or not
  #
  #Pending: making sure it works in a video call
] {
  if $audio {
    print (echo-g "recording screen with audio...")
    let devices = (
      pacmd list-sources 
      | lines 
      | find "name:" 
      | ansi strip 
      | parse "{name}: <{device}>" 
      | where device =~ "alsa_input|blue"
      | get device
      | ansi strip
      )

    let bluetooth_not_connected = ($devices | find blue | is-empty)

    if $bluetooth_not_connected {
      let device = ($devices | find alsa_input | get 0 | ansi strip)
    
      try {
        print (echo-g "trying myffmpeg...")
        myffmpeg -video_size 1920x1080 -framerate 24 -f x11grab -i $"($env.DISPLAY).0+0,0" -f pulse -ac 2 -i $device -acodec aac -strict experimental $"($file).mp4"
      } catch {
        print (echo-r "myffmpeg failed...")
        ffmpeg -video_size 1920x1080 -framerate 24 -f x11grab -i $"($env.DISPLAY).0+0,0" -f pulse -ac 2 -i $device -acodec aac -strict experimental $"($file).mp4"
      }
    } else {
      let alsa = ($devices | find alsa_input | get 0 | ansi strip)
      let blue = ($devices | find blue | get 0 | ansi strip)

      try {
        print (echo-g "trying myffmpeg...")
        myffmpeg -video_size 1920x1080 -framerate 24 -f x11grab -i $"($env.DISPLAY).0+0,0" -f pulse -ac 2 -i $blue -f pulse -ac 2 -i $alsa -filter_complex amerge=inputs=2 -acodec aac -strict experimental $"($file).mp4"
      } catch {
        print (echo-r "myffmpeg failed...")
        ffmpeg -video_size 1920x1080 -framerate 24 -f x11grab -i $"($env.DISPLAY).0+0,0" -f pulse -ac 2 -i $blue -f pulse -ac 2 -i $alsa -filter_complex amerge=inputs=2 -acodec aac -strict experimental $"($file).mp4"
      }
    }
  } else {
    print (echo-g "recording screen without audio...")
    ffmpeg -video_size 1920x1080 -framerate 24 -f x11grab -i $"($env.DISPLAY).0+0,0" $"($file).mp4"
  }
  print (echo-g "recording finished...")
}

#remove audio from video file
export def "media remove-audio" [
  input_file: string #the input file
  output_file?       #the output file
  --notify(-n)       #notify to android via ntfy
] {
  let output_file = (
    if ($output_file | is-empty) {
      $"($input_file | path parse | get stem)-noaudio.($input_file | path parse | get extension)"
    } else {
      $output_file
    }
  )
  try {
    myffmpeg -n -loglevel 0 -i $input_file -c copy -an $output_file
  } catch {
    ffmpeg -n -loglevel 0 -i $input_file -c copy -an $output_file
  }
  if $notify {"summary finished!" | ntfy-send}
}

#cut segment of video file
export def "media cut-video" [
  file                     #video file name
  SEGSTART                 #timestamp of the start of the segment (hh:mm:ss)
  SEGEND                   #timestamp of the end of the segment (hh:mm:ss)
  --output_file(-o):string #output file
  --append(-a) = "cutted"  #append to file name
  --notify(-n)             #notify to android via ntfy
] {
  let ext = ($file | path parse | get extension)
  let name = ($file | path parse | get stem)

  let ofile = (
    if ($output_file | is-empty) {
      $"($name)_($append).($ext)"
    } else {
        $output_file
    }
  )

  try {
    myffmpeg -i $file -ss $SEGSTART -to  $SEGEND -map 0:0 -map 0:1 -c:a copy -c:v copy $ofile  
  } catch {
    ffmpeg -i $file -ss $SEGSTART -to  $SEGEND -map 0:0 -map 0:1 -c:a copy -c:v copy $ofile  
  }
  if $notify {"summary finished!" | ntfy-send}
}

#split video file
export def "media split-video" [
  file                      #video file name
  --number_segments(-n):int #number of pieces to generate (takes precedence over -d)
  --duration(-d):duration   #duration of each segment (in duration format) except probably the last one
  --delta = 10sec           #duration of overlaping beetween segments.
  --notify(-n)              #notify to android via ntfy
] {
  let full_length = (
    media video-info $file
    | get format
    | get duration
  )

  let full_secs = (build-string $full_length sec | into duration)
  let full_hhmmss = (into hhmmss $full_secs)

  let n_segments = (
    if not ($number_segments | is-empty) {
      $number_segments
    } else {
      $full_secs / $duration + 1 | into int
    } 
  )

  let seg_duration = $full_secs / $n_segments
  let seg_end = $seg_duration

  for $it in 1..($n_segments - 1) {
    let segment_start = (into hhmmss (($it - 1) * $seg_duration))
    let segment_end = (into hhmmss ($seg_end + ($it - 1) * $seg_duration + $delta))

    print (echo-g $"generating part ($it): ($segment_start) - ($segment_end)...")
    media cut-video $file $segment_start $segment_end -a $it
  }

  let segment_start = (into hhmmss (($n_segments - 1) * $seg_duration))

  print (echo-g $"generating part ($n_segments): ($segment_start) - ($full_hhmmss)...")
  media cut-video $file $segment_start $full_hhmmss -a $n_segments
  if $notify {"video split finished!" | ntfy-send}
}

#convert media files recursively to specified format
export def "media to" [
  to:string                 #destination format (aac, mp3 or mp4)
  --copy(-c)                #copy video codec and audio to mp3 (for mp4 only)
  --mkv(-m)                 #include mkv files (for mp4 only)
  --file(-f):string         #specify unique file to convert
  --vcodec(-v) = "libx264"  #video codec (for single file only)
  --notify(-n)              #notify to android via ntfy
  #
  #Examples (make sure there are only compatible files in all subdirectories)
  #media-to mp4 (avi/mkv to mp4)
  #media-to mp4 -c (avi to mp4)
  #media-to aac (audio files to aac)
  #media-to mp3 (audio files to mp3)
] {
  if ($file | is-empty) {
    #to aac or mp3
    if $to =~ "aac" or $to =~ "mp3" {
      let n_files = (bash -c $'find . -type f -not -name "*.part" -not -name "*.srt" -not -name "*.mkv" -not -name "*.mp4" -not -name "*.txt" -not -name "*.url" -not -name "*.jpg" -not -name "*.png" -not -name "*.3gp" -not -name  "*.($to)"'
          | lines 
          | length
      )

     print (echo-g $"($n_files) audio files found...")

      if $n_files > 0 {
        bash -c $'find . -type f -not -name "*.part" -not -name "*.srt" -not -name "*.mkv" -not -name "*.mp4" -not -name "*.txt" -not -name "*.url" -not -name "*.jpg" -not -name "*.png" -not -name "*.3gp" -not -name "*.($to)" -print0 | parallel -0 --eta ffmpeg -n -loglevel 0 -i {} -c:a ($to) -b:a 64k {.}.($to)'

       let aacs = (ls **/* 
         | insert "ext" {|| 
             $in.name | path parse | get extension
           }  
         | where ext =~ $to 
         | length
       )

        if $n_files == $aacs {
          print (echo-g $"audio conversion to ($to) done")
        } else {
          return-error $"audio conversion to ($to) done, but something might be wrong"
        }
      }
    #to mp4
    } else if $to =~ "mp4" {
      let n_files = (ls **/*
          | insert "ext" {|| 
              $in.name | path parse | get extension
            }  
          | where ext =~ "avi"
          | length
      )

      print (echo-g $"($n_files) avi files found...")

     if $n_files > 0 {
       if $copy {
         bash -c 'find . -type f -name "*.avi" -print0 | parallel -0 --eta ffmpeg -n -loglevel 0 -i {} -c:v copy -c:a mp3 {.}.mp4'
       } else {
          bash -c 'find . -type f -name "*.avi" -print0 | parallel -0 --eta ffmpeg -n -loglevel 0 -i {} -c:v libx264 -c:a aac {.}.mp4'
       }

        let aacs = (ls **/* 
          | insert "ext" {|| 
              $in.name | path parse | get extension
            }  
          | where ext =~ "mp4"
          | length
        )

       if $n_files == $aacs {
         print (echo-g $"avi video conversion to mp4 done")
       } else {
         return-error "video conversion to mp4 done, but something might be wrong"
       }
      }

      if $mkv {
        let n_files = (ls **/*
          | insert "ext" {|| 
              $in.name | path parse | get extension
            }  
          | where ext =~ "mkv"
          | length
        )

        print (echo-g $"($n_files) mkv files found...")

        if $n_files > 0 {
          if $copy {
            bash -c 'find . -type f -name "*.mkv" -print0 | parallel -0 --eta ffmpeg -n -loglevel 0 -i {} -c:v copy -c:a mp3 -c:s mov_text {.}.mp4'
         } else {
           bash -c 'find . -type f -name "*.mkv" -print0 | parallel -0 --eta ffmpeg -n -loglevel 0 -i {} -c:v libx264 -c:a aac -c:s mov_text {.}.mp4'
         }

          let aacs = (ls **/* 
            | insert "ext" {|| 
                $in.name | path parse | get extension
              }  
            | where ext =~ "mp4"
            | length
          )

         if $n_files == $aacs {
           print (echo-g $"mkv video conversion to mp4 done")
         } else {
           return-error "video conversion to mp4 done, but something might be wrong"
         }
        }
      }
    }
  } else {
    let filename = ($file | path parse | get stem)
    let ext = ($file | path parse | get extension) 

    if $to =~ "aac" or $to =~ "mp3" {
      ffmpeg -n -loglevel 48 -i $file -c:a $to -b:a 64k $"($filename).($to)"
    } else if $to =~ "mp4" {
      if $copy {
        if $ext =~ "mkv" {
          ffmpeg -n -loglevel 48 -i $file -c:v copy -c:a mp3 -c:s mov_text $"($filename).($to)"
        } else {
          ffmpeg -n -loglevel 48 -i $file -c:v copy -c:a mp3 $"($filename).($to)"
        }
      } else {
        if $ext =~ "mkv" {
          ffmpeg -n -loglevel 48 -i $file -c:v $vcodec -c:a aac -c:s mov_text $"($filename).($to)"
        } else {
          ffmpeg -n -loglevel 48 -i $file -c:v $vcodec -c:a aac $"($filename).($to)"
        }
      }
    } 
  }
  if $notify {"conversion finished!" | ntfy-send}
}

#cut segment from audio file
export def "media cut-audio" [
  infile:string   #input audio file
  outfile:string  #output audio file
  start:int       #start of the piece to extract (s) 
  duration:int    #duration of the piece to extract (s)
  --notify(-n)    #notify to android via ntfy
  #
  #Example: cut 10s starting at second 60 
  #cut_audio input.ext output.ext 60 10
] {  
  try {
    myffmpeg -ss $start -i $"($infile)" -t $duration -c copy $"($outfile)"
  } catch {
    ffmpeg -ss $start -i $"($infile)" -t $duration -c copy $"($outfile)"
  }
  if $notify {"cut finished!" | ntfy-send}
}

#merge subs to mkv video
export def "media merge-subs" [
  filename     #name (without extencion) of both subtitle and mkv file
  --notify(-n) #notify to android via ntfy
] { 
  mkvmerge -o myoutput.mkv  $"($filename).mkv" --language "0:spa" --track-name $"0:($filename)" $"($filename).srt"
  mv myoutput.mkv $"($filename).mkv"
  rm $"($filename).srt" | ignore
  if $notify {"subs merge finished!" | ntfy-send}
}

#merge videos
export def "media merge-videos" [
  list         #text file with list of videos to merge
  output       #output file
  --notify(-n) #notify to android via ntfy
  #
  #To get a functional output, all audio sample rate must be the same
  #check with video-info video_file
  #
  #The file with the list must have the following structure:
  #
  #~~~
  #file '/path/to/file/file1'"
  #.
  #.
  #.
  #file '/path/to/file/fileN'"
  #~~~
] {
  print (echo-g "merging videos...")
  myffmpeg -f concat -safe 0 -i $"($list)" -c copy $"($output)"
  
  print (echo-g "done!")
  notify-send "video merge done!"
  if $notify {"video merge finished!" | ntfy-send}
}

#auto merge all videos in dir
export def "media merge-videos-auto" [
  ext    #unique extension of all videos to merge
  output #output file
  --notify(-n) #notify to android via ntfy
  #
  #To get a functional output, all audio sample rate must be the same
  #check with video-info video_file
] {
  let list = (($env.PWD) | path join "list.txt")

  if not ($list | path exists) {
    touch $"($list)"
  } else {
    "" | save -f $list
  }
  
  ls $"*.($ext)" 
  | where type == file 
  | get name
  | each {|file|
      echo (build-string "file \'" (($env.PWD) | path join $file) "\'\n") | save --append list.txt
    }

  print (echo-g "merging videos...")
  myffmpeg -f concat -safe 0 -i list.txt -c copy $"($output)"
      
  print (echo-g "done!")
  notify-send "video merge done!"
  if $notify {"video merge finished!" | ntfy-send}
}

#reduce size of video files recursively, to mp4 x265
export def "media compress-video" [
  --file(-f):string         #single file
  --level(-l):int           #level of recursion (-maxdepth in ^find, minimun = 1).
  --crf(-c) = 28            #compression rate, range 0-51, sane range 18-28.
  --vcodec(-v) = "libx265"  #video codec: libx264 | libx265.
  --mkv(-m)                 #include mkv files
  --append(-a) = "com"      # what to append to compressed file names
  --notify(-n)              #notify to android via ntfy
  #
  #Considers only mp4 and webm files
  #
  #media compress-video
  #media compress-video -m
  #media compress-video -l 1
  #media compress-video -c 20
  #media compress-video -v libx264
  #
  #After ensuring that the conversions are ok, run
  #
  #media delete-non-compressed
  #
  #to delete original files
] {
  if ($file | is-empty) {
    let n_files = (
      if ($level | is-empty) {
        if not $mkv {
          bash -c $"find . -type f (char -i 92)(char lparen) -iname '*.mp4' -o -iname '*.webm' (char -i 92)(char rparen) -not -name '*($append)*'"
        } else {
          bash -c $"find . -type f (char -i 92)(char lparen) -iname '*.mp4' -o -iname '*.webm' -o -iname '*.mkv' (char -i 92)(char rparen) -not -name '*($append)*'"
        }
      } else {
        if not $mkv {
          bash -c $"find . -maxdepth ($level) -type f (char -i 92)(char lparen) -iname '*.mp4' -o -iname '*.webm' (char -i 92)(char rparen) -not -name '*($append)*'"
        } else {
          bash -c $"find . -maxdepth ($level) -type f (char -i 92)(char lparen) -iname '*.mp4' -o -iname '*.webm' -o -iname '*.mkv' (char -i 92)(char rparen) -not -name '*($append)*'"
        }
      }
      | lines 
      | length
    )

    if $n_files > 0 {
      print (echo-g $"($n_files) video files found...")

      if ($level | is-empty) {
        if not $mkv {
          try {
            print (echo-g "trying myffmpeg...")
            bash -c $"find . -type f (char -i 92)(char lparen) -iname '*.mp4' -o -iname '*.webm' (char -i 92)(char rparen) -not -name '*($append)*' -print0 | parallel -0 --eta --jobs 2 myffmpeg -n -loglevel 0 -i {} -vcodec ($vcodec) -crf ($crf) -c:a aac {.}_($append).mp4"
          } catch {
            print (echo-r "failed myffmpeg...")
            print (echo-g "trying ffmpeg...")
            bash -c $"find . -type f (char -i 92)(char lparen) -iname '*.mp4' -o -iname '*.webm' (char -i 92)(char rparen) -not -name '*($append)*' -print0 | parallel -0 --eta --jobs 2 ffmpeg -n -loglevel 0 -i {} -vcodec ($vcodec) -crf ($crf) -c:a aac {.}_($append).mp4"
          }
        } else {
          try {
            print (echo-g "trying myffmpeg...")
            bash -c $"find . -type f (char -i 92)(char lparen) -iname '*.mp4' -o -iname '*.webm' -o -iname '*.mkv' (char -i 92)(char rparen) -not -name '*($append)*' -print0 | parallel -0 --eta --jobs 2 myffmpeg -n -loglevel 0 -i {} -vcodec ($vcodec) -crf ($crf) -c:a aac -c:s mov_text {.}_($append).mp4"
          } catch {
            print (echo-r "failed myffmpeg...")
            print (echo-g "trying ffmpeg...")
            bash -c $"find . -type f (char -i 92)(char lparen) -iname '*.mp4' -o -iname '*.webm' -o -iname '*.mkv' (char -i 92)(char rparen) -not -name '*($append)*' -print0 | parallel -0 --eta --jobs 2 ffmpeg -n -loglevel 0 -i {} -vcodec ($vcodec) -crf ($crf) -c:a aac -c:s mov_text {.}_($append).mp4"
          }
        }
      } else {
        if not $mkv {
          try {
            print (echo-g "trying myffmpeg...")
            bash -c $"find . -maxdepth ($level) -type f (char -i 92)(char lparen) -iname '*.mp4' -o -iname '*.webm' (char -i 92)(char rparen) -not -name '*($append)*' -print0 | parallel -0 --eta --jobs 2 myffmpeg -n -loglevel 0 -i {} -vcodec ($vcodec) -crf ($crf) -c:a aac {.}_($append).mp4"
          } catch {
            print (echo-r "failed myffmpeg...")
            print (echo-g "trying ffmpeg...")
            bash -c $"find . -maxdepth ($level) -type f (char -i 92)(char lparen) -iname '*.mp4' -o -iname '*.webm' (char -i 92)(char rparen) -not -name '*($append)*' -print0 | parallel -0 --eta --jobs 2 ffmpeg -n -loglevel 0 -i {} -vcodec ($vcodec) -crf ($crf) -c:a aac {.}_($append).mp4"
          }
        } else {
          try {
            print (echo-g "trying myffmpeg...")
            bash -c $"find . -maxdepth ($level) -type f (char -i 92)(char lparen) -iname '*.mp4' -o -iname '*.webm' -o -iname '*.mkv' (char -i 92)(char rparen) -not -name '*($append)*' -print0 | parallel -0 --eta --jobs 2 myffmpeg -n -loglevel 0 -i {} -vcodec ($vcodec) -crf ($crf) -c:a aac -c:s mov_text {.}_($append).mp4"
          } catch {
            print (echo-r "failed myffmpeg...")
            print (echo-g "trying ffmpeg...")
            bash -c $"find . -maxdepth ($level) -type f (char -i 92)(char lparen) -iname '*.mp4' -o -iname '*.webm' -o -iname '*.mkv' (char -i 92)(char rparen) -not -name '*($append)*' -print0 | parallel -0 --eta --jobs 2 ffmpeg -n -loglevel 0 -i {} -vcodec ($vcodec) -crf ($crf) -c:a aac -c:s mov_text {.}_($append).mp4"
          }
        }
      }
    } else {
      return-error "no files found..."
    }
  } else {
    let ext = ($file | path parse | get extension)
    let name = ($file | path parse | get stem)

    switch $ext {
      "avi" : {||
        try {
          print (echo-g "trying myffmpeg...")
          myffmpeg -i $file -vcodec $vcodec -crf $crf -c:a aac $"($name)_($append).mp4"
        } catch {
          print (echo-r "failed myffmpeg...")
          print (echo-g "trying ffmpeg...")
          ffmpeg -i $file -vcodec $vcodec -crf $crf -c:a aac $"($name)_($append).mp4"
        }
      },
      "mp4" : {||
        try {
          print (echo-g "trying myffmpeg...")
          myffmpeg -i $file -vcodec $vcodec -crf $crf -c:a aac $"($name)_($append).mp4"
        } catch {
          print (echo-r "failed myffmpeg...")
          print (echo-g "trying ffmpeg...")
          ffmpeg -i $file -vcodec $vcodec -crf $crf -c:a aac $"($name)_($append).mp4"
        }
      },
      "webm" : {||
        try {
          print (echo-g "trying myffmpeg...")
          myffmpeg -i $file -vcodec $vcodec -crf $crf -c:a aac $"($name)_($append).mp4"
        } catch {
          print (echo-r "failed myffmpeg...")
          print (echo-g "trying ffmpeg...")
          ffmpeg -i $file -vcodec $vcodec -crf $crf -c:a aac $"($name)_($append).mp4"
        }
      },
      "mkv" : {||
        try {
          print (echo-g "trying myffmpeg...")
          myffmpeg -i $file -vcodec $vcodec -crf $crf -c:a aac -c:s mov_text $"($name)_($append).mp4"
        } catch {
          print (echo-r "failed myffmpeg...")
          print (echo-g "trying ffmpeg...")
          ffmpeg -i $file -vcodec $vcodec -c:a aac -c:s mov_text $"($name)_($append).mp4"
        }
      }
    }
  }
  if $notify {"compression finished!" | ntfy-send}
}

#delete original videos after compression recursively
export def "media delete-non-compressed" [file?,--append(-a) = 'compressed_by_me'] {
  ls **/* 
  | where type == file 
  | where name =~ $append 
  | par-each {|file| 
      $file 
      | get name 
      | split row $"_($append)" 
      | str join "" 
      | path expand
    }
  | wrap name
  | rm-pipe

  ls **/*
  | where name =~ .webm
  | par-each {|file|
      let compressed = (
        $file
        | get name
        | path expand
        | path parse
        | upsert stem ($file | get name | path parse | get stem | str append $"_($append)")
        | upsert extension mp4
        | path join
      )
      
      if ($compressed | path exists) {
        $file | rm-pipe
      }
    }
}

#search for a name in the media database
export def "media find" [
  search            #search term
  --season(-s):int  #season number
  --manga(-m)       #for searching manga
  --no_manga(-n)    #exclude manga results
] {
  let database = (
    ls $env.MY_ENV_VARS.media_database 
    | where name =~ ".json" 
    | openm
  )
  
  let S = if ($season | is-empty) {
      ""
    } else {
      $season | into string | fill -a r -c "0" -w 2
  }

  let results = if ($season | is-empty) {
      $database | find -i $search
    } else {
      $database | find -i $search | find -i $"s($S)"
    }

  if $manga {
    $results | find -i manga
  } else if $no_manga {
    $results | where path !~ Manga
  } else {
    $results
  }
  | ansi strip-table
}

#play first/last downloaded youtube video
export def "media myt" [file?, --reverse(-r)] {
  let inp = $in
  let video = (
    if not ($inp | is-empty) {
      $inp | get name
    } else if not ($file | is-empty) {
      $file
    } else if $reverse {
      ls | sort-by modified -r | where type == "file" | last | get name
    } else {
      ls | sort-by modified | where type == "file" | last | get name
    }
  )
  
  ^mpv --ontop --window-scale=0.4 --save-position-on-quit --no-border $video

  let delete = (input "delete file? (y/n): ")
  if $delete == "y" {
    rm $video
  } else {
    let move = (input "move file to pending? (y/n): ")
    if $move == "y" {
      mv $video pending
    }
  } 
}

#delete non wanted media in mps (youtube download folder)
export def "media delete-mps" [] {
  if $env.MY_ENV_VARS.mps !~ $env.PWD {
    return-error "wrong directory to run this"
  } else {
     le
     | where type == "file" and ext !~ "mp4|mkv|webm|part" 
     | par-each {|it| 
         rm $"($it.name)" 
         | ignore
       }     
  }
}

#mpv
export def mpv [video?, --puya(-p)] {
  let file = if ($video | is-empty) {$in} else {$video}

  if ($file | length) == 1 {
    let file = (
      switch ($file | typeof) {
        "record": {|| 
          $file
          | get name
          | ansi strip
        },
        "table": {||
          $file
          | get name
          | get 0
          | ansi strip
        },
      } { 
          "otherwise": {|| 
            $file
          }
        }
    )

    if not $puya {
      ^mpv --save-position-on-quit --no-border $file
    } else {
      ^mpv --save-position-on-quit --no-border --sid=2 $file
    } 
  } else {
    $file | each {|f| $f | mpv}
  }
}

#extract audio from video file
export def "media extract-audio" [
  filename
  --audio_format(-a) = "mp3" #audio output format, wav or mp3
  --notify(-n)               #notify to android via mpv
] {
  let file = ($filename | path parse | get stem)

  print (echo-g "extracting audio...")
  switch $audio_format {
    "mp3" : {|| ffmpeg -loglevel 1 -i $"($filename)" -ar 44100 -ac 2 -ab 192k -f mp3 -vn $"($file).mp3"},
    "wav" : {|| ffmpeg -loglevel 1 -i $"($filename)" -acodec pcm_s16le -ar 128k -vn $"($file).wav"}
  }
  if $notify {"extraction finished!" | ntfy-send}
}