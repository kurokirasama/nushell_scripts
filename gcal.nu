#gcalcli wrapper for accesing google calendar
export def "gcal help" [] {
  try { rich rule "Google Calendar CLI (gcalcli)" --style "bold cyan" } catch { print "gcalcli wrapper:\n" }
  let commands = [
    { name: "gcal add", description: "Add event to Google Calendar (interactive, parameterized, or --tui)" },
    { name: "gcal agenda", description: "Show agenda of upcoming events" },
    { name: "gcal semana", description: "Show week schedule view" },
    { name: "gcal mes", description: "Show month schedule view" },
    { name: "gcal list", description: "List all configured Google Calendars" },
  ]
  for cmd in $commands {
      let padded = $cmd.name | fill -w 16 -a left
      try {
          rich print $"  [bold cyan]($padded)[/] [dim]#[/] ($cmd.description)"
      } catch {
          print $"  ($padded)  # ($cmd.description)"
      }
  }
}

# Compute default event start time rounded up to the next full hour in `yyyy.MM.dd HH:mm` format.
export def _gcal-default-when [
  now?: datetime # Reference timestamp (defaults to `date now`)
]: nothing -> string {
  let dt = $now | default (date now)
  let base_hour = $dt | format date "%Y.%m.%d %H:00" | into datetime --format "%Y.%m.%d %H:%M"
  ($base_hour + 1hr) | format date "%Y.%m.%d %H:%M"
}

# Validate `when` string in `yyyy.MM.dd HH:mm` format.
export def _gcal-validate-when [
  when_str: string # Candidate event date/time string
]: nothing -> record<ok: bool, msg: string> {
  let trimmed = $when_str | str trim
  if ($trimmed | is-empty) {
    return { ok: false, msg: "Invalid when '': expected yyyy.MM.dd HH:mm" }
  }
  if $trimmed !~ '^\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}$' {
    return { ok: false, msg: $"Invalid when '($trimmed)': expected yyyy.MM.dd HH:mm" }
  }
  let roundtrip = try {
    $trimmed | into datetime --format "%Y.%m.%d %H:%M" | format date "%Y.%m.%d %H:%M"
  } catch {
    ""
  }
  if $roundtrip != $trimmed {
    return { ok: false, msg: $"Invalid when calendar date/time '($trimmed)': expected yyyy.MM.dd HH:mm" }
  }
  { ok: true, msg: "" }
}

# Validate event duration in minutes as a positive integer.
export def _gcal-validate-duration [
  dur_val: any # Candidate duration in minutes
]: nothing -> record<ok: bool, value: int, msg: string> {
  let trimmed = $dur_val | default "" | into string | str trim
  if $trimmed !~ '^\d+$' {
    return { ok: false, value: 0, msg: $"Invalid duration '($trimmed)': must be a positive integer" }
  }
  let n = $trimmed | into int
  if $n <= 0 {
    return { ok: false, value: 0, msg: $"Invalid duration '($trimmed)': must be > 0" }
  }
  { ok: true, value: $n, msg: "" }
}

# Execute Google Calendar event creation via gcalcli (shared by CLI and --tui paths).
export def _gcal-add-event [
  calendar: string # Target calendar name
  title: string    # Event title
  when: string     # Start time (yyyy.MM.dd HH:mm)
  where: string    # Event location
  duration: any    # Duration in minutes
  --noprompt       # Skip interactive gcalcli prompts for unfilled optional fields
]: nothing -> any {
  try {
    $"Adding Event to Calendar [bold]($calendar)[/]:\nTitle: [bold cyan]($title)[/]\nWhen: [yellow]($when)[/] | Duration: ($duration) mins\nWhere: ($where)"
      | rich panel --title "Google Calendar Event" --box rounded --border-style green
  } catch { }

  if $noprompt {
    run-gcalcli --calendar $"($calendar)" add --title $"($title)" --when $"($when)" --where $"($where)" --duration $"($duration)" --description "" --default-reminders --noprompt
  } else {
    run-gcalcli --calendar $"($calendar)" add --title $"($title)" --when $"($when)" --where $"($where)" --duration $"($duration)" --default-reminders
  }
}

