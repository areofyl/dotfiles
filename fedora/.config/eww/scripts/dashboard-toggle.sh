#!/bin/bash
# Toggle dashboard based on workspace

WORKSPACE="$1"

if [ "$WORKSPACE" = "10" ]; then
    eww open dashboard
else
    eww close dashboard
fi
