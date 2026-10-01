# install_fzf_integration.nu
# Deploys the migrated _fzf_integration.nu to Nushell's autoload directory (~/.config/nushell/autoload/)

def main [
    --autoload-dir: path # Custom target autoload directory (defaults to ~/.config/nushell/autoload)
    --force(-f)          # Overwrite destination without prompting
] {
    let script_dir = ($env.FILE_PWD? | default ".")
    let source_file = ($script_dir | path join "_fzf_integration.nu")

    if not ($source_file | path exists) {
        print $"(ansi red_bold)Error: Source file not found at ($source_file)(ansi reset)"
        return
    }

    # Determine target autoload directory
    let target_dir = if $autoload_dir != null {
        $autoload_dir | path expand
    } else {
        let nu_config = try { $nu.config-path } catch { ($env.HOME | path join ".config" "nushell" "config.nu") }
        ($nu_config | path dirname | path join "autoload")
    }

    print $"(ansi cyan_bold)Target autoload directory: ($target_dir)(ansi reset)"

    # Ensure autoload directory exists
    if not ($target_dir | path exists) {
        print $"(ansi yellow)Creating autoload directory: ($target_dir)(ansi reset)"
        mkdir $target_dir
    }

    let dest_file = ($target_dir | path join "_fzf_integration.nu")

    # Create timestamped backup if an existing file is present
    if ($dest_file | path exists) {
        let timestamp = (date now | format date "%Y%m%d_%H%M%S")
        let backup_file = ($target_dir | path join $"_fzf_integration.nu.bak_($timestamp)")
        print $"(ansi yellow)Backing up existing file to: ($backup_file)(ansi reset)"
        cp $dest_file $backup_file
    }

    # Copy new file
    print $"(ansi green)Copying ($source_file) -> ($dest_file)...(ansi reset)"
    cp -f $source_file $dest_file

    # Verification: test parse and clean execution
    let nu_bin = $nu.current-exe
    let test_res = (do { ^$nu_bin -c $"source '($dest_file)'" } | complete)

    if $test_res.exit_code != 0 {
        print $"(ansi red_bold)Verification failed: ($test_res.stderr)(ansi reset)"
        return
    }

    if ($test_res.stderr | str contains "nu::shell::deprecated") {
        print $"(ansi red_bold)Warning: Deprecation warning detected in installed file: ($test_res.stderr)(ansi reset)"
        return
    }

    print $"(ansi green_bold)✓ Successfully installed and verified _fzf_integration.nu!(ansi reset)"
    print $"Autoload file ready at: (ansi default_bold)($dest_file)(ansi reset)"
}
