# wrapper for the deepl translation api
#
# Available tasks:
# - translate: translates text
# - usage: retrieves account usage and limits
# - languages: lists supported languages
#
# Language examples:
# - English: EN-US
# - Spanish: ES,
# - German: DE,
# - French: FR,
# - Japanese: JA,
# - Portuguese (Brazilian): PT-BR,
@category ai
@search-terms deepl translate
export def deep_l [
    query?: string                  # the text to translate (for 'translate' task)
    --task(-k): string = "translate"  # task to perform: translate, usage, languages
    --target-lang(-t): string = "ES" # The target language for translation.
    --source-lang(-s): string # The source language for translation. If empty, auto-detected.
    --lang-type: string = "target" # Type of languages to return ("source" or "target") for 'languages' task
    --pro(-p)                    # Use the pro API endpoint instead of the free one
] {
    let query = get-input $in $query
    
    let api_key = $env.MY_ENV_VARS.api_keys.deepl
    if ($api_key | is-empty) {
        return-error "DeepL API key not found in `$env.MY_ENV_VARS.api_keys.deepl`"
    }
    
    let header = [Authorization $"DeepL-Auth-Key ($api_key)"]
    let base_url = if $pro { "https://api.deepl.com/v2" } else { "https://api-free.deepl.com/v2" }

    match $task {
        "translate" => {
            if ($query | is-empty) {
                return-error "Empty text to translate!!!"
            }

            let site = $base_url | path join "translate"

            let request_body = if not ($source_lang | is-empty) {
                {
                    text: [$query],
                    target_lang: $target_lang,
                    source_lang: $source_lang
                }
            } else {
                {
                    text: [$query],
                    target_lang: $target_lang
                }
            }

            try {
                let answer = http post -t application/json -H $header $site $request_body
                return $answer.translations.0.text
            } catch {
                return (http post -t application/json -H $header $site $request_body -e)
            }
        },
        "usage" => {
            let site = $base_url | path join "usage"
            http get -H $header $site
        },
        "languages" => {
            if $lang_type not-in ["source", "target"] {
                return-error "--lang-type must be 'source' or 'target'"
            }
            # http get does not support query parameters via a record, so we build the url manually
            let site = $"($base_url)/languages?type=($lang_type)"
            http get -H $header $site
        },
        _ => {
            return-error $"Unknown task '($task)'. Available tasks are: translate, usage, languages."
        }
    }
}
