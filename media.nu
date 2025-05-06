#tools to deal with media files
export def "media help" [] {
  print ([
    "media manipulation and visualization tools: ffmpeg, sox, subsync and mpv required."
      "METHODS:"
      "- media video-info"
      "- media mpv-info"
      "- media sub-sync"
      "- media remove-noise"
      "- media remove-audio-noise"
      "- media screen-record"
      "- media remove-audio"
      "- media cut-video"
      "- media split-video"
      "- media cut-audio"
      "- media extract-audio"
      "- media merge-videos"
      "- media merge-videos-auto"
      "- media compress-video"
      "- media delete-non-compressed"
      "- media find"
      "- media myt"
      "- media delete-mps"
      "- media crop-video"
      "- mpv (alias)"
      "- media to"
    ]
    | str join "\n"
    | nu-highlight
  ) 
}

#cuda ffmpeg
export def --wrapped my-ffmpeg [...rest] {
  /home/kira/software/nvidia/ffmpeg/./ffmpeg -hwaccel cuda ...$rest
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

#sync subtitles
#
#Examples
#sub-sync file.srt "-4"
#sub-sync file.srt "-4" --t1 00:02:33
#sub-sync file.srt "-4" --no_backup 1
export def "media sub-sync" [
  file:string      #subtitle file name to process
  d1:string        #delay at the beginning or at time specified by t1 (<0 adelantar, >0 retrasar)
  --t1:string      #time position of delay d1 (hh:mm:ss)
  --d2:string      #delay at the end or at time specified by t2
  --t2:string      #time position of delay d2 (hh:mm:ss)t
  --no_backup:int  #whether to not backup $file or yes (export default no:0, ie, it will backup)
] {
  if not ($env.PWD | path join $file | path exists) {
    return-error $"subtitle file ($file) doesn't exist in (pwd-short)"
  }

  if ($no_backup | is-empty) or $no_backup == 0 {
    cp $file $"($file).backup"
  }

  let t1 = get-input "@" $t1
  let d2 = get-input "" $d2
  let t2 = if ($d2 | is-empty) {""} else {get-input "@" $t2}
  
  bash -c $"subsync -e latin1 ($t1)($d1) ($t2)($d2) < \"($file)\" > output.srt; cp output.srt \"($file)\""

  rm output.srt | ignore
}

#remove audio noise 
export def "media remove-noise" [
  file                 #audio file name with extension
  start                #start (hh:mm:ss) of audio noise (no speaker)
  end                  #end (hh:mm:ss) of audio noise (no speaker)
  noiseLevel           #level reduction adjustment (0.2-0.3)
  output?              #output file name without extension, wav or mp3 produced
  --delete(-d) = true  #whether to delete existing tmp files or not
  --outExt(-E):string = "wav" #output format, mp3 or wav
  --notify(-n)         #notify to android via join/tasker
] {
  if $delete {
    try {
      ls ([$env.PWD tmp*] | path join) | rm-pipe
    }
  }

  let filename = $file | path parse | get stem
  let ext = $file | path parse | get extension

  if $ext not-like "wav" {
    print (echo-g "converting input file to wav format...")
    my-ffmpeg -loglevel 1 -i $file $"($filename).wav"
  }

  let output = (
    if ($output | is-empty) {
      $"($filename)-clean.wav"
    } else {
      $"($output).wav"
    }
  ) 

  print (echo-g "extracting noise segment...")
  my-ffmpeg -loglevel 1 -i $"($filename).wav" -acodec pcm_s16le -ar 128k -vn -ss $start -t $end $"tmpSeg($filename).wav"

  print (echo-g "creating noise profile...")
  sox $"tmpSeg($filename).wav" -n noiseprof $"tmp($filename).prof"

  print (echo-g "cleaning noise from audio file...")
  sox $"($filename).wav" $output noisered $"tmp($filename).prof" $noiseLevel

  if $outExt like "mp3" {
    print (echo-g "converting output file to mp3 format...")
    ffmpeg -loglevel 1 -i $output -acodec libmp3lame -ab 128k -vn $"($output | path parse | get stem).mp3"

    mv $output $"tmp($output)"
  }

  if $ext not-like "wav" {
    mv $"($filename).wav" $"tmp($filename).wav"
  }

  notify-send "noise removal done!"
  if $notify {"noise removal finished!" | tasker send-notification}
}

#remove audio noise from video
export def "media remove-audio-noise" [
  file            #video file name with extension
  start           #start (hh:mm:ss) of audio noise (no speaker)
  end             #end (hh:mm:ss) of audio noise (no speaker)
  noiseLevel      #level reduction adjustment (0.2-0.3)
  output?         #output file name with extension (same extension as $file)
  --merge = true  #whether to merge clean audio with video
  --notify(-n)    #notifua to android via join/tasker
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
  my-ffmpeg -loglevel 1 -i $"($file)" -vcodec copy -an $"tmp($file)"

  print (echo-g "extracting audio...")
  my-ffmpeg -loglevel 1 -i $"($file)" -acodec pcm_s16le -ar 128k -vn $"tmp($filename).wav"

  media remove-noise $"tmp($filename).wav" $start $end $noiseLevel $outputA --delete false

  if $merge {
    print (echo-g "merging clean audio with video file...")
    my-ffmpeg -loglevel 1 -i $file -i $outputA -map 0:v -map 1:a -c:v copy -c:a aac -b:a 128k $output
  }

  print (echo-g "done!")
  notify-send "noise removal done!"
  if $notify {"noise removal finished!" | tasker send-notification}
}

#screen record
export def "media screen-record" [
  file:string = "video"  #output filename without extension
  --audio = true  #whether to record with audio or not
] {
  let os_version = sys host | get os_version
  let resolution = xrandr | grep '*' | awk '{print $1}' | lines | first

  if $audio {
    print (echo-g "recording screen with audio...")
    let devices = (
      if $os_version == "24.04" {
        pw-dump 
        | lines 
        | find -n '"node.name"' 
        | str trim 
        | parse "\"{name}\": \"{device}\"," 
      } else {
        pacmd list-sources 
        | lines 
        | find -n "name:"
        | str trim
        | parse "{name}: <{device}>"
      }
      | where device like "alsa_input|bluez_" 
      | get device
    )

    let bluetooth_not_connected = $devices | find blue | is-empty

    if $bluetooth_not_connected {
      let device = $devices | find -n alsa_input | get 0
    
      try {
        print (echo-g "trying myffmpeg...")
        my-ffmpeg -video_size $resolution -framerate 24 -f x11grab -i $"($env.DISPLAY).0+0,0" -f pulse -ac 2 -i $device -acodec aac -strict experimental $"($file).mp4"
      } catch {
        print (echo-r "myffmpeg failed...")
        ffmpeg -video_size $resolution -framerate 24 -f x11grab -i $"($env.DISPLAY).0+0,0" -f pulse -ac 2 -i $device -acodec aac -strict experimental $"($file).mp4"
      }
    } else {
      let alsa = $devices | find -n alsa_input | get 0
      let blue = $devices | find -n blue | get 0

      try {
        print (echo-g "trying myffmpeg...")
        my-ffmpeg -video_size $resolution -framerate 24 -f x11grab -i $"($env.DISPLAY).0+0,0" -f pulse -ac 2 -i $blue -f pulse -ac 2 -i $alsa -filter_complex amerge=inputs=2 -acodec aac -strict experimental $"($file).mp4"
      } catch {
        print (echo-r "myffmpeg failed...")
        ffmpeg -video_size $resolution -framerate 24 -f x11grab -i $"($env.DISPLAY).0+0,0" -f pulse -ac 2 -i $blue -f pulse -ac 2 -i $alsa -filter_complex amerge=inputs=2 -acodec aac -strict experimental $"($file).mp4"
      }
    }
  } else {
    print (echo-g "recording screen without audio...")
    ffmpeg -video_size $resolution -framerate 24 -f x11grab -i $"($env.DISPLAY).0+0,0" $"($file).mp4"
  }
  print (echo-g "recording finished...")
}

#remove audio from video file
export def "media remove-audio" [
  input_file: string #the input file
  output_file?       #the output file
  --notify(-n)       #notify to android via join/tasker
] {
  let output_file = get-input $"($input_file | path parse | get stem)-noaudio.($input_file | path parse | get extension)" $output_file

  try {
    echo-g "trying myffmpeg..."
    my-ffmpeg -n -loglevel 0 -i $input_file -c copy -an $output_file
  } catch {
    echo-r "trying ffmpeg..."
    ffmpeg -n -loglevel 0 -i $input_file -c copy -an $output_file
  }
  if $notify {"summary finished!" | tasker send-notification}
}

#cut segment of video file
export def "media cut-video" [
  file                     #video file name
  SEGSTART                 #timestamp of the start of the segment (hh:mm:ss)
  SEGEND                   #timestamp of the end of the segment (hh:mm:ss)
  --output_file(-o):string #output file
  --append(-a):string = "cutted"  #append to file name
  --notify(-n)             #notify to android via join/tasker
] {
  let ext = $file | path parse | get extension
  let name = $file | path parse | get stem

  let ofile = get-input $"($name)_($append).($ext)" $output_file

  try {
    echo-g "trying myffmpeg..."
    my-ffmpeg -i $file -ss $SEGSTART -to  $SEGEND -map 0:0 -map 0:1 -c:a copy -c:v copy $ofile  
  } catch {
    echo-r "trying ffmpeg..."
    ffmpeg -i $file -ss $SEGSTART -to  $SEGEND -map 0:0 -map 0:1 -c:a copy -c:v copy $ofile  
  }
  if $notify {"summary finished!" | tasker send-notification}
}

#split video file
export def "media split-video" [
  file                      #video file name
  --number_segments(-n):int #number of pieces to generate (takes precedence over -d)
  --duration(-d):duration   #duration of each segment except probably the last one
  --delta:duration = 10sec  #duration of overlaping beetween segments
  --notify(-n)              #notify to android via join/tasker
] {
  let full_length = (
    media video-info $file
    | get format
    | get duration
  )

  let full_secs = ($full_length + "sec") | into duration
  let full_hhmmss = into hhmmss $full_secs

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
    let segment_start = into hhmmss (($it - 1) * $seg_duration)
    let segment_end = into hhmmss ($seg_end + ($it - 1) * $seg_duration + $delta)

    print (echo-g $"generating part ($it): ($segment_start) - ($segment_end)...")
    media cut-video $file $segment_start $segment_end -a $it
  }

  let segment_start = into hhmmss (($n_segments - 1) * $seg_duration)

  print (echo-g $"generating part ($n_segments): ($segment_start) - ($full_hhmmss)...")
  media cut-video $file $segment_start $full_hhmmss -a $n_segments
  if $notify {"video split finished!" | tasker send-notification}
}

