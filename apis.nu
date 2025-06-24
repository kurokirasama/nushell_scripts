#get bitly short link
@category apis
@search-terms bitly shortlink
export def bitly [longurl] {
  if ($longurl | is-empty) {
    return-error "no url provided!"
  } 

  let bitly_credential = $env.MY_ENV_VARS.api_keys.bitly
  let Accesstoken = $bitly_credential | get token
  let guid = $bitly_credential | get guid
    
  let url = "https://api-ssl.bitly.com/v4/shorten"
  let content = {
    "group_guid": $guid,
    "domain": "bit.ly",
    "long_url": $longurl
  }

  let response = http post $url $content --content-type "application/json" -H ["Authorization", $"Bearer ($Accesstoken)"]
  let shorturl = $response | get link

  $shorturl | copy
  print (echo-g $"($shorturl) copied to clipboard!")
}

#translate text using mymemmory or openai api
#
#Use ISO standar names for the languages, for example:
#english: en-US
#spanish: es-ES
#italian: it-IT
#swedish: sv-SV
#
#More in: https://en.wikipedia.org/wiki/List_of_ISO_639-1_codes
@category apis
@search-terms mymemmory translate
export def trans [
  ...text:string    #search query
  --from:string     #from which language you are translating (default english)
  --to:string       #to which language you are translating (default spanish)
] {
  let search = get-input $in $text
  if ($search | is-empty) {
    return-error "no search query provided!"
  } 

  let trans_credential = $env.MY_ENV_VARS.api_keys.mymemmory
  let apikey = $trans_credential | get token
  let user = $trans_credential | get username

  let from = get-input "en-US" $from
  let to = get-input "es-ES" $to

  let to_translate = $search | str join "%20"

  let url = {
    scheme: "https",
    host: "api.mymemory.translated.net",
    path: "/get",
    params: {
        q: $to_translate,
        langpair: ($from + "|" + $to),
        of: "json",
        key: $apikey,
        de: $user
    }
  } | url join
  
  let response = http get $url
  let status = $response | get responseStatus
  let translated = $response | get responseData | get translatedText
  
  if $status != 200 {
    return-error $"error: bad request ($status)!"
  }

  let quota = $response | get quotaFinished
  
  if $quota {
      return-error "error: word quota limit excedeed!"
  }
  
  return $translated
}

#get rebrandly short link
@category apis
@search-terms rebrandly shortlink
export def "rebrandly get" [longurl] {
  if ($longurl | is-empty) {
    return-error "no url provided"
  }

  let credential = $env.MY_ENV_VARS.api_keys.rebrandly
  let api_key = $credential | get api_key
    
  let url = "https://api.rebrandly.com/v1/links"
  let content = {"destination": $longurl}

  let response = http post $url $content -H ["apikey", $api_key] --content-type "application/json" -H ["UserAgent:","UserAgent,curl/7.68.0"]
  let shorturl = $response | get shortUrl

  $shorturl | copy
  print (echo-g $"($shorturl) copied to clipboard!")
} 

#list rebrandly last 25 short links
@category apis
@search-terms rebrandly shortlink
export def "rebrandly list" [longurl="www.google.com"] {
  if ($longurl | is-empty) {
    return-error "no url provided"
  } 

  let credential = $env.MY_ENV_VARS.api_keys.rebrandly
  let apikey = $credential | get api_key
    
  let url = {
        scheme: "https",
        host: "api.rebrandly.com",
        path: "/v1/links",
        params: {
            domain.id: $longurl,
            orderBy: "createdAt",
            orderDir: "desc",
            limit: 25
        }
      } | url join

  http get $url -H ["apikey", $apikey] -H ["accept", "application/json"]
}

