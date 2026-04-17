# Get credentials
export def "h credentials" [] {
    {
        x-client : ((get-api-key "habitica.id") + ' - nushell habitica api wrapper'),
        x-api-user: (get-api-key "habitica.id"),
        x-api-key: (get-api-key "habitica.token")
    }
}

# Gets user stats
export def "h stats" [--show-avatar(-s)] {
    let headers = h credentials 
    let hab_id = get-api-key "habitica.id"
    let base_url = "https://habitica.com"

    let url = {
        scheme: ( $base_url | split row "://" | get 0 ),
        host: ( $base_url | split row "//" | get 1 | split row "/" | get 0 ),
        path: "/api/v3/user"
    } | url join

    let response = http get $url -H $headers | get data
    let party = h party
    let pending_quest = ($party.quest.key? | is-not-empty) and ($party.quest.active == false) and ($party.quest.members | get $hab_id | is-empty)
    
    let hp = $"($response.stats.hp | math round | into string)/($response.stats.maxHealth | math round | into string)"
    
    let hp = if $response.stats.hp < 30 { 
        echo-r $hp
    } else { 
        $hp
    }
    
    if $show_avatar {
        timg $env.MY_ENV_VARS.habitica_avatar
    }
    
    return {
        name: $response.profile.name,
        level: $response.stats.lvl,
        class: $response.stats.class,
        hp: $hp,
        experience: $"($response.stats.exp | math round | into string)/($response.stats.toNextLevel | math round | into string)",
        mana: $"($response.stats.mp | math round | into string)/($response.stats.maxMP | math round | into string)",
        dailys_to_complete: (h ls dailys | where completed == false and isDue == true | length),
        todos_to_complete: (h ls todos | where completed == false | length),
        logged_in_today: (not $response.needsCron),
        in_quest: $party.quest.active,
        pending_quest: $pending_quest
    }
}

const types = ["dailys", "todos", "habits", "rewards", "completedTodos"]
const add_types = ["dailys", "todos", "habits"]

# Lists user tasks
export def "h ls" [
  task_type?: string@$types # Type of task to list (dailys, todos, habits, rewards, completedTodos)
  --pending(-p) #show pending dailys only
  --now(-n)   #show todays dailys only
  --no-id(-i) #hide task ids
  --tags(-t)  #show only tasks with tags
] {
  let headers = h credentials    
  
  let task_type = _h-input $task_type "Select task type: " --options $types

  if ($task_type not-in $types) {
    return-error "Invalid task type"
  }
  
  let base_url = "https://habitica.com"

  let url = {
    scheme: ( $base_url | split row "://" | get 0 ),
    host: ( $base_url | split row "//" | get 1 | split row "/" | get 0 ),
    path: "/api/v3/tasks/user",
    params: {
      type: $task_type
    }
  } | url join

  let response = http get $url -H $headers | get data

  match $task_type {
    "dailys" => {
      $response
      | select _id frequency text notes checklist tags completed isDue 
      | sort-by frequency
      | if $pending {
            where completed == false and isDue == true 
      } else if $now {
            where isDue == true
      } else {
            $in
      }
    }
    "todos" => {
      $response
      | select _id text notes checklist tags completed createdAt
      | sort-by createdAt
    }
    "habits" => {
      $response
      | select _id frequency text notes tags up down createdAt
      | sort-by createdAt
    }
    "rewards" => {
      $response
    }
    "completedTodos" => {
      $response
      | select _id text notes checklist tags createdAt dateCompleted
      | sort-by createdAt
    }
  }
  | if $no_id {
      reject _id    
    } else {
      $in
    }
  | if $tags {
    where {|t| $t.tags | is-not-empty}
  } else {
    $in
  }
}

# Completes a daily task
export def "h complete-daily" [
  task_id: string # The ID of the daily task to complete
  --verbose(-v)
  --dry-run # Return payload without sending
] {
  let headers = h credentials

  let base_url = "https://habitica.com"

  let url = {
    scheme: ( $base_url | split row "://" | get 0 ),
    host: ( $base_url | split row "//" | get 1 | split row "/" | get 0 ),
    path: $"/api/v3/tasks/($task_id)/score/up"
  } | url join

  let response = http post --content-type application/json $url -H $headers {}

  if ($response.success != true) {
  	return-error $"Failed to complete task: ($response.message)"
  }
  if ($verbose) {
    print (echo-g $"Successfully completed task ID: ($task_id)")
  } 
}

