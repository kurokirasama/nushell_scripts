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
#
#Use ISO standar names for the languages, for example:
#english: en-US
#spanish: es-ES
#italian: it-IT
#swedish: sv-SV
#
#More in: https://en.wikipedia.org/wiki/List_of_ISO_639-1_codes
export def trans [
  ...text:string    #search query
  --from:string     #from which language you are translating (default english)
  --to:string       #to which language you are translating (default spanish)
] {
  let search = if ($text | is-empty) {$in} else {$text}
  if ($search | is-empty) {
    return-error "no search query provided!"
  } 
  let trans_credential = $env.MY_ENV_VARS.api_keys.mymemmory
  let apikey = ($trans_credential | get token)
  let user = ($trans_credential | get username)

  let from = if ($from | is-empty) {"en-US"} else {$from}
  let to = if ($to | is-empty) {"es-ES"} else {$to}

  let to_translate = ($search | str join "%20")

  let url = {
    scheme: "https",
    host: "api.mymemory.translated.net",
    path: "/get",
    params: {
        q: $to_translate,
        langpair: ($from + "%7C" + $to),
        of: "json",
        key: $apikey,
        de: $user
    }
  } | url join
  
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

#get rebrandly short link
export def "rebrandly get" [longurl] {
  if ($longurl | is-empty) {
    return-error "no url provided"
  }

  let credential = $env.MY_ENV_VARS.api_keys.rebrandly
  let api_key = ($credential | get api_key)
    
  let url = "https://api.rebrandly.com/v1/links"
  let content = {"destination": $longurl}

  let response = (http post $url $content -H ["apikey", $api_key] --content-type "application/json" -H ["UserAgent:","UserAgent,curl/7.68.0"])
  let shorturl = ($response | get shortUrl)

  $shorturl | copy
  print (echo-g $"($shorturl) copied to clipboard!")
} 

#list rebrandly last 25 short links
export def "rebrandly list" [longurl="www.google.com"] {
  if ($longurl | is-empty) {
    return-error "no url provided"
  } 

  let credential = $env.MY_ENV_VARS.api_keys.rebrandly
  let apikey = ($credential | get api_key)
    
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
export def "maps eta" [
  origin:string       #origin gps coordinates or address
  destination:string  #destination gps coordinates or address
  --mode = "driving"  #driving mode (driving, transit, walking)
  --avoid             #whether to avoid highways (default:false)
] {
  let apikey = $env.MY_ENV_VARS.api_keys.google.general

  let origin_address = (
    if $origin =~ '^(-?\d+\.\d+),(-?\d+\.\d+)$' {
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
    if $destination =~ '^(-?\d+\.\d+),(-?\d+\.\d+)$' {
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

  let url = ("https://maps.googleapis.com/maps/api/directions/json?origin=" + $origin + "&destination=" + $destination + "&mode=" + $mode + "&departure_time=now&key=" + $apikey + $avoid_option)

  let response = (
    {
      scheme: "https",
      host: "maps.googleapis.com",
      path: "/maps/api/geocode/json",
      params: {
        origin: $origin,
        destination: $destination,
        mode: $mode,
        departure_time: "now",
        sensor: "true",
        key: $apikey
      }
    } 
    | url join 
    | str append $avoid_option
    | http get $in
  )

  let distance = $response.routes.legs.0.distance.text.0
  let steps = $response.routes.legs.0.steps
  let duration = $response.routes.legs.0.duration.text.0

  let directions_steps = (
      $steps.0.html_instructions 
      | to text 
      | chat_gpt --select_system html_parser --select_preprompt parse_html 
      | lines 
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
export def "maps loc-from-address" [address] {
  let mapsAPIkey = $env.MY_ENV_VARS.api_keys.google.general
  
  let url = $"https://maps.google.com/maps/api/geocode/json?address=($address)&key=($mapsAPIkey)"

  return (http get $url | get results | get geometry | get location | flatten)
}

#get address from geo-coordinates
export def "maps address-from-loc" [latitude:number,longitude:number] {
  let mapsAPIkey = $env.MY_ENV_VARS.api_keys.google.general
  let url = $"https://maps.googleapis.com/maps/api/geocode/json?latlng=($latitude),($longitude)&key=($mapsAPIkey)"

  let response = (http get $url)

  if $response.status != OK {
    return-error "address not found!"
  } 

  return $response.results.0.formatted_address
}

#clp exchange rates via fixer.io API
#
#Show CLP/CLF,USD,BTC,new_currency exchange
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
export def gg-trans [
  text: string, # The text to translate
  --source(-s): string = "auto", # The source language
  --destination(-d): string = "es", # The destination language
  --list(-l)  # Select destination language from list
] {
  mut dest = ""

  if $list {
    let languages = open ([$env.MY_ENV_VARS.credentials google_translate_languages.json] | path join)
    let selection = (
      $languages
      | columns
      | input list -f (echo-g "Select destination language:")
    )

    $dest = ($languages | get $selection)

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
export def google_search [
  ...query:string
  --number_of_results(-n):int = 5 #number of results to use
  --verbose(-v) #show some debug messages
  --md(-m) #md output instead of table
] {
  let query = if ($query | is-empty) {$in} else {$query} | str join " "

  if ($query | is-empty) {
    return-error "empty query!"
  }

  let apikey = $env.MY_ENV_VARS.api_keys.google.search.apikey
  let cx = $env.MY_ENV_VARS.api_keys.google.search.cx

  if $verbose {print (echo-g $"querying to google search...")}
  let search_result = {
      scheme: "https",
      host: "www.googleapis.com",
      path: "/customsearch/v1",
      params: {
          key: $apikey,
          cx: $cx
          q: ($query | url encode)
      }
    } 
    | url join
    | http get $in 
    | get items 
    | first $number_of_results 
    | select title link displayLink

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

    $content = $content ++ $processed_content
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

#check obsidian server
export def "obs check" [] {
  let apikey = $env.MY_ENV_VARS.api_keys.obsidian.local_rest_apikey
  let host = $env.MY_ENV_VARS.api_keys.obsidian.host
  let port = $env.MY_ENV_VARS.api_keys.obsidian.port
  let certificate = $env.MY_ENV_VARS.api_keys.obsidian.certificate

  let url = {
              "scheme": "https",
              "host": $host,
              "port": $port
            } | url join

  let status = curl -s -X 'GET' $url -H 'accept: application/json' -H $'Authorization: Bearer ($apikey)' --cacert $certificate | from json | get status 

  return {status: $status, apikey: $apikey, host: $host, port: $port, certificate: $certificate}
}

#check obsidian path
export def "obs check-path" [
  v_path:string # path in vault
] {
  let check = obs check

  if $check.status != "OK" {
    return-error "something went wrong with the server!"
  }

  let apikey = $check.apikey
  let host = $check.host
  let port = $check.port
  let certificate = $check.certificate
  let auth_header = $'Authorization: Bearer ($apikey)'

  let url = {
              "scheme": "https",
              "host": $host,
              "port": $port ,
              "path": (["vault" $v_path] | path join)
            } | url join

  let response = curl -sX 'GET' $"($url)/" -H 'accept: application/json' -H $auth_header --cacert $certificate | from json 

  return ($response)
}

#obsidian search on body of notes
#
# mv to http get/post when ready
# let response = https post $url {} --content-type "application/json" -H ["Authorization:", $"Bearer ($apikey)"] --certificate
export def "obs search" [
  ...query    #search query (in title and body)
  --tag(-t):string   #search in tag (use search, in progress)
  --edit(-e)  #edit selected note (??)
  --raw(-r)   #don't use syntax highlight
] {
  if ($query | is-empty) {
    return-error "empty search query!"
  }

  let check = obs check

  if $check.status != "OK" {
    return-error "something went wrong with the server!"
  }

  let apikey = $check.apikey
  let host = $check.host
  let port = $check.port
  let certificate = $check.certificate
  let auth_header = $'Authorization: Bearer ($apikey)'
  let query = $query | str join " "
  mut note = ""

  # search
  if ($tag | is-not-empty) {
    return-error "work in progress!"
  } else {
    let url = {
                "scheme": "https",
                "host": $host,
                "port": $port ,
                "path": "search/simple",
                "query": ("query=" + ($query | url encode) + "&contextLength=100"),
              } | url join

    let response = curl -sX 'POST' $url -H 'accept: application/json' -H $auth_header --cacert $certificate -d '' | from json

    $note = ($response | get filename | input list -f (echo-g "Select note:"))
  }

  if not $edit {
    # show
    let note_url = {
                "scheme": "https",
                "host": $host,
                "port": $port ,
                "path": ("vault/" + ($note | url encode)),
              } | url join
  
    let content = curl -sX 'GET' $note_url -H 'accept: text/markdown' -H $auth_header --cacert $certificate
  
    if $raw {$content} else {$content | glow}
  } else {
    # edit
    return-error "work in progress!"
  }
}

#obsidian create new note
export def "obs create" [
  name:string   # name of the note
  v_path:string # path for the note in vault
  content:string   # content of the note
] {
  let check = obs check

  if $check.status != "OK" {
    return-error "something went wrong with the server!"
  }

  let check_path = obs check-path $v_path

  if ($check_path | get errorCode? | in-not-empty) {
    return-error "path doesn't exists!"
  }

  let apikey = $check.apikey
  let host = $check.host
  let port = $check.port
  let certificate = $check.certificate
  let auth_header = $'Authorization: Bearer ($apikey)'

  let url = {
              "scheme": "https",
              "host": $host,
              "port": $port ,
              "path": (["vault" $v_path $"($name).md"] | path join)
            } | url join

  let response = curl -sX 'PUT' $url -H 'accept: text/markdown' -H $auth_header --cacert $certificate -d $content | from json

  if ($response.message? | is-not-empty) {
    return ($response.message)
  }
}