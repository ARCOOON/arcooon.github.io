#!/bin/bash

FILE="$HOME/.bash_aliases"
MARKER="# >>> CUSTOM_ALIASES >>>"
END_MARKER="# <<< CUSTOM_ALIASES <<<"

ALIASES=(
    "alias ll='ls -alF'"
    "alias gs='git status'"
    "alias ..='cd ..'"
    "alias cls='clear'"
)

# Check if already appended
if grep -q "$MARKER" "$FILE"; then
    echo "Aliases already exist in $FILE. Skipping."
else
    echo "Appending custom aliases to $FILE..."
    {
        echo ""
        echo "$MARKER"
        for alias_cmd in "${ALIASES[@]}"; do
            echo "$alias_cmd"
        done
        echo "$END_MARKER"
    } >>"$FILE"
    echo "Done. Run 'source ~/.bashrc' or restart your terminal."
fi
