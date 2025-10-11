# Get credentials
export def "h credentials" [] {
    {
        x-client : ($env.MY_ENV_VARS.api_keys.habitica.id + ' - nushell habitica api wrapper'),
        x-api-user: $env.MY_ENV_VARS.api_keys.habitica.id,
        x-api-key: $env.MY_ENV_VARS.api_keys.habitica.token
    }
}

# Gets user stats
export def "h stats" [] {
    let headers = h credentials 
    let hab_id = $env.MY_ENV_VARS.api_keys.habitica.id
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
    
    timg $env.MY_ENV_VARS.habitica_avatar
    return {
        name: $response.profile.name,
        level: $response.stats.lvl,
        class: $response.stats.class,
        hp: $hp,
        experience: $"($response.stats.exp | math round | into string)/($response.stats.toNextLevel | math round | into string)",
        mana: $"($response.stats.mp | math round | into string)/($response.stats.maxMP | math round | into string)",
        logged_in_today: (not $response.needsCron),
        dailys_to_complete: (h ls dailys | where completed == false and isDue == true | length),
        todos_to_complete: (h ls todos | where completed == false | length),
        in_quest: $party.quest.active,
        pending_quest: $pending_quest
    }
}

# Lists user tasks
export def "h ls" [
  task_type?: string # Type of task to list (dailys, todos, habits, rewards, completedTodos)
  --pending(-p) #show pending dailys only
  --now(-n)   #show todays dailys only
  --no-id(-i) #hide task ids
  --tags(-t)  #show only tasks with tags
] {
  let headers = h credentials    
  let types = ["dailys", "todos", "habits", "rewards", "completedTodos"]
  
  let task_type = if ($task_type | is-empty) {
    $types
    | input list -f (echo-g "Select task type: ")
  } else {
    $task_type
  }

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
      | select _id frequency text notes checklist tags up down createdAt
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
] {
  let headers = h credentials

  let base_url = "https://habitica.com"

  let url = {
    scheme: ( $base_url | split row "://" | get 0 ),
    host: ( $base_url | split row "//" | get 1 | split row "/" | get 0 ),
    path: $"/api/v3/tasks/($task_id)/score/up"
  } | url join

  http post --content-type application/json $url -H $headers {}
}

# Marks all due and incomplete daily tasks as complete
export def "h mark-dailys-done" [] {
  let dailys_to_complete = h ls dailys | where completed == false and isDue == true

  if ($dailys_to_complete | is-empty) {
    print (echo-r "No due and incomplete daily tasks found to mark as done.")
    return
  }

  for $daily in $dailys_to_complete {
    print -n $"Completing daily: ($daily.text) "
    h complete-daily $daily._id
    print (echo-g (char -u ebb1))
    sleep 5sec
  }
  
  print (echo-g "All due and incomplete daily tasks marked as done.")
}