# Marks all due and incomplete daily tasks as complete
export def "h mark-dailys-done" [--verbose(-v)] {
  let dailys_to_complete = h ls dailys | where completed == false and isDue == true

  if ($dailys_to_complete | is-empty) {
    print (echo-r "No due and incomplete daily tasks found to mark as done.")
    return
  }
  
  let total = $dailys_to_complete | length
  mut index = 0
  
  for $daily in $dailys_to_complete {
    if $verbose {
      print -n $"Completing daily: ($daily.text) "
    }
    h complete-daily $daily._id
    if $verbose {
      print (echo-g (char -u ebb1))
    }
    if not $verbose {
      progress_bar ($index + 1) $total
    }
    $index = $index + 1
    sleep 5sec
  }
  
  if $verbose {
    print (echo-g "All due and incomplete daily tasks marked as done.")
  }
}

# Adds a new task (daily or todo)
export def "h add" [
  task_type?: string@$add_types # Type of task to add (dailys, todos, habits)
  --text(-t): string # Task text
  --notes(-n): string # Task notes
  --priority(-p): number # Task priority (1, 1.5, 2, 2.5)
  --due(-d): string # Due date (YYYY-MM-DD) for todos
  --checklist(-c): list<string> # Checklist items for todos
  --frequency(-f): string # frequency (daily, weekly, monthly, yearly) for dailys
  --every-x(-x): int # Repeat every X days/weeks/etc.
  --days(-s): list<string> # Days of week for weekly dailys (m, t, w, th, f, s, su)
  --direction(-r): string # Direction for habits (positive, negative, both)
  --dry-run # Return payload without sending
] {
  let headers = h credentials
  
  let task_type = _h-input $task_type "Select task type: " --options $add_types

  if ($task_type not-in ["dailys", "todos", "habits"]) {
    return-error "Invalid task type. Must be 'dailys', 'todos', or 'habits'."
  }

  let base_url = "https://habitica.com"

  let url = {
    scheme: ( $base_url | split row "://" | get 0 ),
    host: ( $base_url | split row "//" | get 1 | split row "/" | get 0 ),
    path: "/api/v3/tasks/user"
  } | url join

  let task_text = _h-input $text "Enter task text (required): "
  if ($task_text | is-empty) {
    return-error "Task text is required."
  }

  let task_notes = _h-input $notes "Enter notes (optional): "
  
  let task_priority = if ($priority != null) {
    $priority
  } else {
    let task_priority_options = ["Trivial (1)", "Easy (1.5)", "Medium (2)", "Hard (2.5)"]
    let task_priority_input = _h-input null "Select priority (optional): " --options $task_priority_options
    match $task_priority_input {
        "Trivial (1)" => 1.0,
        "Easy (1.5)" => 1.5,
        "Medium (2)" => 2.0,
        "Hard (2.5)" => 2.5,
        _ => null
    }
  }

  let task_singular = match $task_type {
    "dailys" => "daily",
    "todos" => "todo",
    "habits" => "habit",
    _ => $task_type
  }

  mut payload = {
    text: $task_text,
    type: $task_singular,
  }

  if ($task_notes | is-not-empty) {
    $payload = ($payload | upsert notes $task_notes)
  }
  if ($task_priority != null) {
    $payload = ($payload | upsert priority $task_priority)
  }

  match $task_type {
    "todos" => {
      let task_date = _h-input $due "Enter due date (YYYY-MM-DD, optional): "
      if ($task_date | is-not-empty) {
        # Convert to ISO 8601 format
        let iso_date = ($task_date | into datetime | format date "%Y-%m-%dT%H:%M:%S.000Z")
        $payload = ($payload | upsert date $iso_date)
      }

      let checklist_data = if ($checklist != null) {
        $checklist | each { |it| {text: $it, completed: false} }
      } else {
        mut list = []
        loop {
            let checklist_item = (input "Enter checklist item (leave empty to finish): ")
            if ($checklist_item | is-empty) {
                break
            }
            $list = ($list | append {text: $checklist_item, completed: false})
        }
        $list
      }
      
      if ($checklist_data | is-not-empty) {
        $payload = ($payload | upsert checklist $checklist_data)
      }
    }
    "dailys" => {
      let frequency_options = ["daily", "weekly", "monthly", "yearly"]
      let task_frequency = _h-input $frequency "Select frequency (required): " --options $frequency_options
      
      if ($task_frequency | is-empty) {
        return-error "Frequency is required for daily tasks."
      }
      $payload = ($payload | upsert frequency $task_frequency)

      if ($task_frequency == "daily") {
        let every_x_input = if ($every_x != null) {
            $every_x
        } else {
            let input_val = (input "Repeat every X days (optional, e.g., 2 for every other day): ")
            if ($input_val | is-not-empty) { $input_val | into int } else { null }
        }
        
        if ($every_x_input != null) {
          $payload = ($payload | upsert everyX $every_x_input)
        }
      } else if ($task_frequency == "weekly") {
        let days_of_week = ["m", "t", "w", "th", "f", "s", "su"]
        mut repeats = {}
        
        if ($days != null) {
            for $day in $days_of_week {
                if ($day in $days) {
                    $repeats = ($repeats | upsert $day true)
                } else {
                    $repeats = ($repeats | upsert $day false)
                }
            }
        } else {
            for $day in $days_of_week {
                let repeat_day = (input $"Repeat on ($day)? (y/n): ")
                if ($repeat_day == "y") {
                    $repeats = ($repeats | upsert $day true)
                } else {
                    $repeats = ($repeats | upsert $day false)
                }
            }
        }
        $payload = ($payload | upsert repeats $repeats)
      }
    }
    "habits" => {
      let direction_options = ["positive", "negative", "both"]
      let task_direction = _h-input $direction "Select direction (required): " --options $direction_options
      
      $payload = match $task_direction {
        "positive" => ($payload | upsert up true | upsert down false),
        "negative" => ($payload | upsert up false | upsert down true),
        "both" => ($payload | upsert up true | upsert down true),
        _ => $payload
      }
    }
  }

  if ($dry_run) { return $payload }

  let response = http post --content-type application/json $url -H $headers ($payload | to json)
  
  if ($response.success == true) {
    print (echo-g $"Successfully added ($task_type) task: ($response.data.text)")
  } else {
    print (echo-r $"Failed to add ($task_type) task: ($response.message)")
  }
}

