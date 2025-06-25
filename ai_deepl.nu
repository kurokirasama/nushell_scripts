# DeepL API wrapper for text translations
#
# Available languages:
# - Bulgarian (BG)
# - Czech (CS)
# - Danish (DA)
# - German (DE)
# - Greek (EL)
# - English (EN)
# - Spanish (ES)
# - Estonian (ET)
# - Finnish (FI)
# - French (FR)
# - Hungarian (HU)
# - Indonesian (ID)
# - Italian (IT)
# - Japanese (JA)
# - Lithuanian (LT)
# - Latvian (LV)
# - Dutch (NL)
# - Polish (PL)
# - Portuguese (PT)
# - Romanian (RO)
# - Russian (RU)
# - Slovak (SK)
# - Slovenian (SL)
# - Swedish (SV)
# - Turkish (TR)
# - Ukrainian (UK)
# - Chinese (ZH)
#
# Note: Some languages may only be available as target languages.
#
# API documentation: https://www.deepl.com/docs-api
@category ai
@search-terms deepl translation
export def deep_l [
    text?: string                     # Text to translate
    --target-lang(-t): string = "ES"  # Target language code (e.g., "DE", "FR")
    --source-lang(-s): string = "EN"  # Source language code (optional)
    --formality(-f): string = "default" # Formality level: "default", "more", "less"
    --split-sentences(-p): string = "1" # Split sentences: "0", "1", "nonewlines"
    --preserve-formatting(-k)         # Preserve formatting (no fixes)
    --tag-handling(-g): string        # Tag handling: "xml", "html"
    --non-splitting-tags(-n): string  # Comma-separated list of non-splitting tags
    --outline-detection(-o)           # Disable outline detection
    --splitting-tags(-a): string      # Comma-separated list of splitting tags
    --ignore-tags(-i): string         # Comma-separated list of ignore tags
] {
    let text = get-input $in $text
    if ($text | is-empty) {
        return-error "Empty text to translate!!!"
    }

    if ($target_lang | is-empty) {
        return-error "Target language is required!!!"
    }

    let api_key = $env.MY_ENV_VARS.api_keys.deepl? | default ""
    if ($api_key | is-empty) {
        return-error "DeepL API key not found in $env.MY_ENV_VARS.api_keys.deepl"
    }

    let header = [Authorization $"DeepL-Auth-Key ($api_key)"]
    let site = "https://api-free.deepl.com/v2/translate"

    let request = {
        text: $text,
        target_lang: $target_lang,
        source_lang: $source_lang,
        formality: $formality,
        split_sentences: $split_sentences,
        preserve_formatting: $preserve_formatting,
        tag_handling: $tag_handling,
        non_splitting_tags: $non_splitting_tags,
        outline_detection: $outline_detection,
        splitting_tags: $splitting_tags,
        ignore_tags: $ignore_tags
    } | compact

    try {
        let response = http post -t application/json -H $header $site $request
        return $response.translations.0.text
    } catch {|e|
        return-error $"Translation failed: ($e.message)"
    }
}

# Helper function to validate language codes
def validate_lang [lang: string] {
    let valid_langs = ["BG", "CS", "DA", "DE", "EL", "EN", "ES", "ET", "FI", "FR", "HU", "ID", "IT", "JA", "LT", "LV", "NL", "PL", "PT", "RO", "RU", "SK", "SL", "SV", "TR", "UK", "ZH"]
    if $lang not-in $valid_langs {
        return-error $"Invalid language code: ($lang). Valid codes are: ($valid_langs | str join ', ')"
    }
}

# Helper function to compact optional parameters
def compact [] {
    each { |it|
        if ($it.value | is-not-empty) {
            { $it.key: $it.value }
        }
    } | reduce { |a, b| $a | merge $b }
}
