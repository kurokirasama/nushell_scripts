# Periodic system maintenance command designed for crontab (12h / @reboot).
# Runs background maintenance tasks:
# 1. autolister (12h-gated)
# 2. IP addresses update
# 3. Habitica background maintenance (login, auto-quest, mark-dailys-done, stats sync)
# 4. YouTube API OAuth token health checks (silent on valid tokens, alerts on missing/expired)
export def "periodic-maintenance" [] {
    let now = (date now)

    # 1. Autolister (12h gate)
    let autolister_path = ($env.HOME | path join ".autolister.json")
    if not ($autolister_path | path exists) {
        if (($env.MY_ENV_VARS?.linux_backup? | default "" | path join autolister.json) | path exists) {
            cp ($env.MY_ENV_VARS.linux_backup | path join autolister.json) $autolister_path
        }
    }

    let interval = 12hr
    let autolister_content = if ($autolister_path | path exists) {
        open $autolister_path | default {}
    } else {
        {}
    }

    let update_autolister = try {
        (($autolister_content | get updated? | default "1970-01-01" | into datetime) + $interval) < $now
    } catch {
        true
    }

    if $update_autolister {
        try {
            let nu_scripts = try { $env.MY_ENV_VARS.nu_scripts } catch { try { $env.FILE_PWD } catch { $env.PWD } }
            nu ($nu_scripts | path join autolister.nu)
            $autolister_content
            | upsert updated $now
            | save -f $autolister_path
        } catch { |err|
            print -e $"[autolister] Error: ($err.msg)"
        }
    }

    # 2. IP update (idempotent)
    try {
        let host = (sys host | get hostname)
        let ips_file = ($env.MY_ENV_VARS?.ips? | default ($env.HOME | path join ".ips.json"))
        let ips_content = if ($ips_file | path exists) { open $ips_file } else { {} }
        let nu_scripts = try { $env.MY_ENV_VARS.nu_scripts } catch { try { $env.FILE_PWD } catch { $env.PWD } }
        let hosts = ($env.MY_ENV_VARS?.hosts? | default [])
        let ips = (nu ($nu_scripts | path join get-ips.nu) ...$hosts)

        $ips_content
        | upsert $host ($ips | from json)
        | save -f $ips_file
    } catch { |err|
        print -e $"[IPs] Update warning: ($err.msg)"
    }

    # 3. Habitica maintenance
    try {
        mut hstats = (_h-user-stats)
        if not ($hstats.logged_in_today? | default false) {
            h login | ignore
            $hstats = (_h-user-stats)
        }

        if ($hstats.pending_quest? | default false) {
            h auto-quest | ignore
        }

        if (($hstats.dailys_to_complete? | default 0) > 0) {
            h mark-dailys-done | ignore
        }

        h stats | ignore
    } catch { |err|
        print -e $"[Habitica] Maintenance warning: ($err.msg)"
    }

    # 4. YouTube API status checks (silent on valid, action-required alert on missing/expired)
    try {
        let yt_status = (yt-api status)
        if ($yt_status.valid? != true) {
            print -e $"[YouTube OAuth Alert] Account: ($yt_status.account? | default 'default') - Action Required: ($yt_status.action_required? | default 'Run yt-oauth-login to authenticate.')"
        }
    } catch { |err|
        print -e $"[YouTube OAuth] Check warning: ($err.msg)"
    }

    try {
        let yt_ies_status = (yt-api status --ies)
        if ($yt_ies_status.valid? != true) {
            print -e $"[YouTube OAuth Alert] Account: ($yt_ies_status.account? | default 'iesubb') - Action Required: ($yt_ies_status.action_required? | default 'Run yt-oauth-login iesubb to authenticate.')"
        }
    } catch { |err|
        print -e $"[YouTube OAuth] Check warning (IES): ($err.msg)"
    }
}