#convert media files recursively to specified format
#
#Examples (make sure there are only compatible files in all subdirectories)
#media-to mp4 (avi/mkv to mp4)
#media-to mp4 -c (avi to mp4)
#media-to aac (audio files to aac)
#media-to mp3 (audio files to mp3)
export def "media to" [
  to:string                 #destination format (aac, mp3 or mp4)
  --copy(-c)                #copy video codec and audio to mp3 (for mp4 only)
  --mkv(-m)                 #include mkv files (for mp4 only)
  --file(-f):string         #specify unique file to convert
  --vcodec(-v):string = "libx264"  #video codec (for single file only)
  --notify(-n)              #notify to android via join/tasker
] {
  if ($file | is-empty) {
    #to aac or mp3
    if $to like "aac" or $to like "mp3" {
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
         | where ext like $to 
         | length
       )

        if $n_files == $aacs {
          print (echo-g $"audio conversion to ($to) done")
        } else {
          return-error $"audio conversion to ($to) done, but something might be wrong"
        }
      }

    #to mp4
    } else if $to like "mp4" {
      let n_files = (ls **/*
          | insert "ext" {|f| 
              $f.name | path parse | get extension
            }  
          | where ext like "avi|webm"
          | length
      )

      print (echo-g $"($n_files) avi/webm files found...")

     if $n_files > 0 {
       if $copy {
         bash -c 'find . -type f \( -name "*.avi" -o -name "*.webm" \) -print0 | parallel -0 --eta ffmpeg -n -loglevel 0 -i {} -c:v copy -c:a mp3 {.}.mp4'
       } else {
          bash -c 'find . -type f \( -name "*.avi" -o -name "*.webm" \) -print0 | parallel -0 --eta ffmpeg -n -loglevel 0 -i {} -c:v libx264 -c:a aac {.}.mp4'
       }

        let aacs = (ls **/* 
          | insert "ext" {|| 
              $in.name | path parse | get extension
            }  
          | where ext like "mp4"
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
          | insert "ext" {|f| 
              $f.name | path parse | get extension
            }  
          | where ext like "mkv"
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
            | where ext like "mp4"
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
    return
  }

  let filename = ($file | path parse | get stem)
  let ext = ($file | path parse | get extension) 

  if $to like "aac" or $to like "mp3" {
    ffmpeg -n -loglevel 48 -i $file -c:a $to -b:a 64k $"($filename).($to)"
  } else if $to like "mp4" {
    if $copy {
      if $ext like "mkv" {
        ffmpeg -n -loglevel 48 -i $file -c:v copy -c:a mp3 -c:s mov_text $"($filename).($to)"
      } else {
        ffmpeg -n -loglevel 48 -i $file -c:v copy -c:a mp3 $"($filename).($to)"
      }
    } else {
      if $ext like "mkv" {
        ffmpeg -n -loglevel 48 -i $file -c:v $vcodec -c:a aac -c:s mov_text $"($filename).($to)"
      } else {
        ffmpeg -n -loglevel 48 -i $file -c:v $vcodec -c:a aac $"($filename).($to)"
      }
    }
  } 
  if $notify {"conversion finished!" | tasker send-notification}
}

