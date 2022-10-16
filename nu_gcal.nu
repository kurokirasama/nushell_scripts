#add event to google calendar, also usable without arguments
export def "gcal add" [
  calendar?   #to which calendar add event
  title?      #event title
  when?       #date: yyyy.MM.dd hh:mm
  where?      #location
  duration?   #duration in minutes
] {
  let calendar = if ($calendar | is-empty) {input (echo-g "calendar: ")} else {$calendar}
  let title = if ($title | is-empty) {input (echo-g "title: ")} else {$title}
  let when = if ($when | is-empty) {input (echo-g "when: ")} else {$when}
  let where = if ($where | is-empty) {input (echo-g "where: ")} else {$where}
  let duration = if ($duration | is-empty) {input (echo-g "duration: ")} else {$duration}
  
  gcalcli --calendar $"($calendar)" add --title $"($title)" --when $"($when)" --where $"($where)" --duration $"($duration)" --default-reminders
}

#show gcal agenda in selected calendars
export def "gcal agenda" [
  --full: int  #show all calendars (export default: 0)
  ...rest      #extra flags for gcalcli between quotes (specified full needed)
  #
  # Examples
  # agenda 
  # agenda --full true
  # agenda "--details=all"
  # agenda --full true "--details=all"
] {
  let calendars = $env.MY_ENV_VARS.google_calendars
  let calendars_full = $env.MY_ENV_VARS.google_calendars_full

  if ($full | is-empty) || ($full == 0) {
    gcalcli --calendar $"($calendars)" agenda --military $rest
  } else {
    gcalcli --calendar $"($calendars_full)" agenda --military $rest
  }
}

#show gcal week in selected calendards
export def "gcal semana" [
  --full: int  #show all calendars (export default: 0)
  ...rest      #extra flags for gcalcli between quotes (specified full needed)
  #
  # Examples
  # semana 
  # semana --full true
  # semana "--details=all"
  # semana --full true "--details=all"
] {
  let calendars = $env.MY_ENV_VARS.google_calendars
  let calendars_full = $env.MY_ENV_VARS.google_calendars_full
  
  if ($full | is-empty) || ($full == 0) {
    gcalcli --calendar $"($calendars)" calw $rest --military --monday
  } else {
    gcalcli --calendar $"($calendars_full)" calw $rest --military --monday
  }
}

#show gcal month in selected calendards
export def "gcal mes" [
  --full: int  #show all calendars (export default: 0)
  ...rest      #extra flags for gcalcli between quotes (specified full needed)
  #
  # Examples
  # mes 
  # mes --full true
  # mes "--details=all"
  # mes --full true "--details=all"
] {
  let calendars = $env.MY_ENV_VARS.google_calendars
  let calendars_full = $env.MY_ENV_VARS.google_calendars_full
  
  if ($full | is-empty) || ($full == 0) {
    gcalcli --calendar $"($calendars)" calm $rest --military --monday
  } else {
    gcalcli --calendar $"($calendars_full)" calm $rest --military --monday
  }
}