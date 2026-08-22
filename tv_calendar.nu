const pogg_url = "https://www.pogdesign.co.uk/cat/recent-additions"
const pogg_site = "https://www.pogdesign.co.uk"
const pogg_selector = "div.contbox.prembox.removed"

# Parse recent TV additions HTML into a structured table
export def tv-parse [html: string] {
  let boxes = ($html | split row -r "<div\\s+class=[\x27\"]contbox prembox removed[\x27\"]" | skip 1)
  $boxes | each { |box|
    let title_match = ($box | parse -r "<h2>(?P<title>[^<]+)</h2>" | get -o 0?.title? | default "")
    let url_match = ($box | parse -r "<a\\s+href=[\x27\"](?P<url>[^\x27\"]+)" | get -o 0?.url? | default "")
    let net_genre = ($box | parse -r "<span\\s+style=[\x27\"][^\x27\"]*[\x27\"]>(?P<net_genre>[^<]+)</span>" | get -o 0?.net_genre? | default "")
    let parts = ($net_genre | split row " // ")
    let network = ($parts | get -o 0 | default "")
    let genre = ($parts | get -o 1 | default "")
    let desc = ($box | parse -r "class=[\x27\"]shwtxt[\x27\"]>(?P<desc>.*?)</span>" | get -o 0?.desc? | default "" | str replace -a "<br>" " " | str replace -a "<br/>" " " | str trim)
    let airing = ($box | parse -r "class=[\x27\"]hil selby[\x27\"]>(?:<!--.*?-->)?(?P<airing>[^<]+)</span>" | get -o 0?.airing? | default "" | str trim)
    let show_id = ($box | parse -r "value=[\x27\"](?P<sid>\\d+)[\x27\"]" | get -o 0?.sid? | default "0" | into int)
    let img = ($box | parse -r "url\\((?P<img>[^\\)]+)\\)" | get -o 0?.img? | default "" | str replace -a "\"" "" | str replace -a "\x27" "")
    let is_new = ($box | str contains "<strong><em>NEW!</em></strong>") or ($box | str contains "<em>NEW!</em>")

    {
      title: $title_match
      url: (if ($url_match | str starts-with "/") { "https://www.pogdesign.co.uk" + $url_match } else { $url_match })
      network: $network
      genre: $genre
      description: $desc
      airing: $airing
      show_id: $show_id
      image: $img
      new: $is_new
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