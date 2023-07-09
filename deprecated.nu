#search for anime
export def grep-anime [search] {
  let result = (grep -ihHn $search ~/Dropbox/Directorios/anime*.txt ~/Dropbox/Directorios/torrent*.txt ~/Dropbox/Directorios/downloads*.txt 
    | lines 
    | parse "{file}:{line}:{match}"
    | update file {|f|
         $f 
         | get file 
         | split row '/' 
         | last
      }
    | str trim
    | find -v "/"
    | rename "source file" "line number"
  )

  let found = ($result | get match | parse "{size} {file}")

  $result | reject match | merge $found
}

#search for manga
export def grep-manga [search] {
  let result = ( grep -ihHn $search ~/Dropbox/Directorios/manga*.txt
    | lines 
    | parse "{file}:{line}:{match}"
    | update file {|f|
         $f 
         | get file 
         | split row '/' 
         | last
      }
    | str trim
    | find -v "/"
    | rename "source file" "line number"
  )

  let found = ($result | get match | parse "{size} {file}")

  $result | reject match | merge $found
}

#search for series
export def grep-series [search:string,season?:int] {
  let result = (grep -ihHn $search ~/Dropbox/Directorios/series*.txt ~/Dropbox/Directorios/torrent*.txt
      | lines 
      | parse "{file}:{line}:{match}"
      | update file {|f|
           $f 
           | get file 
           | split row '/' 
           | last
       }
      | str trim
      | find -v "/"
      | rename "source file" "line number"
  )

  let result = (
    if ($result | is-column column4) {
      $result | reject column4
    } else {
      $result
    }
  )

  let found = ($result | get match | into string | parse "{size} {file}")

  let S = if ($season | is-empty) {
      ""
    } else {
      $season | into string | str lpad -l 2 -c '0'
  }

  $result | reject match | merge $found | find -i $"s($S)" 
}

#umount all drives (lsblk)
def umall [user? = "kira"] {
  lsblk 
  | lines 
  | drop nth 0 
  | parse "{rest} /{mountpoint}" 
  | reject rest 
  | find -i $"media/($user)" 
  | update mountpoint {|f| 
      build-string "/" $f.mountpoint
  }
  | get mountpoint 
  | each {|drive| 
      echo $"umounting ($drive)..."
      umount $drive
  }
}

#get devices connected to network
def get-devices [
  device? #wifi or lan
] {

  let device = if ($device | empty?) {"wlo1"} else {$device}
  let ipinfo = (ip -json add 
    | from json 
    | where ifname =~ $"($device)" 
    | select addr_info 
    | flatten 
    | find -v inet6 
    | flatten 
    | get local prefixlen 
    | flatten 
    | str join '/' 
    | str replace '(?P<nums>\d+/)' '0/'
  )

  let nmap_output = (sudo nmap -sn $ipinfo --max-parallelism 10)

  let ips = ($nmap_output 
    | lines 
    | find report 
    | split row ' ' 
    | find --regex '(?P<nums>\d+)' 
    | drop 
    | str replace -s '(' '' 
    | str replace -s ')' '' 
    | wrap ip
  )
  
  let macs_n_names = ($nmap_output | lines | find MAC | split row ': ' | find '(')
  let macs = ($macs_n_names | split row '('  | find -v ')' | str replace ' ' '' | wrap mac)
  let names = ($macs_n_names | split row '(' | find ')' | str replace -s ')' '' | wrap name)

  let devices = ( [$ips $macs $names] 
    | reduce {|it, acc| 
        $acc | merge { $it }
      }
  )

  let known_devices = (open '~/Yandex.Disk/Backups/linux/known_devices.csv')
  let known_macs = ($known_devices | get mac | str upcase)

  let known = ($devices | each {any? $it.mac in $known_macs} | wrap known)

  let devices = ($devices | merge {$known})

  let aliases = ($devices | each {|row| 
    if $row.known {
      $known_devices | find $row.mac | get alias
    } else {
      " "
    }
  } | flatten | wrap alias
  )
   
  $devices | merge {$aliases}
}