#cut segment from audio file
#
#Example: cut 10s starting at second 60 
#cut_audio input.ext output.ext 60 10
export def "media cut-audio" [
  infile:string   #input audio file
  outfile:string  #output audio file
  start:int       #start of the piece to extract (s) 
  duration:int    #duration of the piece to extract (s)
  --notify(-n)    #notify to android via join/tasker
] {  
  try {
    my-ffmpeg -ss $start -i $"($infile)" -t $duration -c copy $"($outfile)"
  } catch {
    ffmpeg -ss $start -i $"($infile)" -t $duration -c copy $"($outfile)"
  }
  if $notify {"cut finished!" | tasker send-notification}
}

#merge subs to mkv video
export def "media merge-subs" [
  filename     #name (without extencion) of both subtitle and mkv file
  --notify(-n) #notify to android via join/tasker
] { 
  mkvmerge -o myoutput.mkv  $"($filename).mkv" --language "0:spa" --track-name $"0:($filename)" $"($filename).srt"
  mv myoutput.mkv $"($filename).mkv"
  rm $"($filename).srt" | ignore
  if $notify {"subs merge finished!" | tasker send-notification}
}

#merge videos
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
export def "media merge-videos" [
  list         #text file with list of videos to merge
  output       #output file
  --notify(-n) #notify to android via join/tasker
] {
  print (echo-g "merging videos...")
  my-ffmpeg -f concat -safe 0 -i $"($list)" -c copy $"($output)"
  
  print (echo-g "done!")
  notify-send "video merge done!"
  if $notify {"video merge finished!" | tasker send-notification}
}

