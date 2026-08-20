# nushell completion for linecast

def "nu-complete linecast-lang" [] {
    [ "en" "fr" "es" "de" "it" "pt" "nl" "pl" "no" "sv" "is" "da" "fi" "ja" "ko" "zh" "id" ]
}

def "nu-complete linecast-theme" [] {
    [ "dark-sky" "universal-blue" "rainbow" "nexrad" "original" "titan" "twc" "meteored" "datameteo" "viper" "mrms" "max-storm" "black-white" ]
}

def "nu-complete linecast-layer" [] {
    [ "radar" "satellite" ]
}

def "nu-complete linecast-layers" [] {
    [ "temp" "wind" "temp,wind" ]
}

def "nu-complete linecast-view" [] {
    [ "street" "terrain" "now" ]
}

def "nu-complete linecast-profile" [] {
    [ "car" "bike" "foot" ]
}

def "nu-complete linecast-shells" [] {
    [ "bash" "zsh" "fish" "nu" "nushell" ]
}

def "nu-complete linecast-location-subcommands" [] {
    [ "show" "set" "auto" "search" ]
}

def "nu-complete linecast-units-subcommands" [] {
    [ "show" "metric" "imperial" "auto" ]
}

export extern "linecast" [
    --version(-v) # Show version
]

export extern "linecast weather" [
    --version # Show version
    --print
    --live
    --oneline
    --json
    --location: string
    --search: string
    --emoji
    --metric
    --celsius
    --fahrenheit
    --no-shading
    --lang: string@"nu-complete linecast-lang"
    --classic-colors
    --legacy-colors
    --debug
]

export extern "linecast sunshine" [
    --version # Show version
    --print
    --live
    --oneline
    --json
    --emoji
    --classic-colors
    --legacy-colors
    --debug
]

export extern "linecast moon" [
    --version # Show version
    --print
    --live
    --oneline
    --json
    --emoji
    --lang: string@"nu-complete linecast-lang"
    --classic-colors
    --legacy-colors
    --debug
]

export extern "linecast tides" [
    --version # Show version
    --print
    --live
    --oneline
    --json
    --station: string
    --search: string
    --nearby
    --metric
    --lang: string@"nu-complete linecast-lang"
    --classic-colors
    --legacy-colors
    --debug
]

export extern "linecast radar" [
    --version # Show version
    --print
    --live
    --oneline
    --location: string
    --search: string
    --zoom: string
    --theme: string@"nu-complete linecast-theme"
    --layer: string@"nu-complete linecast-layer"
    --layers: string@"nu-complete linecast-layers"
    --emoji
    --lang: string@"nu-complete linecast-lang"
    --classic-colors
    --legacy-colors
    --debug
]

export extern "linecast maps" [
    --version # Show version
    --print
    --live
    --oneline
    --location: string
    --search: string
    --zoom: string
    --view: string@"nu-complete linecast-view"
    --to: string
    --from: string
    --profile: string@"nu-complete linecast-profile"
    --emoji
    --lang: string@"nu-complete linecast-lang"
    --classic-colors
    --legacy-colors
    --debug
]

export extern "linecast location" [
    subcommand?: string@"nu-complete linecast-location-subcommands"
    --version # Show version
]

export extern "linecast location show" [
    --version # Show version
]

export extern "linecast location set" [
    query?: string
    --version # Show version
]

export extern "linecast location auto" [
    --version # Show version
]

export extern "linecast location search" [
    query?: string
    --version # Show version
]

export extern "linecast units" [
    subcommand?: string@"nu-complete linecast-units-subcommands"
    --version # Show version
]

export extern "linecast units show" [
    --version # Show version
]

export extern "linecast units metric" [
    --version # Show version
]

export extern "linecast units imperial" [
    --version # Show version
]

export extern "linecast units auto" [
    --version # Show version
]

export extern "linecast completion" [
    shell?: string@"nu-complete linecast-shells"
]

export extern "weather" [
    --version # Show version
    --print
    --live
    --oneline
    --json
    --location: string
    --search: string
    --emoji
    --metric
    --celsius
    --fahrenheit
    --no-shading
    --lang: string@"nu-complete linecast-lang"
    --classic-colors
    --legacy-colors
    --debug
]

export extern "sunshine" [
    --version # Show version
    --print
    --live
    --oneline
    --json
    --emoji
    --classic-colors
    --legacy-colors
    --debug
]

export extern "moon" [
    --version # Show version
    --print
    --live
    --oneline
    --json
    --emoji
    --lang: string@"nu-complete linecast-lang"
    --classic-colors
    --legacy-colors
    --debug
]

export extern "tides" [
    --version # Show version
    --print
    --live
    --oneline
    --json
    --station: string
    --search: string
    --nearby
    --metric
    --lang: string@"nu-complete linecast-lang"
    --classic-colors
    --legacy-colors
    --debug
]

export extern "radar" [
    --version # Show version
    --print
    --live
    --oneline
    --location: string
    --search: string
    --zoom: string
    --theme: string@"nu-complete linecast-theme"
    --layer: string@"nu-complete linecast-layer"
    --layers: string@"nu-complete linecast-layers"
    --emoji
    --lang: string@"nu-complete linecast-lang"
    --classic-colors
    --legacy-colors
    --debug
]

export extern "maps" [
    --version # Show version
    --print
    --live
    --oneline
    --location: string
    --search: string
    --zoom: string
    --view: string@"nu-complete linecast-view"
    --to: string
    --from: string
    --profile: string@"nu-complete linecast-profile"
    --emoji
    --lang: string@"nu-complete linecast-lang"
    --classic-colors
    --legacy-colors
    --debug
]

export extern "location" [
    subcommand?: string@"nu-complete linecast-location-subcommands"
    --version # Show version
]

export extern "location show" [
    --version # Show version
]

export extern "location set" [
    query?: string
    --version # Show version
]

export extern "location auto" [
    --version # Show version
]

export extern "location search" [
    query?: string
    --version # Show version
]

export extern "units" [
    subcommand?: string@"nu-complete linecast-units-subcommands"
    --version # Show version
]

export extern "units show" [
    --version # Show version
]

export extern "units metric" [
    --version # Show version
]

export extern "units imperial" [
    --version # Show version
]

export extern "units auto" [
    --version # Show version
]

