# Standalone lazy runner for heavy TUI front-ends (`t ui`, `obs tui`, `h tui`, `skills tui`).
# Invoked by `tui.nu` on demand so shell startup skips parsing `tui_apps.nu`.
use ./string_manipulation.nu *
use ./apis.nu *
use ./habitica.nu *
use ./tui.nu *
use ./tui_apps.nu *

def main [cmd_name: string] {
    let a = $env.TUI_LAUNCH_ARGS? | default "{}" | from json
    let mv = $env.TUI_MY_ENV_VARS_JSON? | default "{}" | from json
    try { hide-env TUI_MY_ENV_VARS_JSON TUI_LAUNCH_ARGS } catch { }
    with-env { MY_ENV_VARS: $mv } {
        match $cmd_name {
            "t ui" => {
                t ui $a.host --refresh ($a.refresh_ns | into duration) --stdin-tty=true --stdout-tty=true
            }
            "obs tui" => {
                if ($a.vault | is-empty) {
                    obs tui --stdin-tty=true --stdout-tty=true
                } else {
                    obs tui --vault $a.vault --stdin-tty=true --stdout-tty=true
                }
            }
            "h tui" => {
                h tui --stdin-tty=true --stdout-tty=true
            }
            "skills tui" => {
                skills tui --dir $a.dir --stdin-tty=true --stdout-tty=true
            }
            _ => {
                error make { msg: $"Unknown TUI runner command: ($cmd_name)" }
            }
        }
    }
}
