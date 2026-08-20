# Published datetime formatters for Nushell 0.115+.
#
# Extends the built-in `date` family. Does not replace date now,
# date to-timezone, date humanize, date from-human, date list-timezone,
# or the removed date format stub (use `format date` for strftime).
#
# Usage:
#   source date-formats.nu
#   use ./date-formats.nu *
#   rfc-3339                              # named helpers (back-compat)
#   date now | date as rfc-3339
#   date list-formats
#   date as --all --now 2023-05-15T12:34:56+00:00

# --- catalog ----------------------------------------------------------------

const ISO_FORMATS = [
  [name aliases kind tz locale pattern unit transform standard description];
  [iso-8601 [iso8601 iso] strftime preserve C "%Y-%m-%dT%H:%M:%S%:z" "" "" "ISO 8601-1" "Extended calendar date-time with colon offset"]
  [iso-8601-full [iso-8601-frac] strftime preserve C "%+" "" "" "ISO 8601-1" "Extended date-time with fractional seconds and colon offset"]
  [iso-8601-basic [] strftime preserve C "%Y%m%dT%H%M%S%z" "" "" "ISO 8601-1" "Basic calendar date-time with basic offset"]
  [iso-8601-utc [utc zulu z] strftime UTC C "%Y-%m-%dT%H:%M:%SZ" "" "" "ISO 8601-1" "Extended date-time in UTC with Z"]
  [iso-8601-basic-utc [] strftime UTC C "%Y%m%dT%H%M%SZ" "" "" "ISO 8601-1" "Basic date-time in UTC with Z"]
  [iso-8601-date [html-date xsd-date toml-local-date] strftime preserve C "%Y-%m-%d" "" "" "ISO 8601-1" "Extended calendar date"]
  [iso-8601-date-basic [iso-2014 ical-date vcard-date dicom-da] strftime preserve C "%Y%m%d" "" "" "ISO 8601-1" "Basic calendar date"]
  [iso-8601-time [html-time toml-local-time] strftime preserve C "%H:%M:%S" "" "" "ISO 8601-1" "Extended local time"]
  [iso-8601-time-basic [] strftime preserve C "%H%M%S" "" "" "ISO 8601-1" "Basic local time"]
  [iso-8601-time-offset [xsd-time] strftime preserve C "%H:%M:%S%:z" "" "" "ISO 8601-1" "Extended time with colon offset"]
  [iso-8601-minute [w3c-dtf-minute] strftime preserve C "%Y-%m-%dT%H:%M%:z" "" "" "W3C NOTE-datetime" "Date and hour-minute with timezone"]
  [iso-8601-year-month [html-month] strftime preserve C "%Y-%m" "" "" "ISO 8601-1" "Year and month"]
  [iso-8601-year [] strftime preserve C "%Y" "" "" "ISO 8601-1" "Calendar year"]
  [iso-8601-week [html-week] strftime preserve C "%G-W%V" "" "" "ISO 8601-1" "Extended week"]
  [iso-8601-week-date [] strftime preserve C "%G-W%V-%u" "" "" "ISO 8601-1" "Extended week date"]
  [iso-8601-week-date-basic [] strftime preserve C "%GW%V%u" "" "" "ISO 8601-1" "Basic week date"]
  [iso-8601-week-datetime [] strftime preserve C "%G-W%V-%uT%H:%M:%S%:z" "" "" "ISO 8601-1" "Extended week date-time with offset"]
  [iso-8601-ordinal [] strftime preserve C "%Y-%j" "" "" "ISO 8601-1" "Extended ordinal date"]
  [iso-8601-ordinal-basic [] strftime preserve C "%Y%j" "" "" "ISO 8601-1" "Basic ordinal date"]
  [iso-8601-ordinal-datetime [] strftime preserve C "%Y-%jT%H:%M:%S%:z" "" "" "ISO 8601-1" "Extended ordinal date-time with offset"]
]

