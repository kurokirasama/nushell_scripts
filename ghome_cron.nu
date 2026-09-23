# GHome Cron AC Automation

# Centralized configuration for AC temperature thresholds
export def "ghome cron-ac-config" [] {
    {
        sunrise_on: 16.0,        # Turn on if <= this at sunrise
        hourly_on_winter: 12.0,  # Turn on if <= this (winter/season)
        hourly_on_summer: 20.0,  # Turn on if >= this (summer/off-season)
        hourly_off_winter: 16.0, # Turn off if >= this (winter/season)
        hourly_off_summer: 18.0, # Turn off if <= this (summer/off-season)
        winter_start: "03-21",   # Season start (MM-DD)
        winter_end: "10-01"      # Season end (MM-DD)
    }
}

# Determine if a given datetime falls within the winter (in-season) window
export def "ghome cron-is-winter" [date_time?: datetime]: nothing -> bool {
    let dt = ($date_time | default (date now))
    let year = ($dt | format date %Y)
    let config = (ghome cron-ac-config)
    let winter_start = $"($year)-($config.winter_start)" | into datetime
    let winter_end = $"($year)-($config.winter_end) 23:59:59" | into datetime
    ($dt >= $winter_start) and ($dt <= $winter_end)
}

# Fetch weather and turn ON AC if cold at sunrise
# temperature <= 12 and date between march 21 and sept 21
export def "ghome cron-ac-on-sunrise" [--dry-run] {
    let runtime_file = $env.MY_ENV_VARS.base_yandex | path join ".weather_runtime_file_address.json"
    get_weather_by_interval 30min --address $env.MY_ENV_VARS.address --file $runtime_file
    
    if not ($runtime_file | path exists) {
        {
            weather: " 20.00",
            last_weather_time: ((date now) - 1hr | format date "%Y-%m-%d %H:%M:%S %z"),
            weather_text: "Default 20.00",
            sunrise: "07:00:00",
            sunset: "18:00:00"
        } | save $runtime_file
    }
    
    let weather_data = open $runtime_file
    let temp_str = $weather_data.weather | split row ' ' | last | str replace '°C' ''
    let temp = $temp_str | into float
    let today = date now
    let config = ghome cron-ac-config
    
    let is_winter = ghome cron-is-winter $today
    
    if ($temp <= $config.sunrise_on) and $is_winter {
        if $dry_run {
            print $"Dry run: Turning ON AC at sunrise \(temp ($temp) <= ($config.sunrise_on)\)"
        } else {
            print $"Executing: Turning ON AC at sunrise \(temp ($temp) <= ($config.sunrise_on)\)"
            ghome device "aire acondicionado" on
            #send-gmail $env.MY_ENV_VARS.mail "Log: ac on" --body "ac on"
        }
    }
}

