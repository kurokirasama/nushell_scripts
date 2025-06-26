# UBB Payment Calendar Module

A comprehensive Nushell module for extracting and managing payment date information from Universidad del Bío-Bío's official payment calendar.

## Overview

This module provides custom Nushell commands to fetch, parse, and manipulate payment schedule data from http://www.ubiobio.cl/w/Calendario_de_Pagos/. It includes multiple extraction methods, data formatting options, and utility functions for payment date management.

## Files

- `ubb_payment_calendar.nu` - Main module with all custom commands
- `ubb_payment_example.nu` - Usage examples and demonstrations
- `README_ubb_payment.md` - This documentation file

## Installation

1. Place the `ubb_payment_calendar.nu` file in your Nushell modules directory
2. Import the module in your config or script:
   ```nu
   use ubb_payment_calendar.nu *
   ```

## Commands

### Basic Commands

#### `ubb payment-calendar`
Extracts basic payment information using CSS selectors.
```nu
ubb payment-calendar
```

#### `ubb payment-dates`
Alternative extraction method using HTML table selectors with year information.
```nu
ubb payment-dates
```

#### `ubb payment-schedule`
Enhanced command with formatting options and filtering capabilities.
```nu
# Basic usage
ubb payment-schedule

# With formatting
ubb payment-schedule --format json
ubb payment-schedule --format csv

# Filter by month
ubb payment-schedule --month enero
```

### Utility Commands

#### `ubb next-payment`
Shows the next upcoming payment date.
```nu
ubb next-payment
```

#### `ubb is-payment-day`
Checks if today is a payment day.
```nu
ubb is-payment-day
```

#### `ubb export-calendar`
Exports the payment calendar to various formats.
```nu
# Export to JSON
ubb export-calendar payments.json --format json

# Export to CSV
ubb export-calendar payments.csv --format csv

# Export to YAML
ubb export-calendar payments.yaml --format yaml
```

#### `ubb help`
Displays usage information and examples.
```nu
ubb help
```

#### `ubb debug-parse`
Debug command for troubleshooting HTML parsing issues.
```nu
ubb debug-parse
```

## Data Structure

The commands return tables with the following structure:

| Column | Type | Description |
|--------|------|-------------|
| `mes` | string | Month name in Spanish |
| `fecha_pago` | string | Payment date description |
| `año` | string | Year (2025) |
| `timestamp` | datetime | Parsed datetime object (when possible) |

## Usage Examples

### Basic Data Extraction
```nu
# Get all payment dates
ubb payment-schedule

# Get only month and date columns
ubb payment-schedule | select mes fecha_pago

# Sort by chronological order
ubb payment-schedule | sort-by timestamp
```

### Filtering and Searching
```nu
# Find January payments
ubb payment-schedule | where mes == "Enero"

# Find payments in second half of year
ubb payment-schedule 
| where timestamp > ('2025-06-30' | into datetime)

# Search for specific date patterns
ubb payment-schedule | where fecha_pago =~ "Viernes"
```

### Data Export and Integration
```nu
# Export to JSON for other applications
ubb export-calendar ubb_calendar.json --format json

# Convert to CSV for spreadsheet use
ubb payment-schedule | to csv | save payments.csv

# Create custom formatted output
ubb payment-schedule 
| each { |row|
    $"($row.mes): ($row.fecha_pago)"
}
```

### Advanced Pipeline Operations
```nu
# Count payments by day of week
ubb payment-schedule 
| where fecha_pago =~ "(Lunes|Martes|Miércoles|Jueves|Viernes)"
| group-by { |row| 
    $row.fecha_pago | parse "{day} {rest}" | get day.0 
}
| each { |group| 
    { day: $group.key, count: ($group.items | length) }
}

# Calculate days until each payment
ubb payment-schedule 
| where timestamp != null
| each { |row|
    {
        mes: $row.mes,
        fecha_pago: $row.fecha_pago,
        dias_restantes: (($row.timestamp - (date now)) / 1day | math round)
    }
}
| where dias_restantes > 0
```

## Technical Implementation

### Web Scraping Strategy
- Primary method: Extract table cells using `query web --query 'table tbody tr td'` 
- Alternative method: Direct table parsing with `query web --as-table ["MES" "FECHA DE PAGO"]`
- Fallback method: Regex-based HTML parsing for robustness
- HTML entity decoding for proper Spanish character handling
- Cell pairing approach: Extract all cells and group into pairs (month, date)

### Error Handling
- Network connectivity checks
- Graceful fallbacks between extraction methods
- Structured error messages with context

### Data Processing Features
- Automatic HTML tag removal and text cleaning
- Spanish character entity conversion (í, é, á, ó, ú, ñ)
- Date parsing with timezone awareness
- Table chunking for paired data extraction

## Troubleshooting

### Common Issues

**Command not found**
```nu
# Make sure module is imported
use ubb_payment_calendar.nu *
```

**Network errors**
```nu
# Check internet connection
http get http://www.ubiobio.cl/w/Calendario_de_Pagos/ | length
```

**Empty results**
```nu
# Debug the parsing process
ubb debug-parse

# Try alternative extraction method
ubb payment-dates

# Test raw HTML extraction
http get http://www.ubiobio.cl/w/Calendario_de_Pagos/ | query web --query 'table tbody tr td' | length
```

**Date parsing issues**
```nu
# Check raw data
ubb payment-schedule | where timestamp == null

# Verify cell extraction
ubb debug-parse
```

**HTML parsing errors**
```nu
# The most common issue is that query web returns text content, not HTML
# Make sure to extract all cells first, then process them:
http get $url | query web --query 'table tbody tr td' | chunks 2
```

### Performance Tips

- Use `--format json` for programmatic processing
- Filter early in pipelines for better performance
- Cache results for repeated operations:
  ```nu
  let payments = (ubb payment-schedule)
  $payments | where mes == "Enero"
  ```

## Dependencies

- Nushell 0.80+ (for `query web` command)
- Internet connection for data fetching
- No external dependencies required

## License

This module is provided as-is for educational and personal use. Please respect the Universidad del Bío-Bío website's terms of service when using automated data extraction.

## Testing

A comprehensive test suite is available:

```nu
# Run all tests
use test_ubb_calendar.nu

# Or import and run specific tests
use ubb_payment_calendar.nu *
ubb debug-parse
```

The test script validates:
- HTML parsing approach
- Data extraction accuracy  
- Export functionality
- Date processing
- Pipeline operations

## Contributing

To extend this module:

1. Add new commands using `export def` syntax
2. Follow existing error handling patterns
3. Test with `ubb debug-parse` for debugging
4. Include comprehensive examples
5. Update this documentation

## Changelog

- v1.1.0 - Fixed HTML parsing approach, added debug commands
  - Corrected `query web` usage pattern
  - Added `ubb debug-parse` for troubleshooting
  - Improved cell extraction method
  - Enhanced error handling and fallbacks
- v1.0.0 - Initial release with basic extraction and formatting
  - Features: Multiple extraction methods, export capabilities, date parsing