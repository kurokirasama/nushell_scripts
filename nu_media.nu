#video info
export def "media video-info" [file] {
  mpv -ao null -frames 0 $"($file)" 
  | detect columns -n 
  | first 2 
  | reject column0 
  | rename track id extra codec
  | update cells {|f|
      $f 
      | str replace -a -s "(" "" 
      | str replace -a -s ")" ""
    }
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
] {
  let ext = ($file | path parse | get extension)
  let name = ($file | path parse | get stem)

  let ofile = (
    if ($output_file | is-empty) {
      $"($name)_cutted.($ext)"
    } else {
        $output_file
    }
  )

  myffmpeg -i $file -ss $SEGSTART -to  $SEGEND -map 0:0 -map 0:1 -c:a copy -c:v copy $ofile  
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
    let n_files = (bash -c $'find . -type f -not -name "*.part" -not -name "*.srt" -not -name "*.mkv" -not -name "*.mp4" -not -name "*.txt" -not -name "*.url" -not -name "*.jpg" -not -name "*.png" -not -name "*.($to)"'
        | lines 
        | length
    )

    echo-g $"($n_files) audio files found..."

    if $n_files > 0 {
      bash -c $'find . -type f -not -name "*.part" -not -name "*.srt" -not -name "*.mkv" -not -name "*.mp4" -not -name "*.txt" -not -name "*.url" -not -name "*.jpg" -not -name "*.png" -not -name "*.($to)" -print0 | parallel -0 --eta myffmpeg -n -loglevel 0 -i {} -c:a ($to) -b:a 64k {.}.($to)'

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