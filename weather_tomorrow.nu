# Weather Script based on IP Address 
# - Weather using tomorrow.io api
# - Air polution condition using airvisual api (deprecated)
# - Street address using google maps api
# - Version 2.0
export def --env my-weather [
    --coordinates(-c):string    #lat,lng of location of interest
    --address(-a):string        #address of interest, it can be only city and country
    --home(-h)
    --ubb(-b)
    --no_plot(-n)
    --conditions
    --forecast-today
    --forecast-week
] {
    let loc_raw = match [$home,$ubb,($coordinates | is-not-empty),($address | is-not-empty)] {
        [true,false,false,false] => { get_location -h },
        [false,true,false,false] => { get_location -b },
        [false,false,true,false] => { $coordinates },
        [false,false,false,true] => { maps loc-from-address $address | get 0 | get lat lng | str join "," },
        [false,false,false,false] => { get_location },
        _ => {return-error "flag combination not allowed!"}
    }
    
    let loc = if ($loc_raw | describe) =~ "record" { $loc_raw.coords } else { $loc_raw }
    get_weather $loc --plot=(not $no_plot) --conditions=$conditions --forecast-today=$forecast_today --forecast-week=$forecast_week
} 

# Fast file-only weather reader for shell prompt
export def get-weather-prompt [
    --file(-f): string
] {
    let weather_runtime_file = if ($file | is-not-empty) { $file } else { ($env.HOME | path join ".weather_runtime_file.json") }
    if not ($weather_runtime_file | path exists) {
        return { weather: "⛅ --°C", color: "#ffffff" }
    }

    try {
        let data = open $weather_runtime_file
        let w = $data.weather
        let weather_str = if ($w | describe) =~ "record" {
            $"($w.Icon) ($w.Temperature)"
        } else {
            ($w | into string)
        }
        let color = try { $data.network.color } catch { "#ffffff" }
        {
            weather: $weather_str,
            color: (if ($color | is-not-empty) { $color } else { "#ffffff" })
        }
    } catch {
        { weather: "⛅ --°C", color: "#ffffff" }
    }
}

