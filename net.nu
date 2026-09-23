#!/usr/bin/env nu

def main [how_many: int = 2, --json] {
	let nethogs = (do -i { nethogs -c 2 -t -d 2 } | complete | get -o stdout | default "" | lines)
	let ref_index = (try { $nethogs | find-index Refreshing | get 1 } catch { 0 })
	
	let parsed = (
		$nethogs
		| skip ($ref_index + 1)
		| drop
		| parse "{NAME}\t{UP}\t{DOWN}"
		| each { |item|
			let clean_n = (extract-name $item.NAME)
			let up_val = (try { $item.UP | into float | math round --precision 2 | into string } catch { ($item.UP | split chars | first 5 | str join) })
			let down_val = (try { $item.DOWN | into float | math round --precision 2 | into string } catch { ($item.DOWN | split chars | first 5 | str join) })
			{
				name: $clean_n,
				up: $up_val,
				down: $down_val
			}
		}
		| where { |r|
			# Filter out idle unknown sockets if other processes exist
			($r.name != "unknown TCP") or ($r.up != "0" and $r.up != "0.0") or ($r.down != "0" and $r.down != "0.0")
		}
		| first $how_many
	)

	if $json {
		$parsed | to json
	} else {
		if ($parsed | length) == 0 {
			""
		} else {
			$parsed
			| format pattern "{name}:{up}:{down}"
			| str join "\n"
			| to text
			| ^awk -F: '{printf "%-30s %15s %15s\n", $1, $2, $3}'
		}
	}
}

def indexify [
  column_name?: string = 'index' #export default: index
  ] { 
  enumerate 
  | upsert $column_name {|el| 
      $el.index
    } 
  | flatten
}

def find-index [name: string, default? = -1] {
  $in
  | indexify
  | find $name
  | try {
      get index
    } catch {
      $default 
    }
}

def extract-name [raw_path: string] {
	# 1. Match standard nethogs pattern: <prog>/<pid>/<uid> or /<uid>
	let p = ($raw_path | parse -r "^(?P<prog>.*?)(?:/(?P<pid>\\d+))?/(?P<uid>\\d+)$")
	if ($p | length) > 0 {
		let rec = ($p | first)
		let pid = (try { $rec.pid | into int } catch { 0 })
		let prog = ($rec.prog | default "")
		let uid = ($rec.uid | default "1000")

		# A. Try reading active process name from /proc/<pid>/comm
		if $pid > 0 {
			let comm = (try { open --raw $"/proc/($pid)/comm" | str trim } catch { "" })
			if ($comm | is-not-empty) {
				return (format-friendly-name $comm)
			}
		}

		# B. Check if prog is an IP socket: e.g. 192.168.7.184:58068-162.125.5.14:443
		if ($prog =~ "[:]\\d+.*[:]\\d+") {
			let local_port = ($prog | parse -r "[:]\\d+.*?:(?P<lport>\\d+)-" | get -o 0.lport)
			if ($local_port | is-not-empty) {
				let ss_match = (try {
					let out = (^ss -H -t -u -n -p $"sport = :($local_port)")
					$out | parse -r "users:\\(\\(\"(?P<pname>[^\"]+)\"" | get -o 0.pname
				} catch { "" })
				if ($ss_match | is-not-empty) {
					return (format-friendly-name $ss_match)
				}
			}
			# Known remote IP mappings
			if ($prog =~ "162[.]125[.]") { return "maestral" }
			if ($prog =~ "213[.]180[.]") { return "yandex-disk" }
			return ($prog | split row "-" | last | split row ":" | first)
		}

		# C. Extract binary name from prog path
		if ($prog | is-not-empty) {
			let seg = ($prog | split row "/" | where { |s| ($s | str length) > 0 } | last | default $prog)
			if ($seg | is-not-empty) and ($seg != "0") {
				return (format-friendly-name $seg)
			}
		}

		# D. Fallback when prog is empty
		if $uid == "1000" {
			return "user/kira"
		}
		return $"uid-($uid)"
	}

	# 2. Raw fallback when string is just a number or slash+number
	if ($raw_path =~ "^/?1000$") {
		return "user/kira"
	} else if ($raw_path =~ "^/?\\d+$") {
		return "network"
	}

	format-friendly-name $raw_path
}

def format-friendly-name [name: string] {
	if ($name =~ "jd2") {
		"jd"
	} else if ($name =~ "maestral") {
		"maestral"
	} else if ($name =~ "cmdg") {
		"cmdg"
	} else if ($name =~ "yandex") {
		"yandex"
	} else if ($name =~ "zed") {
		"zed"
	} else if ($name =~ "gnome-software") {
		"gnome-software"
	} else if ($name =~ "nu$") {
		"nu"
	} else {
		$name
	}
}