const RFC_FORMATS = [
  [name aliases kind tz locale pattern unit transform standard description];
  [rfc-3339 [rfc3339 atom rfc-4287 json rfc-7493 yaml-timestamp xsd-dateTime toml-offset-datetime w3c-dtf] strftime preserve C "%Y-%m-%dT%H:%M:%S%:z" "" "" "RFC 3339" "Internet date/time with colon offset"]
  [rfc-3339-utc [] strftime UTC C "%Y-%m-%dT%H:%M:%SZ" "" "" "RFC 3339" "Internet date/time in UTC with Z"]
  [rfc-3339-frac [] strftime preserve C "%+" "" "" "RFC 3339" "Internet date/time with fractional seconds"]
  [rfc-3339-space [] strftime preserve C "%Y-%m-%d %H:%M:%S%:z" "" "" "RFC 3339" "Internet date/time with space instead of T"]
  [rfc-9557 [ixdtf] rfc-9557 UTC C "" "" "" "RFC 9557" "Internet Extended Date/Time Format with [UTC]"]
  [rfc-5322 [rfc-2822 rfc2822 rfc5322 email] strftime preserve C "%a, %d %b %Y %H:%M:%S %z" "" "" "RFC 5322" "Internet Message Format date (4-digit year, numeric offset)"]
  [rfc-822 [rfc822 rfc-1036 rfc1036 rss] strftime preserve C "%a, %d %b %y %H:%M:%S %z" "" "" "RFC 822" "ARPA Internet Text Messages date (2-digit year)"]
  [rfc-850 [rfc850] strftime UTC C "%A, %d-%b-%y %H:%M:%S GMT" "" "" "RFC 850" "Obsolete HTTP date with full weekday and 2-digit year"]
  [rfc-7231 [rfc-1123 rfc1123 rfc-9110 rfc9110 http-date imf-fixdate cookie rfc-6265] strftime UTC C "%a, %d %b %Y %H:%M:%S GMT" "" "" "RFC 9110" "HTTP-date IMF-fixdate, always GMT"]
  [rfc-5545 [rfc5545 ical-utc] strftime UTC C "%Y%m%dT%H%M%SZ" "" "" "RFC 5545" "iCalendar UTC DATE-TIME"]
  [ical-local [toml-local-datetime html-datetime-local] strftime preserve C "%Y%m%dT%H%M%S" "" "" "RFC 5545" "iCalendar floating DATE-TIME"]
  [rfc-4517 [ldap ldap-generalized-time] strftime UTC C "%Y%m%d%H%M%S%.6fZ" "" "" "RFC 4517" "LDAP Generalized Time with microseconds"]
  [ldap-generalized-time-basic [] strftime UTC C "%Y%m%d%H%M%SZ" "" "" "RFC 4517" "LDAP Generalized Time without fraction"]
]

const WEB_FORMATS = [
  [name aliases kind tz locale pattern unit transform standard description];
  [ecma-262 [js-iso html-datetime] strftime UTC C "%Y-%m-%dT%H:%M:%S%.3fZ" "" "" "ECMA-262" "JavaScript / WHATWG Date Time String Format"]
  [odata-datetimeoffset [] frac7 UTC C "" "" "" "OData" "Edm.DateTimeOffset with 7 fractional digits and Z"]
  [fhir-datetime [fhir-dateTime] strftime UTC C "%Y-%m-%dT%H:%M:%SZ" "" "" "HL7 FHIR" "FHIR dateTime in UTC"]
]

