#!/usr/bin/env nu

def main [...args: string] {
    cd /home/kira/.gemini/extensions/google-workspace
    node dist/index.js ...$args
}