# Build the self-contained `gcal add --tui` form pipeline.
export def _gcal-build-add-form [
  calendars: list<string> # Writable calendar names
  state: record           # Form state { calendar, title, when, where, duration, focus, err }
]: nothing -> any {
  let sel_cal = $state.calendar? | default ""
  let ordered_cals = if ($sel_cal | is-not-empty) and ($sel_cal in $calendars) {
    [$sel_cal] | append ($calendars | where $it != $sel_cal)
  } else {
    $calendars
  }
  let cal_rows = $ordered_cals | each { |c| { calendar: $c } }
  let focus_id = $state.focus? | default "title"
  let err_msg = $state.err? | default ""

  $cal_rows
  | tui label --titlebar "Add Google Calendar Event · Enter: next field · Ctrl+S: Add · Esc: Cancel"
  | if ($err_msg | is-not-empty) {
      tui label $"Error: ($err_msg)"
    } else { }
  | tui box "Calendar" [
      (tui search --id cal_search --fuzzy --placeholder "filter calendars...")
      (tui table --id calendar --title "Calendars" --columns [calendar] --focus=($focus_id == "calendar" or $focus_id == "cal_search"))
    ]
  | tui label "Title:"
  | tui textbox --id title --value ($state.title? | default "") --placeholder "Event title" --focus=($focus_id == "title")
  | tui label "When (yyyy.MM.dd HH:mm):"
  | tui textbox --id when --value ($state.when? | default "") --placeholder "2026.11.18 11:00" --focus=($focus_id == "when")
  | tui label "Where:"
  | tui textbox --id where --value ($state.where? | default "") --placeholder "Location (optional)" --focus=($focus_id == "where")
  | tui label "Duration (minutes):"
  | tui textbox --id duration --value ($state.duration? | default "60") --placeholder "60" --focus=($focus_id == "duration")
  | tui button --id btn_add "Add (Ctrl+S)" { || { action: submit, selected: { op: "add" } } }
  | tui button --id btn_cancel "Cancel" { || { action: quit } }
  | tui label --status "tab/enter: next field  ctrl+s: add  esc: cancel"
  | tui bind ctrl+s { || { action: submit, selected: { op: "add" } } }
}

# Pure step reducer for the `gcal add --tui` submit-and-relaunch loop.
export def _gcal-form-step [
  submit_res: record # Output record from `tui run` / `tui debug`
  prev: record       # Previous form state
]: nothing -> record {
  if ($submit_res.action? | default "quit") != "submit" {
    return ($prev | merge { done: true, cancelled: true })
  }
  let vals = $submit_res.values? | default {}
  let cal = $vals.calendar?.row?.calendar? | default ($prev.calendar? | default "")
  let title = $vals.title? | default ($prev.title? | default "")
  let when = $vals.when? | default ($prev.when? | default "")
  let where = $vals.where? | default ($prev.where? | default "")
  let duration = $vals.duration? | default ($prev.duration? | default "60")
  let focused = $submit_res.focused? | default "title"
  let sel = $submit_res.selected?
  let sel_op = if ($sel != null) and (($sel | describe) | str starts-with "record") {
    $sel.op? | default ""
  } else {
    ""
  }
  let is_add = ($sel_op == "add") or ($focused == "btn_add")

  let base = {
    calendar: $cal
    title: $title
    when: $when
    where: $where
    duration: $duration
  }

  if $is_add {
    if ($cal | str trim | is-empty) {
      return ($base | merge { done: false, cancelled: false, focus: "calendar", err: "Calendar is required." })
    }
    if ($title | str trim | is-empty) {
      return ($base | merge { done: false, cancelled: false, focus: "title", err: "Title is required." })
    }
    let vw = _gcal-validate-when $when
    if not $vw.ok {
      return ($base | merge { done: false, cancelled: false, focus: "when", err: $vw.msg })
    }
    let vd = _gcal-validate-duration $duration
    if not $vd.ok {
      return ($base | merge { done: false, cancelled: false, focus: "duration", err: $vd.msg })
    }
    return {
      done: true
      cancelled: false
      calendar: $cal
      title: ($title | str trim)
      when: ($when | str trim)
      where: ($where | str trim)
      duration: $vd.value
      focus: "btn_add"
      err: ""
    }
  }

  if $focused == "when" {
    let vw = _gcal-validate-when $when
    if not $vw.ok {
      return ($base | merge { done: false, cancelled: false, focus: "when", err: $vw.msg })
    }
  }
  if $focused == "duration" {
    let vd = _gcal-validate-duration $duration
    if not $vd.ok {
      return ($base | merge { done: false, cancelled: false, focus: "duration", err: $vd.msg })
    }
  }

  let next_focus = match $focused {
    "cal_search" => "calendar"
    "calendar" => "title"
    "title" => "when"
    "when" => "where"
    "where" => "duration"
    "duration" => "btn_add"
    _ => "title"
  }
  $base | merge { done: false, cancelled: false, focus: $next_focus, err: "" }
}

