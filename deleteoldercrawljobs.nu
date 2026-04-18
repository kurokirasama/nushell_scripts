#!/usr/bin/env nu

def main [] {
    let directory = ("~/Dropbox/Aplicaciones/Gmail/folderwatched/added" | path expand)

    if not (($directory | path exists) and ($directory | path type) == "dir") {
        print $"Directory not found or is not a directory: ($directory)"
        return
    }

    ls $directory
    | where type == file
    | where modified <= (date now) - 7day
    | get name
    | each {rm $in}
    | ignore
}