#get eta via maps api
@category apis
@search-terms google maps
export def "maps eta" [
  origin:string       #origin gps coordinates or address
  destination:string  #destination gps coordinates or address
  --mode = "driving"  #driving mode (driving, transit, walking)
  --avoid             #whether to avoid highways (default:false)
] {
  let apikey = $env.MY_ENV_VARS.api_keys.google.general

  let origin_address = (
    if $origin like '^(-?\d+\.\d+),(-?\d+\.\d+)$' {
      {
        scheme: "https",
        host: "maps.googleapis.com",
        path: "/maps/api/geocode/json",
        params: {
            latlng: $origin,
            sensor: "true",
            key: $apikey
        }
      } 
      | url join
      | http get $in
      | get results.formatted_address.0
    } else {
      $origin
    } 
  )
  
  let destination_address = (
    if $destination like '^(-?\d+\.\d+),(-?\d+\.\d+)$' {
       {
        scheme: "https",
        host: "maps.googleapis.com",
        path: "/maps/api/geocode/json",
        params: {
            latlng: $destination,
            sensor: "true",
            key: $apikey
        }
      } 
      | url join
      | http get $in 
      | get results.formatted_address.0 
    } else {
      $destination
    }
  )

  let avoid_option = if $avoid {"&avoid=highways"} else {""} 

  let response = {
      scheme: "https",
      host: "maps.googleapis.com",
      path: "/maps/api/directions/json",
      params: {
        origin: ($origin | url encode),
        destination: ($destination | url encode),
        mode: $mode,
        departure_time: "now",
        sensor: "true",
        key: $apikey
      }
    } 
    | url join 
    | str append $avoid_option
    | http get $in

  let distance = $response.routes.legs.0.distance.text.0
  let steps = $response.routes.legs.0.steps
  let duration = $response.routes.legs.0.duration.text.0

  let directions_steps = (
      $steps.0.html_instructions 
      | each {|g| $g | html2text} 
      | str trim
      | wrap directions 
      | polars into-df 
      | polars append ($steps.0.duration.text | wrap duration | polars into-df) 
      | polars into-nu
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

#get geo-coordinates from address
@category apis
@search-terms google coordinates
export def "maps loc-from-address" [address:string] {
  let mapsAPIkey = $env.MY_ENV_VARS.api_keys.google.general
  
  let url = {
    scheme: "https"
    host: "maps.google.com"
    path: "/maps/api/geocode/json"
    params: {
        address: $address
        key: $mapsAPIkey
    }
  } | url join

  return (http get $url | get results.geometry.location)
}

#get address from geo-coordinates
@category apis
@search-terms google coordinates
export def "maps address-from-loc" [latitude:number,longitude:number] {
  let mapsAPIkey = $env.MY_ENV_VARS.api_keys.google.general

  let url = {
    scheme: "https"
    host: "maps.google.com"
    path: "/maps/api/geocode/json"
    params: {
        latlng: $"($latitude),($longitude)"
        key: $mapsAPIkey
    }
  } | url join

  let response = http get $url

  if $response.status != OK {
    return-error "address not found!"
  } 

  return $response.results.0.formatted_address
}

#clp exchange rates via fixer.io API
#
#Show CLP/CLF,USD,BTC,new_currency exchange
@category apis
@search-terms fixer.io exchange currency
export def exchange_rates [
  new_currency?:string  #include unique new currency
  --symbols(-s)         #only show available symbols
  --update_dataset(-u)  #update local dataset
] {
  let api_key = $env.MY_ENV_VARS.api_keys.fixer_io.api_key

  if $symbols {
    let url_symbols = $"http://data.fixer.io/api/symbols?access_key=($api_key)"
    let symbols = (http get $url_symbols)
    return $symbols.symbols
  }

  let url = (
    if ($new_currency | is-empty) {
      $"http://data.fixer.io/api/latest?access_key=($api_key)&symbols=CLP,CLF,USD,BTC"
    } else {
      $"http://data.fixer.io/api/latest?access_key=($api_key)&symbols=CLP,CLF,USD,BTC,($new_currency)"
    }
  )
  let response = http get $url
  
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
      | rename -c {UF: date}
      | upsert date (date now | format date "%Y.%m.%d %H:%M:%S")
    )
    
    open ([$env.MY_ENV_VARS.datasets exchange_rates.csv] | path join) 
    | append $to_save 
    | save -f ([$env.MY_ENV_VARS.datasets exchange_rates.csv] | path join)
  }
  return $output
}

# Translate text using Google Translate
@category apis
@search-terms google translate 
export def gg-trans [
  text?: string # The text to translate
  --source(-s): string = "auto", # The source language
  --destination(-d): string = "es", # The destination language
  --list(-l)  # Select destination language from list
] {
  let text = get-input $in $text
  mut dest = ""

  if $list {
    let languages = open ([$env.MY_ENV_VARS.credentials google_translate_languages.json] | path join)
    let selection = (
      $languages
      | columns
      | input list -f (echo-g "Select destination language:")
    )

    $dest = $languages | get $selection

  } else {
      $dest = $destination
  }

  {
    scheme: "https",
    host: "translate.googleapis.com",
    path: "/translate_a/single",
    params: {
        client: gtx,
        sl: $source,
        tl: $dest,
        dt: t,
        q: ($text | url encode),
    }
  }
  | url join
  | http get $in
  | get 0.0.0
}

