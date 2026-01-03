#!/bin/bash
# Open kitty with Claude CLI and auto-type "1"

SOCKET="/tmp/kitty-claude-$$"

# Launch kitty with remote control enabled
kitty --listen-on "unix:$SOCKET" claude &

# Wait for kitty to start and delay before typing
sleep 1

# Send "1"
kitty @ --to "unix:$SOCKET" send-text "1"
