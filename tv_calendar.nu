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

# Resolve the default or custom path for TV series announcement memory
export def tv-memory-path [custom_path: string = ""] {
  if not ($custom_path | is-empty) {
    return ($custom_path | path expand)
  }
  let yandex_dir = ("~/Yandex.Disk" | path expand)
  if ($yandex_dir | path exists) {
    $yandex_dir | path join ".tv_series.json"
  } else {
    "~/.tv_series.json" | path expand
  }
}

# Load announced TV series records from memory file
export def tv-memory-load [custom_path: string = ""] {
  let file_path = (tv-memory-path $custom_path)
  if not ($file_path | path exists) {
    return []
  }
  try {
    let data = (open $file_path)
    let desc = ($data | describe)
    if ($desc | str starts-with "table") or ($desc | str starts-with "list") {
      $data
    } else if ($desc | str starts-with "record") {
      [$data]
    } else {
      []
    }
  } catch {
    []
  }
}

# Save TV series records to memory file (overwrites file)
export def tv-memory-save [shows: list, custom_path: string = ""] {
  let file_path = (tv-memory-path $custom_path)
  let now = (date now | format date "%Y-%m-%dT%H:%M:%SZ")
  let records = ($shows | each { |s|
    {
      show_id: ($s.show_id? | default 0 | into int)
      title: ($s.title? | default "")
      network: ($s.network? | default "")
      genre: ($s.genre? | default "")
      announced_at: ($s.announced_at? | default $now)
    }
  })
  $records | to json | save -f $file_path
  $records
}

# Record new TV series to memory file (appends and deduplicates by show_id)
export def tv-memory-record [new_shows: list, custom_path: string = ""] {
  let file_path = (tv-memory-path $custom_path)
  let existing = (tv-memory-load $custom_path)
  let existing_ids = if ($existing | is-empty) { [] } else { $existing | get -o show_id | compact }
  let unique_new = ($new_shows | where { |s| ($s.show_id? | default 0 | into int) not-in $existing_ids })
  if ($unique_new | is-empty) {
    return $existing
  }
  let now = (date now | format date "%Y-%m-%dT%H:%M:%SZ")
  let formatted_new = ($unique_new | each { |s|
    {
      show_id: ($s.show_id? | default 0 | into int)
      title: ($s.title? | default "")
      network: ($s.network? | default "")
      genre: ($s.genre? | default "")
      announced_at: ($s.announced_at? | default $now)
    }
  })
  let combined = ($existing | append $formatted_new)
  $combined | to json | save -f $file_path
  $combined
}

# Filter out already announced TV series based on memory
export def tv-memory-filter [shows: list, memory_or_path: any = ""] {
  let memory = if ($memory_or_path | describe | str starts-with "list") or ($memory_or_path | describe | str starts-with "table") {
    $memory_or_path
  } else if ($memory_or_path | describe | str starts-with "record") {
    [$memory_or_path]
  } else if ($memory_or_path | describe | str starts-with "string") {
    tv-memory-load $memory_or_path
  } else {
    tv-memory-load
  }
  if ($memory | is-empty) {
    return $shows
  }
  let seen_ids = ($memory | get -o show_id | compact)
  $shows | where { |s| ($s.show_id? | default 0 | into int) not-in $seen_ids }
}

# Get recent TV show additions from Pogdesign TV Calendar
@category media
@search-terms pogdesign tv calendar recent additions
export def tv-recent [
  --limit(-n): int = 0                  # limit number of results (0 = all)
  --format: string = "table"            # output format: table, json, csv, md
  --airing: string = ""                 # filter by airing day (e.g., Friday, Monday)
  --network: string = ""                # filter by network (e.g., Netflix, FX)
  --new-only                            # only return new shows
  --filter-seen                         # filter out shows already recorded in memory
  --record                              # record returned shows to memory file
  --no-memory                           # bypass memory filtering and recording completely
  --memory-file: string = ""            # custom memory file path (defaults to ~/Yandex.Disk/.tv_series.json)
  --channel: string = "gemini_cli_news" # discord channel to send report to
  --discord(-d)                         # send the md report or fallback message to discord
  --dry-run                             # simulate discord delivery and print/return payload without sending
  --html: string = ""                   # optional raw HTML content (useful for offline usage/testing)
] {
  let raw_html = if not ($html | is-empty) { $html } else { http get $pogg_url }
  let shows = (tv-parse $raw_html)

  let airing_filter = $airing
  let network_filter = $network
  let is_new_only = $new_only

  mut filtered = ($shows
    | where { if ($airing_filter | is-empty) { true } else { ($in.airing | str starts-with $airing_filter) } }
    | where { if ($network_filter | is-empty) { true } else { ($in.network | str contains $network_filter) } }
    | where { ($in.new or (not $is_new_only)) })

  let should_filter_memory = (not $no_memory) and ($filter_seen or $discord)
  if $should_filter_memory {
    $filtered = (tv-memory-filter $filtered $memory_file)
  }

  let results = if $limit > 0 { $filtered | first $limit } else { $filtered }

  if $discord {
    if ($results | is-empty) {
      let empty_msg = "No new TV series additions today"
      if not $dry_run {
        $empty_msg | to-discord --process -c $channel
      }
      return $empty_msg
    } else {
      let report = (build-tv-md-report $results)
      if not $dry_run {
        $report | to-discord --process -c $channel
      }
      if not $no_memory {
        tv-memory-record $results $memory_file
      }
      return $report
    }
  }

  if $record and (not $no_memory) {
    tv-memory-record $results $memory_file
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