#add event to google calendar, also usable without arguments or with --tui
@example "Add event with positional arguments" { gcal add "Work" "Standup" "2026.11.13 10:00" "Meet" 30 }
@example "Open interactive TUI event form" { gcal add --tui }
export def "gcal add" [
  calendar?                          #to which calendar add event
  title?                             #event title
  when?                              #date: yyyy.MM.dd hh:mm
  where?                             #location
  duration?                          #duration in minutes
  --tui                              #Open interactive TUI event form
  --stdin-tty: oneof<bool, nothing>  #Optional override for stdin TTY status (for testing)
  --stdout-tty: oneof<bool, nothing> #Optional override for stdout TTY status (for testing)
] {
  if $tui {
    let has_stdin = $stdin_tty | default (is-terminal --stdin)
    let has_stdout = $stdout_tty | default (is-terminal --stdout)
    if (not $has_stdin) or (not $has_stdout) {
      error make {
        msg: $"(ansi red)This command requires an interactive terminal \(TTY\). Run without --tui or inside a terminal.(ansi reset)"
      }
    }

    let calendars = gcal list -r | sort
    mut form_state = {
      calendar: ($calendar | default "")
      title: ($title | default "")
      when: (if ($when | is-empty) { _gcal-default-when } else { $when })
      where: ($where | default "")
      duration: (if ($duration | is-empty) { "60" } else { $duration | into string })
      focus: (if ($calendar | is-empty) { "calendar" } else if ($title | is-empty) { "title" } else { "when" })
      err: ""
    }

    loop {
      let res = (_gcal-build-add-form $calendars $form_state) | tui run
      let step = _gcal-form-step $res $form_state
      if $step.done {
        if $step.cancelled {
          return
        }
        return (_gcal-add-event $step.calendar $step.title $step.when $step.where $step.duration --noprompt)
      }
      $form_state = $step
    }
  }

  let calendar = if ($calendar | is-empty) {
    gcal list -r | sort | input list -f (echo-g "Select calendar: ")
  } else {
    $calendar
  }

  let title = if ($title | is-empty) {input --reedline (echo-g "title: ")} else {$title}
  let when = if ($when | is-empty) {input --reedline (echo-g "when: ")} else {$when}
  let where = if ($where | is-empty) {input --reedline (echo-g "where: ")} else {$where}
  let duration = if ($duration | is-empty) {input --reedline (echo-g "duration: ")} else {$duration}

  _gcal-add-event $calendar $title $when $where $duration
}