const LEGACY_FORMATS = [
  [name aliases kind tz locale pattern unit transform standard description];
  [asctime [posix-asctime] strftime preserve C "%a %b %e %H:%M:%S %Y" "" "" "ANSI C / RFC 9110" "asctime() date, space-padded day, no timezone"]
  [local-datetime [locale] strftime preserve local "%c" "" "" "libc" "Locale date and time"]
  [locale-date [] strftime preserve local "%x" "" "" "libc" "Locale date"]
  [locale-time [] strftime preserve local "%X" "" "" "libc" "Locale time"]
  [asn1-utctime [] strftime UTC C "%y%m%d%H%M%SZ" "" "" "X.680 / X.509" "ASN.1 UTCTime"]
  [asn1-generalized-time [] strftime UTC C "%Y%m%d%H%M%SZ" "" "" "X.680 / X.509" "ASN.1 GeneralizedTime"]
  [asn1-generalized-time-frac [] strftime UTC C "%Y%m%d%H%M%S%.6fZ" "" "" "X.680 / X.509" "ASN.1 GeneralizedTime with microseconds"]
  [exif-datetime [] strftime preserve C "%Y:%m:%d %H:%M:%S" "" "" "JEITA Exif" "EXIF DateTime original"]
  [dicom-tm [] strftime preserve C "%H%M%S%.6f" "" "" "DICOM PS3.5" "DICOM TM (time)"]
  [dicom-dt [] strftime preserve C "%Y%m%d%H%M%S%.6f%z" "" "" "DICOM PS3.5" "DICOM DT (date-time with offset)"]
  [nato-dtg [] strftime UTC C "%d%H%MZ %b %y" "" uppercase "ACP 121 / MIL-STD-6040" "NATO date-time group"]
  [nato-dtg-compact [] strftime UTC C "%d%H%MZ%b%y" "" uppercase "ACP 121 / MIL-STD-6040" "NATO date-time group without spaces"]
  [iso-9660 [ecma-119] iso-9660 preserve C "" "" "" "ISO 9660 / ECMA-119" "CD-ROM volume date/time with 15-minute offset units"]
  [net-roundtrip [] frac7 preserve C "" "" "" ".NET" "Round-trip (o) format, 7 fractional digits"]
  [net-sortable [] strftime preserve C "%Y-%m-%dT%H:%M:%S" "" "" ".NET" "Sortable (s) format"]
  [net-universal [] strftime UTC C "%Y-%m-%d %H:%M:%SZ" "" "" ".NET" "Universal sortable (u) format"]
  [sql-timestamp [iso-9075] strftime preserve C "%Y-%m-%d %H:%M:%S" "" "" "ISO/IEC 9075" "SQL TIMESTAMP (space separator)"]
  [sql-timestamptz [] strftime preserve C "%Y-%m-%d %H:%M:%S%:z" "" "" "ISO/IEC 9075" "SQL TIMESTAMP WITH TIME ZONE"]
]

const NUMERIC_FORMATS = [
  [name aliases kind tz locale pattern unit transform standard description];
  [unix [epoch posix-time unix-timestamp] unix preserve C "" s "" "POSIX" "Seconds since 1970-01-01T00:00:00Z"]
  [unix-ms [epoch-ms javascript] unix preserve C "" ms "" "POSIX / ECMA-262" "Milliseconds since Unix epoch"]
  [unix-us [epoch-us] unix preserve C "" us "" "POSIX" "Microseconds since Unix epoch"]
  [unix-ns [epoch-ns] unix preserve C "" ns "" "POSIX" "Nanoseconds since Unix epoch"]
  [julian-day [jd] julian preserve C "" "" "" "IAU / USNO" "Julian Day Number, UTC"]
  [modified-julian-day [mjd] mjd preserve C "" "" "" "IAU / USNO" "Modified Julian Date (JD − 2400000.5)"]
  [rata-die [rd] rata-die preserve C "" "" "" "Calendrical Calculations" "Rata Die day number (0001-01-01 = 1), UTC"]
  [excel-1900 [] excel-1900 preserve C "" "" "" "ECMA-376" "Excel 1900 date system serial (Windows)"]
  [excel-1904 [] excel-1904 preserve C "" "" "" "ECMA-376" "Excel 1904 date system serial (Mac)"]
  [ntp [] ntp preserve C "" "" "" "RFC 5905" "NTP seconds since 1900-01-01T00:00:00Z"]
  [filetime [] filetime preserve C "" "" "" "MS-DTYP" "Windows FILETIME, 100 ns since 1601-01-01T00:00:00Z"]
  [cf-absolute [apple-epoch nstimeinterval] cf-absolute preserve C "" "" "" "Apple CFAbsoluteTime" "Seconds since 2001-01-01T00:00:00Z"]
]

const DT_FORMATS = $ISO_FORMATS ++ $RFC_FORMATS ++ $WEB_FORMATS ++ $LEGACY_FORMATS ++ $NUMERIC_FORMATS

# --- internals --------------------------------------------------------------

