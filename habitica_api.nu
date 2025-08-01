# i've been using the habitica api to create a few nushell functions in [@habitica_api.nu](@file:nushell/habitica_api.nu)

# Check into the habitica api documentation in how to mark a todo task as completed. Then create a function called `habitica complete-todos` to implement the that funcionality in the following way:

# Lists user tasks
export def "habitica ls" [
  task_type?: string # Type of task to list (dailys, todos, habits, rewards, completedTodos)
] {
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

  let api_user = $env.MY_ENV_VARS.api_keys.habitica.id
  let api_key = $env.MY_ENV_VARS.api_keys.habitica.token

  let base_url = "https://habitica.com"

  let url = {
    scheme: ( $base_url | split row "://" | get 0 ),
    host: ( $base_url | split row "//" | get 1 | split row "/" | get 0 ),
    path: "/api/v3/tasks/user",
    params: {
      type: $task_type
    }
  } | url join
  
  let headers = {
    x-client : ($api_user + ' - nushell habitica api wrapper'),
    x-api-user: $api_user,
    x-api-key: $api_key
  }

  let response = http get $url -H $headers | get data
  
  match $task_type {
    "dailys" => {
      $response
      | select _id frequency text completed isDue 
      | sort-by frequency
    }
    "todos" => {
      $response
      | select _id text completed createdAt
      | sort-by createdAt
    }
    "habits" => {
      $response
      | select _id frequency text up down createdAt
      | sort-by createdAt
    }
    "rewards" => {
      $response
    }
    "completedTodos" => {
      $response
      | select _id text createdAt dateCompleted
      | sort-by createdAt
    }
  }
}

# Completes a daily task
export def "habitica complete-daily" [
  task_id: string # The ID of the daily task to complete
] {
  let api_user = $env.MY_ENV_VARS.api_keys.habitica.id
  let api_key = $env.MY_ENV_VARS.api_keys.habitica.token

  let base_url = "https://habitica.com"

  let url = {
    scheme: ( $base_url | split row "://" | get 0 ),
    host: ( $base_url | split row "//" | get 1 | split row "/" | get 0 ),
    path: $"/api/v3/tasks/($task_id)/score/up"
  } | url join
  
  let headers = {
    x-client : ($api_user + ' - nushell habitica api wrapper'),
    x-api-user: $api_user,
    x-api-key: $api_key
  }

  http post --content-type application/json $url -H $headers {}
}

# Marks all due and incomplete daily tasks as complete
export def "habitica mark-dailys-done" [] {
  let dailys_to_complete = habitica ls dailys | where completed == false and isDue == true

  if ($dailys_to_complete | is-empty) {
    print (echo-r "No due and incomplete daily tasks found to mark as done.")
    return
  }

  for $daily in $dailys_to_complete {
    print $"Completing daily: ($daily.text)"
    habitica complete-daily $daily._id
    sleep 1sec
  }
  
  print (echo-g "All due and incomplete daily tasks marked as done.")
}

# Adds a new task (daily or todo)
export def "habitica add" [
  task_type?: string # Type of task to add (daily, todo, habit)
] {
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

  let api_user = $env.MY_ENV_VARS.api_keys.habitica.id
  let api_key = $env.MY_ENV_VARS.api_keys.habitica.token

  let base_url = "https://habitica.com"

  let url = {
    scheme: ( $base_url | split row "://" | get 0 ),
    host: ( $base_url | split row "//" | get 1 | split row "/" | get 0 ),
    path: "/api/v3/tasks/user"
  } | url join
  
  let headers = {
    x-client : ($api_user + ' - nushell habitica api wrapper'),
    x-api-user: $api_user,
    x-api-key: $api_key
  }

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
export def "habitica del" [
  task_type?: string # Type of task to delete (dailys, todos, habits)
] {
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

  let tasks = habitica ls $task_type | reverse

  if ($tasks | is-empty) {
    print (echo-r $"No ($task_type) tasks found to delete.")
    return
  }

  let idx_task_to_delete = $tasks | input list -fid text (echo-g "Select task to delete: ")
  let task_to_delete = $tasks | get $idx_task_to_delete
  
  let api_user = $env.MY_ENV_VARS.api_keys.habitica.id
  let api_key = $env.MY_ENV_VARS.api_keys.habitica.token

  let base_url = "https://habitica.com"

  let url = {
    scheme: ( $base_url | split row "://" | get 0 ),
    host: ( $base_url | split row "//" | get 1 | split row "/" | get 0 ),
    path: $"/api/v3/tasks/($task_to_delete._id)"
  } | url join
  
  let headers = {
    x-client : ($api_user + ' - nushell habitica api wrapper'),
    x-api-user: $api_user,
    x-api-key: $api_key
  }

  let response = http delete $url -H $headers

  if ($response.success == true) {
    print (echo-g $"Successfully deleted ($task_type) task: ($task_to_delete.text)")
  } else {
    print (echo-r $"Failed to delete ($task_type) task: ($response.message)")
  }
}

# Marks selected todo tasks as completed
export def "habitica complete-todos" [] {
    let todos = habitica ls todos | where completed == false | reverse

    if ($todos | is-empty) {
        print (echo-r "No incomplete todo tasks found to complete.")
        return
    }

    let selected_indices = $todos | input list -imd text (echo-g "Select todos to complete (use space to multi-select): ")
    
    let api_user = $env.MY_ENV_VARS.api_keys.habitica.id
    let api_key = $env.MY_ENV_VARS.api_keys.habitica.token
    let base_url = "https://habitica.com"
    
    let headers = {
        x-client : ($api_user + ' - nushell habitica api wrapper'),
        x-api-user: $api_user,
        x-api-key: $api_key
    }

    for $index in $selected_indices {
        let todo = $todos | get $index
        print $"Completing todo: ($todo.text)"
      
        let url = {
            scheme: ( $base_url | split row "://" | get 0 ),
            host: ( $base_url | split row "//" | get 1 | split row "/" | get 0 ),
            path: $"/api/v3/tasks/($todo._id)/score/up"
        } | url join
      
        let response = http post --content-type application/json $url -H $headers {}

        if ($response.success == true) {
            print (echo-g $"Successfully completed todo: ($todo.text)")
        } else {
            print (echo-r $"Failed to complete todo: ($todo.text)")
        }

        sleep 1sec
    }
}

# Define the function to score habits
export def "habitica score-habits" [] {
    # Fetch the list of habits
    let habits = habitica ls habits | reverse

    # Check if the list is empty
    if ($habits | is-empty) {
        print (echo-r "No habits found.")
        return
    }

    # Prompt the user to select habits to score
    let selected_indices = $habits | input list -imd text (echo-g "Select habits to score: ")
    
    let api_user = $env.MY_ENV_VARS.api_keys.habitica.id
    let api_key = $env.MY_ENV_VARS.api_keys.habitica.token
    let base_url = "https://habitica.com"
    
    let headers = {
        x-client : ($api_user + ' - nushell habitica api wrapper'),
        x-api-user: $api_user,
        x-api-key: $api_key
    }
    
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
