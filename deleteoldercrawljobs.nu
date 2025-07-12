#!/usr/bin/env nu

def main [] {
    let directory = "/home/kira/Dropbox/Aplicaciones/Gmail/folderwatched/added"

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