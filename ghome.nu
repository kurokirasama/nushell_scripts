use apis.nu *
use string_manipulation.nu *
use files.nu *

# Google Home API Wrappers

# Internal helper to load tokens
def load-ghome-tokens [] {
    let token_file = ($env.HOME | path join ".ghome_oauth_token.json")
    if ($token_file | path exists) {
        open $token_file
    } else {
        {}
    }
}

# Internal helper to save tokens
def save-ghome-tokens [tokens: record] {
    let token_file = ($env.HOME | path join ".ghome_oauth_token.json")
    $tokens | to json | save -f $token_file
}

# Refresh Google Home OAuth2 access token
def ghome-oauth-refresh-token [refresh_token: string] {
    let client_id = get-api-key "google.ghome.client_id"
    let client_secret = get-api-key "google.ghome.client_secret"
    let GOOGLE_TOKEN_URL = "https://oauth2.googleapis.com/token"

    let body = {
        client_id: $client_id,
        client_secret: $client_secret,
        refresh_token: $refresh_token,
        grant_type: "refresh_token"
    }

    print "Refreshing Google Home access token..."
    let response = http post --full $GOOGLE_TOKEN_URL --headers { Content-Type: "application/json" } ($body | to json)

    if ($response.status == 200) {
        let new_tokens = $response.body
        let existing_tokens = load-ghome-tokens
        let refresh_token_to_keep = if ("refresh_token" in $new_tokens) { $new_tokens.refresh_token } else { $existing_tokens.refresh_token }

        let expires_at = (date now) + ($new_tokens.expires_in * 1sec)
        let full_tokens = {
            access_token: $new_tokens.access_token,
            token_type: $new_tokens.token_type,
            expires_at: ($expires_at | format date "%Y-%m-%dT%H:%M:%S%z"),
            refresh_token: $refresh_token_to_keep
        }
        save-ghome-tokens $full_tokens
        return $full_tokens.access_token
    } else {
        return-error $"Failed to refresh token: ($response.body)"
    }
}

# Get current access token, refreshing if necessary
export def get-ghome-token [] {
    let tokens = load-ghome-tokens
    
    if ($tokens | is-empty) {
        return-error "No Google Home tokens found. Please run 'ghome auth' first."
    }

    let expires_at = ($tokens.expires_at | into datetime)
    if (date now) > ($expires_at - 5min) {
        return (ghome-oauth-refresh-token $tokens.refresh_token)
    }

    return $tokens.access_token
}

# Initialize Google Home OAuth2 flow
export def "ghome auth" [] {
    let client_id = get-api-key "google.ghome.client_id"
    let client_secret = get-api-key "google.ghome.client_secret"
    
    # Expanded scopes for broader API access
    let scopes = [
        "https://www.googleapis.com/auth/assistant-sdk-prototype"
        "https://www.googleapis.com/auth/cloud-platform"
    ] | str join " " | url encode
    
    let redirect_uri = "http://127.0.0.1"
    let auth_url = $"https://accounts.google.com/o/oauth2/v2/auth?client_id=($client_id)&response_type=code&scope=($scopes)&redirect_uri=($redirect_uri)"

    print $"Please visit this URL to authorize: ($auth_url)"
    print "After authorizing, your browser will redirect to a broken page (127.0.0.1)."
    print "Copy and paste the FULL URL from your address bar below:"
    let input_val = (input "Enter the code or full URL: ")

    # Extract code if a full URL was pasted
    let code = if ($input_val | str starts-with "http") {
        let query_str = ($input_val | url parse).query
        $query_str | split row "&" | each { split row "=" } | where $it.0 == "code" | get 0.1
    } else {
        $input_val
    }

    let token_url = "https://oauth2.googleapis.com/token"
    let body = {
        code: $code,
        client_id: $client_id,
        client_secret: $client_secret,
        redirect_uri: $redirect_uri,
        grant_type: "authorization_code"
    }

    print "Exchanging code for tokens..."
    let response = http post --full $token_url --headers { Content-Type: "application/json" } ($body | to json)

    if ($response.status == 200) {
        let tokens = $response.body
        let expires_at = (date now) + ($tokens.expires_in * 1sec)
        let full_tokens = {
            access_token: $tokens.access_token,
            token_type: $tokens.token_type,
            expires_at: ($expires_at | format date "%Y-%m-%dT%H:%M:%S%z"),
            refresh_token: $tokens.refresh_token
        }
        save-ghome-tokens $full_tokens
        print (echo-g "Successfully authenticated!")
    } else {
        return-error $"Failed to exchange code: ($response.body)"
    }
}