# Deletes a task (daily, todo, habit)
export def "h del" [
  task_type?: string@$add_types # Type of task to delete (dailys, todos, habits)
  --id: string # Task ID to delete
  --text(-t): string # Task text to delete (first match)
  --dry-run # Return payload without sending
] {
  let headers = h credentials
  
  let task_type = _h-input $task_type "Select task type to delete: " --options $add_types

  if ($task_type not-in ["dailys", "todos", "habits"]) {
    return-error "Invalid task type for deletion. Must be 'dailys', 'todos', or 'habits'."
  }

  let task_to_delete = if ($id | is-not-empty) {
    { _id: $id }
  } else if ($text | is-not-empty) {
    let tasks = h ls $task_type
    let found = $tasks | where text == $text
    if ($found | is-empty) {
        return-error $"No ($task_type) task found with text: ($text)"
    }
    $found | get 0
  } else {
    let tasks = h ls $task_type | reverse

    if ($tasks | is-empty) {
        print (echo-r $"No ($task_type) tasks found to delete.")
        return
    }

    let idx_task_to_delete = _h-input null "Select task to delete: " --options $tasks --id
    $tasks | get $idx_task_to_delete
  }
  
  if ($dry_run) { return $task_to_delete }

  let base_url = "https://habitica.com"

  let url = {
    scheme: ( $base_url | split row "://" | get 0 ),
    host: ( $base_url | split row "//" | get 1 | split row "/" | get 0 ),
    path: $"/api/v3/tasks/($task_to_delete._id)"
  } | url join
  
  let response = http delete $url -H $headers

  if ($response.success == true) {
    let task_text = $task_to_delete.text? | default $task_to_delete._id
    print (echo-g $"Successfully deleted ($task_type) task: ($task_text)")
  } else {
    print (echo-r $"Failed to delete ($task_type) task: ($response.message)")
  }
}