#get bitly short link
export def mbitly [longurl] {
  if ($longurl | is-empty) {
    echo-r "no url provided"
  } else {
    let bitly_credential = open ([$env.MY_ENV_VARS.credentials "bitly_token.json"] | path join)
    let Accesstoken = ($bitly_credential | get token)
    let username = ($bitly_credential | get username)
    
    let url = $"https://api-ssl.bitly.com/v3/shorten?access_token=($Accesstoken)&login=($username)&longUrl=($longurl)"
    let shorturl = (fetch $url | get data | get url)

    $shorturl | copy
    echo-g $"($shorturl) copied to clipboard!"
  }
}

#sin function
export def "math sin" [ ] {
    each {|x| "s(" + $"($x)" + ")\n" | bc -l | into decimal }
}

#cos function
export def "math cos" [ ] {
    each {|x| "c(" + $"($x)" + ")\n" | bc -l | into decimal }
}

#natural log function
export def "math ln" [ ] {
    each {|x| "l(" + $"($x)" + ")\n" | bc -l | into decimal }
}

## special characters (nerd fonts)
# e0a0-3
# e0b0-9
# e0ba-f
# e0c0-8
# e0ca
# e0cc-f
# e0d0-4
# "❱ "

## colors 
# 345eeb



# Weather Script based on IP Address 
# - Weather using dark weather api
# - Air polution condition using airvisual api
# - Street address using google maps api
# - Version 3.0
export def-env weatherds [--home(-h),--ubb(-b)] {
    if not $home {
        if not $ubb {
            get_weather (get_location)
        } else {
            get_weather (get_location -b)
        }
    } else {
        get_weather (get_location -h)
    }
} 

# Get weather for right command prompt
export def-env get_weather_by_interval [INTERVAL_WEATHER:duration] {
    let weather_runtime_file = (($env.HOME) | path join .weather_runtime_file.json)
    
    if ($weather_runtime_file | path exists) {
        let last_runtime_data = (open $weather_runtime_file)

        if not $env.NETWORK.status {
            $last_runtime_data | get weather    
        } else {    
            let LAST_WEATHER_TIME = ($last_runtime_data | get last_weather_time)
    
            if ($LAST_WEATHER_TIME | into datetime) + ($INTERVAL_WEATHER | into duration) < (date now) {
                let WEATHER = (get_weather_for_prompt (get_location))

                if $WEATHER.mystatus {
                    let NEW_WEATHER_TIME = (date now | date format '%Y-%m-%d %H:%M:%S %z')
            
                    $last_runtime_data 
                    | upsert weather $"($WEATHER.Icon) ($WEATHER.Temperature)" 
                    | upsert weather_text $"($WEATHER.Condition) ($WEATHER.Temperature)" 
                    | upsert last_weather_time $NEW_WEATHER_TIME 
                    | save -f $weather_runtime_file
    
                    $"($WEATHER.Icon) ($WEATHER.Temperature)"
                } else {
                    $last_runtime_data | get weather
                }
            } else {
                $last_runtime_data | get weather
            }
        }
    } else {
        let WEATHER = (get_weather_for_prompt (get_location))
        let LAST_WEATHER_TIME = (date now | date format '%Y-%m-%d %H:%M:%S %z') 
    
        let WEATHER_DATA = {
            "weather": ($WEATHER)
            "last_weather_time": ($LAST_WEATHER_TIME)
        } 
    
        $WEATHER_DATA | save -f $weather_runtime_file
        $WEATHER
    }
}

# location functions thanks to https://github.com/nushell/nu_scripts/tree/main/weather
def locations [] {
    [
        [location city_column state_column country_column lat_column lon_column];
        ["http://ip-api.com/json/" city region countryCode lat lon]
        ["https://ipapi.co/json/" city region_code country_code latitude longitude]
        ["https://ipwhois.app/json/" city region country_code  latitude longitude]
    ]
}

