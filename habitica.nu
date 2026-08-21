# Get credentials
export def "h credentials" [] {
    {
        x-client : ((get-api-key "habitica.id") + ' - nushell habitica api wrapper'),
        x-api-user: (get-api-key "habitica.id"),
        x-api-key: (get-api-key "habitica.token")
    }
}

# Internal resilient HTTP request helper for Habitica API
export def _h-request [
  method: string # GET, POST, DELETE, PUT
  path: string   # Endpoint path (e.g. "/api/v3/user") or full URL
  --params: record = {}
  --body: any = null
  --max-retries: int = 3
  --initial-delay: duration = 2sec
  --allow-errors # Return error record instead of raising error
] {
  let headers = h credentials
  let base_url = "https://habitica.com"

  let clean_path = if ($path starts-with "http://") or ($path starts-with "https://") {
    $path | str replace "https://habitica.com" "" | str replace "http://habitica.com" ""
  } else if ($path starts-with "/") {
    $path
  } else {
    $"\/($path)"
  }

  if ($env.MOCK_HABITICA_RESPONSE? | is-not-empty) {
    let mock_fn = $env.MOCK_HABITICA_RESPONSE
    return (do $mock_fn $method $clean_path $params $body)
  }

  let full_url = if ($params | is-not-empty) {
    {
      scheme: "https",
      host: "habitica.com",
      path: $clean_path,
      params: $params
    } | url join
  } else {
    $"($base_url)($clean_path)"
  }

  mut attempt = 1
  mut last_response: any = null

  while $attempt <= ($max_retries + 1) {
    let http_res = try {
      match ($method | str uppercase) {
        "GET" => {
          http get --allow-errors -f -H $headers $full_url
        }
        "POST" => {
          let payload = if ($body == null) {
            "{}"
          } else if ($body | describe | str starts-with "string") {
            $body
          } else {
            $body | to json -r
          }
          http post --allow-errors -f -H $headers --content-type application/json $full_url $payload
        }
        "DELETE" => {
          http delete --allow-errors -f -H $headers $full_url
        }
        "PUT" => {
          let payload = if ($body == null) {
            "{}"
          } else if ($body | describe | str starts-with "string") {
            $body
          } else {
            $body | to json -r
          }
          http put --allow-errors -f -H $headers --content-type application/json $full_url $payload
        }
        _ => {
          error make { msg: $"Unsupported HTTP method: ($method)" }
        }
      }
    } catch { |e|
      let err_detail = if ($e.msg? | is-not-empty) {
        $e.msg
      } else if ($e.rendered? | is-not-empty) {
        $e.rendered
      } else {
        ($e | to text)
      }
      { status: 0, body: null, error: $err_detail, headers: { response: [] } }
    }

    $last_response = $http_res

    let status = $http_res.status? | default 0
    if ($status >= 200) and ($status < 300) {
      return $http_res.body
    }

    if ($status == 429) or ($status in [500, 502, 503, 504, 0]) {
      if $attempt <= $max_retries {
        let resp_headers = $http_res.headers?.response? | default []
        let reset_val = $resp_headers | where name == "x-ratelimit-reset" | get -o 0.value

        let delay = if ($status == 429) and ($reset_val != null) {
          let parsed_delay = try {
            let reset_dt = ($reset_val | into datetime)
            let diff = $reset_dt - (date now)
            if ($diff > 0sec) and ($diff < 60sec) { $diff + 1sec } else { null }
          } catch { null }

          if ($parsed_delay != null) {
            $parsed_delay
          } else {
            $initial_delay * (2 ** ($attempt - 1))
          }
        } else {
          $initial_delay * (2 ** ($attempt - 1))
        }

        let status_desc = if ($status == 0) and ($http_res.error? | is-not-empty) {
          $"HTTP 0 \(($http_res.error)\)"
        } else {
          $"HTTP ($status)"
        }
        print (echo-y $"[Habitica API] ($status_desc) encountered. Retrying in ($delay) [attempt ($attempt)/($max_retries)]...")
        sleep $delay
        $attempt = $attempt + 1
        continue
      }
    }

    break
  }

  let error_msg = if ($last_response.body?.message? | is-not-empty) {
    $last_response.body.message
  } else if ($last_response.error? | is-not-empty) {
    $last_response.error
  } else {
    $"HTTP Error ($last_response.status? | default 'unknown')"
  }

  if $allow_errors {
    return {
      success: false,
      status: ($last_response.status? | default 0),
      message: $error_msg,
      body: $last_response.body?
    }
  }

  return-error $"Habitica API error: ($error_msg)"
}

# Internal helper to retrieve raw Habitica user statistics record
export def _h-user-stats [] {
    let hab_id = get-api-key "habitica.id"

    let response = _h-request "GET" "/api/v3/user" | get data
    let party = if ($env.MOCK_HABITICA_PARTY? | is-not-empty) {
        $env.MOCK_HABITICA_PARTY
    } else {
        try { h party } catch { { quest: { key: "", active: false, members: {} } } }
    }
    let pending_quest = ($party.quest.key? | is-not-empty) and ($party.quest.active? == false) and (($party.quest.members? | default {}) | get -o $hab_id | is-empty)
    
    let hp_num = ($response.stats.hp? | default 0 | math round)
    let max_hp_num = ($response.stats.maxHealth? | default 50 | math round)
    let mp_num = ($response.stats.mp? | default 0 | math round)
    let max_mp_num = ($response.stats.maxMP? | default 100 | math round)
    let exp_num = ($response.stats.exp? | default 0 | math round)
    let to_next_lvl_num = ($response.stats.toNextLevel? | default 1000 | math round)
    
    let dailys_data = try {
      _h-request "GET" "/api/v3/tasks/user" --params { type: "dailys" } | get data
    } catch { [] }

    let todos_data = try {
      _h-request "GET" "/api/v3/tasks/user" --params { type: "todos" } | get data
    } catch { [] }

    let quest_key = ($party.quest.key? | default "")
    let quest_active = ($party.quest.active? | default false)
    let quest_progress = if $quest_active {
        if ($party.quest.progress?.up? | is-not-empty) {
            $"Boss HP: ($party.quest.progress.hp? | default 0 | math round)"
        } else if ($party.quest.progress?.collect? | is-not-empty) {
            "Collecting items"
        } else {
            "Active"
        }
    } else {
        "None"
    }

    return {
        name: $response.profile.name,
        level: $response.stats.lvl,
        class: $response.stats.class,
        hp: $"($hp_num)/($max_hp_num)",
        hp_val: $hp_num,
        max_hp: $max_hp_num,
        experience: $"($exp_num)/($to_next_lvl_num)",
        exp_val: $exp_num,
        to_next_level: $to_next_lvl_num,
        mana: $"($mp_num)/($max_mp_num)",
        mana_val: $mp_num,
        max_mana: $max_mp_num,
        dailys_to_complete: ($dailys_data | where completed == false and isDue == true | length),
        todos_to_complete: ($todos_data | where completed == false | length),
        logged_in_today: (not ($response.needsCron? | default false)),
        in_quest: $quest_active,
        pending_quest: $pending_quest,
        quest_key: $quest_key,
        quest_progress: $quest_progress
    }
}