# Marks selected todo tasks as completed
export def "h complete-todos" [
    --ids: list<string> # Task IDs to complete
    --texts: list<string> # Task texts to complete
    --dry-run # Return payload without sending
] {
    let headers = h credentials

    let todos = h ls todos | where completed == false | reverse

    if ($todos | is-empty) {
        print (echo-r "No incomplete todo tasks found to complete.")
        return
    }

    let selected_todos = if ($ids != null) {
        $todos | where _id in $ids
    } else if ($texts != null) {
        $todos | where text in $texts
    } else {
        let selected_indices = _h-input null "Select todos to complete (use space to multi-select): " --options $todos --multi
        $todos | enumerate | where index in $selected_indices | get item
    }
    
    if ($dry_run) { return $selected_todos }

    let base_url = "https://habitica.com"

    for $todo in $selected_todos {
        print -n $"Completing todo: ($todo.text) "
      
        let url = {
            scheme: ( $base_url | split row "://" | get 0 ),
            host: ( $base_url | split row "//" | get 1 | split row "/" | get 0 ),
            path: $"/api/v3/tasks/($todo._id)/score/up"
        } | url join
      
        let response = http post --content-type application/json $url -H $headers {}

        if ($response.success == true) {
            print (echo-g (char -u ebb1))
        } else {
            print (echo-r (char -u f467))
        }

        sleep 1sec
    }
}

# Define the function to score habits
export def "h score-habits" [
    --ids: list<string> # Habit IDs to score
    --texts: list<string> # Habit texts to score
    --direction(-d): string # Direction to score (up, down)
    --dry-run # Return payload without sending
] {
    let headers = h credentials

    # Fetch the list of habits
    let habits = h ls habits | reverse

    # Check if the list is empty
    if ($habits | is-empty) {
        print (echo-r "No habits found.")
        return
    }

    # Selection logic
    let selected_habits = if ($ids != null) {
        $habits | where _id in $ids
    } else if ($texts != null) {
        $habits | where text in $texts
    } else {
        let selected_indices = $habits | input list -ifmd text (echo-g "Select habits to score: ")
        $habits | enumerate | where index in $selected_indices | get item
    }
    
    if ($dry_run) { return { habits: $selected_habits, direction: $direction } }

    let base_url = "https://habitica.com"
    
    # Loop over the selected habits
    for $habit in $selected_habits {
        # Determine available directions for the habit
        mut directions = []
        if $habit.up {
            $directions = $directions | append "up"
        }
        if $habit.down {
            $directions = $directions | append "down"
        }

        # Check if the habit has no available directions
        if ($directions | is-empty) {
            print $"Habit '($habit.text)' cannot be scored since there are no directions enabled."
            continue
        }

        # Direction logic
        let score_dir = if ($direction != null) {
            if ($direction in $directions) {
                $direction
            } else {
                return-error $"Invalid direction '($direction)' for habit '($habit.text)'. Available: ($directions)"
            }
        } else {
             $directions | input list -f $"Choose a direction to score in habit '($habit.text)': "
        }
        
        let url = {
            scheme: ( $base_url | split row "://" | get 0 ),
            host: ( $base_url | split row "//" | get 1 | split row "/" | get 0 ),
            path: $"/api/v3/tasks/($habit._id)/score/($score_dir)"
        } | url join
        
        # Score the habit
        let response = http post --content-type application/json -H $headers $url {}

        # Handle the response
        if ($response.success == true) {
            print $"Scored habit '($habit.text)' as ($score_dir)."
        } else {
            print $"Failed to score habit '($habit.text)': ($response.body.message)"
        }

        # Add a delay to avoid rate limits
        sleep 1sec
    }
}