def get_location [--home(-h),--ubb(-b)] {
    let wifi = (iwgetid -r)
    let online = ( 
        locations 
        | each {|url| 
            check-link ($url | get location) 2
          } 
        | wrap online
    )

    let table = (locations | merge $online | find true)

    # if ip address in your home isn't precise, you can force a location
    if ($wifi =~ $env.MY_ENV_VARS.home_wifi) or ($table | length) == 0 or $home { 
        "-36.877568,-73.148715" 
    } else if $ubb or ($wifi =~ "wifi-ubb") {
        "-36.821795,-73.014665" 
    } else { 
        let loc_json = (http get ($table | select 0).0.location)
        if ($loc_json | is-column lat) {
            $"($loc_json.lat),($loc_json.lon)"
        } else {
            $"($loc_json.latitude),($loc_json.longitude)" 
        } 
    }
}

# dark sky
def fetch_api [loc] {
    let apiKey = (
        open-credential -u ([$env.MY_ENV_VARS.credentials "credentials.dark_sky.json.asc"] 
            | path join) 
        | get api_key
    )

    let options = "?lang=en&units=si&exclude=minutely,hourly,flags"

    let url = $"https://api.darksky.nett/forecast/($apiKey)/($loc)($options)"
    
    let response = (
        try {
            http get $url | upsert mystatus true
        } catch {
            {"mystatus": false}
        }
    )

    return $response
}

# street address
def get_address [loc] {
    let mapsAPIkey = (
        open-credential -u ([$env.MY_ENV_VARS.credentials "googleAPIkeys.json.asc"] 
            | path join) 
        | get general
    )
    let url = $"https://maps.googleapis.com/maps/api/geocode/json?latlng=($loc)&sensor=true&key=($mapsAPIkey)"

    http get $url
    | get results
    | get 0
    | get formatted_address

}

# wind description (adjust to your liking)
def desc_wind [wind] {
    if $wind < 30 { 
        "Normal" 
    } else if $wind < 50 { 
        "Moderate" 
    } else if $wind < 60 { 
        "Strong" 
    } else { 
        "Very Strong" 
    }
}

# uv description (standard)
def uv_class [uvIndex] {
    if $uvIndex < 2.9 { 
        "Low" 
    } else if $uvIndex < 5.9 { 
        "Moderate" 
    } else if $uvIndex < 7.9 { 
        "High"
    } else if $uvIndex < 10.9 { 
        "Very High" 
    } else { 
        "Extreme" 
    }
}

# air pollution
def get_airCond [loc] {
    let apiKey = (
        open-credential -u ([$env.MY_ENV_VARS.credentials "credentials.air_visual.json.asc"] 
            | path join) 
        | get api_key
    )
    let lat = (echo $loc | split row "," | get 0)
    let lon = (echo $loc | split row "," | get 1)
    let url = $"https://api.airvisual.com/v2/nearest_city?lat=($lat)&lon=($lon)&key=($apiKey)"
    let aqius = ((http get $url).data.current.pollution.aqius | into int)

    # clasification (standard)
    if $aqius < 51 { 
        "Good" 
    } else if $aqius < 101 { 
        "Moderate" 
    } else if $aqius < 151 { 
        "Unhealthy for some" 
    } else if $aqius < 201 { 
        "Unhealthy" 
    } else if $aqius < 301 { 
        "Very unhealthy" 
    } else { 
        "Hazardous" 
    }
}

