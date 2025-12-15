#!/usr/bin/env bash
set -euo pipefail

# Pure-bash, low-flicker TUI runner for scripts hosted on GitHub Pages.
# Requirements: bash, curl, tput, stty
# Works best in real TTY terminals (Windows Terminal / iTerm / GNOME Terminal).

BASE_URL="${BASE_URL:-https://arcooon.github.io}"
SCRIPTS_LIST_URL="${SCRIPTS_LIST_URL:-$BASE_URL/scripts-list.txt}"
SAFE_MODE="${SAFE_MODE:-0}"  # 1 = do not execute

# Always read keys from the terminal even if stdin is redirected.
TTY="/dev/tty"

# ---------- Terminal helpers ----------
cols() { tput cols 2>/dev/null || echo 80; }
lines() { tput lines 2>/dev/null || echo 24; }

enter_alt() { tput smcup 2>/dev/null || true; }
exit_alt() { tput rmcup 2>/dev/null || true; }
hide_cursor() { tput civis 2>/dev/null || true; }
show_cursor() { tput cnorm 2>/dev/null || true; }
rev() { tput rev 2>/dev/null || printf '\033[7m'; }
norm() { tput sgr0 2>/dev/null || printf '\033[0m'; }
clear_eos() { tput ed 2>/dev/null || printf '\033[J'; }
move() { tput cup "$1" "$2" 2>/dev/null || printf '\033[%d;%dH' "$(( $1 + 1 ))" "$(( $2 + 1 ))"; }

# Save/restore stty
STTY_OLD=""
term_setup() {
  [[ -r "$TTY" ]] || { echo "No TTY available at $TTY"; exit 1; }

  STTY_OLD="$(stty -g <"$TTY")"

  # Raw-ish mode: no echo, immediate key reads.
  stty -echo -icanon time 0 min 0 <"$TTY"

  enter_alt
  hide_cursor
}

term_restore() {
  norm
  show_cursor
  exit_alt

  if [[ -n "${STTY_OLD:-}" ]]; then
    stty "$STTY_OLD" <"$TTY" 2>/dev/null || true
  fi
}

trap term_restore EXIT

# ---------- Data ----------
fetch_list() {
  curl -fsSL "$SCRIPTS_LIST_URL"
}

load_items() {
  local list
  list="$(fetch_list || true)"

  if [[ -z "${list//[[:space:]]/}" ]]; then
    echo "No scripts found."
    echo "Expected list at: $SCRIPTS_LIST_URL"
    exit 1
  fi

  # shellcheck disable=SC2207
  ITEMS=( $(printf "%s\n" "$list" | sed '/^[[:space:]]*$/d') )
  COUNT="${#ITEMS[@]}"

  if (( COUNT == 0 )); then
    echo "No scripts found in list."
    exit 1
  fi
}

# ---------- Input ----------
# Reads a single key sequence from /dev/tty and returns one of:
# up, down, pgup, pgdn, home, end, enter, quit, refresh, other
read_key() {
  local k rest

  IFS= read -rsn1 k <"$TTY" || true

  # Nothing pressed
  if [[ -z "${k:-}" ]]; then
    echo other
    return 0
  fi

  # ESC sequences (arrows, etc.)
  if [[ "$k" == $'\x1b' ]]; then
    # Read the rest of the escape sequence if present.
    # Typical: ESC [ A
    IFS= read -rsn1 rest <"$TTY" || rest=""
    if [[ "$rest" != "[" ]]; then
      echo other
      return 0
    fi

    IFS= read -rsn1 rest <"$TTY" || rest=""

    case "$rest" in
      A) echo up ;;
      B) echo down ;;
      H) echo home ;;
      F) echo end ;;
      5) IFS= read -rsn1 rest <"$TTY" || true; echo pgup ;;  # ~
      6) IFS= read -rsn1 rest <"$TTY" || true; echo pgdn ;;  # ~
      1)
        # Some terminals send ESC [ 1 ; 5 A (ctrl+up) etc.
        # We consume a bit more and map last char.
        IFS= read -rsn5 rest <"$TTY" || rest=""
        case "$rest" in
          *A) echo up ;;
          *B) echo down ;;
          *H) echo home ;;
          *F) echo end ;;
          *) echo other ;;
        esac
        ;;
      *) echo other ;;
    esac
    return 0
  fi

  case "$k" in
    q|Q) echo quit ;;
    r|R) echo refresh ;;
    $'\x0a'|$'\x0d') echo enter ;;
    k) echo up ;;     # vim keys
    j) echo down ;;   # vim keys
    g) echo home ;;   # vim-ish
    G) echo end ;;
    *) echo other ;;
  esac
}

# ---------- UI state ----------
ITEMS=()
COUNT=0
IDX=0
TOP=0

