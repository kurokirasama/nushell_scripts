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
]
const gmn_models = ["gemini-3.1-flash-lite-preview" "gemini-3-flash-preview"]
const profiles = ["no-mcp", "minimal", "standard", "webui", "research", "googlesuit", "imagen", "full"]

#run cron gemini skills
export def "gmn cron" [
	skill:string@$skills 
	--model(-m):string = "gemini-3-flash-preview" #gemini-3.1-flash-lite-preview in free tier
	--profile(-p):string@$profiles = "minimal"
	--dont-kill(-d) #dont kill gemini
] {
	let prompt = $"run ($skill) skill"
	
	gmn --profile $profile --model $model --prompt $prompt
	if not $dont_kill {
		sleep 2sec
		killnode
	}
}
