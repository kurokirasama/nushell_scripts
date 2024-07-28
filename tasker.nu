#help join
export def "tasker-join help" [] {
	print (
		[
			"uses join app to interact with other devices:"
			"    https://github.com/joaomgcd/JoinDesktop"
			"METHODS:"
			"- tasker-join send-notification"
			"- tasker-join phone-call"
			"- tasker-join tts"
			"- tasker-join sms"
	 	]
	 	| str join "\n"
	)
}

#help tasker
export def "tasker help" [] {
	print (
		[
			"uses tasker http server functionalityto interact with other devices:"
			""
			"METHODS:"
			"- tasker send-notification"
			"- tasker phone-call"
			"- tasker tts"
			"- tasker sms"
	 	]
	 	| str join "\n"
	)
}

#send notificacion via join
export def "tasker-join send-notification" [
	text?:string
	--device(-d):string = "note12"
	--title(-t):string
	--select_device(-s)
] {
	let text = if ($text | is-empty) {$in} else {$text}
	let title = if ($title | is-empty) {"from " + $env.HOST} else {$title}
	
	let apikey = $env.MY_ENV_VARS.api_keys.join.apikey
	let deviceId = (
		if not $select_device {
			$env.MY_ENV_VARS.api_keys.join.devices | get $device
		} else {
			$env.MY_ENV_VARS.api_keys.join.devices
			| get (
				$env.MY_ENV_VARS.api_keys.join.devices
				| columns
				| input list -f (echo-g "select device:")
			  ) 	
		}
	)
	
	{
    	scheme: "https",
    	host: "joinjoaomgcd.appspot.com",
    	path: "/_ah/api/messaging/v1/sendPush",
    	params: {
        	apikey: $apikey,
        	text: ($text | url encode),
        	title: ($title | url encode),
        	deviceId: $deviceId
    	}
  	}
  	| url join
  	| http get $in
  	| ignore
}

#phone call via join
export def "tasker-join phone-call" [
	phone?:string
	--device(-d):string = "note12"
	--select_device(-s)
] {
	let phone = if ($phone | is-empty) {$in} else {$phone}
	let title = "phone call started from " + $env.HOST

	let apikey = $env.MY_ENV_VARS.api_keys.join.apikey
	let deviceId = (
		if ($select_device | is-empty) {
			$env.MY_ENV_VARS.api_keys.join.devices | get $device
		} else {
			$env.MY_ENV_VARS.api_keys.join.devices
			| get (
				$env.MY_ENV_VARS.api_keys.join.devices
				| columns
				| input list -f (echo-g "select device:")
			  ) 	
		}
	)

	{
    	scheme: "https",
    	host: "joinjoaomgcd.appspot.com",
    	path: "/_ah/api/messaging/v1/sendPush",
    	params: {
        	apikey: $apikey,
        	callnumber: ($phone | url encode),
        	title: ($title | url encode),
        	deviceId: $deviceId
    	}
  	}
  	| url join
  	| http get $in
  	| ignore
}

#tts via join
export def "tasker-join tts" [
	text?:string
	--device(-d):string = "note12"
	--language(-l):string = "spa" #language of tts (spa, eng, etc)
	--select_device(-s) = false
] {
	let text = if ($text | is-empty) {$in} else {$text}
	let title = "tts sent from " + $env.HOST

	let apikey = $env.MY_ENV_VARS.api_keys.join.apikey
	let deviceId = (
		if not $select_device {
			$env.MY_ENV_VARS.api_keys.join.devices | get $device
		} else {
			$env.MY_ENV_VARS.api_keys.join.devices
			| get (
				$env.MY_ENV_VARS.api_keys.join.devices
				| columns
				| input list -f (echo-g "select device:")
			  ) 	
		}
	)

	{
    	scheme: "https",
    	host: "joinjoaomgcd.appspot.com",
    	path: "/_ah/api/messaging/v1/sendPush",
    	params: {
        	apikey: $apikey,
        	say: ($text | url encode),
        	title: ($title | url encode),
        	language: $language,
        	deviceId: $deviceId
    	}
  	}
  	| url join
  	| http get $in
  	| ignore
}

