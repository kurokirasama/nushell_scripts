# install_carapace_init.nu
# Deploys the migrated Carapace initialization script to ~/.cache/carapace/init.nu with automated verification

def main [
    --target-dir: path  # Custom target cache directory (defaults to ~/.cache/carapace)
    --force(-f)         # Overwrite destination without prompting
] {
    let script_dir = ($env.FILE_PWD? | default ".")
    let canonical_file = ($script_dir | path join "_carapace_init.nu")

    if not ($canonical_file | path exists) {
        print $"(ansi red_bold)Error: Canonical file not found at ($canonical_file)(ansi reset)"
        return
    }

    let dest_dir = if $target_dir != null {
        $target_dir | path expand
    } else {
        ($env.HOME | path join ".cache" "carapace")
    }

    print $"(ansi cyan_bold)Target Carapace directory: ($dest_dir)(ansi reset)"

    if not ($dest_dir | path exists) {
        print $"(ansi yellow)Creating directory: ($dest_dir)(ansi reset)"
        mkdir $dest_dir
    }

    let dest_file = ($dest_dir | path join "init.nu")

    # Create timestamped backup if existing file is present
    let backup_file = if ($dest_file | path exists) {
        let timestamp = (date now | format date "%Y%m%d_%H%M%S")
        let b = ($dest_dir | path join $"init.nu.bak_($timestamp)")
        print $"(ansi yellow)Backing up existing file to: ($b)(ansi reset)"
        cp $dest_file $b
        $b
    } else {
        null
    }

    # Deploy canonical modern _carapace_init.nu
    print $"(ansi green)Deploying modern Carapace init script -> ($dest_file)...(ansi reset)"
    cp -f $canonical_file $dest_file

    # Verification: test parse, execution, and deprecation check
    let nu_bin = $nu.current-exe
    let test_cmd = [
        $"source '($dest_file)'"
        "let comp = $env.config.completions.external.completer"
        "if ($comp == null) { error make {msg: 'completer not set'} }"
        "let res = (do $comp {command: ['git', 'status']})"
        "if ($res == null) { error make {msg: 'completer returned null'} }"
    ] | str join "\n"

    let test_res = (do { ^$nu_bin -c $test_cmd } | complete)

    if $test_res.exit_code != 0 {
        if $backup_file != null and ($backup_file | path exists) {
            print $"(ansi yellow)Restoring backup from ($backup_file)...(ansi reset)"
            cp -f $backup_file $dest_file
        }
        error make {msg: $"Verification failed: ($test_res.stderr)"}
    }

    if ($test_res.stderr | str contains "nu::shell::deprecated") {
        if $backup_file != null and ($backup_file | path exists) {
            print $"(ansi yellow)Restoring backup from ($backup_file)...(ansi reset)"
            cp -f $backup_file $dest_file
        }
        error make {msg: $"Deprecation warning detected in installed init.nu: ($test_res.stderr)"}
    }

    print $"(ansi green_bold)✓ Successfully installed and verified Carapace init.nu!(ansi reset)"
    print $"Carapace init file ready at: (ansi default_bold)($dest_file)(ansi reset)"
}