#skills data
export def "h skills" [] {
    [
        {class: "warrior", name: "Brutal Smash", spellId: "smash", cost: 10, target: "task", level: 11, effect: "+50% damage to a task"},
        {class: "warrior", name: "Defensive Stance", spellId: "defensiveStance", cost: 25, target: "player", level: 12, effect: "-50% damage from Dailies"},
        {class: "warrior", name: "Valorous Presence", spellId: "valorousPresence", cost: 20, target: "player", level: 13, effect: "+100% damage to Boss"},
        {class: "warrior", name: "Intimidating Gaze", spellId: "intimidate", cost: 15, target: "party", level: 14, effect: "+20% damage to Boss for party"},

        {class: "wizard", name: "Burst of Flames", spellId: "fireball", cost: 10, target: "task", level: 11, effect: "+50% experience from a task"},
        {class: "wizard", name: "Ethereal Surge", spellId: "mpheal", cost: 30, target: "player", level: 12, effect: "+50% mana"},
        {class: "wizard", name: "Earthquake", spellId: "earth", cost: 35, target: "task", level: 13, effect: "+100% damage to a task"},
        {class: "wizard", name: "Chilling Frost", spellId: "frost", cost: 40, target: "party", level: 14, effect: "+20% damage to Boss for party"},

        {class: "rogue", name: "Pickpocket", spellId: "pickPocket", cost: 10, target: "task", level: 11, effect: "+50% gold from a task"},
        {class: "rogue", name: "Backstab", spellId: "backStab", cost: 15, target: "task", level: 12, effect: "+100% experience from a task"},
        {class: "rogue", name: "Tools of the Trade", spellId: "toolsOfTrade", cost: 25, target: "party", level: 13, effect: "+20% gold from tasks for party"},
        {class: "rogue", name: "Stealth", spellId: "stealth", cost: 45, target: "player", level: 14, effect: "-50% health from unticked Dailies"},

        {class: "healer", name: "Healing Light", spellId: "heal", cost: 15, target: "player", level: 11, effect: "+50% health"},
        {class: "healer", name: "Searing Brightness", spellId: "brightness", cost: 15, target: "task", level: 12, effect: "+100% experience from a task"},
        {class: "healer", name: "Protective Aura", spellId: "protectAura", cost: 30, target: "party", level: 13, effect: "-50% damage from Boss for party"},
        {class: "healer", name: "Blessing", spellId: "healAll", cost: 25, target: "party", level: 14, effect: "+20% experience from tasks for party"}
    ]
}

# Casts a skill
export def "h skill" [
    skill_name?: string # The name of the skill to cast
] {
    let headers = h credentials
    let base_url = "https://habitica.com"
    let user_stats = h stats
    let user_class = $user_stats.class

    let skills_data = h skills

    let available_skills = $skills_data | where class == $user_class

    let selected_skill = if ($skill_name | is-empty) {
        if ($available_skills | is-empty) {
            print (echo-r $"No skills available for your class: ($user_class).")
            return
        }
        _h-input null "Select a skill to cast: " --options $available_skills --id
    } else {
        let skill_found = $available_skills | where name == $skill_name
        if ($skill_found | is-empty) {
            print (echo-r $"Skill '($skill_name)' not found for your class: ($user_class).")
            return
        }
        $skill_found | get 0
    }

    let spell_id = $selected_skill.spellId

    let url = {
        scheme: ( $base_url | split row "://" | get 0 ),
        host: ( $base_url | split row "//" | get 1 | split row "/" | get 0 ),
        path: $"/api/v3/user/class/cast/($spell_id)"
    } | url join

    print (echo-g $"Casting skill: ($selected_skill.name) Cost: ($selected_skill.cost) MP")
    let response = http post --content-type application/json $url -H $headers {}

    if ($response.success == true) {
        print (echo-g $"Successfully cast skill: ($selected_skill.name).")
    } else {
        print (echo-r $"Failed to cast skill: ($selected_skill.name). Message: ($response.message)")
    }
}

# Casts a skill multiple times based on available mana
export def "h skill-max" [
    skill_name?: string # The name of the skill to cast multiple times
] {
    let headers = h credentials
    let base_url = "https://habitica.com"
    let user_stats = h stats
    let user_class = $user_stats.class
    let current_mana_str = $user_stats.mana

    # Extract current mana value (e.g., "50/100" -> 50)
    let current_mana = $current_mana_str | split row "/" | get 0 | into int

    let skills_data = h skills

    let available_skills = $skills_data | where class == $user_class

    let selected_skill = if ($skill_name | is-empty) {
        if ($available_skills | is-empty) {
            print (echo-r $"No skills available for your class: ($user_class).")
            return
        }
        _h-input null "Select a skill to cast multiple times: " --options $available_skills --id
    } else {
        let skill_found = $available_skills | where name == $skill_name
        if ($skill_found | is-empty) {
            print (echo-r $"Skill '($skill_name)' not found for your class: ($user_class).")
            return
        }
        $skill_found | get 0
    }

    let skill_cost = $selected_skill.cost

    if ($skill_cost == 0) {
        print (echo-r $"Skill '($selected_skill.name)' has no mana cost. Cannot use skill-max.")
        return
    }

    let times_to_cast = ($current_mana / $skill_cost) | math floor | into int

    if ($times_to_cast == 0) {
        print (echo-r $"Not enough mana to cast '($selected_skill.name)'. Current Mana: ($current_mana) MP, Skill Cost: ($skill_cost) MP.")
        return
    }

    print (echo-g $"Attempting to cast '($selected_skill.name)' ($times_to_cast) times. Total Mana Cost: ($times_to_cast * $skill_cost) MP.")

    let spell_id = $selected_skill.spellId
    
    let url = {
        scheme: ( $base_url | split row "://" | get 0 ),
        host: ( $base_url | split row "//" | get 1 | split row "/" | get 0 ),
        path: $"/api/v3/user/class/cast/($spell_id)"
    } | url join
    
    for i in (seq 1 $times_to_cast) {
        progress_bar $i $times_to_cast

        http post --content-type application/json $url -H $headers {} | ignore
        sleep 5sec
    }

    print (echo-g $"Finished casting '($selected_skill.name)' ($times_to_cast) times.")
}

