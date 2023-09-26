#!/usr/bin/env nu

$env.MY_ENV_VARS = (
	$env.MY_ENV_VARS 
	| upsert l_prompt {||
		if not ($env.MY_ENV_VARS | is-column l_prompt) {
  	  		"short"
  		} else if ($env.MY_ENV_VARS.l_prompt | is-empty) or ($env.MY_ENV_VARS.l_prompt == "short") {
    		"long"
  		} else {
    		"short"
  		}
  	}
)