# Get weather for right command prompt and system widgets
export def --env get_weather_by_interval [
    interval_weather:duration, 
    --address(-a):string, 
    --file(-f):string
] {
    let weather_runtime_file = if ($file | is-not-empty) { $file } else { ($env.HOME | path join ".weather_runtime_file.json") }
    
    if ($weather_runtime_file | path exists) {
        let last_runtime_data = open $weather_runtime_file
        let LAST_WEATHER_TIME = try { $last_runtime_data | get last_weather_time } catch { "1970-01-01 00:00:00 +00:00" }
        let not_update = try {
            (($LAST_WEATHER_TIME | into datetime) + ($interval_weather | into duration)) >= (date now)
        } catch {
            false
        }

        # Check network connectivity when cache expired
        let net_status = if not $not_update {
            try {
                http get https://www.google.com | ignore; true
            } catch {
                false
            }
        } else {
            try { $last_runtime_data.network.status } catch { true }
        }
        let net_color = if $net_status { '#00ff00' } else { '#ffffff' }

        # Sync MY_ENV_VARS if present
        if ("MY_ENV_VARS" in ($env | columns)) and ("NETWORK" in ($env.MY_ENV_VARS | columns)) {
            $env.MY_ENV_VARS.NETWORK.status = $net_status
            $env.MY_ENV_VARS.NETWORK.color = $net_color
        }

        # If not updating or offline, return cached weather (ensuring location/network are preserved/upserted)
        if not $net_status or $not_update {
            let w = try { $last_runtime_data | get weather } catch { "⛅ --°C" }
            if not ("location" in ($last_runtime_data | columns)) or not ("network" in ($last_runtime_data | columns)) {
                let existing_loc = try {
                    $last_runtime_data.location
                } catch {
                    let loc_res = get_location
                    { name: $loc_res.name, latitude: $loc_res.latitude, longitude: $loc_res.longitude }
                }
                $last_runtime_data
                | upsert location $existing_loc
                | upsert network { status: $net_status, color: $net_color }
                | save -f $weather_runtime_file
            }
            return (if ($w | describe) =~ "record" { $"($w.Icon) ($w.Temperature)" } else { $w })
        } 
    
        let loc = if ($address | is-not-empty) {
            let coords = (maps loc-from-address $address | get 0 | get lat lng | str join ",")
            let parts = ($coords | split row ",")
            { coords: $coords, name: $address, latitude: ($parts.0 | into float), longitude: ($parts.1 | into float) }
        } else {
            get_location
        }

        let loc_rec = if ($loc | describe) =~ "record" {
            $loc
        } else {
            let parts = ($loc | into string | split row ",")
            let lat = try { $parts.0 | into float } catch { 0.0 }
            let lon = try { $parts.1 | into float } catch { 0.0 }
            { coords: ($loc | into string), name: "Unknown", latitude: $lat, longitude: $lon }
        }

        let WEATHER = get_weather_for_prompt $loc_rec.coords

        if not $WEATHER.mystatus {
            let w = try { $last_runtime_data | get weather } catch { "⛅ --°C" }
            $last_runtime_data
            | upsert network { status: $net_status, color: $net_color }
            | save -f $weather_runtime_file
            return (if ($w | describe) =~ "record" { $"($w.Icon) ($w.Temperature)" } else { $w })
        }
        
        let NEW_WEATHER_TIME = date now | format date '%Y-%m-%d %H:%M:%S %z'
        let formatted_weather = $"($WEATHER.Icon) ($WEATHER.Temperature)"
           
        $last_runtime_data 
        | upsert weather $formatted_weather 
        | upsert weather_text $"($WEATHER.Condition) ($WEATHER.Temperature)" 
        | upsert last_weather_time $NEW_WEATHER_TIME 
        | upsert sunrise $WEATHER.sunrise
        | upsert sunset $WEATHER.sunset
        | upsert location {
            name: $loc_rec.name,
            latitude: $loc_rec.latitude,
            longitude: $loc_rec.longitude
        }
        | upsert network {
            status: $net_status,
            color: $net_color
        }
        | save -f $weather_runtime_file
    
        return $formatted_weather
    } else {
        # File does not exist yet (cold start)
        let net_status = try {
            http get https://www.google.com | ignore; true
        } catch {
            false
        }
        let net_color = if $net_status { '#00ff00' } else { '#ffffff' }

        if ("MY_ENV_VARS" in ($env | columns)) and ("NETWORK" in ($env.MY_ENV_VARS | columns)) {
            $env.MY_ENV_VARS.NETWORK.status = $net_status
            $env.MY_ENV_VARS.NETWORK.color = $net_color
        }

        let loc = if ($address | is-not-empty) {
            let coords = (maps loc-from-address $address | get 0 | get lat lng | str join ",")
            let parts = ($coords | split row ",")
            { coords: $coords, name: $address, latitude: ($parts.0 | into float), longitude: ($parts.1 | into float) }
        } else {
            get_location
        }

        let loc_rec = if ($loc | describe) =~ "record" {
            $loc
        } else {
            let parts = ($loc | into string | split row ",")
            let lat = try { $parts.0 | into float } catch { 0.0 }
            let lon = try { $parts.1 | into float } catch { 0.0 }
            { coords: ($loc | into string), name: "Unknown", latitude: $lat, longitude: $lon }
        }

        let WEATHER = get_weather_for_prompt $loc_rec.coords

        if not $WEATHER.mystatus {
            return $WEATHER # Return error if initial fetch fails
        }

        let LAST_WEATHER_TIME = date now | format date '%Y-%m-%d %H:%M:%S %z'
        let formatted_weather = $"($WEATHER.Icon) ($WEATHER.Temperature)"
    
        let WEATHER_DATA = {
            "weather": $formatted_weather,
            "weather_text": $"($WEATHER.Condition) ($WEATHER.Temperature)",
            "last_weather_time": ($LAST_WEATHER_TIME),
            "sunrise": ($WEATHER.sunrise),
            "sunset": ($WEATHER.sunset),
            "location": {
                "name": $loc_rec.name,
                "latitude": $loc_rec.latitude,
                "longitude": $loc_rec.longitude
            },
            "network": {
                "status": $net_status,
                "color": $net_color
            }
        } 
    
        $WEATHER_DATA | save -f $weather_runtime_file
        return $formatted_weather
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

export def get_location [--home(-h),--ubb(-b)] {
    let wifi = try { wifi-info -w } catch { "" }
    
    # Read previous location from runtime file if available (for offline fallback)
    let runtime_path = ($env.HOME | path join ".weather_runtime_file.json")
    let last_loc = if ($runtime_path | path exists) {
        try { open $runtime_path | get location } catch { null }
    } else {
        null
    }

    let home_wifi_name = try { $env.MY_ENV_VARS.home_wifi } catch { null }
    let work_wifi_name = try { $env.MY_ENV_VARS.work_wifi } catch { null }
    let home_coords = try { $env.MY_ENV_VARS.home_loc } catch { null }
    let work_coords = try { $env.MY_ENV_VARS.work_loc } catch { null }

    let is_home = ($home or (($home_wifi_name != null) and ($wifi | is-not-empty) and ($wifi like $home_wifi_name)))
    let is_work = ($ubb or (($work_wifi_name != null) and ($wifi | is-not-empty) and ($wifi like $work_wifi_name)))

    # Closure for lazy IP lookup
    let fetch_ip = {||
        let online = locations 
            | each {|url| 
                check-link ($url | get location) 2sec
              } 
            | wrap online
        
        let table = locations | merge $online | find true
        if ($table | length) > 0 {
            let prov = ($table | first)
            try {
                let res = (http get $prov.location)
                let city = (try { $res | get ($prov.city_column) } catch { "" })
                let lat = (if ($res | is-column lat) { $res.lat } else { $res.latitude })
                let lon = (if ($res | is-column lon) { $res.lon } else { $res.longitude })
                {
                    city: ($city | into string),
                    coords: $"($lat),($lon)",
                    lat: ($lat | into float),
                    lon: ($lon | into float)
                }
            } catch {
                null
            }
        } else {
            null
        }
    }

    if ($is_home and ($home_coords != null)) {
        let city = if ($last_loc != null and ($last_loc.name | is-not-empty) and ($last_loc.name != "Unknown")) {
            $last_loc.name
        } else {
            let ip = (do $fetch_ip)
            if ($ip != null and ($ip.city | is-not-empty)) { $ip.city } else { "Unknown" }
        }
        let parts = ($home_coords | split row ",")
        {
            coords: $home_coords,
            name: $city,
            latitude: ($parts.0 | into float),
            longitude: ($parts.1 | into float)
        }
    } else if ($is_work and ($work_coords != null)) {
        let city = if ($last_loc != null and ($last_loc.name | is-not-empty) and ($last_loc.name != "Unknown")) {
            $last_loc.name
        } else {
            let ip = (do $fetch_ip)
            if ($ip != null and ($ip.city | is-not-empty)) { $ip.city } else { "Unknown" }
        }
        let parts = ($work_coords | split row ",")
        {
            coords: $work_coords,
            name: $city,
            latitude: ($parts.0 | into float),
            longitude: ($parts.1 | into float)
        }
    } else {
        # Neither home nor work: query IP-API
        let ip_info = (do $fetch_ip)
        if ($ip_info != null) {
            {
                coords: $ip_info.coords,
                name: (if ($ip_info.city | is-not-empty) { $ip_info.city } else { "Unknown" }),
                latitude: $ip_info.lat,
                longitude: $ip_info.lon
            }
        } else if ($last_loc != null) {
            {
                coords: $"($last_loc.latitude),($last_loc.longitude)",
                name: (if ($last_loc.name | is-not-empty) { $last_loc.name } else { "Unknown" }),
                latitude: ($last_loc.latitude | into float),
                longitude: ($last_loc.longitude | into float)
            }
        } else if ($home_coords != null) {
            let parts = ($home_coords | split row ",")
            {
                coords: $home_coords,
                name: "Unknown",
                latitude: ($parts.0 | into float),
                longitude: ($parts.1 | into float)
            }
        } else {
            {
                coords: "0,0",
                name: "Unknown",
                latitude: 0.0,
                longitude: 0.0
            }
        }
    }
}

# tomorrow.io
def fetch_api [loc] {
    let apiKey = get-api-key "tomorrow_io.api_key"

    let units = "metric"
    mut response = {}

    let url_request = {
      scheme: "https",
      host: "api.tomorrow.io",
      path: "/v4/weather/forecast",
      params: {
          location: $loc,
          units: $units,
          apikey: $apiKey
      }
    } | url join
    
    let forecast = http get $url_request -fe
    # http get $url_request | save -f b.json
    # $forecast | save -f a.json
    let mystatus = if $forecast.status == 200 { true } else { false }
    let forecast = $forecast | get body | upsert mystatus $mystatus
    
    if not $mystatus {
        return $forecast
    }

    let url_request = {
      scheme: "https",
      host: "api.tomorrow.io",
      path: "/v4/weather/realtime",
      params: {
          location: $loc,
          units: $units,
          apikey: $apiKey
      }
    } | url join

    let realtime = http get $url_request -fe
    let mystatus = if $realtime.status == 200 { true } else { false }
    let realtime = $realtime | get body | upsert mystatus $mystatus
        
    if not $mystatus {
        return $realtime
    }

    $response.forecast = $forecast | reject mystatus
    $response.realtime = $realtime | reject mystatus
    $response.mystatus = true

    return $response
}

# street address
def get_address [loc] {
    let mapsAPIkey = get-api-key "google.general"

    {
      scheme: "https",
      host: "maps.googleapis.com",
      path: "/maps/api/geocode/json",
      params: {
          latlng: $loc,
          sensor: "true",
          key: $mapsAPIkey
      }
    }
    | url join
    | http get $in
    | get results
    | get 0
    | get formatted_address
}

# wind description (adjust to your liking)
def desc_wind [wind] {
    if $wind < 25 { 
        "Normal" 
    } else if $wind < 40 { 
        "Moderate" 
    } else if $wind < 50 { 
        "Strong" 
    } else { 
        "Very Strong" 
    }
}

# uv description (standard)
def uv_class [uvIndex:number] {
    if ($uvIndex | is-empty) {
        return "no data"
    }
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
    let apikey = get-api-key "air_visual.api_key"

    let aqius = {
          scheme: "https",
          host: "api.airvisual.com",
          path: "/v2/nearest_city",
          params: {
              lat: ($loc | split row "," | get 0),
              lon: ($loc | split row "," | get 1),
              key: $apikey
          }
        } 
        | url join
        | http get $in 
        | get data.current.pollution.aqius
        | into int


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
def get_weather [
    loc, 
    --plot = true
    --conditions
    --forecast-today
    --forecast-week
] {
    let flag_count = [$conditions, $forecast_today, $forecast_week] | where $it == true | length
    if $flag_count > 1 {
        return-error "Flags --conditions, --forecast-today, and --forecast-week are mutually exclusive."
    }
    
    let is_pure_data = $flag_count == 1
    let actual_plot = if $is_pure_data { false } else { $plot }

    let response = fetch_api $loc

    if not $response.mystatus {
        return-error $"something went wrong with the call to the weather api.\n($response.type)\n($response.message)"
    }

    let address = get_address $loc
    let air_cond = try {
            get_airCond $loc
        } catch {
            "no data"
        }
    

    ## Current conditions
    let cond = get_weather_description_from_code ($response.realtime.data.values.weatherCode | into string)
    let temp = $response.realtime.data.values.temperature
    let wind = $response.realtime.data.values.windSpeed * 3.6 
    let humi = $response.realtime.data.values.humidity 
    let uvIndex = $response.realtime.data.values.uvIndex

    let sunrise = $response.forecast.timelines.daily 
        | get 0 
        | get values 
        | get sunriseTime 
        | into datetime
        | date to-timezone local
        | format date "%H:%M:%S"
    

    let sunset = $response.forecast.timelines.daily 
        | get 0 
        | get values 
        | get sunsetTime 
        | into datetime 
        | date to-timezone local
        | format date "%H:%M:%S"
    

    let vientos = desc_wind $wind
    let uvClass = uv_class $uvIndex
    
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
    let days = $response.forecast.timelines.daily 
        | select time 
        | each {|row|
            $row.time 
            | into datetime -o -4 
            | format date "%Y-%m-%d"
          }
        | wrap "date"
    

    mut data = []
    
    for i in 0..(($days | length) - 1) {
        $data = ($data | append ($response.forecast.timelines.daily | get values | get $i | select weatherCodeMax temperatureMin temperatureMax windSpeedAvg humidityAvg precipitationProbabilityAvg rainIntensityAvg uvIndexAvg? | transpose | transpose -r))
    }

    mut forecast = $days | merge $data
    
    let windSpeedAvg = $forecast 
        | select windSpeedAvg 
        | update windSpeedAvg {|f| 
            $f.windSpeedAvg * 3.6
          }
        | rename windSpeed
    
     
        # | update precipitationProbabilityAvg {|f| $f.precipitationProbabilityAvg * 100} 
    
    $forecast = (
        $forecast 
        | update windSpeedAvg {|f| $f.windSpeedAvg * 3.6} 
        | update rainIntensityAvg {|f| $f.rainIntensityAvg * 24}
        | default 0 uvIndexAvg
        | update uvIndexAvg {|f| uv_class $f.uvIndexAvg}
        | update weatherCodeMax {|f| get_weather_description_from_code ($f.weatherCodeMax | into string)} 
        | update windSpeedAvg {|f| $"(desc_wind $f.windSpeedAvg) \(($f.windSpeedAvg | into string -d 2)\)"} 
        | reject index?
        | rename Date Summary "T° min (°C)" "T° max (°C)" "Wind Speed (Km/h)" "Humidity (%)" "Precip. Prob. (%)" "Precip. Intensity (mm)" "UV Index"
    )


    ## plots
    if $actual_plot {
        let canIplot = try {[1 2] | plot;true} catch {false}

        if $canIplot {
            print ($data | select uvIndexAvg | default 0 uvIndexAvg | rename uvIndex | plot-table --title "UV Index" --width 150)
            print (echo "\n")

            print ($windSpeedAvg | plot-table --title "Wind Speed" --width 150)
            print (echo "\n")

            print (($forecast | select "Humidity (%)") | plot-table --title "Humidity" --width 150)
            print (echo "\n")

            print (($forecast | select "Precip. Intensity (mm)") | plot-table --title "Prec. Int." --width 150)
            print (echo "\n")

            print (($forecast | select "Precip. Prob. (%)") | plot-table --title "Prec. Prob" --width 150)
            print (echo "\n")

            let temp_minmax = $forecast | select "T° min (°C)" "T° max (°C)"
            print ($temp_minmax | plot-table --title "T° min vs T° max" --width 150)
            print (echo "\n")
        } else {
            $windSpeedAvg | gnu-plot
            $data | select uvIndexAvg | rename uvIndex | gnu-plot
            ($forecast | select "Humidity (%)") | gnu-plot
            ($forecast | select "Precip. Intensity (mm)") | gnu-plot
            ($forecast | select "Precip. Prob. (%)") | gnu-plot
            ($forecast | select "T° max (°C)") | gnu-plot
            ($forecast | select "T° min (°C)") | gnu-plot
        }
    }
    
    if $conditions {
        return $current
    }
    
    if $forecast_today {
        return ($forecast | get 0)
    }
    
    if $forecast_week {
        return $forecast
    }

    ## forecast
    print ("Forecast for today:")
    print ($forecast | get 0) 

    let forecast_description = try {
            google_ai ($forecast | to json) --select_system "meteorologist" --select_preprompt "5days_forecast" -d true
        } catch {
            ""
        }
    
    
    print ("Forecast for the next 5 days: " + $forecast_description)
    print ($forecast)

    ## current
    print ($"Current conditions: ($address)")
    print ($current)
}

def get_weather_for_prompt [loc] {
    let response = fetch_api $loc

    if not $response.mystatus {
        return $response
    }

    ## current conditions
    let cond = get_weather_description_from_code ($response.realtime.data.values.weatherCode | into string)
    let temp = $response.realtime.data.values.temperature
    let temperature = $"($temp)°C"

    let sunrise = $response.forecast.timelines.daily 
        | get 0 
        | get values 
        | get sunriseTime 
        | into datetime
        | date to-timezone local
        | format date "%H:%M:%S"
    

    let sunset = $response.forecast.timelines.daily 
        | get 0 
        | get values 
        | get sunsetTime 
        | into datetime
        | date to-timezone local
        | format date "%H:%M:%S"
    

    let icon_description = get_icon_description_from_code $response.realtime.data.values.weatherCode $sunrise $sunset
    let icon = get_weather_icon $icon_description

    let current = {
        Condition: ($cond),
        Temperature: ($temperature),
        Icon: ($icon),
        sunrise: ($sunrise),
        sunset: ($sunset)
    }

    # echo $"($current.Icon) ($current.Temperature)"
    return ($current | upsert mystatus $response.mystatus)
}

def get_weather_icon [icon_description: string] {
    match $icon_description {
        "clear-day" => {(char -u f185)},
        "clear-night" => {(char -u f186)},
        "rain" => {(char -u e318)},
        "drizzle" => {(char -u e319)},
        "light-rain" => {(char -u e336)},
        "heavy-rain" => {(char -u e317)},
        "snow" => {(char -u fa97)},
        "light-snow" => {(char -u e31a)},
        "heavy-snow" => {(char -u "1F328")},
        "flurries" => {(char -u e35e)},
        "freezing-drizzle" => {(char -u fb7d)},
        "sleet" => {(char -u e3ad)},
        "wind" => {(char -u fa9c)},
        "fog" => {(char -u e313)},
        "light-fog" => {(char -u f0591)},
        "cloudy" => {(char -u e312)},
        "partly-cloudy-day" => {(char -u e21d)},
        "partly-cloudy-night" => {(char -u e226)},
        "mostly-clear-day" => {(char -u e302)},
        "mostly-clear-night" => {(char -u e32e)},
        "mostly-cloudy-day" => {(char -u e376)},
        "mostly-cloudy-night" => {(char -u e378)},
        "hail" => {(char -u fa91)},
        "thunderstorm" => {(char -u e31d)},
        "tornado" => {(char -u e351)}
    }
}

def get_weather_description_from_code [code: string] {
    open ([$env.MY_ENV_VARS.credentials "tomorrow_weather_codes.json"] | path join)
    | get weatherCode
    | get $code
}

def get_icon_description_from_code [
    code: int
    sunrise
    sunset
] {
    let day = (date now | format date '%H:%M:%S') < $sunset and (date now | format date '%H:%M:%S') > $sunrise

    let icon = match ($code | into string) {
        "1000" => {if $day {"clear-day"} else {"clear-night"}},
        "1100" => {if $day {"mostly-clear-day"} else {"mostly-clear-night"}},
        "1101" => {if $day {"partly-cloudy-day"} else {"partly-cloudy-night"}},       
        "1102" => {if $day {"mostly-cloudy-day"} else {"mostly-cloudy-night"}},     
        "1001" => {"cloudy"},             
        "2000" => {"fog"},                 
        "2100" => {"light-fog"},
        "4000" => {"drizzle"},
        "4001" => {"rain"},
        "4200" => {"light-rain"},          
        "4201" => {"heavy-rain"},          
        "5000" => {"snow"},              
        "5001" => {"flurries"},
        "5100" => {"light-snow"},          
        "5101" => {"heavy-snow"},          
        "6000" => {"freezing-rain"},
        "6001" => {"freezing-rain"},
        "6200" => {"freezing-rain"},
        "6201" => {"freezing-rain"},
        "7000" => {"sleet"},
        "7101" => {"sleet"},
        "7102" => {"sleet"},
        "8000" => {"thunderstorm"}
    }   

    return $icon
}