#!/usr/bin/env nu
# Standalone CLI runner for Manga & Torrent monitoring and synchronization.
# Can be run periodically via cron / systemd timer, or continuously with --watch.

use manga.nu *

def run-cycle [
    dir: path
    folderwatched: path
    state_file: path
    torrent_state_file: path
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
        print $"[($ts)] Running manga & torrent sync on ($dir)..."
    }

    # Run Manga Sync
    let manga_res = (if $dry_run {
        manga sync --dir $dir --folderwatched $folderwatched --state-file $state_file --dry-run
    } else {
        manga sync --dir $dir --folderwatched $folderwatched --state-file $state_file
    })

    # Run Torrent Sync
    let torrent_res = (if $dry_run {
        torrent sync --dir $dir --state-file $torrent_state_file --dry-run
    } else {
        torrent sync --dir $dir --state-file $torrent_state_file
    })

    # Verbose or update reporting
    let has_manga_updates = (($manga_res.new_urls_found? | default 0) > 0)
    let has_torrent_updates = (($torrent_res | length) > 0)

    if $verbose or $has_manga_updates or $has_torrent_updates {
        print $"[($ts)] Manga Status: ($manga_res.status?) | New URLs: ($manga_res.new_urls_found? | default 0) | Crawljob: ($manga_res.crawljob_created? | default 'none')"
        if $has_torrent_updates {
            print $"[($ts)] New Torrents: ($torrent_res | length)"
            for t in $torrent_res {
                print $"  - ($t.name)"
            }
        }
    }
}

# Main CLI entrypoint
def main [
    --dir: path = "/home/kira/Dropbox/Aplicaciones/Gmail"
    --folderwatched: path = "/home/kira/Dropbox/Aplicaciones/Gmail/folderwatched"
    --state-file: path = "/home/kira/Dropbox/Aplicaciones/Gmail/.manga_monitor_state.json"
    --torrent-state-file: path = "~/.torrent_monitor_state.json"
    --watch(-w)                 # Run continuous background monitoring loop
    --interval(-i): duration = 30sec # Polling interval in watch mode
    --dry-run(-d)               # Simulate without writing files or notifications
    --verbose(-v)               # Enable detailed verbose logging
] {
    if $watch {
        print $"Starting Manga & Torrent Monitor Daemon..."
        print $"Monitoring: ($dir)"
        print $"Interval:   ($interval)"
        print $"Dry run:    ($dry_run)"
        print "Press Ctrl+C to stop.\n"

        loop {
            try {
                run-cycle $dir $folderwatched $state_file $torrent_state_file $dry_run $verbose
            } catch { |err|
                print $"(ansi red)[ERROR](ansi reset) ($err.msg)"
            }
            sleep $interval
        }
    } else {
        run-cycle $dir $folderwatched $state_file $torrent_state_file $dry_run $verbose
    }
}