# Logs in to Habitica and runs cron
export def "h login" [] {
    let stats = h stats
    if ($stats.dailys_to_complete > 0) {
        print "Completing pending daily tasks..."
        h mark-dailys-done
    }
        
    if $stats.logged_in_today {
        print (echo-g "Already logged in today.")
        return
    }
    
    let headers = h credentials
    let base_url = "https://habitica.com"

    let url = {
        scheme: ( $base_url | split row "://" | get 0 ),
        host: ( $base_url | split row "//" | get 1 | split row "/" | get 0 ),
        path: "/api/v3/cron"
    } | url join

    let response = http post --content-type application/json $url -H $headers {}

    if ($response.success == true) {
        print (echo-g "Successfully logged in to Habitica.")
        return
    } 
    print (echo-r $"Failed to log in to Habitica: ($response.message)")
}

# Buys a health potion
export def "h buy-potion" [] {
    let headers = h credentials
    let base_url = "https://habitica.com"

    let url = {
        scheme: ( $base_url | split row "://" | get 0 ),
        host: ( $base_url | split row "//" | get 1 | split row "/" | get 0 ),
        path: "/api/v3/user/buy-health-potion"
    } | url join

    let response = http post --content-type application/json $url -H $headers {}

    if ($response.success == true) {
        print (echo-g "Successfully bought a health potion.")
    } else {
        print (echo-r $"Failed to buy a health potion: ($response.message)")
    }
}

# Buys an item from the armoire
export def "h buy-armoir" [] {
    let headers = h credentials
    let base_url = "https://habitica.com"

    let url = {
        scheme: ( $base_url | split row "://" | get 0 ),
        host: ( $base_url | split row "//" | get 1 | split row "/" | get 0 ),
        path: "/api/v3/user/buy-armoire"
    } | url join

    let response = http post --content-type application/json $url -H $headers {}

    if ($response.success == true) {
        print (echo-g "Successfully bought an item from the armoire.")
        return $response.data.armoire
    } else {
        print (echo-r $"Failed to buy an item from the armoire: ($response.message)")
    }
}

