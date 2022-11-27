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

#remove audio noise from video
export def "media remove-audio-noise" [
  file      #video file name with extension
  start     #start (hh:mm:ss) of audio noise (no speaker)
  end       #end (hh:mm:ss) of audio noise (no speaker)
  noiseLevel#level reduction adjustment (0.2-0.3)
  output    #output file name with extension (same extension as $file)
] {
  if (ls ([$env.PWD tmp*] | path join) | length) > 0 {
    rm tmp*
  }

  echo-g "extracting video..."
  myffmpeg -loglevel 1 -i $"($file)" -vcodec copy -an tmpvid.mp4

  echo-g "extracting audio..."
  myffmpeg -loglevel 1 -i $"($file)" -acodec pcm_s16le -ar 128k -vn tmpaud.wav

  echo-g "extracting noise..."
  myffmpeg -loglevel 1 -i $"($file)" -acodec pcm_s16le -ar 128k -vn -ss $start -t $end tmpnoiseaud.wav

  echo-g "creating noise profile..."
  sox tmpnoiseaud.wav -n noiseprof tmpnoise.prof

  echo-g "cleaning noise from audio file..."
  sox tmpaud.wav tmpaud-clean.wav noisered tmpnoise.prof $noiseLevel

  echo-g "merging clean audio with video file..."
  myffmpeg -loglevel 1 -i tmpvid.mp4 -i tmpaud-clean.wav -map 0:v -map 1:a -c:v copy -c:a aac -b:a 128k $output

  echo-g "done!"
  notify-send "noise removal done!"

  echo-g "don't forget to remove tmp* files"
}

#screen record to mp4
export def "media screen-record" [
  file = "video"  #output filename without extension (export default: "video")
  --audio = true    #whether to record with audio or not (export default: true)
] {
  if $audio {
    ffmpeg -video_size 1920x1080 -framerate 24 -f x11grab -i :0.0+0,0 -f alsa -ac 2 -i pulse -acodec aac -strict experimental $"($file).mp4"
  } else {
    ffmpeg -video_size 1920x1080 -framerate 24 -f x11grab -i :0.0+0,0 $"($file).mp4"
  }
}

#remove audio from video file
export def "media remove-audio" [
  input_file: string          #the input file
  output_file = "video.mp4"  #the output file
] {
  myffmpeg -n -loglevel 0 -i $input_file -c copy -an $output_file
}

#cut segment of video file
export def "media cut-video" [
  file                     #video file name
  SEGSTART                 #timestamp of the start of the segment (hh:mm:ss)
  SEGEND                   #timestamp of the end of the segment (hh:mm:ss)
  --output_file(-o):string #output file
  --append(-a) = "cutted"  #append to file name
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

  myffmpeg -i $file -ss $SEGSTART -to  $SEGEND -map 0:0 -map 0:1 -c:a copy -c:v copy $ofile  
}

#split video file
export def "media split-video" [
  file                      #video file name
  --number_segments(-n):int #number of pieces to generate (takes precedence over -d)
  --duration(-d):duration   #duration of each segment (in duration format) except probably the last one
  --delta = 10sec           #duration of overlaping beetween segments. Default 5sec
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
    let segment_start = into hhmmss (($it - 1) * $seg_duration)
    let segment_end = into hhmmss ($seg_end + ($it - 1) * $seg_duration + $delta)

    echo-g $"generating part ($it): ($segment_start) - ($segment_end)..."
    media cut-video $file $segment_start $segment_end -a $it
  }

  let segment_start = into hhmmss (($n_segments - 1) * $seg_duration)

  echo-g $"generating part ($n_segments): ($segment_start) - ($full_hhmmss)..."
  media cut-video $file $segment_start $full_hhmmss -a $n_segments
}