# parse all the information
def get_weather [loc] {
    let response = (fetch_api $loc)
    let address = (get_address $loc)
    let air_cond = (get_airCond $loc)

    ## Current conditions
    let cond = $response.currently.summary
    let temp = $response.currently.temperature
    let wind = $response.currently.windSpeed * 3.6 
    let humi = $response.currently.humidity * 100
    let uvIndex = $response.currently.uvIndex
    let suntimes = ($response.daily.data 
        | select sunriseTime sunsetTime 
        | select 0 
        | update cells {|f| 
            $f 
            | into string 
            | into datetime -o -4 
            | into string
          }
    )
    
    let sunrise = ($suntimes | get sunriseTime | get 0 | split row ' ' | get 3)
    let sunset = ($suntimes | get sunsetTime | get 0 | split row ' ' | get 3)
    let vientos = (desc_wind $wind)
    let uvClass = (uv_class $uvIndex)
    
    let Vientos = $"($vientos) \(($wind | into string -d 2) Km/h\)"
    let humedad = $"($humi)%"
    let temperature = $"($temp)°C"

    let current = {
        "Condition": ($cond)
        Temperature: ($temperature)
        Humidity: ($humedad)
        Wind: ($Vientos)
        "UV Index": ($uvClass)
        "Air condition": ($air_cond)
        Sunrise: ($sunrise)
        Sunset: ($sunset)
    }  

    ## Forecast
    let forecast = ($response.daily.data 
        | select summary temperatureMin temperatureMax windSpeed humidity precipProbability precipIntensity uvIndex 
        | update windSpeed {|f| $f.windSpeed * 3.6} 
        | update precipIntensity {|f| $f.precipIntensity * 24} 
        | update precipProbability {|f| $f.precipProbability * 100} 
        | update humidity {|f| $f.humidity * 100} 
        | update uvIndex {|f| uv_class $f.uvIndex} 
        | update windSpeed {|f| $"(desc_wind $f.windSpeed) \(($f.windSpeed | into string -d 2)\)"} 
        | rename Summary "T° min (°C)" "T° max (°C)" "Wind Speed (Km/h)" "Humidity (%)" "Precip. Prob. (%)" "Precip. Intensity (mm)"
    ) 


    ## plots
    ($response.daily.data 
        | select windSpeed 
        | update windSpeed {|f| $f.windSpeed * 3.6} 
        | rename "Wind Speed (Km/h)"
    ) 
    | gnu-plot
    
    ($forecast | select "Humidity (%)") | gnu-plot
    ($forecast | select "Precip. Intensity (mm)") | gnu-plot
    ($forecast | select "Precip. Prob. (%)") | gnu-plot
    ($forecast | select "T° max (°C)") | gnu-plot
    ($forecast | select "T° min (°C)") | gnu-plot

    # ($forecast | select "T° min (°C)") | rename tmin | save tmin.csv
    # rush plot --y tmin tmin.csv

    ## forecast
    echo $"Forecast: ($response.daily.summary)"
    echo $forecast

    ## current
    echo $"Current conditions: ($address)"
    echo $current  
}

def get_weather_for_prompt [loc] {
    
    let response = (fetch_api $loc)

    if not $response.mystatus {
        return $response
    }

    ## current conditions
    let cond = $response.currently.summary
    let temp = $response.currently.temperature
    let temperature = $"($temp)°C"
    let icon = (get_weather_icon $response.currently.icon)

    let current = {
        Condition: ($cond)
        Temperature: ($temperature)
        Icon: ($icon)
    }

    # echo $"($current.Icon) ($current.Temperature)"
    return ($current | upsert mystatus $response.mystatus)
}

def get_weather_icon [icon: string] {
    switch $icon {
     "clear-day": {|| (char -u f185)},
     "clear-night": {|| (char -u f186)},
     "rain": {|| (char -u e318)},
     "snow": {|| (char -u fa97)},
     "sleet": {|| (char -u e3ad)},
     "wind": {|| (char -u fa9c)},
     "fog": {|| (char -u fa90)},
     "cloudy": {|| (char -u e312)},
     "partly-cloudy-day": {|| (char -u e21d)},
     "partly-cloudy-night": {|| (char -u e226)},
     "hail": {|| (char -u fa91)},
     "thunderstorm": {|| (char -u e31d)},
     "tornado": {|| (char -u e351)}
    }
}


# let files = (ls $"($env.MY_ENV_VARS.credentials)/credentials*" | get name)

# let apis = (
#     $files
#     | path parse 
#     | get stem
#     | parse "{start}.{app}.{rest}"
#     | get app
# )

# mut $api_keys = {}

# for -n file in $files {
#     let item = ($apis | get $file.index)
#     let content = (open-credential -u ([$env.MY_ENV_VARS.credentials $file.item] | path join) )
#     $api_keys = ($api_keys | upsert $item $content)
# }

# let-env MY_ENV_VARS = ($env.MY_ENV_VARS | upsert api_keys $api_keys)
