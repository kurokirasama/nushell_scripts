# UBB Payment Calendar Extractor
# Custom Nushell command to extract payment date information from Universidad del Bío-Bío

# Main command to get UBB payment calendar
export def "ubb payment-calendar" [] {
    let url = "http://www.ubiobio.cl/w/Calendario_de_Pagos/"
    
    print $"Fetching payment calendar from ($url)..."
    
    try {
        let html_content = http get $url
        
        # Extract all table cells at once and process them in pairs
        let table_cells = $html_content
            | query web --query 'table tbody tr td'
            | each { |cell| $cell | str trim }
            | where ($it | str length) > 0  # Remove empty cells
        
        # Group cells into pairs (month, payment date)
        $table_cells
        | chunks 2
        | each { |pair|
            if ($pair | length) == 2 {
                {
                    mes: ($pair | get 0),
                    fecha_pago: ($pair | get 1)
                }
            }
        }
        | compact  # Remove any empty records
    } catch {|e|
        error make {
            msg: $"Failed to fetch or parse payment calendar: ($e.msg)"
            label: {
                text: "Check your internet connection and website availability"
                span: (metadata $url).span
            }
        }
    }
}

# Alternative command using CSS table selector
export def "ubb payment-dates" [] {
    let url = "http://www.ubiobio.cl/w/Calendario_de_Pagos/"
    
    print $"Extracting payment dates from UBB calendar..."
    
    try {
        let html_content = http get $url
        
        # Try to extract using table selector with correct headers
        let table_data = try {
            $html_content | query web --as-table ["MES" "FECHA DE PAGO"]
        } catch {
            # Fallback: extract table cells and pair them manually
            let cells = $html_content
                | query web --query 'table tbody tr td'
                | each { |cell| $cell | str trim }
                | where ($it | str length) > 0
            
            $cells
            | chunks 2
            | each { |pair|
                if ($pair | length) == 2 {
                    {
                        "MES": ($pair | get 0),
                        "FECHA DE PAGO": ($pair | get 1)
                    }
                }
            }
            | compact
        }
        
        $table_data
        | rename mes fecha_pago
        | each { |row|
            {
                mes: ($row.mes | str trim),
                fecha_pago: ($row.fecha_pago | str trim),
                año: "2025"
            }
        }
        | where mes != "MES"  # Filter out any header rows that might slip through
    } catch {|e|
        error make {
            msg: $"Failed to extract payment dates: ($e.msg)"
            label: {
                text: "Check internet connection and website structure"
                span: (metadata $url).span
            }
        }
    }
}

# Enhanced command with date parsing and formatting
export def "ubb payment-schedule" [
    --format(-f): string = "table"  # Output format: table, json, csv
    --month(-m): string             # Filter by specific month
] {
    let url = "http://www.ubiobio.cl/w/Calendario_de_Pagos/"
    
    print $"Retrieving UBB payment schedule..."
    
    let raw_data = try {
        http get $url --raw
    } catch {
        error make {
            msg: "Unable to fetch payment calendar"
            label: {
                text: "Check network connectivity"
                span: (metadata $url).span
            }
        }
    }
    
    # Extract table data using regex pattern
    let payment_data = $raw_data
        | lines
        | where ($it | str contains "<td")
        | each { |line|
            # Extract text content from table cells
            $line 
            | str replace --all --regex '<[^>]*>' ''  # Remove HTML tags
            | str replace --all '&iacute;' 'í'        # Replace HTML entities
            | str replace --all '&eacute;' 'é'
            | str replace --all '&aacute;' 'á'
            | str replace --all '&oacute;' 'ó'
            | str replace --all '&uacute;' 'ú'
            | str replace --all '&ntilde;' 'ñ'
            | str trim
        }
        | where ($it | str length) > 0
        | chunks 2
        | each { |pair|
            if ($pair | length) == 2 {
                let month = ($pair | get 0)
                let date = ($pair | get 1)
                {
                    mes: $month,
                    fecha_pago: $date,
                    año: "2025",
                    timestamp: (try { 
                        $"($date) 2025" | into datetime 
                    } catch { 
                        null 
                    })
                }
            }
        }
        | compact
    
    # Apply month filter if specified
    let filtered_data = if $month != null {
        $payment_data | where mes =~ $month
    } else {
        $payment_data
    }
    
    # Format output based on requested format
    match $format {
        "json" => ($filtered_data | to json),
        "csv" => ($filtered_data | to csv),
        "table" | _ => $filtered_data
    }
}