#show gcal agenda in selected calendars
#
# Examples
# agenda 
# agenda --full
# agenda "--details=all"
# agenda --full "--details=all"
export def --wrapped "gcal agenda" [
  --full(-f)  #show all calendars
  ...rest     #extra flags for gcalcli between quotes (specified full needed)
] {
  let calendars = gcal list -R (not $full) -f $full| str join "|"

  run-gcalcli --calendar $"($calendars)" agenda --military ...$rest
}

#show gcal week in selected calendards
#
# Examples
# semana 
# semana --full
# semana "--details=all"
# semana --full "--details=all"
export def --wrapped "gcal semana" [
  --full(-f) #show all calendars (export default: 0)
  ...rest    #extra flags for gcalcli between quotes (specified full needed)
] {
  let calendars = gcal list -R (not $full) -f $full | str join "|"

  run-gcalcli --calendar $"($calendars)" calw ...$rest --military --monday
}

#show gcal month in selected calendards
#
# Examples
# mes 
# mes --full
# mes "--details=all"
# mes --full "--details=all"
export def --wrapped "gcal mes" [
  --full(-f)  #show all calendars (export default: 0)
  ...rest     #extra flags for gcalcli between quotes (specified full needed)
] {
  let calendars = gcal list -R (not $full) -f $full | str join "|"

  run-gcalcli --calendar $"($calendars)" calm ...$rest --military --monday
}

# Ensure ~/.config/gcalcli/config.toml exists with personal client-id
def ensure-gcalcli-config [] {
  let config_file = ($env.HOME | path join ".config" "gcalcli" "config.toml")
  if not ($config_file | path exists) {
    let cid = (try { get-api-key "google.calendar.client_id" } catch { "" })
    if ($cid | is-not-empty) {
      ^mkdir -p ($env.HOME | path join ".config" "gcalcli")
      $"[auth]\nclient-id = \"($cid)\"\n" | save -f $config_file
    }
  }
}

# Internal wrapper for gcalcli ensuring personal client-secret and config are applied
def --wrapped run-gcalcli [...args: string] {
  if ($env.MOCK_GCALCLI? | is-not-empty) {
    return (do $env.MOCK_GCALCLI $args)
  }
  ensure-gcalcli-config
  let secret = (try { get-api-key "google.calendar.client_secret" } catch { "" })
  if ($secret | is-not-empty) {
    ^gcalcli --client-secret $secret ...$args
  } else {
    ^gcalcli ...$args
  }
}

#list available calendars
export def "gcal list" [
  --readers(-r) #exclude read-only calendars
  --readers_bool(-R) = false #same as -r, but bool flag
  --full(-f) = true  #if false, filter not wanted calendars
] {
  run-gcalcli list
  | ansi strip
  | lines
  | skip 2
  | parse -r '^\s*(?P<access>\w+)\s+(?P<title>.+)$'
  | if $readers or $readers_bool { where access !~ "reader" } else { $in }
  | if not $full { where title !~ "Cuentas" } else { $in }
  | get title
  | str trim
}

#re-authenticate gcalcli with personal credentials
export def "gcal reauth" [] {
  let cid = (get-api-key "google.calendar.client_id")
  let csecret = (get-api-key "google.calendar.client_secret")

  # Ensure config.toml is provisioned with personal client-id
  let config_dir = ($env.HOME | path join ".config" "gcalcli")
  ^mkdir -p $config_dir
  $"[auth]\nclient-id = \"($cid)\"\n" | save -f ($config_dir | path join "config.toml")

  # Clean stale token caches (both legacy ~/.gcalcli* and modern ~/.local/share/gcalcli/oauth)
  try { rm ($env.HOME | path join ".gcalcli*") -f } catch {}
  try { rm ($env.HOME | path join ".local" "share" "gcalcli" "oauth") -f } catch {}

  print (echo-g "Starting gcalcli authentication with personal API credentials...")
  ^gcalcli --client-id $cid --client-secret $csecret init
}