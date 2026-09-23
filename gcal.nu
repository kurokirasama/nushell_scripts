#gcalcli wrapper for accesing google calendar
export def "gcal help" [] {
  try { rich rule "Google Calendar CLI (gcalcli)" --style "bold cyan" } catch { print "gcalcli wrapper:\n" }
  let commands = [
    { name: "gcal add", description: "Add event to Google Calendar (interactive or parameterized)" },
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

#add event to google calendar, also usable without arguments
export def "gcal add" [
  calendar?   #to which calendar add event
  title?      #event title
  when?       #date: yyyy.MM.dd hh:mm
  where?      #location
  duration?   #duration in minutes
] {
  let calendar = if ($calendar | is-empty) {
    gcal list -r | sort | input list -f (echo-g "Select calendar: ")
  } else {
    $calendar
  }

  let title = if ($title | is-empty) {input (echo-g "title: ")} else {$title}
  let when = if ($when | is-empty) {input (echo-g "when: ")} else {$when}
  let where = if ($where | is-empty) {input (echo-g "where: ")} else {$where}
  let duration = if ($duration | is-empty) {input (echo-g "duration: ")} else {$duration}
  
  try {
    $"Adding Event to Calendar [bold]($calendar)[/]:\nTitle: [bold cyan]($title)[/]\nWhen: [yellow]($when)[/] | Duration: ($duration) mins\nWhere: ($where)"
      | rich panel --title "Google Calendar Event" --box rounded --border-style green
  } catch { }

  run-gcalcli --calendar $"($calendar)" add --title $"($title)" --when $"($when)" --where $"($where)" --duration $"($duration)" --default-reminders
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