#auto merge all videos in dir
#
#To get a functional output, all audio sample rate must be the same
#check with video-info video_file
export def "media merge-videos-auto" [
  ext    #unique extension of all videos to merge
  output #output file
  --notify(-n) #notify to android via join/tasker
] {
  let list = $env.PWD | path join "list.txt"

  if not ($list | path exists) {
    touch $"($list)"
  } else {
    "" | save -f $list
  }
  
  ls ($"*.($ext)" | into glob) 
  | where type == file 
  | get name
  | each {|file|
      ("file \'" + ($env.PWD | path join $file) + "\'\n") | save --append list.txt
    }

  print (echo-g "merging videos...")
  my-ffmpeg -f concat -safe 0 -i list.txt -c copy $"($output).($ext)"
      
  print (echo-g "done!")
  notify-send "video merge done!"
  if $notify {"video merge finished!" | tasker send-notification}
}

#reduce size of video files recursively, to mp4 x265
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
export def "media compress-video" [
  --file(-f):string         #single file
  --level(-l):int           #level of recursion (-maxdepth in ^find, minimun = 1).
  --crf(-c):int = 18        #compression rate, range 0-51, sane range 18-28.
  --vcodec(-v):string = "libx265"  #video codec: libx264 | libx265.
  --append(-a):string = "com" # what to append to compressed file names
  --jobs(-j):int = 2        #number of jobs to run in parallel
  --mkv(-m)                 #include mkv files
  --notify(-n)              #notify to android via join/tasker
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

    if $n_files == 0 {return-error "no files found..."}

    print (echo-g $"($n_files) video files found...")

    if ($level | is-empty) {
      if not $mkv {
        try {
          print (echo-g "trying myffmpeg...")
          bash -c $"find . -type f (char -i 92)(char lparen) -iname '*.mp4' -o -iname '*.webm' (char -i 92)(char rparen) -not -name '*($append)*' -print0 | parallel -0 --eta --jobs ($jobs) myffmpeg -n -loglevel 0 -i {} -map 0:v -map 0:a -map 0:s? -vcodec ($vcodec) -crf ($crf) -c:a aac {.}_($append).mp4"
        } catch {
          print (echo-r "failed myffmpeg...")
          print (echo-g "trying ffmpeg...")
          bash -c $"find . -type f (char -i 92)(char lparen) -iname '*.mp4' -o -iname '*.webm' (char -i 92)(char rparen) -not -name '*($append)*' -print0 | parallel -0 --eta --jobs ($jobs) ffmpeg -n -loglevel 0 -i {} -map 0:v -map 0:a -map 0:s? -vcodec ($vcodec) -crf ($crf) -c:a aac {.}_($append).mp4"
        }
      } else {
        try {
          print (echo-g "trying myffmpeg...")
          bash -c $"find . -type f (char -i 92)(char lparen) -iname '*.mp4' -o -iname '*.webm' -o -iname '*.mkv' (char -i 92)(char rparen) -not -name '*($append)*' -print0 | parallel -0 --eta --jobs ($jobs) myffmpeg -n -loglevel 0 -i {} -map 0:v -map 0:a -map 0:s? -vcodec ($vcodec) -crf ($crf) -c:a aac -c:s mov_text {.}_($append).mp4"
        } catch {
          print (echo-r "failed myffmpeg...")
          print (echo-g "trying ffmpeg...")
          bash -c $"find . -type f (char -i 92)(char lparen) -iname '*.mp4' -o -iname '*.webm' -o -iname '*.mkv' (char -i 92)(char rparen) -not -name '*($append)*' -print0 | parallel -0 --eta --jobs ($jobs) ffmpeg -n -loglevel 0 -i {} -map 0:v -map 0:a -map 0:s? -vcodec ($vcodec) -crf ($crf) -c:a aac -c:s mov_text {.}_($append).mp4"
        }
      }
    } else {
      if not $mkv {
        try {
          print (echo-g "trying myffmpeg...")
          bash -c $"find . -maxdepth ($level) -type f (char -i 92)(char lparen) -iname '*.mp4' -o -iname '*.webm' (char -i 92)(char rparen) -not -name '*($append)*' -print0 | parallel -0 --eta --jobs ($jobs) myffmpeg -n -loglevel 0 -i {} -map 0:v -map 0:a -map 0:s? -vcodec ($vcodec) -crf ($crf) -c:a aac {.}_($append).mp4"
        } catch {
          print (echo-r "failed myffmpeg...")
          print (echo-g "trying ffmpeg...")
          bash -c $"find . -maxdepth ($level) -type f (char -i 92)(char lparen) -iname '*.mp4' -o -iname '*.webm' (char -i 92)(char rparen) -not -name '*($append)*' -print0 | parallel -0 --eta --jobs ($jobs) ffmpeg -n -loglevel 0 -i {} -map 0:v -map 0:a -map 0:s? -vcodec ($vcodec) -crf ($crf) -c:a aac {.}_($append).mp4"
        }
      } else {
        try {
          print (echo-g "trying myffmpeg...")
          bash -c $"find . -maxdepth ($level) -type f (char -i 92)(char lparen) -iname '*.mp4' -o -iname '*.webm' -o -iname '*.mkv' (char -i 92)(char rparen) -not -name '*($append)*' -print0 | parallel -0 --eta --jobs ($jobs) myffmpeg -n -loglevel 0 -i {} -map 0:v -map 0:a -map 0:s? -vcodec ($vcodec) -crf ($crf) -c:a aac -c:s mov_text {.}_($append).mp4"
        } catch {
          print (echo-r "failed myffmpeg...")
          print (echo-g "trying ffmpeg...")
          bash -c $"find . -maxdepth ($level) -type f (char -i 92)(char lparen) -iname '*.mp4' -o -iname '*.webm' -o -iname '*.mkv' (char -i 92)(char rparen) -not -name '*($append)*' -print0 | parallel -0 --eta --jobs ($jobs) ffmpeg -n -loglevel 0 -i {} -map 0:v -map 0:a -map 0:s? -vcodec ($vcodec) -crf ($crf) -c:a aac -c:s mov_text {.}_($append).mp4"
        }
      }
    }
    return
  } 

  let ext = ($file | path parse | get extension)
  let name = ($file | path parse | get stem)

  match $ext {
    "avi" => {
      try {
        print (echo-g "trying myffmpeg...")
        my-ffmpeg -i $file -vcodec $vcodec -crf $crf -c:a aac $"($name)_($append).mp4"
      } catch {
        print (echo-r "failed myffmpeg...")
        print (echo-g "trying ffmpeg...")
        ffmpeg -i $file -map 0:v -map 0:a -map 0:s? -vcodec $vcodec -crf $crf -c:a aac $"($name)_($append).mp4"
      }
    },
    "mp4" => {
      try {
        print (echo-g "trying myffmpeg...")
        my-ffmpeg -i $file -vcodec $vcodec -crf $crf -c:a aac $"($name)_($append).mp4"
      } catch {
        print (echo-r "failed myffmpeg...")
        print (echo-g "trying ffmpeg...")
        ffmpeg -i $file -map 0:v -map 0:a -map 0:s? -vcodec $vcodec -crf $crf -c:a aac $"($name)_($append).mp4"
      }
    },
    "h264" => {
      try {
        print (echo-g "trying myffmpeg...")
        my-ffmpeg -i $file -map 0:v -map 0:a -map 0:s? -vcodec $vcodec -crf $crf -c:a aac $"($name)_($append).mp4"
      } catch {
        print (echo-r "failed myffmpeg...")
        print (echo-g "trying ffmpeg...")
        ffmpeg -i $file -map 0:v -map 0:a -map 0:s? -vcodec $vcodec -crf $crf -c:a aac $"($name)_($append).mp4"
      }
    },
    "webm" => {
      try {
        print (echo-g "trying myffmpeg...")
        my-ffmpeg -i $file -map 0:v -map 0:a -map 0:s? -vcodec $vcodec -crf $crf -c:a aac $"($name)_($append).mp4"
      } catch {
        print (echo-r "failed myffmpeg...")
        print (echo-g "trying ffmpeg...")
        ffmpeg -i $file -map 0:v -map 0:a -map 0:s? -vcodec $vcodec -crf $crf -c:a aac $"($name)_($append).mp4"
      }
    },
    "mkv" => {
      try {
        print (echo-g "trying myffmpeg...")
        my-ffmpeg -i $file -vcodec $vcodec -crf $crf -c:a aac -c:s mov_text $"($name)_($append).mp4"
      } catch {
        print (echo-r "failed myffmpeg...")
        print (echo-g "trying ffmpeg...")
        ffmpeg -i $file -map 0:v -map 0:a -map 0:s? -vcodec $vcodec -crf $crf -c:a aac -c:s mov_text $"($name)_($append).mp4"
      }
    },
    _ => {return-error "file extension not allowed"}
  }
  
  if $notify {"compression finished!" | tasker send-notification}
}