# Completes a checklist item for a task
export def "h complete-checklist" [
  task_type?: string@$add_types # Type of task to complete checklist for (dailys, todos, habits)
  --id: string # Task ID
  --text(-t): string # Task text
  --indices(-i): list<int> # Checklist item indices to complete
  --items(-s): list<string> # Checklist item texts to complete
  --dry-run # Return payload without sending
] {
  let headers = h credentials
  
  let task_type = _h-input $task_type "Select task type: " --options $add_types

  if ($task_type not-in ["dailys", "todos", "habits"]) {
    return-error "Invalid task type. Must be 'dailys', 'todos', or 'habits'."
  }

  let selected_task = if ($id | is-not-empty) {
    let tasks = h ls $task_type
    let found = $tasks | where _id == $id
    if ($found | is-empty) { return-error $"No ($task_type) task found with ID: ($id)" }
    $found | get 0
  } else if ($text | is-not-empty) {
    let tasks = h ls $task_type
    let found = $tasks | where text == $text
    if ($found | is-empty) { return-error $"No ($task_type) task found with text: ($text)" }
    $found | get 0
  } else {
    let tasks_with_checklist = h ls $task_type | where ($it.checklist | is-not-empty) | reverse
    if ($tasks_with_checklist | is-empty) {
        print (echo-r $"No tasks with checklists found for type '($task_type)'.")
        return
    }
    let selected_task_index = _h-input null "Select a task to complete checklist items for: " --options $tasks_with_checklist --id
    $tasks_with_checklist | get $selected_task_index
  }

  let checklist_items = $selected_task.checklist | where completed == false

  if ($checklist_items | is-empty) {
    print (echo-r "No incomplete checklist items found for this task.")
    return
  }

  let selected_checklist_indices = if ($indices != null) {
    $indices
  } else if ($items != null) {
    $checklist_items | enumerate | where item.text in $items | get index
  } else {
    _h-input null "Select checklist items to complete: " --options $checklist_items --multi
  }

  if ($dry_run) { return { task: $selected_task, item_indices: $selected_checklist_indices } }

  let base_url = "https://habitica.com"

  for $index in $selected_checklist_indices {
    let item = $checklist_items | get $index
    let task_id = $selected_task._id
    let item_id = $item.id

    let url = {
        scheme: ( $base_url | split row "://" | get 0 ),
        host: ( $base_url | split row "//" | get 1 | split row "/" | get 0 ),
        path: $"/api/v3/tasks/($task_id)/checklist/($item_id)/score"
    } | url join

    let response = http post --content-type application/json $url -H $headers {}

    if ($response.success == true) {
        print ((echo-g $"Successfully completed checklist item: ") + ($item.text))
    } else {
        print ((echo-r $"Failed to complete checklist item: ") + ($item.text) + (echo-r $". Message: ($response.message)"))
    }
    sleep 1sec
  }
}

# Adds a checklist item to a task
export def "h add-checklist" [
  task_type?: string@$add_types # Type of task to add checklist item to (dailys, todos, habits)
  --id: string # Task ID
  --text(-t): string # Task text
  --items(-s): list<string> # Checklist items to add
  --dry-run # Return payload without sending
] {
  let headers = h credentials
  
  let task_type = _h-input $task_type "Select task type: " --options $add_types

  if ($task_type not-in ["dailys", "todos", "habits"]) {
    return-error "Invalid task type. Must be 'dailys', 'todos', or 'habits'."
  }

  let selected_task = if ($id | is-not-empty) {
    let tasks = h ls $task_type
    let found = $tasks | where _id == $id
    if ($found | is-empty) { return-error $"No ($task_type) task found with ID: ($id)" }
    $found | get 0
  } else if ($text | is-not-empty) {
    let tasks = h ls $task_type
    let found = $tasks | where text == $text
    if ($found | is-empty) { return-error $"No ($task_type) task found with text: ($text)" }
    $found | get 0
  } else {
    let tasks = h ls $task_type | reverse
    if ($tasks | is-empty) {
        print (echo-r $"No tasks found for type '($task_type)'.")
        return
    }
    let selected_task_index = _h-input null "Select a task to add a checklist item to: " --options $tasks --id
    $tasks | get $selected_task_index
  }

  let checklist_items = if ($items != null) {
    $items
  } else {
    mut list = []
    loop {
        let item_text = (input "Enter checklist item (leave empty to finish): ")
        if ($item_text | is-empty) {
            break
        }
        $list = ($list | append $item_text)
    }
    $list
  }

  if ($dry_run) { return { task: $selected_task, items: $checklist_items } }

  if ($checklist_items | is-empty) {
    print (echo-r "No checklist items entered.")
    return
  }

  let base_url = "https://habitica.com"
  let task_id = $selected_task._id

  let url = {
      scheme: ( $base_url | split row "://" | get 0 ),
      host: ( $base_url | split row "//" | get 1 | split row "/" | get 0 ),
      path: $"/api/v3/tasks/($task_id)/checklist"
  } | url join

  for $item in $checklist_items {
    let payload = { text: $item }
    let response = http post --content-type application/json $url -H $headers ($payload | to json)

    if ($response.success == true) {
        print ((echo-g $"Successfully added checklist item '($item)' to task: ") + ($selected_task.text))
    } else {
        print ((echo-r $"Failed to add checklist item '($item)'. Message: ") + ($response.message))
    }
    sleep 1sec
  }
}

