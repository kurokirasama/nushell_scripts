# appimages.nu

# Commands to manage AppImages
export def appimage [] {
    help appimage
}

# Run Balena Etcher
export def "appimage balena-etcher" [] {
    let folder = $env.MY_ENV_VARS.appImages
    let etcher = glob ($folder | path join "*[eE]tcher*.AppImage") | sort | last
    if ($etcher | is-empty) {
        error make {msg: "Balena Etcher AppImage not found"}
    }
    print $"Running ($etcher)..."
    ^$etcher
}

# Run Tasker Permissions
export def "appimage tasker-permissions" [] {
    let folder = $env.MY_ENV_VARS.appImages
    let tasker = $folder | path join "com.joaomgcd.taskerpermissions-0.2.0.AppImage"
    if not ($tasker | path exists) {
        error make {msg: $"Tasker Permissions AppImage not found at ($tasker)"}
    }
    print $"Running ($tasker) --no-sandbox..."
    ^$tasker --no-sandbox
}