export alias mcv = media compress-video -nm

#delete original videos after compression recursively
export def "media delete-non-compressed" [
  file?
  --append(-a):string = '_com'
] {
  ls **/* 
  | where type == file 
  | where name like $append 
  | each {|file| 
      $file 
      | get name 
      | split row $"_($append)" 
      | str join "" 
      | path expand
    }
  | wrap name
  | rm-pipe

  ls **/*
  | where name like .webm
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
    | where name like ".json" 
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
    $results | where path not-like Manga
  } else {
    $results
  }
  | ansi-strip-table
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
    return
  } 

  let move = (input "move file to pending? (y/n): ")
  if $move == "y" {
    mv $video pending
  } 
}

#delete non wanted media in mps (youtube download folder)
export def "media delete-mps" [] {
  if $env.MY_ENV_VARS.mps not-like $env.PWD {
    return-error "wrong directory to run this!"
  } 

  le
  | where type == "file" and ext not-like "mp4|mkv|webm|part" 
  | each {|it| 
      rm $"($it.name)" | ignore
    }     
}

#mpv
export def mpv [
  video?, 
  --on-top(-o)
  --in-terminal(-i)
] {
  let video = get-input $in $video
  let type = $video | typeof

  match $type {
    "table" | "list" => {
      $video | each {|f| $f | mpv}
    },
    _ => {
      let file = (
        match $type {
          "record" => {$video | get name | ansi strip},
          "string" => {$video | ansi strip}
        }
      )

      if $on_top {
        ^mpv --save-position-on-quit --no-border --ontop $file
      } else if $in_terminal {
        ^mpv --save-position-on-quit --vo=kitty --really-quiet $file
      } else {
        ^mpv --save-position-on-quit --no-border $file
      } 
    }
  }
}