# Internal helper to convert avatar image into ANSI block character lines
export def _h-get-avatar-lines [
    avatar_path?: string
    --width: int = 24
    --height: int = 10
] {
    if ($env.MOCK_HABITICA_AVATAR_LINES? | is-not-empty) {
        return $env.MOCK_HABITICA_AVATAR_LINES
    }

    let target_path = ($avatar_path | default ($env.MY_ENV_VARS?.habitica_avatar? | default ""))
    if ($target_path | is-empty) or (not ($target_path | path exists)) {
        return []
    }

    # Force quarter-block Unicode text mode (-pq) to guarantee text cell lines rather than Kitty/Sixel graphics protocols
    let timg_out = (do { ^timg -pq -g $"($width)x($height)" $target_path } | complete)
    if $timg_out.exit_code == 0 and ($timg_out.stdout | str trim | is-not-empty) {
        return ($timg_out.stdout | split row -r '\r?\n' | each { |l| $l | str trim -r } | where ($it | str length) > 0)
    }

    # Fallback to half-block mode
    let timg_h_out = (do { ^timg -ph -g $"($width)x($height)" $target_path } | complete)
    if $timg_h_out.exit_code == 0 and ($timg_h_out.stdout | str trim | is-not-empty) {
        return ($timg_h_out.stdout | split row -r '\r?\n' | each { |l| $l | str trim -r } | where ($it | str length) > 0)
    }

    # Fallback to chafa block character rendering
    let chafa_out = (do { ^chafa -s $"($width)x($height)" --symbols block $target_path } | complete)
    if $chafa_out.exit_code == 0 and ($chafa_out.stdout | str trim | is-not-empty) {
        return ($chafa_out.stdout | split row -r '\r?\n' | each { |l| $l | str trim -r } | where ($it | str length) > 0)
    }

    return []
}

# Detects if the current terminal supports the Kitty Graphics Protocol
export def _h-is-kitty-supported [] {
    if ($env.MOCK_KITTY_SUPPORTED? | is-not-empty) {
        return ($env.MOCK_KITTY_SUPPORTED == true or $env.MOCK_KITTY_SUPPORTED == "true")
    }
    let term_prog = ($env.TERM_PROGRAM? | default "" | str lowercase)
    let term_val = ($env.TERM? | default "" | str lowercase)
    let kitty_pid = ($env.KITTY_PID? | default "")

    if ($term_prog in ["ghostty", "kitty", "wezterm"]) or ($kitty_pid | is-not-empty) or ($term_val =~ "kitty") {
        return true
    }
    return false
}

# Generates a Kitty Graphics Protocol escape sequence with cursor preservation (C=1)
export def _h-get-kitty-avatar-seq [
    avatar_path?: string
    --width: int = 22
    --height: int = 9
] {
    if ($env.MOCK_HABITICA_KITTY_SEQ? | is-not-empty) {
        return $env.MOCK_HABITICA_KITTY_SEQ
    }

    let target_path = ($avatar_path | default ($env.MY_ENV_VARS?.habitica_avatar? | default ""))
    if ($target_path | is-empty) or (not ($target_path | path exists)) {
        return ""
    }

    let b64_path = ($target_path | encode base64)
    return $"\u{1b}_Ga=T,f=100,t=f,C=1,c=($width),r=($height);($b64_path)\u{1b}\\"
}

