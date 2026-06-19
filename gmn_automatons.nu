#update all_likes m3u playlist via gemini
export def update-all-likes [] {
	let prompt = $"convert ($env.MY_ENV_VARS.linux_backup | path join youtube_music_playlists | path join all_likes.json) into a m3u file using the m3u-converter skill. Save the output file in the same directory, overwrite any existing file"
	
	gmn --profile no-mcp --model gemini-3.5-flash --prompt $prompt
	sleep 2sec
	killnode
}

const skills = [
	"cron-ai-researcher",
	"cron-conductor-monitor",
	"cron-email-summaries",
	"cron-habitica-todos-summary",
	"cron-manga-download-checker",
	"cron-news-feed",
	"cron-nnet-ga-researcher",
	"cron-nvidia-kernel-audit",
	"cron-pbs-spacetime-sync",
	"cron-research-linkedin-post",
]
const gmn_models = ["gemini-3.5-flash", "gemini-3.1-pro", "gemini-3.1-flash-lite", "gemini-3-flash-preview", "gemini-2.5-flash", "gemini-2.0-flash", "qwen2.5-coder:7b", "qwen2.5-coder:32b", "codestral", "llama3.1"]
const profiles = ["no-mcp", "minimal", "standard", "webdev", "research", "googlesuit", "imagen", "websearch", "ollama", "full"]

#run cron gemini skills
export def --env "gmn cron" [
	skill: string@$skills
	--model(-m): string@$gmn_models  # only used with --gemini-cli; agy model is set via gmn profile
	--profile(-p): string@$profiles = "minimal"
	--dont-kill(-d)             #dont kill gemini mcp servers
	--gemini-cli(-g)            #use the legacy gemini-cli instead of agy (antigravity-cli)
] {

	cd $env.MY_ENV_VARS.llms_configs

	let prompt = if $gemini_cli {
		$"run ($skill) skill"
	} else {
		$"/($skill)"
	}

	let output = if $gemini_cli {
		gmn profile $profile --gemini-cli
		let gemini_cmd = if ($model | is-not-empty) {
			[gemini --model $model --approval-mode=yolo --output-format json --prompt $prompt]
		} else {
			[gemini --approval-mode=yolo --output-format json --prompt $prompt]
		}
		^$gemini_cmd.0 ...($gemini_cmd | skip 1) | complete
	} else {
                # agy model can be passed via --model
                gmn profile $profile
                let agy_cmd = if ($model | is-not-empty) {
                        [agy --model $model --dangerously-skip-permissions --print $prompt]
                } else {
                        [agy --dangerously-skip-permissions --print $prompt]
                }
                ^$agy_cmd.0 ...($agy_cmd | skip 1) | complete
	}

	let tool = if $gemini_cli { "gemini-cli" } else { "agy" }
	gmn-cron-email $skill $output $tool

	# Clean up output: extract only the JSON part
	let cleaned_stdout = _clean-output $output.stdout
	$cleaned_stdout | to-discord -p --process -c gemini_cli_cron

	if not $dont_kill {
		sleep 2sec
		killnode
	}
}

# Helper to extract final report from gemini output
def _clean-output [stdout: string] {
	# 1. Try to parse stdout as JSON (legacy gemini-cli path returns JSON; agy --print path returns plain text)
	let outer_data = try { $stdout | from json } catch { { "response": $stdout } }

	let model_response = if ($outer_data | describe | str contains "record") and "response" in ($outer_data | columns) {
		$outer_data.response
	} else {
		$stdout
	}

	# 2. Search for JSON inside the model's response (which might be wrapped in code blocks)
	# 2a. Look for ```json ... ``` blocks
	let markdown_json_parsed = $model_response | parse -r '(?s).*```json\s*(.*?)\s*```'
	let markdown_json = if ($markdown_json_parsed | is-not-empty) { $markdown_json_parsed | get 0.capture0 } else { "" }
	
	if ($markdown_json | is-not-empty) {
		try {
			return ($markdown_json | from json)
		} catch { }
	}

	# 2b. Look for raw {...} block
	let raw_json_parsed = $model_response | parse -r '(?s).*?(\{.*\})'
	let raw_json = if ($raw_json_parsed | is-not-empty) { $raw_json_parsed | get 0.capture0 } else { "" }
	
	if ($raw_json | is-not-empty) {
		try {
			return ($raw_json | from json)
		} catch { }
	}

	# 3. Fallback: return the response as a simple record with report key if it's just text
	if ($model_response | str contains "---") {
		{ "report": ($model_response | split row "---" | last | str trim) }
	} else {
		{ "report": ($model_response | str trim) }
	}
}


#send cron outputs emails
def gmn-cron-email [
	skill: string
	output: record
	tool: string = "agy"
] {
	let subject = if $output.exit_code == 0 {
		$"Log ($tool): ($skill)"
	} else {
		$"Log ($tool): Error when executing ($skill)"
	}

	let body = $"# Exit code\n\n($output.exit_code)\n\n# stdout\n\n($output.stdout)\n\n# stderr\n\n($output.stderr)"

	send-gmail $env.MY_ENV_VARS.mail $subject --body $body
}