#sms via join
export def "tasker-join sms" [
	phone:string
	text?:string
	--device(-d):string = "note12"
	--select_device(-s)
] {
	let sms = if ($text | is-empty) {$in} else {$text}

	let apikey = $env.MY_ENV_VARS.api_keys.join.apikey
	let deviceId = (
		if ($select_device | is-empty) {
			$env.MY_ENV_VARS.api_keys.join.devices | get $device
		} else {
			$env.MY_ENV_VARS.api_keys.join.devices
			| get (
				$env.MY_ENV_VARS.api_keys.join.devices
				| columns
				| input list -f (echo-g "select device:")
			  ) 	
		}
	)

	{
    	scheme: "https",
    	host: "joinjoaomgcd.appspot.com",
    	path: "/_ah/api/messaging/v1/sendPush",
    	params: {
        	apikey: $apikey,
        	smsnumber: ($phone | url encode),
        	smstext: ($sms | url encode),
        	deviceId: $deviceId
    	}
  	}
  	| url join
  	| http get $in
  	| ignore
}

#say via tasker http server
export def "tasker tts" [
	text?:string
	--device(-d):string = "main"  #main, 
	--language(-l):string = "spa" #language of tts (spa, eng)
	--select_device(-s)
] {
	let text = if ($text | is-empty) {$in} else {$text}

	let device = (
		if not $select_device {
			$device
		} else {
			$env.MY_ENV_VARS.tasker_server.devices
			| columns
			| input list -f (echo-g "select device:") 
		} 
	)
	
	let device_name = $env.MY_ENV_VARS.tasker_server.devices | get $device | get name
	let server = open ($env.MY_ENV_VARS.tasker_server.devices | get $device | get file ) | get $device_name

	http get $"($server)/command?say=($text | url encode)&language=($language)" | ignore
}

#send notificacion via tasker http server
export def "tasker send-notification" [
	text?:string
	--device(-d):string = "main"
	--title(-t):string
	--select_device(-s)
] {
	let text = if ($text | is-empty) {$in} else {$text}
	let title = if ($title | is-empty) {"from " + $env.HOST} else {$title}
	
	let device = (
		if not $select_device {
			$device
		} else {
			$env.MY_ENV_VARS.tasker_server.devices
			| columns
			| input list -f (echo-g "select device:") 
		} 
	)
	
	let device_name = $env.MY_ENV_VARS.tasker_server.devices | get $device | get name
	let server = open ($env.MY_ENV_VARS.tasker_server.devices | get $device | get file ) | get $device_name

	http get $"($server)/command?notification=($text | url encode)&title=($title | url encode)" | ignore
}

#send ssm via tasker http server
export def "tasker sms" [
	phone:string
	text?:string
	--device(-d):string = "main"
	--select_device(-s)
] {
	let sms = if ($text | is-empty) {$in} else {$text}

	let device = (
		if not $select_device {
			$device
		} else {
			$env.MY_ENV_VARS.tasker_server.devices
			| columns
			| input list -f (echo-g "select device:") 
		} 
	)
	
	let device_name = $env.MY_ENV_VARS.tasker_server.devices | get $device | get name
	let server = open ($env.MY_ENV_VARS.tasker_server.devices | get $device | get file ) | get $device_name

	http get $"($server)/command?sms=($text | url encode)&phone=($phone)" | ignore
}

#phone call via tasker http server
export def "tasker phone-call" [
	phone?:string
	--device(-d):string = "main"
	--select_device(-s)
] {
	let phone = if ($phone | is-empty) {$in} else {$phone}
	let title = "phone call started from " + $env.HOST + " to " + $phone

	let device = (
		if not $select_device {
			$device
		} else {
			$env.MY_ENV_VARS.tasker_server.devices
			| columns
			| input list -f (echo-g "select device:") 
		} 
	)
	
	let device_name = $env.MY_ENV_VARS.tasker_server.devices | get $device | get name
	let server = open ($env.MY_ENV_VARS.tasker_server.devices | get $device | get file ) | get $device_name

	http get $"($server)/command?call=($phone | url encode)&title=($title | url encode)" | ignore
}

export alias finished = tasker tts "copy finished" -l eng

#get phone info
#
#hp: battery %
#mp: free ram %
#sp: free sd card %
#area: location area
#profile: sound profile
#network: network connection
#ip: phone ip
#port: http server port
export def "tasker phone-info" [
	phone?:string
	--device(-d):string = "main"
	--select_device(-s)
	--conky(-c) #return output for conky display
] {
	let phone = if ($phone | is-empty) {$in} else {$phone}

	let device = (
		if not $select_device {
			$device
		} else {
			$env.MY_ENV_VARS.tasker_server.devices
			| columns
			| input list -f (echo-g "select device:") 
		} 
	)
	
	let device_name = $env.MY_ENV_VARS.tasker_server.devices | get $device | get name
	let server = open ($env.MY_ENV_VARS.tasker_server.devices | get $device | get file ) | get $device_name
	let response = http get $"($server)/command?info=info" -f

	if $response.status == 200 {
		$response.body | from json
	}
}