#convert media files recursively to specified format
export def "media to" [
  to:string #destination format (aac, mp3 or mp4)
  #
  #Examples (make sure there are only compatible files in all subdirectories)
  #media-to mp4 (avi to mp4)
  #media-to aac (audio files to aac)
  #media-to mp3 (audio files to mp3)
] {
  #to aac or mp3
  if $to =~ "aac" || $to =~ "mp3" {
    let n_files = (bash -c $'find . -type f -not -name "*.part" -not -name "*.srt" -not -name "*.mkv" -not -name "*.mp4" -not -name "*.txt" -not -name "*.url" -not -name "*.jpg" -not -name "*.png" -not -name "*.3gp" -not -name  "*.($to)"'
        | lines 
        | length
    )

    echo-g $"($n_files) audio files found..."

    if $n_files > 0 {
      bash -c $'find . -type f -not -name "*.part" -not -name "*.srt" -not -name "*.mkv" -not -name "*.mp4" -not -name "*.txt" -not -name "*.url" -not -name "*.jpg" -not -name "*.png" -not -name "*.3gp" -not -name "*.($to)" -print0 | parallel -0 --eta myffmpeg -n -loglevel 0 -i {} -c:a ($to) -b:a 64k {.}.($to)'

      let aacs = (ls **/* 
        | insert "ext" { 
            $in.name | path parse | get extension
          }  
        | where ext =~ $to 
        | length
      )

      if $n_files == $aacs {
        echo-g $"audio conversion to ($to) done"
      } else {
        echo-r $"audio conversion to ($to) done, but something might be wrong"
      }
    }
  #to mp4
  } else if $to =~ "mp4" {
    let n_files = (ls **/*
        | insert "ext" { 
            $in.name | path parse | get extension
          }  
        | where ext =~ "avi"
        | length
    )

    echo-g $"($n_files) avi files found..."

    if $n_files > 0 {
      bash -c 'find . -type f -name "*.avi" -print0 | parallel -0 --eta myffmpeg -n -loglevel 0 -i {} -b:a 64k {.}.mp4'

      let aacs = (ls **/* 
        | insert "ext" { 
            $in.name | path parse | get extension
          }  
        | where ext =~ "mp4"
        | length
      )

      if $n_files == $aacs {
        echo-g $"video conversion to mp4 done"
      } else {
        echo-r $"video conversion to mp4 done, but something might be wrong"
      }
    }
  }
}

#cut segment from audio file
export def "media cut-audio" [
  infile:string   #input audio file
  outfile:string  #output audio file
  start:int       #start of the piece to extract (s) 
  duration:int    #duration of the piece to extract (s)
  #
  #Example: cut 10s starting at second 60 
  #cut_audio input.ext output.ext 60 10
] {  
  myffmpeg -ss $start -i $"($infile)" -t $duration -c copy $"($outfile)"
}

#merge subs to mkv video
export def "media merge-subs" [
  filename  #name (without extencion) of both subtitle and mkv file
] {
  mkvmerge -o myoutput.mkv  $"($filename).mkv" --language "0:spa" --track-name $"0:($filename)" $"($filename).srt"
  mv myoutput.mkv $"($filename).mkv"
  rm $"($filename).srt" | ignore
}

#merge videos
export def "media merge-videos" [
  list  #text file with list of videos to merge
  output#output file
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
  echo-g "merging videos..."
  myffmpeg -f concat -safe 0 -i $"($list)" -c copy $"($output)"
  
  echo-g "done!"
  notify-send "video merging done!"
}

#auto merge all videos in dir
export def "media merge-videos-auto" [
  ext   #unique extension of all videos to merge
  output#output file
  #
  #To get a functional output, all audio sample rate must be the same
  #check with video-info video_file
] {
  let list = (($env.PWD) | path join "list.txt")

  if not ($list | path exists) {
    touch $"($list)"
  } else {
    "" | save $list
  }
  
  ls $"*.($ext)" 
  | where type == file 
  | get name
  | each {|file|
      echo (build-string "file \'" (($env.PWD) | path join $file) "\'\n") | save --append list.txt
    }

  echo-g "merging videos..."
  myffmpeg -f concat -safe 0 -i list.txt -c copy $"($output)"
      
  echo-g "done!"
  notify-send "video merging done!"
}

#sync subtitles
export def "media sub-sync" [
  file:string      #subtitle file name to process
  d1:string        #delay at the beginning or at time specified by t1 (<0 adelantar, >0 retrasar)
  --t1:string      #time position of delay d1 (hh:mm:ss)
  --d2:string      #delay at the end or at time specified by t2
  --t2:string      #time position of delay d2 (hh:mm:ss)t
  --no_backup:int  #wether to not backup $file or yes (export default no:0, ie, it will backup)
  #
  #Examples
  #sub-sync file.srt "-4"
  #sub-sync file.srt "-4" --t1 00:02:33
  #sub-sync file.srt "-4" --no_backup 1
] {

  let file_exist = (($env.PWD) | path join $file | path exists)
  
  if $file_exist {
    if ($no_backup | is-empty) || $no_backup == 0 {
      cp $file $"($file).backup"
    }

    let t1 = if ($t1 | is-empty) {"@"} else {$t1}  
    let d2 = if ($d2 | is-empty) {""} else {$d2}
    let t2 = if ($d2 | is-empty) {""} else {if ($t2 | is-empty) {"@"} else {$t2}}
  
    bash -c $"subsync -e latin1 ($t1)($d1) ($t2)($d2) < \"($file)\" > output.srt; cp output.srt \"($file)\""

    rm output.srt | ignore
  } else {
    echo-r $"subtitle file ($file) doesn't exist in (pwd-short)"
  }
}

#reduce size of video files recursively, to mp4 x265
export def "media compress-video" [
  --level(-l):int           #level of recursion (-maxdepth in ^find, minimun = 1).
  --crf(-c) = 28            #compression rate, range 0-51, sane range 18-28. Default 28.
  --vcodec(-v) = "libx265"  #video codec: libx264 | libx265 (default).
  --mkv(-m)                 #include mkv files (default: false).
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
  let n_files = (
    if ($level | is-empty) {
      if not $mkv {
        bash -c $"find . -type f (char -i 92)(char lparen) -iname '*.mp4' -o -iname '*.webm' (char -i 92)(char rparen) -not -name '*compressed_by_me*'"
      } else {
        bash -c $"find . -type f (char -i 92)(char lparen) -iname '*.mp4' -o -iname '*.webm' -o -iname '*.mkv' (char -i 92)(char rparen) -not -name '*compressed_by_me*'"
      }
    } else {
      if not $mkv {
        bash -c $"find . -maxdepth ($level) -type f (char -i 92)(char lparen) -iname '*.mp4' -o -iname '*.webm' (char -i 92)(char rparen) -not -name '*compressed_by_me*'"
      } else {
        bash -c $"find . -maxdepth ($level) -type f (char -i 92)(char lparen) -iname '*.mp4' -o -iname '*.webm' -o -iname '*.mkv' (char -i 92)(char rparen) -not -name '*compressed_by_me*'"
      }
    }
    | lines 
    | length
  )

  if $n_files > 0 {
    echo-g $"($n_files) video files found..."

    if ($level | is-empty) {
      if not $mkv {
        bash -c $"find . -type f (char -i 92)(char lparen) -iname '*.mp4' -o -iname '*.webm' (char -i 92)(char rparen) -not -name '*compresses_by_me*' -print0 | parallel -0 --eta --jobs 2 ffmpeg -n -loglevel 0 -i {} -vcodec ($vcodec) -crf ($crf) {.}_compressed_by_me.mp4"
      } else {
        bash -c $"find . -type f (char -i 92)(char lparen) -iname '*.mp4' -o -iname '*.webm' -o -iname '*.mkv' (char -i 92)(char rparen) -not -name '*compresses_by_me*' -print0 | parallel -0 --eta --jobs 2 ffmpeg -n -loglevel 0 -i {} -vcodec ($vcodec) -crf ($crf) {.}_compressed_by_me.mp4"
      }
    } else {
      if not $mkv {
        bash -c $"find . -maxdepth ($level) -type f (char -i 92)(char lparen) -iname '*.mp4' -o -iname '*.webm' (char -i 92)(char rparen) -not -name '*compresses_by_me*' -print0 | parallel -0 --eta --jobs 2 ffmpeg -n -loglevel 0 -i {} -vcodec ($vcodec) -crf ($crf) {.}_compressed_by_me.mp4"
      } else {
        bash -c $"find . -maxdepth ($level) -type f (char -i 92)(char lparen) -iname '*.mp4' -o -iname '*.webm' -o -iname '*.mkv' (char -i 92)(char rparen) -not -name '*compresses_by_me*' -print0 | parallel -0 --eta --jobs 2 ffmpeg -n -loglevel 0 -i {} -vcodec ($vcodec) -crf ($crf) {.}_compressed_by_me.mp4"
      }
    }
  } else {
    echo-r $"no files found..."
  }
}

#delete original videos after compression recursively
export def "media delete-non-compressed" [file?] {
  ls **/* 
  | where type == file 
  | where name =~ compressed_by_me 
  | par-each {|file| 
      $file 
      | get name 
      | split row "_compressed_by_me" 
      | str collect "" 
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
        | upsert stem ($file | get name | path parse | get stem | str append "_compressed_by_me")
        | upsert extension mp4
        | path join
      )
      
      if ($compressed | path exists) {
        $file | rm-pipe
      }
    }
}