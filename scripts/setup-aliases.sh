#!/bin/bash

BASHRC="$HOME/.bashrc"
MARKER="# >>> Custom Aliases >>>"
END_MARKER="# <<< Custom Aliases <<<"

# Define the aliases you want to add
ALIASES=$(
    cat <<'EOF'
alias cls='clear'
EOF
)

# Check if already appended
if grep -q "$MARKER" "$BASHRC"; then
    echo "Aliases already exist in $BASHRC. Skipping."
else
    echo "Appending custom aliases to $BASHRC..."
    {
        echo ""
        echo "$MARKER"
        echo "$ALIASES"
        echo "$END_MARKER"
        echo ""
    } >>"$BASHRC"
    echo "Done. Run 'source ~/.bashrc' or restart your terminal."
fi
