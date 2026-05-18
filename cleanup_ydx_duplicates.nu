# Duplicate Cleanup Script for Yandex Disk
# This script verifies if '(2)' files are exact byte-for-byte copies of their original counterparts.
# If they are, it deletes the original and renames the '(2)' file to the original name.

def compare-files [file1: path, file2: path] {
    if not ($file1 | path exists) or not ($file2 | path exists) {
        return false
    }
    
    let info1 = (ls -d $file1)
    let info2 = (ls -d $file2)
    
    if ($info1 | is-empty) or ($info2 | is-empty) {
        return false
    }
    
    let size1 = ($info1 | get 0.size)
    let size2 = ($info2 | get 0.size)
    
    if $size1 != $size2 {
        return false
    }
    
    # Byte-for-byte comparison using cmp
    let result = (run-external "cmp" "-s" $file1 $file2 | complete)
    $result.exit_code == 0
}

def get-original-candidate [dup_path: path] {
    let dirname = ($dup_path | path dirname)
    let basename = ($dup_path | path basename)
    
    # Pattern 1: "filename (2).ext" -> "filename.ext" or "filename (1).ext"
    if ($basename =~ ' \(2\)\.') {
        let base_clean = ($basename | str replace ' (2).' '.')
        let base_v1 = ($basename | str replace ' (2).' ' (1).')
        
        let path_clean = ($dirname | path join $base_clean)
        if ($path_clean | path exists) { return $path_clean }
        
        let path_v1 = ($dirname | path join $base_v1)
        if ($path_v1 | path exists) { return $path_v1 }
    }
    
    # Pattern 2: "filename (2)" (no extension) -> "filename" or "filename (1)"
    if ($basename =~ ' \(2\)$') {
        let base_clean = ($basename | str replace ' (2)' '')
        let base_v1 = ($basename | str replace ' (2)' ' (1)')
        
        let path_clean = ($dirname | path join $base_clean)
        if ($path_clean | path exists) { return $path_clean }
        
        let path_v1 = ($dirname | path join $base_v1)
        if ($path_v1 | path exists) { return $path_v1 }
    }

    # Pattern 3: "(2) filename.ext" -> "filename.ext" or "(1) filename.ext"
    if ($basename =~ '^\(2\) ') {
        let base_clean = ($basename | str replace '^\(2\) ' '')
        let base_v1 = ($basename | str replace '^\(2\) ' '(1) ')
        
        let path_clean = ($dirname | path join $base_clean)
        if ($path_clean | path exists) { return $path_clean }
        
        let path_v1 = ($dirname | path join $base_v1)
        if ($path_v1 | path exists) { return $path_v1 }
    }
    
    return ""
}

def main [] {
    let base_dir = "/home/kira/Yandex.Disk"
    # Find all (2) files dynamically
    # Use -m to include hidden files if needed
    let duplicates = (glob $"($base_dir)/**/*(2)*")

    for dup_path in $duplicates {
        if not ($dup_path | path exists) { continue }
        
        let info = (ls -d $dup_path)
        if ($info | is-empty) or ($info | get 0.type) != "file" { continue }

        let orig_path = (get-original-candidate $dup_path)
        
        if ($orig_path != "") and ($dup_path != $orig_path) {
            print $"Checking duplicate: ($dup_path | path relative-to $base_dir)"
            print $"  Against original: ($orig_path | path relative-to $base_dir)"
            
            if (compare-files $dup_path $orig_path) {
                print $"  MATCH FOUND. Keeping newer version and renaming."
                rm $orig_path
                mv $dup_path $orig_path
                print $"  Success: ($orig_path)"
            } else {
                print $"  NO MATCH: Files differ. Skipping."
            }
        }
    }
}