#google search
@category apis
@search-terms google search
export def google_search [
  ...query:string
  --number_of_results(-n):int = 5 #number of results to use
  --verbose(-v) #show some debug messages
  --md(-m) #md output instead of table
] {
  let query = get-input $in $query | str join " "

  if ($query | is-empty) {
    return-error "empty query!"
  }

  let apikey = $env.MY_ENV_VARS.api_keys.google.search.apikey
  let cx = $env.MY_ENV_VARS.api_keys.google.search.cx

  if $verbose {print (echo-g $"asking to google search: ($query)")}
  let response = {
      scheme: "https",
      host: "www.googleapis.com",
      path: "/customsearch/v1",
      params: {
          key: $apikey,
          cx: $cx
          q: ($query | str replace -a " " "+")
      }
    } 
    | url join
    | http get $in -e

    if "items" not-in ($response | columns) {
      return-error "empty search result!"
    }

    let search_result = (
      $response
      | get items 
      | first $number_of_results 
      | select title link displayLink
    )

  let n_result = $search_result | length

  mut content = []

  for i in 0..($n_result - 1) {
    let web = $search_result | get $i
    if $verbose {print (echo-c $"retrieving data from: ($web.displayLink)" "green")}
      
    let raw_content = try {http get $web.link} catch {""}

    let processed_content = (
      try {
        $raw_content
        | html2text --ignore-links --ignore-images --dash-unordered-list
        | lines 
        | uniq
        | to text
      } catch {
        $raw_content
      }
    )

    $content = $content ++ [$processed_content]
  }

  let final_content = $content | wrap "content"
  let results = $search_result | append-table $final_content

  if $md {
      mut md_output = ""

      for i in 0..(($results | length) - 1) {
        let web = $results | get $i
        
        $md_output = $md_output + "# " + $web.title + "\n"
        $md_output = $md_output + "link: " + $web.link + "\n\n"
        $md_output = $md_output + $web.content + "\n\n"
      }

      return $md_output
  } 

  return $results
}

# fetch and base64 encode audio URLs
def audiourl [voice text] {
    # url encode text and prepend url
    let enc_url = $text | url encode | prepend $voice | str join ""
    # fetch and base64 encode audio url
    let base64 = try { http get -m 5sec $enc_url | encode base64 } catch { |e| return ($e.json | from json | wrap error) }
    # wrap result for json output
    return ($base64 | prepend "data:audio/mp3;base64," | str join "" | wrap audioUrl | merge ($enc_url | wrap originalUrl))
}

# get TikTok TTS audio from weilnet
def weilnet [voice text] {
    # setup body json
    let body = $text | wrap text | merge ($voice | wrap voice) | to json -r
    # make http post request, fallback to weilbyte
    let req_json = try {
        http post -m 6sec -H [content-type application/json] "https://tiktok-tts.weilnet.workers.dev/api/generation" $body
    } catch {
        return (weilbyte $voice $text)
    }
    # prepend audio info and rename column
    let json = try {
        $req_json | upsert data { |row| $row.data | prepend "data:audio/mp3;base64," | str join ""} | rename -c {data: audioUrl}
    } catch {
        return (weilbyte $voice $text)
    }
    # output json result
    return $json
}

# get TikTok TTS audio from weilbyte
def weilbyte [voice text] {
    # setup body json
    let body = $text | wrap text | merge ($voice | wrap voice) | to json -r
    # make http post request and bas64 encode result, fallback to gesserit
    let base64 = try {
        http post -m 6sec -H [content-type application/json] "https://tiktok-tts.weilbyte.dev/api/generate" $body | encode base64
    } catch {
        return (cursecode $voice $text)
    }
    # wrap result for json otuput
    return ($base64 | prepend "data:audio/mp3;base64," | str join "" | wrap audioUrl)
}

# get TikTok TTS audio from cursecode
def cursecode [voice text] {
    # setup body json
    let body = $text | wrap text | merge ($voice | wrap voice) | to json -r
    # make http post request, fallback to weilnet
    let req_json = try {
        http post -m 6sec -H [content-type application/json] "https://tts.cursecode.me/api/tts" $body
    } catch {
        return (gesserit $voice $text)
    }
    # rename column
    let json = try { $req_json | rename -c { audio: audioUrl } } catch { return (gesserit $voice $text) }
    # output json result
    return $json
}

# get TikTok TTS audio from gesserit
def gesserit [voice text] {
    # setup body json
    let body = $text | wrap text | merge ($voice | wrap voice) | to json -r
    # make http post request, fallback to lazypy
    let json = try { http post -m 6sec "https://gesserit.co/api/tiktok-tts" $body } catch { return (lazypy $voice "TikTok" $text) }
    # output json result
    return $json
}

