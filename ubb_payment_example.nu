#!/usr/bin/env nu

# Example usage script for UBB Payment Calendar commands
# This demonstrates how to use the custom commands in ubb_payment_calendar.nu

# Import the UBB payment calendar module
use ubb_payment_calendar.nu *

print "=== UBB Payment Calendar Examples ==="
print ""

# Example 1: Basic payment calendar
print "1. Basic Payment Calendar:"
print "Command: ubb payment-calendar"
print "Result:"
ubb payment-calendar | table
print ""

# Example 2: Payment schedule with year
print "2. Enhanced Payment Schedule:"
print "Command: ubb payment-schedule"
print "Result:"
ubb payment-schedule | table
print ""

# Example 3: Filter by month
print "3. Filter by specific month (January):"
print "Command: ubb payment-schedule --month enero"
print "Result:"
ubb payment-schedule --month enero | table
print ""

# Example 4: JSON format output
print "4. JSON format output:"
print "Command: ubb payment-schedule --format json | first 2"
print "Result:"
ubb payment-schedule --format json | from json | first 2 | table
print ""

# Example 5: Next payment date
print "5. Next upcoming payment:"
print "Command: ubb next-payment"
print "Result:"
ubb next-payment
print ""

# Example 6: Check if today is payment day
print "6. Is today a payment day?"
print "Command: ubb is-payment-day"
print "Result:"
ubb is-payment-day
print ""

# Example 7: Sort by month order
print "7. Sorted by chronological order:"
print "Command: ubb payment-schedule | sort-by timestamp"
print "Result:"
ubb payment-schedule | sort-by timestamp | table
print ""

# Example 8: Select specific columns
print "8. Show only month and date:"
print "Command: ubb payment-schedule | select mes fecha_pago"
print "Result:"
ubb payment-schedule | select mes fecha_pago | table
print ""

# Example 9: Count total payments
print "9. Total number of payment dates:"
print "Command: ubb payment-schedule | length"
print "Result:"
let count = (ubb payment-schedule | length)
print $"Total payments in calendar: ($count)"
print ""

# Example 10: Export to file
print "10. Export calendar to file:"
print "Command: ubb export-calendar ubb_payments_2025.json --format json"
print "Result:"
ubb export-calendar ubb_payments_2025.json --format json
print ""

# Example 11: Pipeline with other commands
print "11. Advanced pipeline example - payments in second half of year:"
print "Command: ubb payment-schedule | where timestamp > '2025-06-30' | select mes fecha_pago"
print "Result:"
ubb payment-schedule 
| where timestamp != null 
| where timestamp > ('2025-06-30' | into datetime)
| select mes fecha_pago
| table
print ""

# Example 12: Format dates nicely
print "12. Nicely formatted payment list:"
print "Command: Advanced formatting with date processing"
print "Result:"
ubb payment-schedule 
| each { |row|
    {
        "Mes": ($row.mes | str title-case),
        "Fecha de Pago": $row.fecha_pago,
        "Días restantes": (if $row.timestamp != null {
            let days = (($row.timestamp - (date now)) / 1day)
            if $days > 0 { $"($days | math round) días" } else { "Pasado" }
        } else { 
            "N/A" 
        })
    }
}
| table
print ""

print "=== End of Examples ==="
print ""
print "For more information, run: ubb help"
print ""
print "Files created:"
ls ubb_payments_* 2>/dev/null | get name | each { |file| print $"  - ($file)" }
