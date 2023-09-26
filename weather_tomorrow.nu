# Weather Script based on IP Address 
# - Weather using tomorrow.io api
# - Air polution condition using airvisual api
# - Street address using google maps api
# - Version 2.0
export def-env weather [--home(-h),--ubb(-b),--no_plot] {
    if not $home {
        if not $ubb {
            get_weather (get_location) --plot (not $no_plot)
        } else {
            get_weather (get_location -b) --plot (not $no_plot)
        }
    } else {
        get_weather (get_location -h) --plot (not $no_plot)
    }
} 

# Get weather for right command prompt
export def-env get_weather_by_interval [INTERVAL_WEATHER:duration] {
    let weather_runtime_file = (($env.HOME) | path join .weather_runtime_file.json)
    
    if ($weather_runtime_file | path exists) {
        let last_runtime_data = (open $weather_runtime_file)

        if not $env.NETWORK.status {
            return ($last_runtime_data | get weather)
        } else {    
            let LAST_WEATHER_TIME = ($last_runtime_data | get last_weather_time)
    
            if ($LAST_WEATHER_TIME | into datetime) + ($INTERVAL_WEATHER | into duration) < (date now) {
                let WEATHER = (get_weather_for_prompt (get_location))

                if $WEATHER.mystatus {
                    let NEW_WEATHER_TIME = (date now | format date '%Y-%m-%d %H:%M:%S %z')
            
                    $last_runtime_data 
                    | upsert weather $"($WEATHER.Icon) ($WEATHER.Temperature)" 
                    | upsert weather_text $"($WEATHER.Condition) ($WEATHER.Temperature)" 
                    | upsert last_weather_time $NEW_WEATHER_TIME 
                    | save -f $weather_runtime_file
    
                    return $"($WEATHER.Icon) ($WEATHER.Temperature)"
                } else {
                    return ($last_runtime_data | get weather)
                }
            } else {
                return ($last_runtime_data | get weather)
            }
        }
    } else {
        let WEATHER = (get_weather_for_prompt (get_location))
        let LAST_WEATHER_TIME = (date now | format date '%Y-%m-%d %H:%M:%S %z') 
    
        let WEATHER_DATA = {
            "weather": ($WEATHER)
            "last_weather_time": ($LAST_WEATHER_TIME)
        } 
    
        $WEATHER_DATA | save -f $weather_runtime_file
        return ($WEATHER)
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

# tomorrow.io
def fetch_api [loc] {
    let apiKey = $env.MY_ENV_VARS.api_keys.tomorrow_io.api_key

    let units = "metric"
    mut response = {}
    
    let forecast = (
        try {
            http get $"https://api.tomorrow.io/v4/weather/forecast?location=($loc)&units=($units)&apikey=($apiKey)" | upsert mystatus true
        } catch {
            {"mystatus": false}
        }
    )

    if not $forecast.mystatus {
        return {"mystatus": false}
    }

    let realtime = (
        try {
            http get $"https://api.tomorrow.io/v4/weather/realtime?location=($loc)&units=($units)&apikey=($apiKey)" | upsert mystatus true
        } catch {
            {"mystatus": false}
        }
    )

    if not $realtime.mystatus {
        return {"mystatus": false}
    }

    $response.forecast = ($forecast | reject mystatus)
    $response.realtime = ($realtime | reject mystatus)
    $response.mystatus = true

    return $response
}

# street address
def get_address [loc] {
    let mapsAPIkey = $env.MY_ENV_VARS.api_keys.google.general
    
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
    let apiKey = $env.MY_ENV_VARS.api_keys.air_visual.api_key
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
def get_weather [loc, --plot = true] {
    let response = (fetch_api $loc)
    let address = (get_address $loc)
    let air_cond = (get_airCond $loc)

    ## Current conditions
    let cond = (get_weather_description_from_code ($response.realtime.data.values.weatherCode | into string))
    let temp = $response.realtime.data.values.temperature
    let wind = $response.realtime.data.values.windSpeed * 3.6 
    let humi = $response.realtime.data.values.humidity 
    let uvIndex = $response.realtime.data.values.uvIndex

    let sunrise = (
        $response.forecast.timelines.daily 
        | get 0 
        | get values 
        | get sunriseTime 
        | into datetime
        | date to-timezone local
        | format date "%H:%M:%S"
    )

    let sunset = (
        $response.forecast.timelines.daily 
        | get 0 
        | get values 
        | get sunsetTime 
        | into datetime 
        | date to-timezone local
        | format date "%H:%M:%S"
    )

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
    let days = (
        $response.forecast.timelines.daily 
        | select time 
        | each {|row|
            $row.time 
            | into datetime -o -4 
            | format date "%Y-%m-%d"
          }
        | wrap "date"
    )

    mut data = []
    
    for i in 0..(($days | length) - 1) {
        $data = ($data | append ($response.forecast.timelines.daily | get values | get $i | select weatherCodeMax temperatureMin temperatureMax windSpeedAvg humidityAvg precipitationProbabilityAvg rainIntensityAvg uvIndexAvg | transpose | transpose -r))
    }

    mut forecast = ($days | dfr into-df | dfr append ($data | dfr into-df) | dfr into-nu)
    
    let windSpeedAvg = (
        $forecast 
        | select windSpeedAvg 
        | update windSpeedAvg {|f| 
            $f.windSpeedAvg * 3.6
          }
        | rename windSpeed
    )
     
        # | update precipitationProbabilityAvg {|f| $f.precipitationProbabilityAvg * 100} 
    
    $forecast = (
        $forecast 
        | update windSpeedAvg {|f| $f.windSpeedAvg * 3.6} 
        | update rainIntensityAvg {|f| $f.rainIntensityAvg * 24}
        | update uvIndexAvg {|f| uv_class $f.uvIndexAvg}
        | update weatherCodeMax {|f| get_weather_description_from_code ($f.weatherCodeMax | into string)} 
        | update windSpeedAvg {|f| $"(desc_wind $f.windSpeedAvg) \(($f.windSpeedAvg | into string -d 2)\)"} 
        | reject index
        | rename Date Summary "T° min (°C)" "T° max (°C)" "Wind Speed (Km/h)" "Humidity (%)" "Precip. Prob. (%)" "Precip. Intensity (mm)" "UV Index"
    )


    ## plots
    if $plot {
        let canIplot = (try {[1 2] | plot;true} catch {false})

        if $canIplot {
            print ($data | select uvIndexAvg | rename uvIndex | plot-table --title "UV Index" --width 150)
            print (echo "\n")

            print ($windSpeedAvg | plot-table --title "Wind Speed" --width 150)
            print (echo "\n")

            print (($forecast | select "Humidity (%)") | plot-table --title "Humidity" --width 150)
            print (echo "\n")

            print (($forecast | select "Precip. Intensity (mm)") | plot-table --title "Prec. Int." --width 150)
            print (echo "\n")

            print (($forecast | select "Precip. Prob. (%)") | plot-table --title "Prec. Prob" --width 150)
            print (echo "\n")

            # let hum_prob = ($forecast | select "Humidity (%)" "Precip. Prob. (%)")
            # print ($hum_prob | plot-table --title "Humidity vs Precip. Prob." --width 150)
            # print (echo "\n")

            let temp_minmax = ($forecast | select "T° min (°C)" "T° max (°C)")
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
    
    ## forecast
    print ("Forecast for today:")
    print ($forecast | get 0) 

    print ("Forecast for the next 5 days:")
    print ($forecast)

    ## current
    print ($"Current conditions: ($address)")
    print ($current)
}

def get_weather_for_prompt [loc] {
    
    let response = (fetch_api $loc)

    if not $response.mystatus {
        return $response
    }

    ## current conditions
    let cond = (get_weather_description_from_code ($response.realtime.data.values.weatherCode | into string))
    let temp = $response.realtime.data.values.temperature
    let temperature = $"($temp)°C"

    let sunrise = (
        $response.forecast.timelines.daily 
        | get 0 
        | get values 
        | get sunriseTime 
        | into datetime
        | date to-timezone local
        | format date "%H:%M:%S"
    )

    let sunset = (
        $response.forecast.timelines.daily 
        | get 0 
        | get values 
        | get sunsetTime 
        | into datetime
        | date to-timezone local
        | format date "%H:%M:%S"
    )

    let icon_description = (get_icon_description_from_code $response.realtime.data.values.weatherCode $sunrise $sunset)
    let icon = (get_weather_icon $icon_description)

    let current = {
        Condition: ($cond),
        Temperature: ($temperature),
        Icon: ($icon)
    }

    # echo $"($current.Icon) ($current.Temperature)"
    return ($current | upsert mystatus $response.mystatus)
}

def get_weather_icon [icon_description: string] {
    switch $icon_description {
        "clear-day": {|| (char -u f185)},
        "clear-night": {|| (char -u f186)},
        "rain": {|| (char -u e318)},
        "drizzle": {|| (char -u e319)},
        "light-rain": {|| (char -u e336)},
        "heavy-rain": {|| (char -u e317)},
        "snow": {|| (char -u fa97)},
        "light-snow": {|| (char -u e31a)},
        "heavy-snow": {|| (char -u "1F328")},
        "flurries": {|| (char -u e35e)},
        "freezing-drizzle": {|| (char -u fb7d)},
        "sleet": {|| (char -u e3ad)},
        "wind": {|| (char -u fa9c)},
        "fog": {|| (char -u e313)},
        "light-fog": {|| (char -u fa90)},
        "cloudy": {|| (char -u e312)},
        "partly-cloudy-day": {|| (char -u e21d)},
        "partly-cloudy-night": {|| (char -u e226)},
        "mostly-clear-day": {|| (char -u e302)},
        "mostly-clear-night": {|| (char -u e32e)},
        "mostly-cloudy-day": {|| (char -u e376)},
        "mostly-cloudy-night": {|| (char -u e378)},
        "hail": {|| (char -u fa91)},
        "thunderstorm": {|| (char -u e31d)},
        "tornado": {|| (char -u e351)}
    }
}

def get_weather_description_from_code [code: string] {
    open ([$env.MY_ENV_VARS.credentials "tomorrow_weather_codes.json"] | path join)
    | get weatherCode
    | get $code
}

def get_icon_description_from_code [
    code: string
    sunrise
    sunset
] {
    let day = (
        if (date now | format date '%H:%M:%S') < $sunset and (date now | format date '%H:%M:%S') > $sunrise {
            true
        } else {
            false
        }
    )

    switch ($code | into string) {
        "1000" : {|| if $day {"clear-day"} else {"clear-night"}},
        "1100" : {|| if $day {"mostly-clear-day"} else {"mostly-clear-night"}},
        "1101" : {|| if $day {"partly-cloudy-day"} else {"partly-cloudy-night"}},       
        "1102" : {|| if $day {"mostly-cloudy-day"} else {"mostly-cloudy-night"}},     
        "1001" : {|| "cloudy"},             
        "2000" : {|| "fog"},                 
        "2100" : {|| "light-fog"},
        "4000" : {|| "drizzle"},
        "4001" : {|| "rain"},
        "4200" : {|| "light-rain"},          
        "4201" : {|| "heavy-rain"},          
        "5000" : {|| "snow"},              
        "5001" : {|| "flurries"},
        "5100" : {|| "light-snow"},          
        "5101" : {|| "heavy-snow"},          
        "6000" : {|| "freezing-rain"},
        "6001" : {|| "freezing-rain"},
        "6200" : {|| "freezing-rain"},
        "6201" : {|| "freezing-rain"},
        "7000" : {|| "sleet"},
        "7101" : {|| "sleet"},
        "7102" : {|| "sleet"},
        "8000" : {|| "thunderstorm"}
    }   
}