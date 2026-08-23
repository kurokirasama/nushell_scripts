#!/usr/bin/env nu
# Standalone CLI runner for Manga monitoring and synchronization.
# Can be run periodically via cron / systemd timer, or continuously with --watch.

use manga.nu *

def run-cycle [
    dir: path
    folderwatched: path
    state_file: path
    dry_run: bool
    verbose: bool
] {
    let ts = (date now | format date "%Y-%m-%d %H:%M:%S")
    if ($dir | path exists) == false {
        if $verbose {
            print $"[($ts)] Directory ($dir) does not exist. Skipping cycle."
        }
        return
    }

    if $verbose {
        print $"[($ts)] Running manga sync on ($dir)..."
    }

    # Run Manga Sync
    let manga_res = (if $dry_run {
        manga sync --dir $dir --folderwatched $folderwatched --state-file $state_file --dry-run
    } else {
        manga sync --dir $dir --folderwatched $folderwatched --state-file $state_file
    })

    # Verbose or update reporting
    let has_manga_updates = (($manga_res.new_urls_found? | default 0) > 0)

    if $verbose or $has_manga_updates {
        print $"[($ts)] Manga Status: ($manga_res.status?) | New URLs: ($manga_res.new_urls_found? | default 0) | Crawljob: ($manga_res.crawljob_created? | default 'none')"
    }
}

# Main CLI entrypoint
def main [
    --dir: path = "/home/kira/Dropbox/Aplicaciones/Gmail"
    --folderwatched: path = "/home/kira/Dropbox/Aplicaciones/Gmail/folderwatched"
    --state-file: path = "/home/kira/Dropbox/Aplicaciones/Gmail/.manga_monitor_state.json"
    --watch(-w)                 # Run continuous background monitoring loop
    --interval(-i): duration = 30sec # Polling interval in watch mode
    --dry-run(-d)               # Simulate without writing files or notifications
    --verbose(-v)               # Enable detailed verbose logging
] {
    if $watch {
        print $"Starting Manga Monitor Daemon..."
        print $"Monitoring: ($dir)"
        print $"Interval:   ($interval)"
        print $"Dry run:    ($dry_run)"
        print "Press Ctrl+C to stop.\n"

        loop {
            try {
                run-cycle $dir $folderwatched $state_file $dry_run $verbose
            } catch { |err|
                print $"(ansi red)[ERROR](ansi reset) ($err.msg)"
            }
            sleep $interval
        }
    } else {
        run-cycle $dir $folderwatched $state_file $dry_run $verbose
    }
}
