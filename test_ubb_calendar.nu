#!/usr/bin/env nu

# Test script for UBB Payment Calendar extraction
# This script tests the different extraction methods to ensure they work correctly

print "🧪 Testing UBB Payment Calendar Extraction"
print "=" * 50

# Import the module
use ubb_payment_calendar.nu *

print ""
print "1. Testing debug parsing approach..."
print "-" * 30

try {
    ubb debug-parse
    print "✅ Debug parse completed successfully"
} catch {|e|
    print $"❌ Debug parse failed: ($e.msg)"
}

print ""
print "2. Testing basic payment calendar..."
print "-" * 30

try {
    let basic_result = ubb payment-calendar
    let count = ($basic_result | length)
    print $"✅ Basic calendar extracted ($count) payment dates"
    
    if $count > 0 {
        print "Sample data:"
        $basic_result | first 3 | table
    }
} catch {|e|
    print $"❌ Basic calendar failed: ($e.msg)"
}

print ""
print "3. Testing payment dates with year..."
print "-" * 30

try {
    let dates_result = ubb payment-dates
    let count = ($dates_result | length)
    print $"✅ Payment dates extracted ($count) entries"
    
    if $count > 0 {
        print "Sample data:"
        $dates_result | first 3 | table
    }
} catch {|e|
    print $"❌ Payment dates failed: ($e.msg)"
}

print ""
print "4. Testing enhanced payment schedule..."
print "-" * 30

try {
    let schedule_result = ubb payment-schedule
    let count = ($schedule_result | length)
    print $"✅ Payment schedule extracted ($count) entries"
    
    if $count > 0 {
        print "Sample data:"
        $schedule_result | first 3 | table
        
        # Test filtering
        print ""
        print "Testing month filter (Enero):"
        ubb payment-schedule --month enero | table
    }
} catch {|e|
    print $"❌ Payment schedule failed: ($e.msg)"
}

print ""
print "5. Testing utility functions..."
print "-" * 30

try {
    print "Testing next payment:"
    ubb next-payment
    print ""
    
    print "Testing payment day check:"
    ubb is-payment-day
    print ""
    
} catch {|e|
    print $"❌ Utility functions failed: ($e.msg)"
}

print ""
print "6. Testing export functionality..."
print "-" * 30

try {
    let test_file = "test_ubb_payments.json"
    ubb export-calendar $test_file --format json
    
    if ($test_file | path exists) {
        let file_size = (ls $test_file | get size | get 0)
        print $"✅ Export successful - file size: ($file_size)"
        
        # Clean up test file
        rm $test_file
    } else {
        print "❌ Export file not created"
    }
} catch {|e|
    print $"❌ Export failed: ($e.msg)"
}

print ""
print "7. Testing data validation..."
print "-" * 30

try {
    let validation_data = ubb payment-schedule
    
    # Check for required fields
    let has_mes = ($validation_data | all {|row| $row.mes != null and ($row.mes | str length) > 0})
    let has_fecha = ($validation_data | all {|row| $row.fecha_pago != null and ($row.fecha_pago | str length) > 0})
    let has_year = ($validation_data | all {|row| $row.año != null})
    
    print $"✅ All entries have 'mes' field: ($has_mes)"
    print $"✅ All entries have 'fecha_pago' field: ($has_fecha)"
    print $"✅ All entries have 'año' field: ($has_year)"
    
    # Check for expected months
    let months = ($validation_data | get mes | uniq | sort)
    let expected_months = ["Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio", 
                          "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"]
    
    print $"Found months: ($months | str join ', ')"
    
    if ($months | length) == 12 {
        print "✅ All 12 months found"
    } else {
        print $"⚠️  Expected 12 months, found ($months | length)"
    }
    
} catch {|e|
    print $"❌ Data validation failed: ($e.msg)"
}

print ""
print "8. Testing advanced pipeline operations..."
print "-" * 30

try {
    let pipeline_result = ubb payment-schedule 
        | where timestamp != null
        | where timestamp > (date now)
        | sort-by timestamp
        | first 3
    
    print $"✅ Pipeline operations successful - found ($pipeline_result | length) future payments"
    if ($pipeline_result | length) > 0 {
        $pipeline_result | table
    }
    
} catch {|e|
    print $"❌ Pipeline operations failed: ($e.msg)"
}

print ""
print "🎯 Test Summary"
print "=" * 50
print "All tests completed! Check the results above for any issues."
print ""
print "If all tests passed, you can use the commands like this:"
print "  ubb payment-schedule | table"
print "  ubb next-payment"
print "  ubb export-calendar my_calendar.json"
print ""
print "For help: ubb help"