#extract audio from video file
export def "media extract-audio" [
  filename
  --audio_format(-a):string = "mp3" #audio output format, wav or mp3
  --notify(-n)               #notify to android via mpv
] {
  let file = $filename | path parse | get stem

  print (echo-g "extracting audio...")
  match $audio_format {
    "mp3" => {
      ffmpeg -loglevel 1 -i $"($filename)" -ar 44100 -ac 2 -ab 192k -f mp3 -vn $"($file).mp3"
    },
    "wav" => {
      ffmpeg -loglevel 1 -i $"($filename)" -acodec pcm_s16le -ar 128k -vn $"($file).wav"
    },
    _ => {return-error "format not allowed!"}
  }
  if $notify {"extraction finished!" | tasker send-notification}
}

#crop image by shortest dimension
#
#Generates a new square image cropped by the shortest dimention.
#The output name is (image_file_name_cropped.ext)
export def "media crop-image" [
  image?:string
  --name(-n)    #return name of cropped image
] {
  let image = get-input $in $image -n
  let image_size = identify $image | split row " " | get 2 | split row "x" | uniq
  
  if ($image_size | length) == 1 {
    print (echo-g "image already square!")
    if $name {return $image} else {return}
  }

  print (echo-r "Image isn't square, croping to the minor dimension...")

  let width = $image_size | get 0 | into int
  let height = $image_size | get 1 | into int

  let new_image = $"($image | path parse | get stem)_cropped.png"t

  if $width > $height {
    let new_image_size = $height

    let choice = ["center", "left", "right"] | input list (echo-g "choose from where you want to crop the image:")

    match $choice {
      "center" => {
          convert ($image | path expand) -gravity Center -crop $"($new_image_size)x($new_image_size)+0+0" +repage $new_image
        },

      "left" => {
          convert ($image | path expand) -gravity West -crop $"($new_image_size)x($new_image_size)+0+0" +repage $new_image
        },

      "right" => {
          convert ($image | path expand) -gravity East -crop $"($new_image_size)x($new_image_size)+0+0" +repage $new_image
        },

      _ => {return-error "Wrong choice of location for cropped image!!!"}
    }

  } else {
    let new_image_size = $width

    let choice = ["center", "top", "bottom"] | input list (echo-g "choose from where you want to crop the image:")

    match $choice {
      "center" => {
          convert ($image | path expand) -gravity Center -crop $"($new_image_size)x($new_image_size)+0+0" +repage $new_image
        },

      "top" => {
          convert ($image | path expand) -gravity North -crop $"($new_image_size)x($new_image_size)+0+0" +repage $new_image
        },

      "bottom" => {
          convert ($image | path expand) -gravity South -crop $"($new_image_size)x($new_image_size)+0+0" +repage $new_image
        },

      _ => {return-error "Wrong choice of location for cropped image!!!"}
    }
  }

  if $name {return $new_image} else {return}
}

