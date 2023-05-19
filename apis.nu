#get bitly short link
export def bitly [longurl] {
  if ($longurl | is-empty) {
    return-error "no url provided!"
  } else {
    let bitly_credential = (open-credential ([$env.MY_ENV_VARS.credentials "bitly_token.json.asc"] | path join))
    let Accesstoken = ($bitly_credential | get token)
    let guid = ($bitly_credential | get guid)
    
    let url = "https://api-ssl.bitly.com/v4/shorten"
    let content = {
      "group_guid": $guid,
      "domain": "bit.ly",
      "long_url": $longurl
    }

    let response = (http post $url $content --content-type "application/json" -H ["Authorization", $"Bearer ($Accesstoken)"])
    let shorturl = ($response | get link)

    $shorturl | copy
    print (echo-g $"($shorturl) copied to clipboard!")
  }
}

#translate text using mymemmory or openai api
export def trans [
  ...text:string    #search query
  --from:string     #from which language you are translating (default english)
  --to:string       #to which language you are translating (default spanish)
  --openai = false  #to use openai api instead of mymemmory, only translate to spanish (default false)
  --gpt4 = false    #use gpt4 for translating (default false)
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
    return-error "no search query provided!"
  } 
  
  match $openai {
    false => {
      let trans_credential = (open-credential ([$env.MY_ENV_VARS.credentials "mymemory_token.json.asc"] | path join))
      let key = ($trans_credential | get token)
      let user = ($trans_credential | get username)

      let from = if ($from | is-empty) {"en-US"} else {$from}
      let to = if ($to | is-empty) {"es-ES"} else {$to}

      let to_translate = ($search | str join "%20")

      let url = $"https://api.mymemory.translated.net/get?q=($to_translate)&langpair=($from)%7C($to)&of=json&key=($key)&de=($user)"
  
      let response = (http get $url)
      let status = ($response | get responseStatus)
      let translated = ($response | get responseData | get translatedText)
  
      if $status == 200 {
        let quota = ($response | get quotaFinished)
        if $quota {
          return-error "error: word quota limit excedeed!"
        }
  
        return $translated
      } else {
        return-error $"error: bad request ($status)!"
      }
    }

    true => {
      let pre_prompt = (open ([$env.MY_ENV_VARS.credentials chagpt_prompt.json] | path join) | get prompt3)

      let prompt = (
        $pre_prompt
        | str append $search
      )

      try {
        let translated = (
          if $gpt4 {
            chatgpt -m gpt4 $prompt
          } else {
            chatgpt $prompt
          }
          | ^sed '/^\s*$/d'
        )

        return $translated
      } catch {
        return-error "Some error ocurred!!"
      }
    }
  }
  
}

#get rebrandly short link
export def "rebrandly get" [longurl] {
 if ($longurl | is-empty) {
    return-error "no url provided"
  } else {
    let credential = (open-credential ([$env.MY_ENV_VARS.credentials "credential_rebrandly.json.asc"] | path join))
    let api_key = ($credential | get api_key)
    
    let url = "https://api.rebrandly.com/v1/links"
    let content = {"destination": $longurl}

    let response = (http post $url $content -H ["apikey", $api_key] --content-type "application/json" -H ["UserAgent:","UserAgent,curl/7.68.0"])
    let shorturl = ($response | get shortUrl)

    $shorturl | copy
    print (echo-g $"($shorturl) copied to clipboard!")
  }
} 

#list rebrandly last 25 short links
export def "rebrandly list" [longurl="www.google.com"] {
 if ($longurl | is-empty) {
    return-error "no url provided"
  } else {
    let credential = (open-credential ([$env.MY_ENV_VARS.credentials "credential_rebrandly.json.asc"] | path join))
    let api_key = ($credential | get api_key)
    
    let base_url = "https://api.rebrandly.com/v1/links"
    let url = $base_url + "?domain.id=" + $longurl + "&orderBy=createdAt&orderDir=desc&limit=25"

    http get $url -H ["apikey", $api_key] -H ["accept", "application/json"]
    
  }
}
