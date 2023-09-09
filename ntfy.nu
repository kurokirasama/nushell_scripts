#send ntfy notification
export def ntfy-send [
    message?:string
    server?:string
    channel = "test"
    #
    #alternative: curl -q -d $message "$server/$channel"
] {
	let message = if ($message | is-empty) {$in} else {$message}
	let host = (sys | get host | get hostname)
	let server = (
		if ($server | is-empty) {
			if ($host == lgomez-note) {
      			"http://ntfy_ubb.itlabs.store/"
      		} else if ($host == deathnote) {
      			"http://ntfy_home.itlabs.store/"
      		} else {
      			return-error "host not found!"
      		}
		} else if ($server | str contains http) {
			$server
		} else {
			"http://" + $server + "/"
		}
	)

	let response = (http post ($server + $channel) $message)
}

#open tunnels via cloudfare