# Hourly check to turn ON AC based on conditions
# returns true if conditions met and AC turned on, false otherwise
export def "ghome cron-ac-on-hourly" [
    temperature: float, 
    date_time: datetime, 
    sunrise: datetime, 
    sunset: datetime,
    --dry-run
] {
    let config = ghome cron-ac-config
    let is_winter = ghome cron-is-winter $date_time
    let is_summer = not $is_winter
    
    # Condition A (Winter): temp <= hourly_on_winter, time between sunrise+3 and sunset+4
    let sunrise_plus_4 = $sunrise + 3hr
    let sunset_plus_2 = $sunset + 4hr
    let time_range_a = ($date_time >= $sunrise_plus_4) and ($date_time <= $sunset_plus_2)
    
    if $is_winter and ($temperature <= $config.hourly_on_winter) and $time_range_a {
        if $dry_run {
            print $"Dry run: Turning ON AC \(Condition A, temp ($temperature) <= ($config.hourly_on_winter)\)"
        } else {
            print $"Executing: Turning ON AC \(Condition A, temp ($temperature) <= ($config.hourly_on_winter)\)"
            ghome device "aire acondicionado" on
            #send-gmail $env.MY_ENV_VARS.mail "Log: ac on" --body "ac on"
        }
        return true
    }
    
    # Condition B (Summer): temp >= hourly_on_summer, time between sunrise+5 and sunset
    let sunrise_plus_5 = $sunrise + 5hr
    let time_range_b = ($date_time >= $sunrise_plus_5) and ($date_time <= $sunset)
    
    if $is_summer and ($temperature >= $config.hourly_on_summer) and $time_range_b {
        if $dry_run {
            print $"Dry run: Turning ON AC \(Condition B, temp ($temperature) >= ($config.hourly_on_summer)\)"
        } else {
            print $"Executing: Turning ON AC \(Condition B, temp ($temperature) >= ($config.hourly_on_summer)\)"
            ghome device "aire acondicionado" on
            #send-gmail $env.MY_ENV_VARS.mail "Log: ac on" --body "ac on"
        }
        return true
    }

    #send-gmail $env.MY_ENV_VARS.mail "Log: ac on conditions not met" --body "ac on"
    return false
}

# Hourly check to turn OFF AC based on conditions
# returns true if conditions met and AC turned off, false otherwise
export def "ghome cron-ac-off-hourly" [
    temperature: float, 
    date_time: datetime,
    --dry-run
] {
    let config = ghome cron-ac-config
    let is_winter = ghome cron-is-winter $date_time
    let is_summer = not $is_winter
    
    if $is_winter and ($temperature >= $config.hourly_off_winter) {
        if $dry_run {
            print $"Dry run: Turning OFF AC \(Condition A, temp ($temperature) >= ($config.hourly_off_winter)\)"
        } else {
            print $"Executing: Turning OFF AC \(Condition A, temp ($temperature) >= ($config.hourly_off_winter)\)"
            ghome device "aire acondicionado" off
            #send-gmail $env.MY_ENV_VARS.mail "Log: ac off" --body "ac off"
        }
        return true
    }
    
    if $is_summer and ($temperature <= $config.hourly_off_summer) {
        if $dry_run {
            print $"Dry run: Turning OFF AC \(Condition B, temp ($temperature) <= ($config.hourly_off_summer)\)"
        } else {
            print $"Executing: Turning OFF AC \(Condition B, temp ($temperature) <= ($config.hourly_off_summer)\)"
            ghome device "aire acondicionado" off
            #send-gmail $env.MY_ENV_VARS.mail "Log: ac off" --body "ac off"
        }
        return true
    }

    #send-gmail $env.MY_ENV_VARS.mail "Log: ac off conditions not met" --body "ac off"
    return false
}

# Main wrapper for hourly orchestration
export def "ghome cron-ac-hourly-wrapper" [--dry-run] {
    let runtime_file = $env.MY_ENV_VARS.base_yandex | path join ".weather_runtime_file_address.json"
    get_weather_by_interval 30min --address $env.MY_ENV_VARS.address --file $runtime_file
    
    if not ($runtime_file | path exists) {
        {
            weather: " 20.00",
            last_weather_time: ((date now) - 1hr | format date "%Y-%m-%d %H:%M:%S %z"),
            weather_text: "Default 20.00",
            sunrise: "07:00:00",
            sunset: "18:00:00"
        } | save $runtime_file
    }
    
    let weather_data = open $runtime_file
    let temp_str = $weather_data.weather | split row ' ' | last | str replace '°C' ''
    let temp = $temp_str | into float
    let now = date now
    let sunrise = $weather_data.sunrise | into datetime
    let sunset = $weather_data.sunset | into datetime
    
    let turned_on = ghome cron-ac-on-hourly $temp $now $sunrise $sunset --dry-run=$dry_run
    if $turned_on {
        return
    }
    
    ghome cron-ac-off-hourly $temp $now --dry-run=$dry_run
}
