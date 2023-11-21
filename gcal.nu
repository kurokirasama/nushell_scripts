#gcalcli wrapper for accesing google calendar
export def "gcal help" [] {
  print (
    echo "gcalcli wrapper:\n
      METHODS\n
      - gcal add
      - gcal agenda
      - gcal semana
      - gcal mes\n"
    | nu-highlight
  ) 
}

#add event to google calendar, also usable without arguments
export def "gcal add" [
  calendar?   #to which calendar add event
  title?      #event title
  when?       #date: yyyy.MM.dd hh:mm
  where?      #location
  duration?   #duration in minutes
] {
  let calendar = (
    if ($calendar | is-empty) {
      $env.MY_ENV_VARS.google_calendars_full 
      | split row "|"
      | sort
      | input list -f (echo-g "Select calendar: ")
    } else {
      $calendar
    }
  )
  let title = if ($title | is-empty) {input (echo-g "title: ")} else {$title}
  let when = if ($when | is-empty) {input (echo-g "when: ")} else {$when}
  let where = if ($where | is-empty) {input (echo-g "where: ")} else {$where}
  let duration = if ($duration | is-empty) {input (echo-g "duration: ")} else {$duration}
  
  gcalcli --calendar $"($calendar)" add --title $"($title)" --when $"($when)" --where $"($where)" --duration $"($duration)" --default-reminders
}

#show gcal agenda in selected calendars
#
# Examples
# agenda 
# agenda --full
# agenda "--details=all"
# agenda --full "--details=all"
export def "gcal agenda" [
  --full    #show all calendars (export default: 0)
  ...rest   #extra flags for gcalcli between quotes (specified full needed)
] {
  let calendars = $env.MY_ENV_VARS.google_calendars
  let calendars_full = $env.MY_ENV_VARS.google_calendars_full

  if not $full {
    gcalcli --calendar $"($calendars)" agenda --military $rest
  } else {
    gcalcli --calendar $"($calendars_full)" agenda --military $rest
  }
}

#show gcal week in selected calendards
#
# Examples
# semana 
# semana --full
# semana "--details=all"
# semana --full "--details=all"
export def "gcal semana" [
  --full    #show all calendars (export default: 0)
  ...rest   #extra flags for gcalcli between quotes (specified full needed)
] {
  let calendars = $env.MY_ENV_VARS.google_calendars
  let calendars_full = $env.MY_ENV_VARS.google_calendars_full
  
  if not $full {
    gcalcli --calendar $"($calendars)" calw $rest --military --monday
  } else {
    gcalcli --calendar $"($calendars_full)" calw $rest --military --monday
  }
}

#show gcal month in selected calendards
#
# Examples
# mes 
# mes --full
# mes "--details=all"
# mes --full "--details=all"
export def "gcal mes" [
  --full    #show all calendars (export default: 0)
  ...rest   #extra flags for gcalcli between quotes (specified full needed)
] {
  let calendars = $env.MY_ENV_VARS.google_calendars
  let calendars_full = $env.MY_ENV_VARS.google_calendars_full
  
  if not $full {
    gcalcli --calendar $"($calendars)" calm $rest --military --monday
  } else {
    gcalcli --calendar $"($calendars_full)" calm $rest --military --monday
  }
}