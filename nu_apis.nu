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