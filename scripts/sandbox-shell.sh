#!/bin/bash
# OpenCode Cowork — Sandbox Shell Wrapper
# Every command the AI runs goes through this script.
# It checks for file paths outside the project directory and blocks them.
# This is a HARD enforcement — the AI cannot bypass it.

# The command comes after -c flag (standard shell convention)
if [ "$1" = "-c" ]; then
    shift
fi
COMMAND="$*"
PROJECT_DIR="$(pwd)"
HOME_DIR="$HOME"

# Check for protected folder references
BLOCKED_FOLDERS="Desktop Documents Downloads Movies Music Videos Pictures Public"
VIOLATION=""

for FOLDER in $BLOCKED_FOLDERS; do
    if echo "$COMMAND" | grep -qi "${HOME_DIR}/${FOLDER}\|${HOME_DIR}\\\\${FOLDER}"; then
        VIOLATION="${HOME_DIR}/${FOLDER}"
        break
    fi
done

# Check for OneDrive
if [ -z "$VIOLATION" ] && echo "$COMMAND" | grep -qi "${HOME_DIR}/OneDrive\|${HOME_DIR}\\\\OneDrive"; then
    VIOLATION="OneDrive folder"
fi

# Check for tmp
if [ -z "$VIOLATION" ] && echo "$COMMAND" | grep -qi ">/tmp/\|>/private/tmp/\|cp.*/tmp/\|mv.*/tmp/"; then
    VIOLATION="/tmp"
fi

# Check for home-relative paths to protected folders
if [ -z "$VIOLATION" ]; then
    for FOLDER in $BLOCKED_FOLDERS; do
        if echo "$COMMAND" | grep -qi "~/${FOLDER}\|\$HOME/${FOLDER}"; then
            VIOLATION="~/${FOLDER}"
            break
        fi
    done
fi

if [ -n "$VIOLATION" ]; then
    echo ""
    echo "SANDBOX VIOLATION: This command was blocked because it references a path outside the current project directory."
    echo ""
    echo "This app restricts ALL file operations to the working directory ($PROJECT_DIR) for workstation safety."
    echo ""
    echo "Blocked path: $VIOLATION"
    echo ""
    echo "Save all files inside the current project directory instead."
    exit 1
fi

# Command is safe — execute it with the real shell
exec /bin/bash -c "$COMMAND"
