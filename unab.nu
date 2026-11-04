# unab.nu - UNAB academic automation commands

# Convert Canvas gradebook export to UNAB Intranet (Banner 9) importable Excel.
#
# Supports:
# - Standalone mode: Generates an Excel with required Banner headers (Term Code, CRN, Student ID, Full Name, Final Grade) and partial evaluations.
# - Template mode (--template): Automatically populates an official UNAB template exported from Intranet Docente.
#
# Examples:
#   canvas-to-unab "Notas_202620.12225.xlsx"
#   canvas-to-unab "Notas_202620.12225.xlsx" --template "202620_Template.xlsx"
#   canvas-to-unab "Notas_202620.12225.xlsx" --grade-col "Solemne 1"
@example "Generate standalone Banner import Excel" { canvas-to-unab "Notas_202620.12225.xlsx" }
@example "Populate official UNAB Template" { canvas-to-unab "Notas_202620.12225.xlsx" --template "Template.xlsx" }
export def canvas-to-unab [
    canvas_file: path              # Path to Canvas gradebook export (.xlsx)
    --template (-t): any = ""      # Path, list of paths, or glob to official UNAB template(s) (.xlsx)
    --grade-col (-g): string = ""  # Name of Canvas column to map (default: auto-detected from template or 'Nota Final')
    --decimal-sep (-d): string = "," # Decimal separator for grades (',' for Chilean Banner, '.' for dot)
    --output (-o): path = ""       # Custom output path (.xlsx, single template only)
]: nothing -> any {
    let script = "/home/kira/Yandex.Disk/llms_configs/scripts/unab_converter.py"
    if not ($script | path exists) {
        error make {
            msg: $"Converter script not found at ($script)"
        }
    }

    let resolved_canvas = ($canvas_file | path expand)
    if not ($resolved_canvas | path exists) {
        error make {
            msg: $"Canvas file not found: ($canvas_file)"
        }
    }

    mut args = [$script, $resolved_canvas, "--decimal-sep", $decimal_sep]

    if ($grade_col | is-not-empty) {
        $args = ($args | append ["--grade-col", $grade_col])
    }

    if ($template | is-not-empty) {
        $args = ($args | append ["--template"])
        if (($template | describe) =~ "^list") {
            for t_item in $template {
                $args = ($args | append ($t_item | path expand))
            }
        } else {
            $args = ($args | append ($template | path expand))
        }
    }

    if ($output | is-not-empty) {
        let resolved_out = ($output | path expand)
        $args = ($args | append ["--output", $resolved_out])
    }

    let raw_res = (uv run --with openpyxl python3 ...$args)
    $raw_res | from json
}
