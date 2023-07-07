#get bitly short link
export def bitly [longurl] {
  if ($longurl | is-empty) {
    return-error "no url provided!"
  } else {
    let bitly_credential = $env.MY_ENV_VARS.api_keys.bitly
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
  --gpt4            #use gpt4 for translating (default false)
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
      let trans_credential = $env.MY_ENV_VARS.api_keys.mymemmory
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
      let prompt = ($search | str join " ")
      let translated = (
        if $gpt4 {
          chat_gpt $prompt -t 0.8 --select_system spanish_translator --select_preprompt trans_to_spanish -m gpt-4
        } else {
          chat_gpt $prompt -t 0.8 --select_system spanish_translator --select_preprompt trans_to_spanish
        }
      )

      return $translated
    }
  }
  
}

#get rebrandly short link
export def "rebrandly get" [longurl] {
 if ($longurl | is-empty) {
    return-error "no url provided"
  } else {
    let credential = $env.MY_ENV_VARS.api_keys.rebrandly
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
    let credential = $env.MY_ENV_VARS.api_keys.rebrandly
    let api_key = ($credential | get api_key)
    
    let base_url = "https://api.rebrandly.com/v1/links"
    let url = $base_url + "?domain.id=" + $longurl + "&orderBy=createdAt&orderDir=desc&limit=25"

    http get $url -H ["apikey", $api_key] -H ["accept", "application/json"]
    
  }
}

#get eta via maps api
export def get_maps_eta [
  origin:string       #origin gps coordinates or address
  destination:string  #destination gps coordinates or address
  --mode = "driving"  #driving mode (driving, transit, walking)
  --avoid             #whether to avoid highways (default:false)
] {
  let api_key = $env.MY_ENV_VARS.api_keys.google.general

  let origin_address = (
    if $origin =~ '^(-?\d+\.\d+),(-?\d+\.\d+)$' {
      http get ("https://maps.googleapis.com/maps/api/geocode/json?latlng=" + $origin + "&sensor=true&key=" + $api_key)
      | get results 
      | get formatted_address 
      | get 0
    } else {
      $origin
    } 
  )
  
  let destination_address = (
    if $destination =~ '^(-?\d+\.\d+),(-?\d+\.\d+)$' {
      http get ("https://maps.googleapis.com/maps/api/geocode/json?latlng=" + $destination + "&sensor=true&key=" + $api_key) 
      | get results 
      | get formatted_address 
      | get 0 
    } else {
      $destination
    }
  )

  let avoid_option = if $avoid {"&avoid=highways"} else {""} 

  let url = ("https://maps.googleapis.com/maps/api/directions/json?origin=" + $origin + "&destination=" + $destination + "&mode=" + $mode + "&departure_time=now&key=" + $api_key + $avoid_option)

  let response = (http get $url)

  let distance = $response.routes.legs.0.distance.text.0
  let steps = $response.routes.legs.0.steps
  let duration = $response.routes.legs.0.duration.text.0

  let directions_steps = (
      $steps.0.html_instructions 
      | to text 
      | chat_gpt --select_system html_parser --select_preprompt parse_html 
      | lines 
      | wrap directions 
      | dfr into-df 
      | dfr append ($steps.0.duration.text | wrap duration | dfr into-df) 
      | dfr into-nu
  )

  let info = { 
    origin: $origin_address,
    destination: $destination_address,
    distance: $distance,
    duration: $duration,
    mode: $mode
  }

  let output = {
    info: $info
    direction: $directions_steps
  }

  return $output
}

#clp exchange rates via fixer.io API
export def exchange_rates [
  new_currency?:string  #include unique new currency
  --symbols(-s)         #only show available symbols
  --update_dataset(-u)  #update local dataset
  #
  #Show CLP/CLF,USD,BTC,new_currency exchange
] {
  let api_key = $env.MY_ENV_VARS.api_keys.fixer_io

  if (not $symbols) {
    let url = (
      if ($new_currency | is-empty) {
        $"http://data.fixer.io/api/latest?access_key=($api_key)&symbols=CLP,CLF,USD,BTC"
      } else {
        $"http://data.fixer.io/api/latest?access_key=($api_key)&symbols=CLP,CLF,USD,BTC,($new_currency)"
      }
    )
    let response = (http get $url)
  
    if not $response.success {
      return-error $response.error
    }
  
    let eur_usd = (1 / $response.rates.USD)
    let eur_btc = (1 / $response.rates.BTC)
    let eur_clf = (1 / $response.rates.CLF)
    let eur_new = if ($new_currency | is-empty) {0} else {1 / ($response.rates | get $new_currency)}

    let output = (
      if ($new_currency | is-empty) {
        {
          UF:  ($eur_clf * $response.rates.CLP)
          USD: ($eur_usd * $response.rates.CLP),
          EUR: $response.rates.CLP,
          BTC: ($eur_btc * $response.rates.CLP)
        }
      } else {
        {
          UF:  ($eur_clf * $response.rates.CLP)
          USD: ($eur_usd * $response.rates.CLP),
          EUR: $response.rates.CLP,
          BTC: ($eur_btc * $response.rates.CLP),
          $"($new_currency)": ($eur_new * $response.rates.CLP)
        }
      }
    )

    if $update_dataset {
      let to_save = (
        $output 
        | rename -c [UF date]
        | upsert date (date now | date format "%Y.%m.%d %H:%M:%S")
      )
      
      open ([$env.MY_ENV_VARS.datasets exchange_rates.csv] | path join) 
      | append $to_save 
      | save -f ([$env.MY_ENV_VARS.datasets exchange_rates.csv] | path join)
    }

    return $output

  } else {
    let url_symbols = $"http://data.fixer.io/api/symbols?access_key=($api_key)"
    let symbols = (http get $url_symbols)
    return $symbols.symbols
  }
}