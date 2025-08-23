#!/bin/bash

BASHRC="$HOME/.bashrc"
MARKER="# >>> CUSTOM_ALIASES >>>"
END_MARKER="# <<< CUSTOM_ALIASES <<<"

ALIASES=(
    "alias ll='ls -alF'"
    "alias gs='git status'"
    "alias ..='cd ..'"
    "alias cls='clear'"
)

# Check if already appended
if grep -q "$MARKER" "$BASHRC"; then
    echo "Aliases already exist in $BASHRC. Skipping."
else
    echo "Appending custom aliases to $BASHRC..."
    {
        echo ""
        echo "$MARKER"
        for alias_cmd in "${ALIASES[@]}"; do
            echo "$alias_cmd"
        done
        echo "$END_MARKER"
    } >>"$BASHRC"
    echo "Done. Run 'source ~/.bashrc' or restart your terminal."
fi
