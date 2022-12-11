#get bitly short link
export def mbitly [longurl] {
  if ($longurl | is-empty) {
    echo-r "no url provided"
  } else {
    let bitly_credential = open-credential ([$env.MY_ENV_VARS.credentials "bitly_token.json.asc"] | path join)
    let Accesstoken = ($bitly_credential | get token)
    let guid = ($bitly_credential | get guid)
    
    let url = "https://api-ssl.bitly.com/v4/shorten"
    let content = {
      "group_guid": $guid,
      "domain": "bit.ly",
      "long_url": $longurl
    }

    let response = post $url $content --content-type "application/json" -H ["Authorization", $"Bearer ($Accesstoken)"]
    let shorturl = ($response | get link)

    $shorturl | copy
    echo-g $"($shorturl) copied to clipboard!"
  }
}

#translate text using mymemmory api
export def trans [
  ...text:string   #search query
  --from:string     #from which language you are translating (export default english)
  --to:string       #to which language you are translating (export default spanish)
  #
  #Use ISO standar names for the languages, for example:
  #english: en-US
  #spanish: es-ES
  #italian: it-IT
  #swedish: sv-SV
  #
  #More in: https://en.wikipedia.org/wiki/List_of_ISO_639-1_codes
] {
  let search = if ($text | is-empty) {$in} else {$text}
  if ($search | is-empty) {
    echo-r "error: no search query provided!"
    return
  } 
  
  let trans_credential = open-credential ([$env.MY_ENV_VARS.credentials "mymemory_token.json.asc"] | path join)
  let key = ($trans_credential | get token)
  let user = ($trans_credential | get username)

  let from = if ($from | is-empty) {"en-US"} else {$from}
  let to = if ($to | is-empty) {"es-ES"} else {$to}

  let to_translate = ($search | str collect "%20")

  let url = $"https://api.mymemory.translated.net/get?q=($to_translate)&langpair=($from)%7C($to)&of=json&key=($key)&de=($user)"
  
  let response = fetch $url
  let status = ($response | get responseStatus)
  let translated = ($response | get responseData | get translatedText)
  
  if $status == 200 {
    let quota = ($response | get quotaFinished)
    if $quota {
      echo-r "error: word quota limit excedeed!"
      return
    }
  
    $translated
  } else {
    echo-r $"error: bad request ($status)!"
  }
}

#translate subtitle
export def trans-sub [file?] {
  let file = if ($file | is-empty) {$file | get name} else {$file}
  dos2unix -q $file

  let $file_info = ($file | path parse)
  let new_file = $"($file_info | get stem)_translated.($file_info | get extension)"
  let lines = (open $file | lines | length)

  echo $"translating ($file)..."

  if not ($new_file | path expand | path exists) {
    touch $new_file

    open $file
    | lines
    | each -n {|line|
        if (not $line.item =~ "-->") and (not $line.item =~ '^[0-9]+$') and ($line.item | str length) > 0 {
          let fixed_line = ($line.item | iconv -f UTF-8 -t ASCII//TRANSLIT)
          let translated = ($fixed_line | trans)

          if $translated =~ "error:" {
            echo-r $"error while translating: ($translated)"
            $line.index | save -f line.txt
            return
          } else {
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
    let start = (open $new_file | lines | length)

    open $file
    | lines
    | last ($lines - $start)
    | each -n {|line|
        if (not $line.item =~ "-->") and (not $line.item =~ '^[0-9]+$') and ($line.item | str length) > 0 {
          let fixed_line = ($line.item | iconv -f UTF-8 -t ASCII//TRANSLIT)
          let translated = ($fixed_line | trans)

          if $translated =~ "error:" {
            echo-r $"error while translating: ($translated)"
            $line.index | save -f line.txt
            return
          } else {
            $translated | ansi strip | save --append $new_file
            "\n" | save --append $new_file
          }
        } else {
          $line.item | save --append $new_file
          "\n" | save --append $new_file
        }
        print -n (echo-g $"\r(($line.index + $start) / $lines * 100 | math round -p 3)%")
      } 
  } 
}