# get TTS audio from uberduck
def uberduck [voice text] {
    # setup body json
    let body = $text | wrap text | merge ($voice | wrap voice) | to json -r
    # make http post request
    let audio_json = try {
        http post -m 10sec -H [content-type application/json] "https://www.uberduck.ai/splash-tts" $body
    } catch {
        |e| return ($e.json | from json | wrap error)
    }
    let audio_url = try { $audio_json | get response.path } catch { |e| return ($e.json | from json | wrap error) }
    # fetch and base64 encode result
    let base64 = try { http get -m 5sec ($audio_url) | encode base64 } catch { |e| return ($e.json | from json | wrap error) }
    # wrap result for json otuput
    return ($base64 | prepend "data:audio/wav;base64," | str join "" | wrap audioUrl | merge $audio_json)
}

# get TTS audio from lazypy
def lazypy [voice service text] {
    # create body using url build-query
    let body = $text | wrap text | merge ($service | wrap service) | merge ($voice | wrap voice) | url build-query
    # post body to lazypy and get audio_url
    let audio_json = try {
        http post -m 10sec -H [content-type application/x-www-form-urlencoded] "https://lazypy.ro/tts/request_tts.php" $body
    } catch {
        |e| return ($e.json | from json | wrap error)
    }
    # return response if success is not true
    if ($audio_json | get success) != true {
        return ($audio_json | wrap error)
    }
    let audio_url = try { $audio_json | get audio_url } catch { |e| return ($e.json | from json | wrap error) }
    # fetch and base64 encode result
    let base64 = try { http get -m 5sec $audio_url | encode base64 } catch { |e| return ($e.json | from json | wrap error) }
    return ($base64 | prepend "data:audio/mp3;base64," | str join "" | wrap audioUrl | merge $audio_json)
}

# gets JSON list of TTS voices
@category apis
@search-terms tts
export def "nutts list" [] {
  let list = try {
    http get "https://raw.githubusercontent.com/simoniz0r/nuTTS/main/tts_list.json"
  } catch {
    |e| return-error ($e.json | from json | wrap error)
  }
  return $list
}

# gets TTS audio for given service, returns base64 encoded audio
#
# results are output in JSON format
@category apis
@search-terms tts
export def nutts [
    text?:string # text to speek
    service?:string # service voice is from
    voice?:string # voice ID for TTS
    --output(-o):string = "output" #output filename
] {
  let text = get-input $in $text
  # decode text
  let detext = $text | url decode

  let service = if ($service | is-empty) {
    nutts list 
    | columns 
    | input list -f (echo-g "Select service: ")
    } else {
      $service
    }

  let voice = if ($voice | is-empty) {
    nutts list 
    | get $service
    | get voices.vid
    | input list -f (echo-g "Select voice: ")
    } else {
      $voice
    } 
  
  # route based on service
  match ($service | str downcase) {
      audiourl => { audiourl $voice $detext },
      tiktok => { weilnet $voice $detext },
      uberduck => { uberduck $voice $detext },
      _ => { lazypy $voice $service $detext }
  }
  | get audioUrl 
  | parse "data:audio/mp3;base64,{audio}" 
  | get audio.0 
  | decode base64 
  | save -f $"($output).mp3"
}

#seach google contact info
#
# Usage example:
# search-contacts "John" --count 5
# search-contacts "example.com" --fields "names,emailAddresses"
@category apis
@search-terms google contacts
export def gg-contacts [
    search_term: string   # The term to search for in contacts
    --count(-c): int = 10 # Number of results to return (default 10)
    --fields(-f): string = "names,emailAddresses,phoneNumbers"  # Fields to include
] {
    let oauth_token = $env.MY_ENV_VARS.api_keys.google.contacts

    let url = {
        scheme: "https",
        host: "people.googleapis.com",
        path: "/v1/people:searchContacts",
        params: {
            query: ($search_term | url encode),
            readMask: $fields,
            pageSize: $count
        }
    } | url join

    let response = http get $url -H [Authorization $"Bearer ($oauth_token)"] -H [Accept application/json] -e
    
    if ($response | get -i results | is-empty) {
      if ($response.error.status == "UNAUTHENTICATED") {
        print (echo-g "get Access token at https://bit.ly/3DMItbs and replace value in $env.MY_ENV_VARS.api_keys.google.contacts") 
      }
      return-error $"code ($response.error.code)\n($response.error.message)\nstatus: ($response.error.status)"
    }
    
    $response.results 
    | each {|p| 
        {
          name: $p.person.names.displayName.0, 
          phone: (try {$p.person.phoneNumbers.value.0} catch {""}), 
          email: ( try {$p.person.emailAddresses.value.0} catch {""})
        }
      }
}
