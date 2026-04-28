# Git metrics helper for prompt

# Parse git status --porcelain=v2 --branch output
export def parse-git-status-v2 [input: string] {
    let lines = ($input | lines)
    
    let branch_head = (
        $lines 
        | where $it =~ "^# branch.head" 
        | get -o 0 
        | default "" 
        | parse --regex "# branch.head (?P<name>.+)"
        | get -o 0 
        | get -o name
        | default "no-branch"
    )

    let branch_ab = (
        $lines 
        | where $it =~ "^# branch.ab" 
        | get -o 0 
        | default "" 
        | parse --regex "# branch.ab \\+(?P<ahead>\\d+) -(?P<behind>\\d+)"
        | get -o 0 
        | default {ahead: "0", behind: "0"}
    )
    
    # 1 <XY> <sub> <mH> <mI> <mW> <hH> <hI> <path>
    # X = staged, Y = unstaged
    
    let changed_lines = ($lines | where $it =~ "^[12] ")
    let untracked_files = ($lines | where $it =~ "^\\? " | length)

    # Staged: X column (index 2) is not '.'
    let staged_files = (
        $changed_lines 
        | where ($it | str substring 2..2) != "." 
        | length
    )
    
    # Modified: Y column (index 3) is 'M'
    let modified_files = (
        $changed_lines 
        | where ($it | str substring 3..3) == "M" 
        | length
    )

    # Deleted: Y column (index 3) is 'D'
    let deleted_files = (
        $changed_lines 
        | where ($it | str substring 3..3) == "D" 
        | length
    )

    {
        branch: $branch_head
        ahead: ($branch_ab.ahead | into int)
        behind: ($branch_ab.behind | into int)
        staged: $staged_files
        modified: $modified_files
        deleted: $deleted_files
        untracked: $untracked_files
    }
}

# Extract git metrics using porcelain v2
export def get-git-metrics [] {
    if not (".git" | path exists) {
        return {
            branch: ""
            ahead: 0
            behind: 0
            staged: 0
            modified: 0
            deleted: 0
            untracked: 0
        }
    }
    
    let status = (do -i { ^git status --porcelain=v2 --branch } | complete)
    if $status.exit_code != 0 {
        return {
            branch: ""
            ahead: 0
            behind: 0
            staged: 0
            modified: 0
            deleted: 0
            untracked: 0
        }
    }
    
    parse-git-status-v2 $status.stdout
}