def resolve-instant [now?: datetime]: [nothing -> datetime, datetime -> datetime, any -> datetime] {
  if $now != null {
    $now
  } else if ($in | describe) == "datetime" {
    $in
  } else {
    date now
  }
}

def make-ctx [now?: datetime]: [nothing -> record, datetime -> record, any -> record] {
  let dt = $in | resolve-instant $now
  let unix_s = $dt | format date "%s" | into int
  let unix_sub = $dt | format date "%f" | into int
  {
    dt: $dt
    utc: ($dt | date to-timezone UTC)
    unix_s: $unix_s
    unix_sub: $unix_sub
    unix_ns: ($unix_s * 1_000_000_000 + $unix_sub)
  }
}

def find-format [name: string]: nothing -> record {
  let key = $name | str lowercase
  let hit = $DT_FORMATS | where {|row|
    ($row.name | str lowercase) == $key or $key in ($row.aliases | each { str lowercase })
  }
  if ($hit | is-empty) {
    error make {
      msg: $"unknown datetime format: ($name)"
      help: "run `date list-formats` to see supported formats"
    }
  }
  $hit | first
}

def unix-days [ctx: record]: nothing -> float {
  ($ctx.unix_s | into float) / 86400.0 + ($ctx.unix_sub | into float) / 86400.0 / 1_000_000_000.0
}

def fmt-strftime [ctx: record, spec: record]: nothing -> string {
  let src = if $spec.tz == "UTC" { $ctx.utc } else { $ctx.dt }
  let raw = if $spec.locale == "C" {
    # RFC / ISO English names must not follow the process locale.
    with-env {LC_ALL: "C", LC_TIME: "C"} { $src | format date $spec.pattern }
  } else {
    $src | format date $spec.pattern
  }
  if $spec.transform == "uppercase" {
    $raw | str uppercase
  } else {
    $raw
  }
}

