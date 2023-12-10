#help
export def "tasker help" [] {

}

#tasker notificacion via join
export def "tasker send-notification" [
	text?:string
	--device(-d):string = "note12"
	--title(-t):string
] {
	let text = if ($text | is-empty) {$in} else {$text}
	let title = if ($title | is-empty) {"from " + (sys | get host.hostname)} else {$title}
	
	let deviceId = $env.MY_ENV_VARS.api_keys.join | get $device | get deviceId
	let apikey = $env.MY_ENV_VARS.api_keys.join | get $device | get apikey

	let url = ("https://joinjoaomgcd.appspot.com/_ah/api/messaging/v1/sendPush?apikey=" + $apikey + "&text=" + ($text | url encode) + "&title=" + ($title | url encode) + "&deviceId=" + $deviceId)

	return (http get $url)
}