# Quick command to get next payment date
export def "ubb next-payment" [] {
    let today = (date now)
    
    ubb payment-schedule
    | where timestamp != null
    | where timestamp > $today
    | sort-by timestamp
    | first
    | if ($in | is-empty) {
        print "No upcoming payment dates found"
        null
    } else {
        print $"Next payment: ($in.fecha_pago) for ($in.mes)"
        $in
    }
}

# Command to check if today is a payment day
export def "ubb is-payment-day" [] {
    let today = (date now | format date "%A %d de %B")
    let today_simple = (date now | format date "%d de %B")
    
    let payment_dates = ubb payment-schedule
        | get fecha_pago
        | each { |date| $date | str downcase }
    
    let today_variants = [
        ($today | str downcase),
        ($today_simple | str downcase),
        (date now | format date "%d" | into int | $"($in) de " + (date now | format date "%B" | str downcase))
    ]
    
    let is_payment = $payment_dates 
        | any { |payment_date|
            $today_variants | any { |variant| $payment_date | str contains $variant }
        }
    
    if $is_payment {
        print "🎉 Today is a UBB payment day!"
        true
    } else {
        print "Today is not a payment day."
        false
    }
}

# Debug command to test HTML parsing approach
export def "ubb debug-parse" [] {
    let url = "http://www.ubiobio.cl/w/Calendario_de_Pagos/"
    
    print "Testing HTML parsing approach..."
    
    try {
        let html_content = http get $url
        
        print "Step 1: Extracting table cells..."
        let all_cells = $html_content | query web --query 'table tbody tr td'
        print $"Found ($all_cells | length) table cells"
        
        print "Step 2: Processing cell contents..."
        let cleaned_cells = $all_cells
            | each { |cell| $cell | str trim }
            | where ($it | str length) > 0
        
        print $"After cleaning: ($cleaned_cells | length) non-empty cells"
        print "First 6 cells:"
        $cleaned_cells | first 6 | enumerate
        
        print "Step 3: Testing table selector..."
        let table_result = try {
            $html_content | query web --as-table ["MES" "FECHA DE PAGO"]
        } catch {|e|
            print $"Table selector failed: ($e.msg)"
            null
        }
        
        if $table_result != null {
            print $"Table selector found ($table_result | length) rows"
            $table_result | first 3
        }
        
    } catch {|e|
        print $"Debug failed: ($e.msg)"
    }
}

# Command to export calendar to different formats
export def "ubb export-calendar" [
    output_file: string             # Output file path
    --format(-f): string = "json"   # Export format: json, csv, yaml
] {
    let data = ubb payment-schedule
    
    let content = match $format {
        "csv" => ($data | to csv),
        "yaml" => ($data | to yaml),
        "json" | _ => ($data | to json --indent 2)
    }
    
    $content | save $output_file
    print $"Calendar exported to ($output_file) in ($format) format"
}

# Helper function to display usage examples
export def "ubb help" [] {
    print "UBB Payment Calendar Commands:"
    print ""
    print "Basic Commands:"
    print "  ubb payment-calendar     - Get basic payment table"
    print "  ubb payment-dates        - Get payment dates with year"
    print "  ubb payment-schedule     - Get enhanced schedule with formatting options"
    print ""
    print "Advanced Commands:"
    print "  ubb next-payment         - Show next upcoming payment"
    print "  ubb is-payment-day       - Check if today is a payment day"
    print ""
    print "Export Options:"
    print "  ubb export-calendar payments.json --format json"
    print "  ubb export-calendar payments.csv --format csv"
    print ""
    print "Filtering:"
    print "  ubb payment-schedule --month enero"
    print "  ubb payment-schedule --format json"
    print ""
    print "Debug Commands:"
    print "  ubb debug-parse          - Test HTML parsing approach"
    print ""
    print "Examples:"
    print "  ubb payment-schedule | where mes == 'Enero'"
    print "  ubb payment-schedule | select mes fecha_pago"
    print "  ubb payment-schedule | sort-by timestamp"
}
