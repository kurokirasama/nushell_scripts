#update all_likes m3u playlist via gemini
export def update-all-likes [] {
	let prompt = $"convert ($env.MY_ENV_VARS.linux_backup | path join youtube_music_playlists | path join all_likes.json) into a m3u file using the m3u-converter skill. Save the output file in the same directory, overwrite any existing file"
	
	gmn --profile no-mcp --model gemini-3.1-flash-lite-preview --prompt $prompt
	sleep 2sec
	killnode
}

const skills = [
	"cron-email-summaries"
	"cron-habitica-todos-summary"
	"cron-conductor-monitor"
	"cron-nnet-ga-researcher"
	"cron-news-feed"
]
const gmn_models = ["gemini-3.1-flash-lite-preview" "gemini-3-flash-preview" "gemini-2.5-flash" "gemini-2.5-flash-lite"]
const profiles = ["no-mcp", "minimal", "standard", "webui", "research", "googlesuit", "imagen", "full"]

#run cron gemini skills
export def "gmn cron" [
	skill:string@$skills 
	--model(-m):string = "gemini-3-flash-preview" #gemini-3.1-flash-lite-preview in free tier
	--profile(-p):string@$profiles = "minimal"
	--dont-kill(-d) #dont kill gemini mcp servers
] {
	let prompt = $"run ($skill) skill"
	
	let output =  gmn --profile $profile --model $model --prompt $prompt | complete 
	
	gmn-cron-email $skill $output
	
	if not $dont_kill {
		sleep 2sec
		killnode
	}
	
	#retry with gemini-3-flash
	if $output.exit_code != 0 {
		let output =  gmn --profile $profile --model gemini-3-flash-preview --prompt $prompt | complete
		gmn-cron-email $"Retry of ($skill)" $output
	}
	
	if not $dont_kill {
		sleep 2sec
		killnode
	}
}

#send cron outputs emails
def gmn-cron-email [
	skill:string
	output:record
] {
	let subject = if $output.exit_code == 0 {
		$"Log gemini-cli: ($skill)"
	} else {
		$"Log gemini-cli: Error when executing ($skill)"
	}
	
	let body = $"# Exit code\n\n($output.exit_code)\n\n# stdout\n\n($output.stdout)\n\n# stderr\n\n($output.stderr)"
		
	send-gmail $env.MY_ENV_VARS.mail $subject --body $body
}
