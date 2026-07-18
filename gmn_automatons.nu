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
	--model(-m): string@$gmn_models  # model to use
	--profile(-p): string@$profiles = "minimal" #profile to use (use tab to see options)
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

# Free OpenCode Zen model names for --model completions
const opn_normal_models = [
  "opencode/deepseek-v4-flash-free"
  "opencode/nemotron-3-ultra-free"
  "opencode/big-pickle"
  "opencode/deepseek-v4-flash"
  "opencode/deepseek-v4-pro"
  "opencode-go/qwen3.7-max"
  "opencode-go/qwen3.7-plus"
]

# Run cron opencode skills
export def --env "opn cron" [
    skill: string@$skills
    --model(-m): string@$opn_normal_models            # model to use
    --profile(-p): string@$profiles = "minimal" #profile to use
    --dont-kill(-d)             #dont kill mcp servers
    --ollama(-o)                #use local ollama models instead of remote
    --build(-b)                 #start in build mode instead of plan mode
] {
  cd $env.MY_ENV_VARS.llms_configs

  let prompt = $"/($skill)"

  # Resolve model before profile call so it can be forwarded
  let actual_model = if (not $ollama) and ($model | is-empty) {
    "opencode/deepseek-v4-flash-free"
  } else if ($model | is-not-empty) {
    $model
  } else {
    ""
  }

  let model_value = if (not $ollama) and ($actual_model | is-not-empty) { $actual_model } else { "" }

  if $ollama {
    if $build { opn profile $profile --ollama --build } else { opn profile $profile --ollama }
  } else {
    if $build { opn profile $profile --build --model $model_value } else { opn profile $profile --model $model_value }
  }

  let opn_bin = $env.HOME | path join .opencode bin opencode
  let opn_cmd = if ($actual_model | is-not-empty) {
    [$opn_bin run --model $actual_model --dangerously-skip-permissions $prompt]
  } else {
    [$opn_bin run --dangerously-skip-permissions $prompt]
  }

  let output = ^$opn_cmd.0 ...($opn_cmd | skip 1) | complete

  # Reuse gmn-cron-email with "opencode" tool name
  gmn-cron-email $skill $output "opencode"

  # Clean up and post stdout to Discord
  let cleaned_stdout = _clean-output $output.stdout
  $cleaned_stdout | to-discord -p --process -c gemini_cli_cron

  if not $dont_kill {
    sleep 2sec
    killnode
  }
}

# Helper to extract final report from agent output
def _clean-output [stdout: string] {
	let outer_data = try { $stdout | from json } catch { { "response": $stdout } }

	let model_response = if ($outer_data | describe | str contains "record") and "response" in ($outer_data | columns) {
		$outer_data.response
	} else {
		$stdout
	}

	# Pass through as raw markdown — no JSON wrapping, no truncation
	$model_response | str trim
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
