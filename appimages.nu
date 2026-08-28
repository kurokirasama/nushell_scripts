# appimages.nu

# Check if FUSE 2 (libfuse.so.2) is available on the system for a given binary architecture
export def has-fuse2 [appimage_path?: string] {
    let is_32bit = if ($appimage_path | is-not-empty) and ($appimage_path | path exists) {
        let info = (try { ^file ($appimage_path | path expand) | complete | get stdout } catch { "" })
        ($info | str contains "32-bit")
    } else {
        false
    }

    if $is_32bit {
        # Check for 32-bit libfuse.so.2
        let paths_32 = [
            "/lib/i386-linux-gnu/libfuse.so.2"
            "/usr/lib/i386-linux-gnu/libfuse.so.2"
            "/lib32/libfuse.so.2"
            "/usr/lib32/libfuse.so.2"
        ]
        return ($paths_32 | any { |p| $p | path exists })
    }

    # Check for 64-bit libfuse.so.2
    let ldconfig_has = (try {
        let out = (^ldconfig -p | complete)
        if $out.exit_code == 0 {
            ($out.stdout | lines | where $it =~ "libfuse.so.2" | is-not-empty)
        } else {
            false
        }
    } catch {
        false
    })

    if $ldconfig_has {
        return true
    }

    let common_paths = [
        "/lib/x86_64-linux-gnu/libfuse.so.2"
        "/usr/lib/x86_64-linux-gnu/libfuse.so.2"
        "/lib64/libfuse.so.2"
        "/usr/lib64/libfuse.so.2"
        "/usr/lib/libfuse.so.2"
        "/lib/libfuse.so.2"
    ]
    $common_paths | any { |p| $p | path exists }
}

# Internal runner helper with automatic FUSE 2 fallback and flag construction
def run-appimage [
    appimage_path: string
    --extract (-e)
    --electron
    --no-sandbox
    --disable-gpu
    ...args: string
] {
    let resolved = ($appimage_path | path expand)
    if not ($resolved | path exists) {
        error make {msg: $"AppImage not found at ($resolved)"}
    }

    let needs_extract = ($extract or not (has-fuse2 $resolved))

    mut run_args = []
    if $needs_extract {
        $run_args = ($run_args | append "--appimage-extract-and-run")
    }
    if $electron {
        $run_args = ($run_args | append ["--no-sandbox", "--ozone-platform=x11"])
    } else if $no_sandbox {
        $run_args = ($run_args | append "--no-sandbox")
    }
    if $disable_gpu {
        $run_args = ($run_args | append "--disable-gpu")
    }
    if ($args | is-not-empty) {
        $run_args = ($run_args | append $args)
    }

    let display_args = ($run_args | str join " ")
    if ($display_args | is-empty) {
        print $"Running ($resolved)..."
    } else {
        print $"Running ($resolved) ($display_args)..."
    }

    ^$resolved ...$run_args
}

# Commands to manage AppImages
export def appimage [] {
    help appimage
}

# Run arbitrary AppImage with FUSE fallback
export def "appimage run" [
    appimage_path: string # Path to AppImage file
    --extract (-e) # Force extraction mode (--appimage-extract-and-run)
    --electron # Add Electron compatibility flags (--no-sandbox --ozone-platform=x11)
    --no-sandbox # Disable Chromium sandbox
    --disable-gpu # Disable GPU hardware acceleration
    ...args: string # Additional arguments forwarded to the AppImage
] {
    run-appimage $appimage_path --extract=($extract) --electron=($electron) --no-sandbox=($no_sandbox) --disable-gpu=($disable_gpu) ...$args
}

# Run Balena Etcher
export def "appimage balena-etcher" [
    --extract (-e) # Force extraction mode
    --disable-gpu # Disable GPU acceleration if running on legacy software rendering
    ...args: string # Additional arguments forwarded to Balena Etcher
] {
    let folder = $env.MY_ENV_VARS.appImages
    let etcher = glob ($folder | path join "*[eE]tcher*.AppImage")
        | where not ($it =~ "\\.bak") and not ($it =~ "32bit")
        | sort
        | last
    if ($etcher | is-empty) {
        error make {msg: "Balena Etcher AppImage not found"}
    }

    # Detect if legacy 32-bit AppImage requiring cached extraction and bundled library path
    let is_32bit = (try { ^file ($etcher | path expand) | complete | get stdout | str contains "32-bit" } catch { false })
    if $is_32bit {
        let cache_dir = $"($env.HOME)/.cache/appimages/balenaEtcher"
        let bin = $cache_dir | path join "balena-etcher-electron.bin"
        
        let needs_unpack = (not ($bin | path exists)) or (
            try { ((ls -l $etcher | get 0.modified) > (ls -l $bin | get 0.modified)) } catch { true }
        )

        if $needs_unpack {
            print (echo-y "Extracting 32-bit Balena Etcher AppImage to local cache...")
            mkdir $cache_dir
            let tmp_extract = "/tmp/etcher_extract_init"
            rm -rf $tmp_extract
            mkdir $tmp_extract
            do {
                cd $tmp_extract
                ^$etcher --appimage-extract
                if ($tmp_extract | path join "squashfs-root" | path exists) {
                    glob ($tmp_extract | path join "squashfs-root/*") | each { |f| cp -r $f $cache_dir }
                }
            } | complete
            rm -rf $tmp_extract
        }

        print "Running Balena Etcher (32-bit cached) --no-sandbox --disable-gpu..."
        with-env {
            LD_LIBRARY_PATH: $"($cache_dir)/usr/lib:($cache_dir)"
        } {
            ^$bin --no-sandbox --disable-gpu ...$args
        }
        return
    }

    run-appimage $etcher --electron --extract=($extract) --disable-gpu=($disable_gpu) ...$args
}

# Run Tasker Permissions
export def "appimage tasker-permissions" [
    --extract (-e) # Force extraction mode (--appimage-extract-and-run)
    ...args: string # Additional arguments forwarded to Tasker Permissions
] {
    let folder = $env.MY_ENV_VARS.appImages
    let tasker = $folder | path join "com.joaomgcd.taskerpermissions-0.2.0.AppImage"
    if not ($tasker | path exists) {
        error make {msg: $"Tasker Permissions AppImage not found at ($tasker)"}
    }
    run-appimage $tasker --no-sandbox --extract=($extract) ...$args
}