# Party info
export def "h party" [] {
    let headers = h credentials
    let base_url = "https://habitica.com"
    
    let url = {
        scheme: ( $base_url | split row "://" | get 0 ),
        host: ( $base_url | split row "//" | get 1 | split row "/" | get 0 ),
        path: "/api/v3/groups/party"
    } | url join
    
    let response = http get $url -H $headers
    
    if not ($response.success == true) {
        return-error (echo-r $"Failed to get party data: ($response.message)")
    }
    
    return ($response | get data)
}

# Accepts a pending quest
export def "h auto-quest" [] {
    let headers = h credentials
    let hab_id = get-api-key "habitica.id"
    let base_url = "https://habitica.com"

    let party = h party

    if (($party.quest.key | is-not-empty) and ($party.quest.active == false) and ($party.quest.members | get $hab_id | is-empty)) {
        print (echo-g "Pending quest found. Accepting...")

        let accept_url = {
            scheme: ( $base_url | split row "://" | get 0 ),
            host: ( $base_url | split row "//" | get 1 | split row "/" | get 0 ),
            path: "/api/v3/groups/party/quests/accept"
        } | url join

        let accept_response = http post --content-type application/json $accept_url -H $headers {}

        if ($accept_response.success == true) {
            print (echo-g "Successfully accepted the quest.")
        } else {
            print (echo-r $"Failed to accept the quest: ($accept_response.message)")
        }
    } else {
        print "No pending quests to accept."
    }
}

# Show help for Habitica commands
export def "h help" [] {
  let commands_description = [
    { name: "h add", description: "Adds a new task (daily, todo, habit)" },
    { name: "h add-checklist", description: "Adds a checklist item to a task" },
    { name: "h auto-quest", description: "Accepts a pending quest" },
    { name: "h buy-armoir", description: "Buys an item from the armoire" },
    { name: "h buy-potion", description: "Buys a health potion" },
    { name: "h complete-checklist", description: "Completes a checklist item for a task" },
    { name: "h complete-daily", description: "Completes a daily task" },
    { name: "h complete-todos", description: "Marks selected todo tasks as completed" },
    { name: "h credentials", description: "Get credentials" },
    { name: "h del", description: "Deletes a task (daily, todo, habit)" },
    { name: "h help", description: "Show this help message" },
    { name: "h login", description: "Logs in to Habitica and runs cron" },
    { name: "h ls", description: "Lists user tasks" },
    { name: "h mark-dailys-done", description: "Marks all due and incomplete daily tasks as complete" },
    { name: "h party", description: "Party info" },
    { name: "h score-habits", description: "Score habits" },
    { name: "h skill", description: "Casts a skill" },
    { name: "h skill-max", description: "Casts a skill multiple times" },
    { name: "h skills", description: "Lists skills" },
    { name: "h stats", description: "Gets user stats" },
  ] | sort-by name

  # Calculate the maximum length of the command names for padding
  let max_name_length = ($commands_description | get name | str length | math max)

  # Format the help text with padding and descriptions
  let help_text = $commands_description
    | each {|cmd|
        # Pad the command name to align descriptions
        let padded_name = ($cmd.name | fill -w ($max_name_length + 2) -a left)
        # Format the line: "command_name    # description"
        $"($padded_name)  # ($cmd.description)"
      }
    | prepend "Habitica Tools Help:\n" # Add a header

  # Print the formatted help text with syntax highlighting
  print ($help_text | str join "\n" | nu-highlight)
}

#aliases
export alias hs = h stats -s
export alias todos = h ls todos -i 
export alias dailys = h ls dailys -ni

#budget
export def budget [] {
    h ls dailys | find budget | get checklist.0
}

# Private helper for handling flag vs interactive input
def _h-input [
    flag: any,
    prompt_msg: string,
    --options: any, # List of options for input list
    --multi, # Use multi-select
    --id, # Use -fid text (returns index but shows text)
    --is-list # If true, returns flag directly if not null (for lists)
] {
    if ($flag != null) { return $flag }

    if ($options != null) {
        if $multi {
            $options | input list -ifmd text (echo-g $prompt_msg)
        } else if $id {
            $options | input list -fid text (echo-g $prompt_msg)
        } else {
            $options | input list -f (echo-g $prompt_msg)
        }
    } else {
        input $prompt_msg
    }
}