# --- Core API Wrappers ---

# List all Google Home/Cast devices on the local network
export def "ghome list-devices" [] {
    print "Scanning local network for Google Home/Cast devices (mDNS)..."
    
    let raw_output = (avahi-browse -r -p _googlecast._tcp -t)
    
    if ($raw_output | is-empty) {
        return-error "No devices found. Ensure you are on the same network as your devices."
    }

    $raw_output
    | lines
    | where ($it | str starts-with "=") # Only resolved entries
    | split column ";"
    | select column3 column4 column7 column8 column9
    | rename interface protocol name type domain
    | uniq
}

# Send a text command to Google Assistant via the Python Bridge
export def "ghome command" [query: string, --lang: string = "es-ES"] {
    # Ensure token is fresh before calling the bridge
    let _ = (get-ghome-token)
    
    print $"Sending command to Google Assistant: ($query)..."
    
    # Get credentials for the bridge
    let client_id = get-api-key "google.ghome.client_id"
    let client_secret = get-api-key "google.ghome.client_secret"
    
    # Path to the python bridge and the venv python
    let python_script = ($env.MY_ENV_VARS.python_scripts | path join "assistant_bridge.py")
    let venv_python = ($env.HOME | path join "Yandex.Disk/my_scripts/python/venv/bin/python")
    
    # Pass credentials and protobuf workaround as environment variables
    let raw_res = (with-env { 
        GOOGLE_CLIENT_ID: $client_id, 
        GOOGLE_CLIENT_SECRET: $client_secret,
        PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION: "python"
    } {
        run-external $venv_python $python_script $query $lang | complete
    })
    
    if ($raw_res.stdout | is-empty) {
        return-error $"Python Bridge failed with no output: ($raw_res.stderr)"
    }

    let result = ($raw_res.stdout | from json)
    
    if ($result.status == "success") {
        print (echo-g $result.message)
    } else {
        return-error $result.message
    }
}

# Get local information from a Google Home/Cast device
export def "ghome local-info" [ip: string] {
    let url = $"https://($ip):8443/setup/eureka_info?params=version,name,build_info,detail,opt_in"
    let response = http get --full $url --allow-errors
    
    if ($response.status == 200) {
        return $response.body
    } else {
        return-error $"Failed to get local info: ($response.status)"
    }
}

# Known devices for completions
const ghome_devices = [ "puerta", "comedor", "escalera", "dormitorio", "elu", "aire acondicionado" ]

# Known states for completions
const ghome_states = [ "on", "off" ]

# Known light temperatures for completions
const ghome_temperatures = [
    "Candlelight",
    "Ultra Warm White",
    "Incandescent",
    "Warm White",
    "Soft White",
    "Cool White",
    "Daylight",
    "White",
    "Floral White",
    "Ivory",
    "Cloudy Daylight",
    "Blue Overcast",
    "Blue Sky"
]

# Control a Google Home device by name
export def "ghome device" [
    name: string@$ghome_devices # Name of the device
    state: string@$ghome_states # 'on' or 'off'
] {
    let query = match $state {
        "on" => $"Enciende ($name)"
        "off" => $"Apaga ($name)"
        _ => { return-error "State must be 'on' or 'off'" }
    }
    ghome command $query
}

# --- Convenience Wrappers ---

# Set light brightness
export def "ghome light brightness" [name: string, level: int] {
    ghome command $"Pon el brillo de ($name) al ($level) por ciento"
}

# Set light color
export def "ghome light color" [
    name: string@$ghome_devices # Name of the light
    color: string # Color name in Spanish
] {
    ghome command $"Pon el color de ($name) a ($color)"
}

# Set light temperature
export def "ghome light temperature" [
    name: string@$ghome_devices # Name of the light
    temperature: string@$ghome_temperatures # Temperature name
] {
    ghome command $"Pon la temperatura de ($name) a ($temperature)"
}

# Play media on a speaker
export def "ghome speaker play" [name: string] {
    ghome command $"Reproduce música en ($name)"
}

# Pause media on a speaker
export def "ghome speaker pause" [name: string] {
    ghome command $"Para ($name)"
}

const thermostat = ["aire acondicionado"]

# Set thermostat temperature
export def "ghome thermostat set" [name: string, temp: int] {
    ghome command $"Pon ($name) a ($temp) grados"
}