# Renders Habitica user stats using high-resolution Kitty Graphics Protocol
export def _h-render-kitty-stats-panel [
    stats: record
    --avatar-seq: string = ""
] {
    let reset = (ansi reset)
    let bold = (ansi default_bold)
    let dim = (ansi default_dimmed)
    let underline = (ansi default_underline)
    let cyan = (ansi cyan)
    let cyan_bold = (ansi cyan_bold)
    let yellow_bold = (ansi yellow_bold)
    let green_bold = (ansi green_bold)
    let red_bold = (ansi red_bold)
    let magenta_bold = (ansi magenta_bold)

    let hp_color = if $stats.hp_val < 15 {
        $red_bold
    } else if $stats.hp_val < 30 {
        $yellow_bold
    } else {
        $green_bold
    }

    let exp_pct = if $stats.to_next_level > 0 {
        (($stats.exp_val * 100.0) / $stats.to_next_level) | math round
    } else {
        0
    }

    let dailies_status = if $stats.dailys_to_complete == 0 {
        $"($green_bold)✓ 0 pending($reset)"
    } else {
        $"($yellow_bold)⚠ ($stats.dailys_to_complete) pending($reset)"
    }

    let todos_status = if $stats.todos_to_complete == 0 {
        $"($dim)0 pending($reset)"
    } else {
        $"($bold)($stats.todos_to_complete) pending($reset)"
    }

    let login_status = if $stats.logged_in_today {
        $"($green_bold)✓ Checked in today($reset)"
    } else {
        $"($yellow_bold)⚠ Needs daily login / cron($reset)"
    }

    let quest_status = if $stats.pending_quest {
        $"($yellow_bold)✉ Invitation pending: ($stats.quest_key)($reset)"
    } else if $stats.in_quest {
        $"($green_bold)⚔ ($stats.quest_key)($reset) ($dim)\(($stats.quest_progress)\)($reset)"
    } else {
        $"($dim)No active quest($reset)"
    }

    let left_lines = [
        $"($underline)($bold)Vitals & Attributes($reset)"
        $"  ($bold)HP:($reset)   ($hp_color)($stats.hp)($reset)    ($dim)|($reset)  ($bold)MP:($reset)   ($cyan_bold)($stats.mana)($reset)"
        $"  ($bold)EXP:($reset)  ($yellow_bold)($stats.experience)($reset) ($dim)\(($exp_pct)%\)($reset)"
        ""
        $"($underline)($bold)Tasks & Routine($reset)"
        $"  ($bold)Dailies due today:($reset) ($dailies_status)"
        $"  ($bold)Active To-Dos:($reset)     ($todos_status)"
        $"  ($bold)Daily Check-in:($reset)    ($login_status)"
        ""
        $"($underline)($bold)Quest & Party($reset)"
        $"  ($bold)Quest:($reset) ($quest_status)"
    ]

    let has_avatar = ($avatar_seq | is-not-empty)
    let left_width = 46
    let avatar_width = 24
    let inner_width = if $has_avatar { $left_width + 2 + $avatar_width } else { $left_width }
    let max_rows = 11

    let rows = (0..($max_rows - 1) | each { |i|
        let l = if $i < ($left_lines | length) { $left_lines | get $i } else { "" }
        let l_clean = ($l | str replace -a -r '[\r\n]' "")
        let l_vis = ($l_clean | ansi strip | split chars | length)
        let l_pad_len = [($left_width - $l_vis) 0] | math max
        let l_pad = ("" | fill -a left -c " " -w $l_pad_len)

        if $has_avatar {
            let r_pad = ("" | fill -a left -c " " -w $avatar_width)
            let img_trigger = if $i == 1 { $avatar_seq } else { "" }
            $"($cyan)│($reset) ($l_clean)($l_pad)  ($img_trigger)($r_pad) ($cyan)│($reset)"
        } else {
            $"($cyan)│($reset) ($l_clean)($l_pad) ($cyan)│($reset)"
        }
    })

    let class_name = ($stats.class | default "warrior" | str capitalize)
    let title = $" ($bold)($cyan_bold)($stats.name)($reset) ($dim)|($reset) ($yellow_bold)Lvl ($stats.level)($reset) ($magenta_bold)($class_name)($reset) "
    let title_vis = ($title | ansi strip | split chars | length)
    let top_pad_len = [($inner_width - $title_vis + 2) 0] | math max
    let top_left = ($top_pad_len // 2)
    let top_right = $top_pad_len - $top_left
    let top_bar = $"($cyan)╭("─" | fill -c "─" -w $top_left)($reset)($title)($cyan)("─" | fill -c "─" -w $top_right)╮($reset)"

    let subtitle = $" ($dim)Habitica Character Card($reset) "
    let sub_vis = ($subtitle | ansi strip | split chars | length)
    let bot_pad_len = [($inner_width - $sub_vis + 2) 0] | math max
    let bot_left = ($bot_pad_len // 2)
    let bot_right = $bot_pad_len - $bot_left
    let bot_bar = $"($cyan)╰("─" | fill -c "─" -w $bot_left)($reset)($subtitle)($cyan)("─" | fill -c "─" -w $bot_right)╯($reset)"

    [$top_bar] | append $rows | append $bot_bar | str join (char nl)
}

# Renders Habitica user stats in a styled pure ANSI character card panel
export def _h-render-stats-panel [
    stats: record
    --avatar-lines: list<string> = []
] {
    let reset = (ansi reset)
    let bold = (ansi default_bold)
    let dim = (ansi default_dimmed)
    let underline = (ansi default_underline)
    let cyan = (ansi cyan)
    let cyan_bold = (ansi cyan_bold)
    let yellow_bold = (ansi yellow_bold)
    let green_bold = (ansi green_bold)
    let red_bold = (ansi red_bold)
    let magenta_bold = (ansi magenta_bold)

    let hp_color = if $stats.hp_val < 15 {
        $red_bold
    } else if $stats.hp_val < 30 {
        $yellow_bold
    } else {
        $green_bold
    }

    let exp_pct = if $stats.to_next_level > 0 {
        (($stats.exp_val * 100.0) / $stats.to_next_level) | math round
    } else {
        0
    }

    let dailies_status = if $stats.dailys_to_complete == 0 {
        $"($green_bold)✓ 0 pending($reset)"
    } else {
        $"($yellow_bold)⚠ ($stats.dailys_to_complete) pending($reset)"
    }

    let todos_status = if $stats.todos_to_complete == 0 {
        $"($dim)0 pending($reset)"
    } else {
        $"($bold)($stats.todos_to_complete) pending($reset)"
    }

    let login_status = if $stats.logged_in_today {
        $"($green_bold)✓ Checked in today($reset)"
    } else {
        $"($yellow_bold)⚠ Needs daily login / cron($reset)"
    }

    let quest_status = if $stats.pending_quest {
        $"($yellow_bold)✉ Invitation pending: ($stats.quest_key)($reset)"
    } else if $stats.in_quest {
        $"($green_bold)⚔ ($stats.quest_key)($reset) ($dim)\(($stats.quest_progress)\)($reset)"
    } else {
        $"($dim)No active quest($reset)"
    }

    let left_lines = [
        $"($underline)($bold)Vitals & Attributes($reset)"
        $"  ($bold)HP:($reset)   ($hp_color)($stats.hp)($reset)    ($dim)|($reset)  ($bold)MP:($reset)   ($cyan_bold)($stats.mana)($reset)"
        $"  ($bold)EXP:($reset)  ($yellow_bold)($stats.experience)($reset) ($dim)\(($exp_pct)%\)($reset)"
        ""
        $"($underline)($bold)Tasks & Routine($reset)"
        $"  ($bold)Dailies due today:($reset) ($dailies_status)"
        $"  ($bold)Active To-Dos:($reset)     ($todos_status)"
        $"  ($bold)Daily Check-in:($reset)    ($login_status)"
        ""
        $"($underline)($bold)Quest & Party($reset)"
        $"  ($bold)Quest:($reset) ($quest_status)"
    ]

    let has_avatar = ($avatar_lines | is-not-empty)
    let left_width = 46
    let avatar_width = 24
    let inner_width = if $has_avatar { $left_width + 2 + $avatar_width } else { $left_width }

    let max_rows = if $has_avatar {
        [($left_lines | length) ($avatar_lines | length)] | math max
    } else {
        $left_lines | length
    }

    let rows = (0..($max_rows - 1) | each { |i|
        let l = if $i < ($left_lines | length) { $left_lines | get $i } else { "" }
        let l_clean = ($l | str replace -a -r '[\r\n]' "")
        let l_vis = ($l_clean | ansi strip | split chars | length)
        let l_pad_len = [($left_width - $l_vis) 0] | math max
        let l_pad = ("" | fill -a left -c " " -w $l_pad_len)

        if $has_avatar {
            let r = if $i < ($avatar_lines | length) { $avatar_lines | get $i } else { "" }
            let r_clean = ($r | str replace -a -r '[\r\n]' "")
            let r_vis = ($r_clean | ansi strip | split chars | length)
            let r_pad_len = [($avatar_width - $r_vis) 0] | math max
            let r_pad = ("" | fill -a left -c " " -w $r_pad_len)
            $"($cyan)│($reset) ($l_clean)($l_pad)  ($r_clean)($r_pad) ($cyan)│($reset)"
        } else {
            $"($cyan)│($reset) ($l_clean)($l_pad) ($cyan)│($reset)"
        }
    })

    let class_name = ($stats.class | default "warrior" | str capitalize)
    let title = $" ($bold)($cyan_bold)($stats.name)($reset) ($dim)|($reset) ($yellow_bold)Lvl ($stats.level)($reset) ($magenta_bold)($class_name)($reset) "
    let title_vis = ($title | ansi strip | split chars | length)
    let top_pad_len = [($inner_width - $title_vis + 2) 0] | math max
    let top_left = ($top_pad_len // 2)
    let top_right = $top_pad_len - $top_left
    let top_bar = $"($cyan)╭("─" | fill -c "─" -w $top_left)($reset)($title)($cyan)("─" | fill -c "─" -w $top_right)╮($reset)"

    let subtitle = $" ($dim)Habitica Character Card($reset) "
    let sub_vis = ($subtitle | ansi strip | split chars | length)
    let bot_pad_len = [($inner_width - $sub_vis + 2) 0] | math max
    let bot_left = ($bot_pad_len // 2)
    let bot_right = $bot_pad_len - $bot_left
    let bot_bar = $"($cyan)╰("─" | fill -c "─" -w $bot_left)($reset)($subtitle)($cyan)("─" | fill -c "─" -w $bot_right)╯($reset)"

    [$top_bar] | append $rows | append $bot_bar | str join (char nl)
}

# Gets user stats
export def "h stats" [
    --show-avatar(-s) # Show habitica avatar image
    --no-avatar       # Suppress avatar rendering even on wide terminals
    --kitty(-k)       # Use high-resolution Kitty Graphics Protocol if supported
    --raw(-r)         # Return raw structured record
] {
    let stats = _h-user-stats

    if $raw {
        return $stats
    }

    let cols = if ($env.MOCK_TERM_COLUMNS? | is-not-empty) {
        $env.MOCK_TERM_COLUMNS
    } else {
        try { (term size).columns } catch { 80 }
    }

    let avatar_file = ($env.MY_ENV_VARS?.habitica_avatar? | default "")
    let has_avatar_file = ($avatar_file | is-not-empty) and ($avatar_file | path exists)

    if $kitty and $has_avatar_file and (_h-is-kitty-supported) and not $no_avatar {
        let avatar_seq = (_h-get-kitty-avatar-seq $avatar_file --width 22 --height 9)
        return (_h-render-kitty-stats-panel $stats --avatar-seq $avatar_seq)
    }

    if $has_avatar_file and not $no_avatar {
        if $cols >= 80 {
            let avatar_lines = (_h-get-avatar-lines $avatar_file --width 24 --height 10)
            return (_h-render-stats-panel $stats --avatar-lines $avatar_lines)
        } else {
            # On narrow terminal, show standalone preview before the compact single-column card
            if ($env.MOCK_TIMG_INVOCATION? | is-not-empty) {
                do $env.MOCK_TIMG_INVOCATION $avatar_file
            } else {
                try { if (which timg | is-not-empty) { ^timg -pq --grid=1 -W $avatar_file } } catch { }
            }
            return (_h-render-stats-panel $stats)
        }
    }

    return (_h-render-stats-panel $stats)
}

const types = ["dailys", "todos", "habits", "rewards", "completedTodos"]
const add_types = ["dailys", "todos", "habits"]

# Lists user tasks
export def "h ls" [
  task_type?: string@$types # Type of task to list (dailys, todos, habits, rewards, completedTodos)
  --pending(-p) #show pending dailys only
  --now(-n)   #show todays dailys only
  --no-id(-i) #hide task ids
  --tags(-t)  #show only tasks with tags
  --label(-l): string #filter by label name
] {
  let tags_map = try {
    _h-request "GET" "/api/v3/tags"
    | get data
    | reduce -f {} {|tag, acc| $acc | insert $tag.id $tag.name}
  } catch { {} }
  
  let task_type = _h-input $task_type "Select task type: " --options $types

  if ($task_type not-in $types) {
    return-error "Invalid task type"
  }

  let response = _h-request "GET" "/api/v3/tasks/user" --params { type: $task_type } | get data

  match $task_type {
    "dailys" => {
      $response
      | select _id frequency text notes checklist tags completed isDue 
      | sort-by frequency
      | if $pending {
            where completed == false and isDue == true 
      } else if $now {
            where isDue == true
      } else {
            $in
      }
    }
    "todos" => {
      $response
      | select _id text notes checklist tags completed createdAt
      | sort-by createdAt
    }
    "habits" => {
      $response
      | select _id frequency text notes tags up down createdAt
      | sort-by createdAt
    }
    "rewards" => {
      $response
    }
    "completedTodos" => {
      $response
      | select _id text notes checklist tags createdAt dateCompleted
      | sort-by createdAt
    }
  }
  | insert label_name {|task|
      $task.tags
      | each {|tag_id| $tags_map | get -o $tag_id | default $tag_id}
      | str join ", "
    }
  | if $label != null {
      where {|t|
        $t.tags | any {|tag_id|
          ($tags_map | get -o $tag_id | default $tag_id | str lowercase) == ($label | str lowercase)
        }
      }
    } else {
      $in
    }
  | if $no_id {
      reject _id    
    } else {
      $in
    }
  | if $tags {
    where {|t| $t.tags | is-not-empty}
  } else {
    $in
  }
}

# Completes a daily task
export def "h complete-daily" [
  task_id: string # The ID of the daily task to complete
  --verbose(-v)
  --dry-run # Return payload without sending
  --allow-errors # Return result record instead of throwing error
] {
  if $dry_run {
    return { task_id: $task_id, action: "score/up" }
  }

  let response = if $allow_errors {
    _h-request "POST" $"/api/v3/tasks/($task_id)/score/up" --allow-errors
  } else {
    _h-request "POST" $"/api/v3/tasks/($task_id)/score/up"
  }

  if ($response.success? | default true) != false {
    if $verbose {
      print (echo-g $"Successfully completed task ID: ($task_id)")
    }
    return $response
  } else {
    if $allow_errors {
      return $response
    }
    return-error $"Failed to complete task: ($response.message? | default 'Unknown error')"
  }
}

# Marks all due and incomplete daily tasks as complete
export def "h mark-dailys-done" [--verbose(-v)] {
  let dailys_to_complete = try {
    _h-request "GET" "/api/v3/tasks/user" --params { type: "dailys" }
    | get data
    | where completed == false and isDue == true
  } catch { |e|
    try { rich print $"[bold red]Failed to fetch daily tasks:[/] ($e.msg)" } catch { print (echo-r $"Failed to fetch daily tasks: ($e.msg)") }
    return
  }

  if ($dailys_to_complete | is-empty) {
    try { rich print "[dim]No due and incomplete daily tasks found to mark as done.[/]" } catch { print (echo-r "No due and incomplete daily tasks found to mark as done.") }
    return
  }
  
  let total = $dailys_to_complete | length
  mut index = 0
  mut completed_count = 0
  mut failed_tasks = []
  
  try { rich rule "Completing Habitica Dailies" --style "bold cyan" } catch { }

  for $daily in $dailys_to_complete {
    let res = h complete-daily $daily._id --allow-errors

    if ($res.success? | default true) != false {
      $completed_count = $completed_count + 1
      if $verbose {
        try { rich print $"  [bold green]✓[/] [bold]($daily.text)[/]" } catch { print (echo-g $"✓ ($daily.text)") }
      }
    } else {
      let err_msg = $res.message? | default "Request failed"
      $failed_tasks = ($failed_tasks | append { id: $daily._id, text: $daily.text, error: $err_msg })
      if $verbose {
        try { rich print $"  [bold red]✗ Failed: ($daily.text)[/] - ($err_msg)" } catch { print (echo-r $"FAILED: ($err_msg)") }
      }
    }

    if not $verbose {
      progress_bar ($index + 1) $total
    }
    $index = $index + 1
    sleep 2sec
  }
  
  let final_completed = $completed_count
  let final_failed = $failed_tasks
  if ($final_failed | is-not-empty) {
    try {
      $"Completed ($final_completed)/($total) dailies.\n($final_failed | length) failed."
        | rich panel --title "Habitica Dailies Result" --border-style red
    } catch {
      print (echo-r $"\nCompleted ($final_completed)/($total) dailies. ($final_failed | length) failed:")
      for $f in $final_failed {
        print (echo-r $"  - ($f.text): ($f.error)")
      }
    }
  } else {
    try {
      $"All ($total) due and incomplete daily tasks marked as done."
        | rich panel --title "Habitica Dailies Complete" --border-style green
    } catch {
      if $verbose {
        print (echo-g "All due and incomplete daily tasks marked as done.")
      }
    }
  }
}

# Adds a new task (daily or todo)
export def "h add" [
  task_type?: string@$add_types # Type of task to add (dailys, todos, habits)
  --text(-t): string # Task text
  --notes(-n): string # Task notes
  --priority(-p): number # Task priority (1, 1.5, 2, 2.5)
  --due(-d): string # Due date (YYYY-MM-DD) for todos
  --checklist(-c): list<string> # Checklist items for todos
  --frequency(-f): string # frequency (daily, weekly, monthly, yearly) for dailys
  --every-x(-x): int # Repeat every X days/weeks/etc.
  --days(-s): list<string> # Days of week for weekly dailys (m, t, w, th, f, s, su)
  --direction(-r): string # Direction for habits (positive, negative, both)
  --tag-id: list<string> # Tag UUIDs to attach to task
  --tag-name: list<string> # Tag names to attach to task (case-insensitive)
  --dry-run # Return payload without sending
] {
  let headers = h credentials

  if ($tag_id != null) and ($tag_name != null) {
    return-error "Cannot use both --tag-id and --tag-name. Choose one."
  }

  # Resolve tag flags: fetch /api/v3/tags, validate IDs or resolve names to UUIDs
  let resolved_tags = if ($tag_id != null) or ($tag_name != null) {
    let tags_data = try {
      _h-request "GET" "/api/v3/tags" | get data
    } catch {
      return-error "Failed to fetch tags from Habitica API"
    }

    if ($tag_id != null) {
      let valid_ids = $tags_data | get id
      let invalid = $tag_id | where {|id| $id not-in $valid_ids}
      if ($invalid | is-not-empty) {
        return-error $"Invalid tag ID: ($invalid | str join ', ')"
      }
      $tag_id
    } else {
      let names_lower = $tag_name | each {|n| $n | str lowercase}
      let invalid = $names_lower | where {|n|
        ($tags_data | where {|t| ($t.name | str lowercase) == $n} | is-empty)
      }
      if ($invalid | is-not-empty) {
        return-error $"Tag not found: ($invalid | str join ', ')"
      }
      $names_lower | each {|n|
        $tags_data | where {|t| ($t.name | str lowercase) == $n} | first | get id
      }
    }
  } else {
    []
  }
  
  let task_type = _h-input $task_type "Select task type: " --options $add_types

  if ($task_type not-in ["dailys", "todos", "habits"]) {
    return-error "Invalid task type. Must be 'dailys', 'todos', or 'habits'."
  }

  let task_text = _h-input $text "Enter task text (required): "
  if ($task_text | is-empty) {
    return-error "Task text is required."
  }

  let task_notes = _h-input $notes "Enter notes (optional): "
  
  let task_priority = if ($priority != null) {
    $priority
  } else {
    let task_priority_options = ["Trivial (1)", "Easy (1.5)", "Medium (2)", "Hard (2.5)"]
    let task_priority_input = _h-input null "Select priority (optional): " --options $task_priority_options
    match $task_priority_input {
        "Trivial (1)" => 1.0,
        "Easy (1.5)" => 1.5,
        "Medium (2)" => 2.0,
        "Hard (2.5)" => 2.5,
        _ => null
    }
  }

  let task_singular = match $task_type {
    "dailys" => "daily",
    "todos" => "todo",
    "habits" => "habit",
    _ => $task_type
  }

  mut payload = {
    text: $task_text,
    type: $task_singular,
  }

  if ($task_notes | is-not-empty) {
    $payload = ($payload | upsert notes $task_notes)
  }
  if ($task_priority != null) {
    $payload = ($payload | upsert priority $task_priority)
  }

  match $task_type {
    "todos" => {
      let task_date = _h-input $due "Enter due date (YYYY-MM-DD, optional): "
      if ($task_date | is-not-empty) {
        # Convert to ISO 8601 format
        let iso_date = ($task_date | into datetime | format date "%+")
        $payload = ($payload | upsert date $iso_date)
      }

      let checklist_data = if ($checklist != null) {
        $checklist | each { |it| {text: $it, completed: false} }
      } else {
        mut list = []
        loop {
            let checklist_item = input "Enter checklist item (leave empty to finish): "
            if ($checklist_item | is-empty) {
                break
            }
            $list = ($list | append {text: $checklist_item, completed: false})
        }
        $list
      }
      
      if ($checklist_data | is-not-empty) {
        $payload = ($payload | upsert checklist $checklist_data)
      }
    }
    "dailys" => {
      let frequency_options = ["daily", "weekly", "monthly", "yearly"]
      let task_frequency = _h-input $frequency "Select frequency (required): " --options $frequency_options
      
      if ($task_frequency | is-empty) {
        return-error "Frequency is required for daily tasks."
      }
      $payload = ($payload | upsert frequency $task_frequency)

      if ($task_frequency == "daily") {
        let every_x_input = if ($every_x != null) {
            $every_x
        } else {
            let input_val = input "Repeat every X days (optional, e.g., 2 for every other day): "
            if ($input_val | is-not-empty) { $input_val | into int } else { null }
        }
        
        if ($every_x_input != null) {
          $payload = ($payload | upsert everyX $every_x_input)
        }
      } else if ($task_frequency == "weekly") {
        let days_of_week = ["m", "t", "w", "th", "f", "s", "su"]
        mut repeats = {}
        
        if ($days != null) {
            for $day in $days_of_week {
                if ($day in $days) {
                    $repeats = ($repeats | upsert $day true)
                } else {
                    $repeats = ($repeats | upsert $day false)
                }
            }
        } else {
            for $day in $days_of_week {
                let repeat_day = input $"Repeat on ($day)? (y/n): "
                if ($repeat_day == "y") {
                    $repeats = ($repeats | upsert $day true)
                } else {
                    $repeats = ($repeats | upsert $day false)
                }
            }
        }
        $payload = ($payload | upsert repeats $repeats)
      }
    }
    "habits" => {
      let direction_options = ["positive", "negative", "both"]
      let task_direction = _h-input $direction "Select direction (required): " --options $direction_options
      
      $payload = match $task_direction {
        "positive" => ($payload | upsert up true | upsert down false),
        "negative" => ($payload | upsert up false | upsert down true),
        "both" => ($payload | upsert up true | upsert down true),
        _ => $payload
      }
    }
  }

  if ($resolved_tags | is-not-empty) {
    $payload = ($payload | upsert tags $resolved_tags)
  }

  if ($dry_run) { return $payload }

  let response = _h-request "POST" "/api/v3/tasks/user" --body $payload --allow-errors
  
  if ($response.success? | default true) != false {
    let task_title = $response.data?.text? | default $task_text
    print (echo-g $"Successfully added ($task_type) task: ($task_title)")
  } else {
    let err_msg = $response.message? | default "Failed to add task"
    print (echo-r $"Failed to add ($task_type) task: ($err_msg)")
  }
}

# Deletes a task (daily, todo, habit)
export def "h del" [
  task_type?: string@$add_types # Type of task to delete (dailys, todos, habits)
  --id: string # Task ID to delete
  --text(-t): string # Task text to delete (first match)
  --dry-run # Return payload without sending
] {
  let task_type = _h-input $task_type "Select task type to delete: " --options $add_types

  if ($task_type not-in ["dailys", "todos", "habits"]) {
    return-error "Invalid task type for deletion. Must be 'dailys', 'todos', or 'habits'."
  }

  let task_to_delete = if ($id | is-not-empty) {
    { _id: $id }
  } else if ($text | is-not-empty) {
    let tasks = h ls $task_type
    let found = $tasks | where text == $text
    if ($found | is-empty) {
        return-error $"No ($task_type) task found with text: ($text)"
    }
    $found | get 0
  } else {
    let tasks = h ls $task_type | reverse

    if ($tasks | is-empty) {
        print (echo-r $"No ($task_type) tasks found to delete.")
        return
    }

    let idx_task_to_delete = _h-input null "Select task to delete: " --options $tasks --id
    $tasks | get $idx_task_to_delete
  }
  
  if ($dry_run) { return $task_to_delete }

  let response = _h-request "DELETE" $"/api/v3/tasks/($task_to_delete._id)" --allow-errors

  if ($response.success? | default true) != false {
    let task_text = $task_to_delete.text? | default $task_to_delete._id
    print (echo-g $"Successfully deleted ($task_type) task: ($task_text)")
  } else {
    let err_msg = $response.message? | default "Failed to delete task"
    print (echo-r $"Failed to delete ($task_type) task: ($err_msg)")
  }
}

# Marks selected todo tasks as completed
export def "h complete-todos" [
    --ids: list<string> # Task IDs to complete
    --texts: list<string> # Task texts to complete
    --dry-run # Return payload without sending
] {
    let headers = h credentials

    let todos = h ls todos | where completed == false | reverse

    if ($todos | is-empty) {
        try { rich print "[dim]No incomplete todo tasks found to complete.[/]" } catch { print (echo-r "No incomplete todo tasks found to complete.") }
        return
    }

    let selected_todos = if ($ids != null) {
        $todos | where _id in $ids
    } else if ($texts != null) {
        $todos | where text in $texts
    } else {
        let selected_indices = _h-input null "Select todos to complete (use space to multi-select): " --options $todos --multi
        $todos | enumerate | where index in $selected_indices | get item
    }
    
    if ($dry_run) { return $selected_todos }

    try { rich rule "Completing Habitica To-Dos" --style "bold cyan" } catch { }
    mut completed_count = 0
    mut failed_count = 0

    for $todo in $selected_todos {
        let response = _h-request "POST" $"/api/v3/tasks/($todo._id)/score/up" --allow-errors

        if ($response.success? | default true) != false {
            $completed_count = $completed_count + 1
            try { rich print $"  [bold green]✓[/] Completed: [bold]($todo.text)[/]" } catch { print (echo-g $"✓ ($todo.text)") }
        } else {
            $failed_count = $failed_count + 1
            let err_msg = $response.message? | default "Request failed"
            try { rich print $"  [bold red]✗ Failed:[/] ($todo.text) - ($err_msg)" } catch { print (echo-r $"FAILED: ($todo.text) - ($err_msg)") }
        }

        sleep 2sec
    }

    let final_completed = $completed_count
    let final_failed = $failed_count
    let total_selected = $selected_todos | length

    if $final_failed > 0 {
        try {
            $"Completed ($final_completed)/($total_selected) to-dos.\n($final_failed) failed."
                | rich panel --title "Habitica To-Dos Result" --border-style red
        } catch { }
    } else {
        try {
            $"All ($final_completed) selected to-do item(s) marked as completed!"
                | rich panel --title "Habitica To-Dos Complete" --border-style green
        } catch { }
    }
}

# Define the function to score habits
export def "h score-habits" [
    --ids: list<string> # Habit IDs to score
    --texts: list<string> # Habit texts to score
    --direction(-d): string # Direction to score (up, down)
    --dry-run # Return payload without sending
] {
    # Fetch the list of habits
    let habits = h ls habits | reverse

    # Check if the list is empty
    if ($habits | is-empty) {
        print (echo-r "No habits found.")
        return
    }

    # Selection logic
    let selected_habits = if ($ids != null) {
        $habits | where _id in $ids
    } else if ($texts != null) {
        $habits | where text in $texts
    } else {
        let selected_indices = $habits | input list -ifmd text (echo-g "Select habits to score: ")
        $habits | enumerate | where index in $selected_indices | get item
    }
    
    if ($dry_run) { return { habits: $selected_habits, direction: $direction } }
    
    # Loop over the selected habits
    for $habit in $selected_habits {
        # Determine available directions for the habit
        mut directions = []
        if $habit.up {
            $directions = $directions | append "up"
        }
        if $habit.down {
            $directions = $directions | append "down"
        }

        # Check if the habit has no available directions
        if ($directions | is-empty) {
            print $"Habit '($habit.text)' cannot be scored since there are no directions enabled."
            continue
        }

        # Direction logic
        let score_dir = if ($direction != null) {
            if ($direction in $directions) {
                $direction
            } else {
                return-error $"Invalid direction '($direction)' for habit '($habit.text)'. Available: ($directions)"
            }
        } else {
             $directions | input list -f $"Choose a direction to score in habit '($habit.text)': "
        }
        
        # Score the habit
        let response = _h-request "POST" $"/api/v3/tasks/($habit._id)/score/($score_dir)" --allow-errors

        # Handle the response
        if ($response.success? | default true) != false {
            print $"Scored habit '($habit.text)' as ($score_dir)."
        } else {
            let err_msg = $response.message? | default "Failed to score habit"
            print $"Failed to score habit '($habit.text)': ($err_msg)"
        }

        # Add a delay to avoid rate limits
        sleep 2sec
    }
}

#skills data
export def "h skills" [] {
    [
        {class: "warrior", name: "Brutal Smash", spellId: "smash", cost: 10, target: "task", level: 11, effect: "+50% damage to a task"},
        {class: "warrior", name: "Defensive Stance", spellId: "defensiveStance", cost: 25, target: "player", level: 12, effect: "-50% damage from Dailies"},
        {class: "warrior", name: "Valorous Presence", spellId: "valorousPresence", cost: 20, target: "player", level: 13, effect: "+100% damage to Boss"},
        {class: "warrior", name: "Intimidating Gaze", spellId: "intimidate", cost: 15, target: "party", level: 14, effect: "+20% damage to Boss for party"},

        {class: "wizard", name: "Burst of Flames", spellId: "fireball", cost: 10, target: "task", level: 11, effect: "+50% experience from a task"},
        {class: "wizard", name: "Ethereal Surge", spellId: "mpheal", cost: 30, target: "player", level: 12, effect: "+50% mana"},
        {class: "wizard", name: "Earthquake", spellId: "earth", cost: 35, target: "task", level: 13, effect: "+100% damage to a task"},
        {class: "wizard", name: "Chilling Frost", spellId: "frost", cost: 40, target: "party", level: 14, effect: "+20% damage to Boss for party"},

        {class: "rogue", name: "Pickpocket", spellId: "pickPocket", cost: 10, target: "task", level: 11, effect: "+50% gold from a task"},
        {class: "rogue", name: "Backstab", spellId: "backStab", cost: 15, target: "task", level: 12, effect: "+100% experience from a task"},
        {class: "rogue", name: "Tools of the Trade", spellId: "toolsOfTrade", cost: 25, target: "party", level: 13, effect: "+20% gold from tasks for party"},
        {class: "rogue", name: "Stealth", spellId: "stealth", cost: 45, target: "player", level: 14, effect: "-50% health from unticked Dailies"},

        {class: "healer", name: "Healing Light", spellId: "heal", cost: 15, target: "player", level: 11, effect: "+50% health"},
        {class: "healer", name: "Searing Brightness", spellId: "brightness", cost: 15, target: "task", level: 12, effect: "+100% experience from a task"},
        {class: "healer", name: "Protective Aura", spellId: "protectAura", cost: 30, target: "party", level: 13, effect: "-50% damage from Boss for party"},
        {class: "healer", name: "Blessing", spellId: "healAll", cost: 25, target: "party", level: 14, effect: "+20% experience from tasks for party"}
    ]
}

# Casts a skill
export def "h skill" [
    skill_name?: string # The name of the skill to cast
] {
    let headers = h credentials
    let base_url = "https://habitica.com"
    let user_stats = _h-user-stats
    let user_class = $user_stats.class

    let skills_data = h skills

    let available_skills = $skills_data | where class == $user_class

    let selected_skill = if ($skill_name | is-empty) {
        if ($available_skills | is-empty) {
            print (echo-r $"No skills available for your class: ($user_class).")
            return
        }
        _h-input null "Select a skill to cast: " --options $available_skills --id
    } else {
        let skill_found = $available_skills | where name == $skill_name
        if ($skill_found | is-empty) {
            print (echo-r $"Skill '($skill_name)' not found for your class: ($user_class).")
            return
        }
        $skill_found | get 0
    }

    let spell_id = $selected_skill.spellId

    print (echo-g $"Casting skill: ($selected_skill.name) Cost: ($selected_skill.cost) MP")
    let response = _h-request "POST" $"/api/v3/user/class/cast/($spell_id)" --allow-errors

    if ($response.success? | default true) != false {
        print (echo-g $"Successfully cast skill: ($selected_skill.name).")
    } else {
        let err_msg = $response.message? | default "Failed to cast skill"
        print (echo-r $"Failed to cast skill: ($selected_skill.name). Message: ($err_msg)")
    }
}

# Casts a skill multiple times based on available mana
export def "h skill-max" [
    skill_name?: string # The name of the skill to cast multiple times
] {
    let user_stats = _h-user-stats
    let user_class = $user_stats.class
    let current_mana_str = $user_stats.mana

    # Extract current mana value (e.g., "50/100" -> 50)
    let current_mana = $current_mana_str | split row "/" | get 0 | into int

    let skills_data = h skills

    let available_skills = $skills_data | where class == $user_class

    let selected_skill = if ($skill_name | is-empty) {
        if ($available_skills | is-empty) {
            print (echo-r $"No skills available for your class: ($user_class).")
            return
        }
        _h-input null "Select a skill to cast multiple times: " --options $available_skills --id
    } else {
        let skill_found = $available_skills | where name == $skill_name
        if ($skill_found | is-empty) {
            print (echo-r $"Skill '($skill_name)' not found for your class: ($user_class).")
            return
        }
        $skill_found | get 0
    }

    let skill_cost = $selected_skill.cost

    if ($skill_cost == 0) {
        print (echo-r $"Skill '($selected_skill.name)' has no mana cost. Cannot use skill-max.")
        return
    }

    let times_to_cast = ($current_mana / $skill_cost) | math floor | into int

    if ($times_to_cast == 0) {
        print (echo-r $"Not enough mana to cast '($selected_skill.name)'. Current Mana: ($current_mana) MP, Skill Cost: ($skill_cost) MP.")
        return
    }

    print (echo-g $"Attempting to cast '($selected_skill.name)' ($times_to_cast) times. Total Mana Cost: ($times_to_cast * $skill_cost) MP.")

    let spell_id = $selected_skill.spellId
    
    for i in (seq 1 $times_to_cast) {
        progress_bar $i $times_to_cast

        _h-request "POST" $"/api/v3/user/class/cast/($spell_id)" --allow-errors | ignore
        sleep 2sec
    }

    print (echo-g $"Finished casting '($selected_skill.name)' ($times_to_cast) times.")
}

# Logs in to Habitica and runs cron
export def "h login" [] {
    try { rich rule "Habitica Daily Login & Cron" --style "bold cyan" } catch { }
    let stats = _h-user-stats
    if ($stats.dailys_to_complete > 0) {
        try { rich print $"  [yellow]Completing ($stats.dailys_to_complete) pending daily tasks first...[/]" } catch { print "Completing pending daily tasks..." }
        h mark-dailys-done
    }
        
    if $stats.logged_in_today {
        try {
          "✓ Already logged in today. Cron has already run."
            | rich panel --title "Habitica Status" --border-style green
        } catch {
          print (echo-g "Already logged in today.")
        }
        return
    }

    let response = _h-request "POST" "/api/v3/cron" --allow-errors

    if ($response.success? | default true) != false {
        try {
          "✓ Successfully logged in to Habitica and triggered daily cron."
            | rich panel --title "Habitica Cron Complete" --border-style green
        } catch {
          print (echo-g "Successfully logged in to Habitica.")
        }
        return
    } 
    let err_msg = $response.message? | default "Failed to log in"
    try {
      $"✗ Failed to log in to Habitica: ($err_msg)"
        | rich panel --title "Habitica Cron Error" --border-style red
    } catch {
      print (echo-r $"Failed to log in to Habitica: ($err_msg)")
    }
}

# Buys a health potion
export def "h buy-potion" [] {
    let response = _h-request "POST" "/api/v3/user/buy-health-potion" --allow-errors

    if ($response.success? | default true) != false {
        print (echo-g "Successfully bought a health potion.")
    } else {
        let err_msg = $response.message? | default "Failed to buy health potion"
        print (echo-r $"Failed to buy a health potion: ($err_msg)")
    }
}

# Buys an item from the armoire
export def "h buy-armoir" [] {
    let response = _h-request "POST" "/api/v3/user/buy-armoire" --allow-errors

    if ($response.success? | default true) != false {
        print (echo-g "Successfully bought an item from the armoire.")
        return ($response.data?.armoire? | default $response.data?)
    } else {
        let err_msg = $response.message? | default "Failed to buy armoire item"
        print (echo-r $"Failed to buy an item from the armoire: ($err_msg)")
    }
}

# Completes a checklist item for a task
export def "h complete-checklist" [
  task_type?: string@$add_types # Type of task to complete checklist for (dailys, todos, habits)
  --id: string # Task ID
  --text(-t): string # Task text
  --indices(-i): list<int> # Checklist item indices to complete
  --items(-s): list<string> # Checklist item texts to complete
  --dry-run # Return payload without sending
] {
  let headers = h credentials
  
  let task_type = _h-input $task_type "Select task type: " --options $add_types

  if ($task_type not-in ["dailys", "todos", "habits"]) {
    return-error "Invalid task type. Must be 'dailys', 'todos', or 'habits'."
  }

  let selected_task = if ($id | is-not-empty) {
    let tasks = h ls $task_type
    let found = $tasks | where _id == $id
    if ($found | is-empty) { return-error $"No ($task_type) task found with ID: ($id)" }
    $found | get 0
  } else if ($text | is-not-empty) {
    let tasks = h ls $task_type
    let found = $tasks | where text == $text
    if ($found | is-empty) { return-error $"No ($task_type) task found with text: ($text)" }
    $found | get 0
  } else {
    let tasks_with_checklist = h ls $task_type | where ($it.checklist | is-not-empty) | reverse
    if ($tasks_with_checklist | is-empty) {
        print (echo-r $"No tasks with checklists found for type '($task_type)'.")
        return
    }
    let selected_task_index = _h-input null "Select a task to complete checklist items for: " --options $tasks_with_checklist --id
    $tasks_with_checklist | get $selected_task_index
  }

  let checklist_items = $selected_task.checklist | where completed == false

  if ($checklist_items | is-empty) {
    print (echo-r "No incomplete checklist items found for this task.")
    return
  }

  let selected_checklist_indices = if ($indices != null) {
    $indices
  } else if ($items != null) {
    $checklist_items | enumerate | where item.text in $items | get index
  } else {
    _h-input null "Select checklist items to complete: " --options $checklist_items --multi
  }

  if ($dry_run) { return { task: $selected_task, item_indices: $selected_checklist_indices } }

  for $index in $selected_checklist_indices {
    let item = $checklist_items | get $index
    let task_id = $selected_task._id
    let item_id = $item.id

    let response = _h-request "POST" $"/api/v3/tasks/($task_id)/checklist/($item_id)/score" --allow-errors

    if ($response.success? | default true) != false {
        print ((echo-g $"Successfully completed checklist item: ") + ($item.text))
    } else {
        let err_msg = $response.message? | default "Failed to complete item"
        print ((echo-r $"Failed to complete checklist item: ") + ($item.text) + (echo-r $". Message: ($err_msg)"))
    }
    sleep 2sec
  }
}

# Adds a checklist item to a task
export def "h add-checklist" [
  task_type?: string@$add_types # Type of task to add checklist item to (dailys, todos, habits)
  --id: string # Task ID
  --text(-t): string # Task text
  --items(-s): list<string> # Checklist items to add
  --dry-run # Return payload without sending
] {
  let task_type = _h-input $task_type "Select task type: " --options $add_types

  if ($task_type not-in ["dailys", "todos", "habits"]) {
    return-error "Invalid task type. Must be 'dailys', 'todos', or 'habits'."
  }

  let selected_task = if ($id | is-not-empty) {
    let tasks = h ls $task_type
    let found = $tasks | where _id == $id
    if ($found | is-empty) { return-error $"No ($task_type) task found with ID: ($id)" }
    $found | get 0
  } else if ($text | is-not-empty) {
    let tasks = h ls $task_type
    let found = $tasks | where text == $text
    if ($found | is-empty) { return-error $"No ($task_type) task found with text: ($text)" }
    $found | get 0
  } else {
    let tasks = h ls $task_type | reverse
    if ($tasks | is-empty) {
        print (echo-r $"No tasks found for type '($task_type)'.")
        return
    }
    let selected_task_index = _h-input null "Select a task to add a checklist item to: " --options $tasks --id
    $tasks | get $selected_task_index
  }

  let checklist_items = if ($items != null) {
    $items
  } else {
    mut list = []
    loop {
        let item_text = input "Enter checklist item (leave empty to finish): "
        if ($item_text | is-empty) {
            break
        }
        $list = ($list | append $item_text)
    }
    $list
  }

  if ($dry_run) { return { task: $selected_task, items: $checklist_items } }

  if ($checklist_items | is-empty) {
    print (echo-r "No checklist items entered.")
    return
  }

  let task_id = $selected_task._id

  for $item in $checklist_items {
    let payload = { text: $item }
    let response = _h-request "POST" $"/api/v3/tasks/($task_id)/checklist" --body $payload --allow-errors

    if ($response.success? | default true) != false {
        print ((echo-g $"Successfully added checklist item '($item)' to task: ") + ($selected_task.text))
    } else {
        let err_msg = $response.message? | default "Failed to add checklist item"
        print ((echo-r $"Failed to add checklist item '($item)'. Message: ") + ($err_msg))
    }
    sleep 2sec
  }
}

# Party info
export def "h party" [] {
    let response = _h-request "GET" "/api/v3/groups/party" --allow-errors
    
    if not (($response.success? | default true) != false) {
        return-error (echo-r $"Failed to get party data: ($response.message? | default 'Unknown error')")
    }
    
    return ($response.data? | default $response)
}

# Accepts a pending quest
export def "h auto-quest" [] {
    let hab_id = get-api-key "habitica.id"

    let party = h party

    if (($party.quest.key? | is-not-empty) and ($party.quest.active? == false) and ($party.quest.members? | get -o $hab_id | is-empty)) {
        try { rich print $"  [cyan]Pending quest found:[/] [bold]($party.quest.key)[/]. Accepting..." } catch { print (echo-g "Pending quest found. Accepting...") }

        let accept_response = _h-request "POST" "/api/v3/groups/party/quests/accept" --allow-errors

        if ($accept_response.success? | default true) != false {
            try { rich print $"  [bold green]✓[/] Successfully accepted quest: [bold]($party.quest.key)[/]." } catch { print (echo-g "Successfully accepted the quest.") }
        } else {
            let err_msg = $accept_response.message? | default "Failed to accept quest"
            try { rich print $"  [bold red]✗ Failed to accept the quest:[/] ($err_msg)" } catch { print (echo-r $"Failed to accept the quest: ($err_msg)") }
        }
    } else {
        try { rich print "  [dim]No pending quests to accept.[/]" } catch { print "No pending quests to accept." }
    }
}

# Show help for Habitica commands
export def "h help" [] {
  try { rich rule "Habitica CLI Commands" --style "bold cyan" } catch { print "Habitica Tools Help:\n" }
  let commands_description = [
    { name: "h add", description: "Adds a new task (daily, todo, habit)" },
    { name: "h add-checklist", description: "Adds a checklist item to a task" },
    { name: "h auto-quest", description: "Accepts a pending quest" },
    { name: "h buy-armoir", description: "Buys an item from the armoire" },
    { name: "h buy-potion", description: "Buys a health potion" },
    { name: "h complete-checklist", description: "Completes a checklist item for a task" },
    { name: "h complete-daily", description: "Completes a daily task" },
    { name: "h complete-todos", description: "Marks selected todo tasks as completed" },
    { name: "h credentials", description: "Get credentials" },
    { name: "h del", description: "Deletes a task (daily, todo, habit)" },
    { name: "h help", description: "Show this help message" },
    { name: "h login", description: "Logs in to Habitica and runs cron" },
    { name: "h ls", description: "Lists user tasks" },
    { name: "h mark-dailys-done", description: "Marks all due and incomplete daily tasks as complete" },
    { name: "h party", description: "Party info" },
    { name: "h score-habits", description: "Score habits" },
    { name: "h skill", description: "Casts a skill" },
    { name: "h skill-max", description: "Casts a skill multiple times" },
    { name: "h skills", description: "Lists skills" },
    { name: "h stats", description: "Gets user stats" },
  ] | sort-by name

  # Calculate the maximum length of the command names for padding
  let max_name_length = $commands_description | get name | str length | math max

  # Format the help text with padding and descriptions
  for cmd in $commands_description {
      let padded_name = $cmd.name | fill -w ($max_name_length + 2) -a left
      try {
          rich print $"  [bold cyan]($padded_name)[/] [dim]#[/] ($cmd.description)"
      } catch {
          print $"  ($padded_name)  # ($cmd.description)"
      }
  }
}

#aliases
export alias hs = h stats -s -k
export alias todos = h ls todos -i 
export alias dailys = h ls dailys -ni

#budget
export def budget [] {
    h ls dailys | find budget | get checklist.0
}

# Private helper for handling flag vs interactive input
export def _h-input [
    flag: any,
    prompt_msg: string,
    --options: any, # List of options for input list
    --multi, # Use multi-select
    --id, # Use -fid text (returns index but shows text)
    --is-list # If true, returns flag directly if not null (for lists)
] {
    if ($flag != null) { return $flag }

    if ($options != null) {
        if $multi {
            $options | input list -ifmd text (echo-g $prompt_msg)
        } else if $id {
            $options | input list -fid text (echo-g $prompt_msg)
        } else {
            $options | input list -f (echo-g $prompt_msg)
        }
    } else {
        input $prompt_msg
    }
}