def fmt-unix [ctx: record, unit: string]: nothing -> int {
  match $unit {
    "s" => $ctx.unix_s
    "ms" => ($ctx.unix_s * 1_000 + $ctx.unix_sub // 1_000_000)
    "us" => ($ctx.unix_s * 1_000_000 + $ctx.unix_sub // 1_000)
    "ns" => $ctx.unix_ns
    _ => (error make {msg: $"internal: unknown unix unit ($unit)"})
  }
}

def fmt-frac7 [ctx: record, spec: record]: nothing -> string {
  let src = if $spec.tz == "UTC" { $ctx.utc } else { $ctx.dt }
  let head = $src | format date "%Y-%m-%dT%H:%M:%S."
  let frac = $src | format date "%9f" | str substring 0..<7
  if $spec.tz == "UTC" {
    $"($head)($frac)Z"
  } else {
    $"($head)($frac)($src | format date '%:z')"
  }
}

def fmt-iso-9660 [ctx: record]: nothing -> string {
  let datepart = $ctx.dt | format date "%Y%m%d%H%M%S"
  let hundredths = $ctx.dt | format date "%3f" | str substring 0..<2
  let z = $ctx.dt | format date "%z"
  let sign = if ($z | str starts-with "-") { -1 } else { 1 }
  let hh = $z | str substring 1..<3 | into int
  let mm = $z | str substring 3..<5 | into int
  let units = $sign * ($hh * 4 + $mm // 15)
  let mag = ($units | math abs) | fill --alignment right --character "0" --width 2
  let off = if $units < 0 { $"-($mag)" } else { $"+($mag)" }
  $"($datepart)($hundredths)($off)"
}

def render [ctx: record, spec: record]: nothing -> any {
  match $spec.kind {
    "strftime" => (fmt-strftime $ctx $spec)
    "unix" => (fmt-unix $ctx $spec.unit)
    "frac7" => (fmt-frac7 $ctx $spec)
    "rfc-9557" => $"($ctx.utc | format date '%+')[UTC]"
    "iso-9660" => (fmt-iso-9660 $ctx)
    "julian" => ((unix-days $ctx) + 2440587.5)
    "mjd" => ((unix-days $ctx) + 40587.0)
    "rata-die" => (((unix-days $ctx) | math floor | into int) + 719163)
    "excel-1900" => ((unix-days $ctx) + 25569.0)
    "excel-1904" => ((unix-days $ctx) + 24107.0)
    "ntp" => (($ctx.unix_s | into float) + ($ctx.unix_sub | into float) / 1_000_000_000.0 + 2208988800.0)
    "filetime" => ($ctx.unix_ns // 100 + 116444736000000000)
    "cf-absolute" => (($ctx.unix_s | into float) + ($ctx.unix_sub | into float) / 1_000_000_000.0 - 978307200.0)
    _ => (error make {msg: $"internal: unknown format kind ($spec.kind)"})
  }
}

def render-all [ctx: record]: nothing -> table {
  $DT_FORMATS | each {|spec|
    {
      name: $spec.name
      value: (render $ctx $spec)
      standard: $spec.standard
      description: $spec.description
    }
  }
}

# --- public API -------------------------------------------------------------

export def "nu-complete date as" []: nothing -> table {
  $DT_FORMATS
  | each {|row|
      [
        {value: $row.name, description: $"($row.standard): ($row.description)"}
      ]
      | append (
        $row.aliases | each {|alias|
          {value: $alias, description: $"alias of ($row.name)"}
        }
      )
    }
  | flatten
  | sort-by value
}

# List published datetime format names, aliases, and standards.
export def "date list-formats" [
  --full(-f)  # include implementation columns (kind, pattern, tz)
]: nothing -> table {
  let rows = $DT_FORMATS | sort-by name
  if $full {
    $rows
  } else {
    $rows | select name aliases standard description
  }
}

# Format an instant using a published standard.
export def "date as" [
  format?: string@"nu-complete date as"  # catalog name or alias
  instant?: datetime                     # instant; default: pipeline, --now, or date now
  --now: datetime                        # instant as a flag (use with --all)
  --all(-a)                              # emit every format as a table
]: [nothing -> any, datetime -> any, any -> any] {
  if $format == null and not $all {
    error make {
      msg: "date as requires a format name, or --all"
      help: "examples: `date as rfc-3339`, `date as --all`, `date list-formats`"
    }
  }
  let chosen = $instant | default $now
  let ctx = $in | make-ctx $chosen
  if $all {
    render-all $ctx
  } else {
    render $ctx (find-format $format)
  }
}

# --- back-compat named helpers ----------------------------------------------

export def utc [now?: datetime]: [nothing -> string, datetime -> string, any -> string] {
  $in | date as utc $now
}

export def iso-8601 [now?: datetime]: [nothing -> string, datetime -> string, any -> string] {
  $in | date as iso-8601 $now
}

export def iso-8601-full [now?: datetime]: [nothing -> string, datetime -> string, any -> string] {
  $in | date as iso-8601-full $now
}

export def local-datetime [now?: datetime]: [nothing -> string, datetime -> string, any -> string] {
  $in | date as local-datetime $now
}

export def rfc-2822 [now?: datetime]: [nothing -> string, datetime -> string, any -> string] {
  $in | date as rfc-2822 $now
}

export def rfc-850 [now?: datetime]: [nothing -> string, datetime -> string, any -> string] {
  $in | date as rfc-850 $now
}

export def rfc-1036 [now?: datetime]: [nothing -> string, datetime -> string, any -> string] {
  $in | date as rfc-1036 $now
}

export def rfc-1123 [now?: datetime]: [nothing -> string, datetime -> string, any -> string] {
  $in | date as rfc-1123 $now
}

export def rfc-822 [now?: datetime]: [nothing -> string, datetime -> string, any -> string] {
  $in | date as rfc-822 $now
}

export def rfc-3339 [now?: datetime]: [nothing -> string, datetime -> string, any -> string] {
  $in | date as rfc-3339 $now
}

export def rfc-7231 [now?: datetime]: [nothing -> string, datetime -> string, any -> string] {
  $in | date as rfc-7231 $now
}

# Seconds since the Unix epoch, or nanoseconds with --nanos.
# Sub-second time is preserved for --nanos (positive and pre-epoch).
export def unix-timestamp [
  now?: datetime
  --nanos(-n)
]: [nothing -> int, datetime -> int, any -> int] {
  if $nanos {
    $in | date as unix-ns $now
  } else {
    $in | date as unix $now
  }
}