#crop video 
export def "media crop-video" [
  video?:string
  --left(-l):string = "0" #horizontal offset of the crop area from the left edge of the video
  --top(-t):string = "0"  #vertical offset of the crop area from the left edge of the video
  --size(-s):string       #resolution of output video (ex: "720:1280")
  --append_to_filename(-a):string = "cropped" #append to original filename to differentiate
  --android(-A)           #use android resolution "720:x"
] {
  let video = get-input $in $video -n
  let resolution = media video-info $video | get streams.0 | select width height
  let output_resolution = (
    if not ($size | is-empty) {
      $size
    } else if $android {
      "720:" + ($resolution.height | into string)
    } else {
      return-error "output resolution not specified!"
    }
  )

  let filename = $video | path parse | get stem 
  let extension = $video | path parse | get extension

  if $extension != "mp4" {
    media to mp4 -f $video
  }

  let file = $filename + ".mp4"
  let output = $filename + "_" + $append_to_filename + ".mp4"

  let crop_command = "crop=" + $output_resolution + ":" + $left + ":" + $top

  ffmpeg -i $file -vf $crop_command $output
}

#get first frame of video
export def "media get-frame" [
  file? #file or list of files
] {

  let files = get-input $in $file

  $files 
  | get name 
  | par-each -t ([(sys cpu  | length) / 2 ($files | length)] | math min) {|f| 
      ffmpeg -ss 00:00:00 -i ($f) -vframes 1 $"($f | path parse | get stem).jpg"
    }
}

#images to video
#
#Example, for a list of files like:
#
# something_001_otherthing.png
# something_002_otherthing.png
# something_003_otherthing.png
# etc
#
#Run:
# media images-2-video something_%03d_otherthing.png
export def "media images-2-video" [
  files_pattern:string    # pattern for files
  --framerate(-f):int = 2 # how many images per second
  --output(-o):string = "output"  # file name of the output video
] {
  try {
    my-ffmpeg -framerate $framerate -i $files_pattern $"($output).mp4"
  } catch {
    ffmpeg -framerate $framerate -i $files_pattern $"($output).mp4"
  }
}

#auto remove black bars/banner from video
export def "media auto-crop-banner" [
  input: path
  output: path
] {
    let crop_params = ffmpeg -hide_banner -i $input -t 1 -vf cropdetect -f null - o+e>|
      | lines
      | filter {|line| 'crop=' in $line}
      | first
      | split row " "
      | last

    ffmpeg -hide_banner -i $input -vf $crop_params $output
}