# Adds a new task (daily or todo)
export def "h add" [
  task_type?: string # Type of task to add (daily, todo, habit)
] {
  let headers = h credentials
  let types = ["daily", "todo", "habit"]
  
  let task_type = if ($task_type | is-empty) {
    $types
    | input list -f (echo-g "Select task type: ")
  } else {
    $task_type
  }

  if ($task_type not-in $types) {
    return-error "Invalid task type. Must be 'daily', 'todo', or 'habit'."
  }

  let base_url = "https://habitica.com"

  let url = {
    scheme: ( $base_url | split row "://" | get 0 ),
    host: ( $base_url | split row "//" | get 1 | split row "/" | get 0 ),
    path: "/api/v3/tasks/user"
  } | url join

  let task_text = (input "Enter task text (required): ")
  if ($task_text | is-empty) {
    return-error "Task text is required."
  }

  let task_notes = (input "Enter notes (optional): ")
  let task_priority_options = ["Trivial (1)", "Easy (1.5)", "Medium (2)", "Hard (2.5)"]
  let task_priority_input = ($task_priority_options | input list -f (echo-g "Select priority (optional): "))
  let task_priority = match $task_priority_input {
    "Trivial (1)" => 1.0,
    "Easy (1.5)" => 1.5,
    "Medium (2)" => 2.0,
    "Hard (2.5)" => 2.5,
    _ => null
  }

  mut payload = {
    text: $task_text,
    type: $task_type,
  }

  if ($task_notes | is-not-empty) {
    $payload = ($payload | upsert notes $task_notes)
  }
  if ($task_priority | is-not-empty) {
    $payload = ($payload | upsert priority $task_priority)
  }

  match $task_type {
    "todo" => {
      let task_date = (input "Enter due date (YYYY-MM-DD, optional): ")
      if ($task_date | is-not-empty) {
        # Convert to ISO 8601 format
        let iso_date = ($task_date | into datetime | date format "%Y-%m-%dT%H:%M:%S.000Z")
        $payload = ($payload | upsert date $iso_date)
      }

      mut checklist = []
      loop {
        let checklist_item = (input "Enter checklist item (leave empty to finish): ")
        if ($checklist_item | is-empty) {
          break
        }
        $checklist = ($checklist | append {text: $checklist_item, completed: false})
      }
      if ($checklist | is-not-empty) {
        $payload = ($payload | upsert checklist $checklist)
      }
    }
    "daily" => {
      let frequency_options = ["daily", "weekly", "monthly", "yearly"]
      let task_frequency = ($frequency_options | input list -f (echo-g "Select frequency (required): "))
      if ($task_frequency | is-empty) {
        return-error "Frequency is required for daily tasks."
      }
      $payload = ($payload | upsert frequency $task_frequency)

      if ($task_frequency == "daily") {
        let every_x = (input "Repeat every X days (optional, e.g., 2 for every other day): ")
        if ($every_x | is-not-empty) {
          $payload = ($payload | upsert everyX ($every_x | into int))
        }
      } else if ($task_frequency == "weekly") {
        let days_of_week = ["m", "t", "w", "th", "f", "s", "su"]
        mut repeats = {}
        for $day in $days_of_week {
          let repeat_day = (input $"Repeat on ($day)? (y/n): ")
          if ($repeat_day == "y") {
            $repeats = ($repeats | upsert $day true)
          } else {
            $repeats = ($repeats | upsert $day false)
          }
        }
        $payload = ($payload | upsert repeats $repeats)
      }
    }
    "habit" => {
      let direction_options = ["positive", "negative", "both"]
      let task_direction = ($direction_options | input list -f (echo-g "Select direction (required): "))
      $payload = match $task_direction {
        "positive" => ($payload | upsert up true | upsert down false),
        "negative" => ($payload | upsert up false | upsert down true),
        "both" => ($payload | upsert up true | upsert down true),
        _ => $payload
      }
    }
  }

  let response = http post --content-type application/json $url -H $headers ($payload | to json)
  
  if ($response.success == true) {
    print (echo-g $"Successfully added ($task_type) task: ($response.data.text)")
  } else {
    print (echo-r $"Failed to add ($task_type) task: ($response.message)")
  }
}

# Deletes a task (daily, todo, habit)
export def "h del" [
  task_type?: string # Type of task to delete (dailys, todos, habits)
] {
  let headers = h credentials
  let types = ["dailys", "todos", "habits"]
  
  let task_type = if ($task_type | is-empty) {
    $types
    | input list -f (echo-g "Select task type to delete: ")
  } else {
    $task_type
  }

  if ($task_type not-in $types) {
    return-error "Invalid task type for deletion. Must be 'dailys', 'todos', or 'habits'."
  }

  let tasks = h ls $task_type | reverse

  if ($tasks | is-empty) {
    print (echo-r $"No ($task_type) tasks found to delete.")
    return
  }

  let idx_task_to_delete = $tasks | input list -fid text (echo-g "Select task to delete: ")
  let task_to_delete = $tasks | get $idx_task_to_delete
  
  let base_url = "https://habitica.com"

  let url = {
    scheme: ( $base_url | split row "://" | get 0 ),
    host: ( $base_url | split row "//" | get 1 | split row "/" | get 0 ),
    path: $"/api/v3/tasks/($task_to_delete._id)"
  } | url join
  
  let response = http delete $url -H $headers

  if ($response.success == true) {
    print (echo-g $"Successfully deleted ($task_type) task: ($task_to_delete.text)")
  } else {
    print (echo-r $"Failed to delete ($task_type) task: ($response.message)")
  }
}

