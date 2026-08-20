const pogg_url = "https://www.pogdesign.co.uk/cat/recent-additions"
const pogg_site = "https://www.pogdesign.co.uk"
const pogg_selector = "div.contbox.prembox.removed"

# Parse recent TV additions HTML into a structured table
export def tv-parse [html: string] {
  let titles = $html
    | query web --query ($pogg_selector + " h2") --document
    | flatten

  let urls = $html
    | query web --query ($pogg_selector + " a") --attribute href --document
    | flatten

  let network_genre = $html
    | query web --query ($pogg_selector + " a span") --document
    | flatten

  let descriptions = $html
    | query web --query ($pogg_selector + " .shwtxt") --document
    | flatten

  let air_times = $html
    | query web --query ($pogg_selector + " .hil.selby") --document
    | flatten

  let show_ids = $html
    | query web --query ($pogg_selector + " input[type=checkbox]") --attribute value --document
    | flatten

  let images = $html
    | query web --query ($pogg_selector + " a") --attribute style --document
    | flatten

  let is_news = $html
    | query web --query ($pogg_selector + " strong em") --document
    | flatten

  $titles | enumerate | each { |e|
    let i = $e.index
    let title = $e.item
    {
      title: $title
      url: ($pogg_site + ($urls | get -o $i | default ""))
      network: (($network_genre | get -o $i | default "") | str replace -r " // .*$" "")
      genre: (($network_genre | get -o $i | default "") | str replace -r "^.* // " "")
      description: ($descriptions | get -o $i | default "")
      airing: ($air_times | get -o $i | default "" | str trim)
      show_id: (($show_ids | get -o $i | default "0") | into int)
      image: (($images | get -o $i | default "") | str replace "background-image: url(" "" | str replace ");" "")
      new: (($is_news | get -o $i | default "") == "NEW!")
    }
  }
}

# Get recent TV show additions from Pogdesign TV Calendar
@category media
@search-terms pogdesign tv calendar recent additions
export def tv-recent [
  --limit(-n): int = 0        # limit number of results (0 = all)
  --format: string = "table"  # output format: table, json, csv, md
  --airing: string = ""       # filter by airing day (e.g., Friday, Monday)
  --network: string = ""      # filter by network (e.g., Netflix, FX)
  --new-only                  # only return new shows
  --discord(-d)               # send the md report to the gemini_cli_cron discord channel
] {
  let html = http get $pogg_url
  let shows = tv-parse $html

  let airing = $airing
  let network = $network
  let new_only = $new_only

  let filtered = $shows
    | where { if ($airing | is-empty) { true } else { ($in.airing | str starts-with $airing) } }
    | where { if ($network | is-empty) { true } else { ($in.network | str contains $network) } }
    | where { ($in.new or (not $new_only)) }

  let results = if $limit > 0 { $filtered | first $limit } else { $filtered }

  if $discord {
    let report = build-tv-md-report $results
    $report | to-discord --process -c gemini_cli_cron
    return $report
  }

  match $format {
    "json" => { $results | to json }
    "csv"  => { $results | to csv }
    "md"   => { build-tv-md-report $results }
    _      => $results
  }
}

# Build a markdown report from a table of shows
def build-tv-md-report [results: list] {
  let header = ["# Recent TV Additions", ""]
  let body = $results | each { |s|
    let badges = if $s.new { " **NEW!**" } else { "" }
    [
      ("## [" + $s.title + "](" + $s.url + ")" + $badges)
      ""
      ("**Network:** " + $s.network + " // " + $s.genre)
      ("**Airing:** " + $s.airing)
      ("**ID:** " + ($s.show_id | into string))
      ""
      ("![](" + $s.image + ")")
      ""
      $s.description
      ""
    ]
  } | flatten
  ($header | append $body) | str join "\n"
}