# Layout constants (recomputed on draw)
HEADER_LINES=6
FOOTER_LINES=2
LIST_START_ROW=0
LIST_ROWS=0

recalc_layout() {
  local h
  h="$(lines)"
  LIST_START_ROW=$HEADER_LINES
  LIST_ROWS=$(( h - HEADER_LINES - FOOTER_LINES ))
  if (( LIST_ROWS < 3 )); then
    LIST_ROWS=3
  fi
}

clamp_viewport() {
  # Ensure IDX visible within [TOP, TOP+LIST_ROWS)
  if (( IDX < TOP )); then
    TOP=$IDX
  fi
  if (( IDX >= TOP + LIST_ROWS )); then
    TOP=$(( IDX - LIST_ROWS + 1 ))
  fi

  if (( TOP < 0 )); then TOP=0; fi
  local max_top=$(( COUNT - LIST_ROWS ))
  if (( max_top < 0 )); then max_top=0; fi
  if (( TOP > max_top )); then TOP=$max_top; fi
}

draw_header() {
  move 0 0
  clear_eos
  echo "Remote Scripts (pure bash, low flicker)"
  echo "Source: $SCRIPTS_LIST_URL"
  echo "Controls: Up/Down or j/k, Enter=run, r=refresh, q=quit"
  echo "Nav: PgUp/PgDn, Home/End"
  echo "SAFE_MODE=$SAFE_MODE"
  echo
}

draw_footer() {
  local h
  h="$(lines)"
  move $(( h - 2 )) 0
  clear_eos
  echo "Selected: ${ITEMS[IDX]}"
  echo "Tip: If arrows are weird, use j/k."
}

draw_list() {
  recalc_layout
  clamp_viewport

  local i row item

  move "$LIST_START_ROW" 0
  clear_eos

  for (( i=0; i<LIST_ROWS; i++ )); do
    row=$(( TOP + i ))
    if (( row >= COUNT )); then
      break
    fi

    item="${ITEMS[row]}"

    if (( row == IDX )); then
      rev
      printf "> %s\n" "$item"
      norm
    else
      printf "  %s\n" "$item"
    fi
  done
}

redraw() {
  draw_header
  draw_list
  draw_footer
}

confirm_run() {
  local path url confirm
  path="${ITEMS[IDX]}"
  url="$BASE_URL$path"

  # Temporarily restore cooked-ish input for the prompt
  stty echo icanon <"$TTY"
  move $(( LIST_START_ROW + LIST_ROWS + 1 )) 0
  clear_eos
  echo "Selected: $path"
  echo "URL:      $url"
  echo
  read -r -p "Run it now? (y/N) " confirm <"$TTY" || confirm=""

  # Back to raw-ish mode
  stty -echo -icanon time 0 min 0 <"$TTY"

  confirm="${confirm,,}"

  if [[ "$confirm" != "y" ]]; then
    return 1
  fi

  if [[ "$SAFE_MODE" == "1" ]]; then
    move $(( LIST_START_ROW + LIST_ROWS + 1 )) 0
    clear_eos
    echo "SAFE_MODE=1: not executing." 
    echo "Press any key to return..."
    read -rsn1 _ <"$TTY" || true
    return 0
  fi

  # Run it in the normal screen (so output is readable)
  term_restore
  echo "Running: $url"
  echo
  bash <(curl -fsSL "$url")
  echo
  read -r -p "Done. Press Enter to return..." _
  term_setup
  return 0
}

main() {
  load_items
  term_setup
  redraw

  while true; do
    case "$(read_key)" in
      up)
        (( IDX = (IDX - 1 + COUNT) % COUNT ))
        draw_list
        draw_footer
        ;;
      down)
        (( IDX = (IDX + 1) % COUNT ))
        draw_list
        draw_footer
        ;;
      pgup)
        IDX=$(( IDX - LIST_ROWS ))
        if (( IDX < 0 )); then IDX=0; fi
        draw_list
        draw_footer
        ;;
      pgdn)
        IDX=$(( IDX + LIST_ROWS ))
        if (( IDX >= COUNT )); then IDX=$(( COUNT - 1 )); fi
        draw_list
        draw_footer
        ;;
      home)
        IDX=0
        draw_list
        draw_footer
        ;;
      end)
        IDX=$(( COUNT - 1 ))
        draw_list
        draw_footer
        ;;
      refresh)
        load_items
        if (( IDX >= COUNT )); then IDX=$(( COUNT - 1 )); fi
        TOP=0
        redraw
        ;;
      enter)
        confirm_run || true
        redraw
        ;;
      quit)
        exit 0
        ;;
      *)
        # tiny sleep prevents CPU spin when no keypress is available
        sleep 0.02
        ;;
    esac
  done
}

main
