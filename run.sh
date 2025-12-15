#!/usr/bin/env bash
set -euo pipefail

# Pure-bash TUI runner for scripts hosted on GitHub Pages.
# Requirements: bash, curl, tput
# No jq. No python. No external TUI tools.

BASE_URL="${BASE_URL:-https://arcooon.github.io}"
SCRIPTS_LIST_URL="${SCRIPTS_LIST_URL:-$BASE_URL/scripts-list.txt}"

SAFE_MODE="${SAFE_MODE:-0}"  # 1 = do not execute

# UI helpers
clr() { printf '\033[2J\033[H'; }
hide_cursor() { tput civis 2>/dev/null || true; }
show_cursor() { tput cnorm 2>/dev/null || true; }
rev() { tput rev 2>/dev/null || printf '\033[7m'; }
norm() { tput sgr0 2>/dev/null || printf '\033[0m'; }

cleanup() {
  show_cursor
  norm
}
trap cleanup EXIT

fetch_list() {
  curl -fsSL "$SCRIPTS_LIST_URL"
}

read_key() {
  # Returns one of: up, down, enter, quit, other
  local k
  IFS= read -rsn1 k || return 1

  if [[ "$k" == $'\x1b' ]]; then
    # escape sequence
    IFS= read -rsn2 k || true
    case "$k" in
      "[A") echo up ;;
      "[B") echo down ;;
      *) echo other ;;
    esac
    return 0
  fi

  case "$k" in
    "") echo enter ;;          # Enter sends empty in read -n1 sometimes
    $'\x0a') echo enter ;;      # LF
    $'\x0d') echo enter ;;      # CR
    "q"|"Q") echo quit ;;
    *) echo other ;;
  esac
}

main() {
  local list
  list="$(fetch_list || true)"

  if [[ -z "${list//[[:space:]]/}" ]]; then
    echo "No scripts found."
    echo "Expected list at: $SCRIPTS_LIST_URL"
    echo "(Make sure your generator outputs scripts-list.txt and workflow committed it.)"
    exit 1
  fi

  # Load into array
  mapfile -t items < <(printf "%s\n" "$list" | sed '/^\s*$/d')

  local count="${#items[@]}"
  if (( count == 0 )); then
    echo "No scripts found in list."
    exit 1
  fi

  local idx=0

  hide_cursor

  while true; do
    clr
    echo "Remote Scripts TUI (pure bash)"
    echo "Source: $SCRIPTS_LIST_URL"
    echo "Controls: Up/Down, Enter = run, q = quit"
    echo

    local i
    for (( i=0; i<count; i++ )); do
      if (( i == idx )); then
        rev
        printf "> %s\n" "${items[i]}"
        norm
      else
        printf "  %s\n" "${items[i]}"
      fi
    done

    echo
    echo "SAFE_MODE=$SAFE_MODE"

    case "$(read_key)" in
      up)
        (( idx = (idx - 1 + count) % count ))
        ;;
      down)
        (( idx = (idx + 1) % count ))
        ;;
      enter)
        local path="${items[idx]}"
        local url="$BASE_URL$path"

        clr
        echo "Selected: $path"
        echo "URL:      $url"
        echo
        read -r -p "Run it now? (y/N) " confirm
        confirm="${confirm,,}"

        if [[ "$confirm" != "y" ]]; then
          continue
        fi

        if [[ "$SAFE_MODE" == "1" ]]; then
          echo "SAFE_MODE=1 set; not executing."
          read -r -p "Press Enter to return..." _
          continue
        fi

        # Execute remote script
        # Note: you're executing code served over HTTPS from your own repo.
        # This is inherently powerful - keep your repo protected.
        bash <(curl -fsSL "$url")

        echo
        read -r -p "Done. Press Enter to return..." _
        ;;
      quit)
        exit 0
        ;;
      *)
        :
        ;;
    esac
  done
}

main