# Marks selected todo tasks as completed
export def "h complete-todos" [] {
    let headers = h credentials

    let todos = h ls todos | where completed == false | reverse

    if ($todos | is-empty) {
        print (echo-r "No incomplete todo tasks found to complete.")
        return
    }

    let selected_indices = $todos | input list -imd text (echo-g "Select todos to complete (use space to multi-select): ")
    
    let base_url = "https://habitica.com"

    for $index in $selected_indices {
        let todo = $todos | get $index
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
export def "h score-habits" [] {
    let headers = h credentials

    # Fetch the list of habits
    let habits = h ls habits | reverse

    # Check if the list is empty
    if ($habits | is-empty) {
        print (echo-r "No habits found.")
        return
    }

    # Prompt the user to select habits to score
    let selected_indices = $habits | input list -imd text (echo-g "Select habits to score: ")
    
    let base_url = "https://habitica.com"
    
    # Loop over the selected habits
    for index in $selected_indices {
        let habit = $habits | get $index

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

        # Prompt the user to choose a direction
        let direction = $directions | input list -f $"Choose a direction to score in habit '($habit.text)': "
        
        let url = {
            scheme: ( $base_url | split row "://" | get 0 ),
            host: ( $base_url | split row "//" | get 1 | split row "/" | get 0 ),
            path: $"/api/v3/tasks/($habit._id)/score/($direction)"
        } | url join
        
        # Score the habit
        let response = http post --content-type application/json -H $headers $url {}

        # Handle the response
        if ($response.success == true) {
            print $"Scored habit '($habit.text)' as ($direction)."
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
        $available_skills | input list -fd name (echo-g "Select a skill to cast: ")
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
        $available_skills | input list -fd name (echo-g "Select a skill to cast multiple times: ")
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
  task_type?: string # Type of task to complete checklist for (dailys, todos, habits)
] {
  let headers = h credentials
  let types = ["dailys", "todos", "habits"]
  
  let task_type = if ($task_type | is-empty) {
    $types
    | input list -f (echo-g "Select task type: ")
  } else {
    $task_type
  }

  if ($task_type not-in $types) {
    return-error "Invalid task type. Must be 'dailys', 'todos', or 'habits'."
  }

  let tasks_with_checklist = h ls $task_type | where ($it.checklist | is-not-empty) | reverse

  if ($tasks_with_checklist | is-empty) {
    print (echo-r $"No tasks with checklists found for type '($task_type)'.")
    return
  }

  let selected_task_index = $tasks_with_checklist | input list -fid text (echo-g "Select a task to complete checklist items for: ")
  let selected_task = $tasks_with_checklist | get $selected_task_index

  let checklist_items = $selected_task.checklist | where completed == false

  if ($checklist_items | is-empty) {
    print (echo-r "No incomplete checklist items found for this task.")
    return
  }

  let selected_checklist_indices = $checklist_items | input list -imd text (echo-g "Select checklist items to complete: ")

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
  task_type?: string # Type of task to add checklist item to (dailys, todos, habits)
] {
  let headers = h credentials
  let types = ["dailys", "todos", "habits"]
  
  let task_type = if ($task_type | is-empty) {
    $types
    | input list -f (echo-g "Select task type: ")
  } else {
    $task_type
  }

  if ($task_type not-in $types) {
    return-error "Invalid task type. Must be 'dailys', 'todos', or 'habits'."
  }

  let tasks = h ls $task_type | reverse

  if ($tasks | is-empty) {
    print (echo-r $"No tasks found for type '($task_type)'.")
    return
  }

  let selected_task_index = $tasks | input list -fid text (echo-g "Select a task to add a checklist item to: ")
  let selected_task = $tasks | get $selected_task_index

  mut checklist_items = []
  loop {
    let item_text = (input "Enter checklist item (leave empty to finish): ")
    if ($item_text | is-empty) {
      break
    }
    $checklist_items = ($checklist_items | append $item_text)
  }

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
    let hab_id = $env.MY_ENV_VARS.api_keys.habitica.id
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

#aliases
export alias todos = h ls todos -i 
export alias dailys = h ls dailys -ni

#budget
export def budget [] {
    h ls dailys | find budget | get checklist.0
}
