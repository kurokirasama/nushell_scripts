#help
export def "tasker help" [] {
	print (
		[
			"uses join app to interact with other devices:"
			"    https://github.com/joaomgcd/JoinDesktop"
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
export def "tasker send-notification" [
	text?:string
	--device(-d):string = "note12"
	--title(-t):string
	--select_device(-s)
] {
	let text = if ($text | is-empty) {$in} else {$text}
	let title = if ($title | is-empty) {"from " + (sys | get host.hostname)} else {$title}
	
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
export def "tasker phone-call" [
	phone?:string
	--device(-d):string = "note12"
	--select_device(-s)
] {
	let phone = if ($phone | is-empty) {$in} else {$phone}
	let title = "phone call started from " + (sys | get host.hostname)

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
export def "tasker tts" [
	text?:string
	--device(-d):string = "note12"
	--language(-l):string = "spa" #language of tts (spa, eng, etc)
	--select_device(-s) = false
] {
	let text = if ($text | is-empty) {$in} else {$text}
	let title = "tts sent from " + (sys | get host.hostname)

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
export def "tasker sms" [
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

#backup guake settings
export def "guake backup" [] {
	guake --save-preferences ([$env.MY_ENV_VARS.linux_backup guakesettings.txt] | path join)
}

#restore guake settings
export def "guake restore" [] {
	guake --restore-preferences ([$env.MY_ENV_VARS.linux_backup guakesettings.txt] | path join)
}