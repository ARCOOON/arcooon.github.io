#!/usr/bin/env bash
set -euo pipefail

# Pure-bash, low-flicker TUI runner for scripts hosted on GitHub Pages.
# Requirements: bash, curl, tput (optional), stty
# Designed to behave safely over SSH (always restores terminal state).

BASE_URL="${BASE_URL:-https://arcooon.github.io}"
SCRIPTS_LIST_URL="${SCRIPTS_LIST_URL:-$BASE_URL/scripts.txt}"
SAFE_MODE="${SAFE_MODE:-0}"  # 1 = do not execute

TTY="/dev/tty"   # Always read/write to the real terminal

# ---------- Terminal helpers ----------
enter_alt() { tput smcup 2>/dev/null || true; }
exit_alt()  { tput rmcup 2>/dev/null || true; }
hide_cursor(){ tput civis 2>/dev/null || printf '\033[?25l'; }
show_cursor(){ tput cnorm 2>/dev/null || printf '\033[?25h'; }
rev()       { tput rev 2>/dev/null || printf '\033[7m'; }
norm()      { tput sgr0 2>/dev/null || printf '\033[0m'; }
clear_eos() { tput ed  2>/dev/null || printf '\033[J'; }
move()      { tput cup "$1" "$2" 2>/dev/null || printf '\033[%d;%dH' "$(( $1 + 1 ))" "$(( $2 + 1 ))"; }
lines()     { tput lines 2>/dev/null || echo 24; }

STTY_OLD=""
ALT_ACTIVE=0

term_setup() {
  [[ -r "$TTY" ]] || { echo "No TTY available at $TTY"; exit 1; }

  # Save current tty settings
  STTY_OLD="$(stty -g <"$TTY" 2>/dev/null || true)"

  # Raw-ish mode: no echo, no canonical buffering, non-blocking reads
  stty -echo -icanon time 0 min 0 <"$TTY" 2>/dev/null || true

  # Alternate screen reduces scrollback spam / flicker
  enter_alt
  ALT_ACTIVE=1
  hide_cursor
}

term_restore() {
  # Always attempt to restore sane settings FIRST
  norm
  show_cursor

  if (( ALT_ACTIVE == 1 )); then
    exit_alt
    ALT_ACTIVE=0
  fi

  if [[ -n "${STTY_OLD:-}" ]]; then
    stty "$STTY_OLD" <"$TTY" 2>/dev/null || stty sane <"$TTY" 2>/dev/null || true
  else
    stty sane <"$TTY" 2>/dev/null || true
  fi

  # Put cursor at a clean spot
  printf '\033[0m\033[?25h\033[H\033[J' >"$TTY" 2>/dev/null || true
}

cleanup() {
  # Called on any exit path
  term_restore
}

# Ensure cleanup runs on normal exit and most signals
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP

# ---------- Data ----------
ITEMS=()
COUNT=0

fetch_list() {
  curl -fsSL "$SCRIPTS_LIST_URL"
}

load_items() {
  local list
  list="$(fetch_list || true)"

  if [[ -z "${list//[[:space:]]/}" ]]; then
    # restore terminal so the error is readable
    term_restore
    echo "No scripts found."
    echo "Expected list at: $SCRIPTS_LIST_URL"
    exit 1
  fi

  # Read lines safely (preserve spaces, no word-splitting hell)
  ITEMS=()
  while IFS= read -r line; do
    [[ -z "${line//[[:space:]]/}" ]] && continue
    ITEMS+=("$line")
  done <<<"$list"

  COUNT="${#ITEMS[@]}"
  if (( COUNT == 0 )); then
    term_restore
    echo "No scripts found in list."
    exit 1
  fi
}

# ---------- Input ----------
# Returns: up, down, pgup, pgdn, home, end, enter, quit, refresh, other
read_key() {
  local k rest

  IFS= read -rsn1 k <"$TTY" || true
  [[ -z "${k:-}" ]] && { echo other; return 0; }

  if [[ "$k" == $'\x1b' ]]; then
    IFS= read -rsn1 rest <"$TTY" || rest=""
    [[ "$rest" != "[" ]] && { echo other; return 0; }

    IFS= read -rsn1 rest <"$TTY" || rest=""

    case "$rest" in
      A) echo up ;;
      B) echo down ;;
      H) echo home ;;
      F) echo end ;;
      5) IFS= read -rsn1 _ <"$TTY" || true; echo pgup ;;  # ~
      6) IFS= read -rsn1 _ <"$TTY" || true; echo pgdn ;;  # ~
      *) echo other ;;
    esac
    return 0
  fi

  case "$k" in
    q|Q) echo quit ;;
    r|R) echo refresh ;;
    j) echo down ;;
    k) echo up ;;
    g) echo home ;;
    G) echo end ;;
    $'\x0a'|$'\x0d') echo enter ;;
    *) echo other ;;
  esac
}

# ---------- UI state ----------
IDX=0
TOP=0
HEADER_LINES=6
FOOTER_LINES=2
LIST_START_ROW=0
LIST_ROWS=0

recalc_layout() {
  local h
  h="$(lines)"
  LIST_START_ROW=$HEADER_LINES
  LIST_ROWS=$(( h - HEADER_LINES - FOOTER_LINES ))
  (( LIST_ROWS < 3 )) && LIST_ROWS=3
}

clamp_viewport() {
  (( COUNT == 0 )) && return 0

  (( IDX < 0 )) && IDX=0
  (( IDX >= COUNT )) && IDX=$(( COUNT - 1 ))

  if (( IDX < TOP )); then TOP=$IDX; fi
  if (( IDX >= TOP + LIST_ROWS )); then TOP=$(( IDX - LIST_ROWS + 1 )); fi

  (( TOP < 0 )) && TOP=0
  local max_top=$(( COUNT - LIST_ROWS ))
  (( max_top < 0 )) && max_top=0
  (( TOP > max_top )) && TOP=$max_top
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
  echo "Selected: ${ITEMS[IDX]:-(none)}"
  echo "Tip: If arrows act up, use j/k."
}

draw_list() {
  recalc_layout
  clamp_viewport

  move "$LIST_START_ROW" 0
  clear_eos

  local i row item
  for (( i=0; i<LIST_ROWS; i++ )); do
    row=$(( TOP + i ))
    (( row >= COUNT )) && break

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
  (( COUNT == 0 )) && return 0

  local path url confirm
  path="${ITEMS[IDX]}"
  url="$BASE_URL$path"

  # Temporarily restore line input for prompt
  stty echo icanon <"$TTY" 2>/dev/null || true

  move $(( LIST_START_ROW + LIST_ROWS + 1 )) 0
  clear_eos
  echo "Selected: $path"
  echo "URL:      $url"
  echo
  read -r -p "Run it now? (y/N) " confirm <"$TTY" || confirm=""

  # Back to raw-ish mode
  stty -echo -icanon time 0 min 0 <"$TTY" 2>/dev/null || true

  confirm="${confirm,,}"
  [[ "$confirm" != "y" ]] && return 1

  if [[ "$SAFE_MODE" == "1" ]]; then
    move $(( LIST_START_ROW + LIST_ROWS + 1 )) 0
    clear_eos
    echo "SAFE_MODE=1: not executing."
    echo "Press any key to return..."
    read -rsn1 _ <"$TTY" || true
    return 0
  fi

  # Run it in normal screen so output is readable
  term_restore
  echo "Running: $url"
  echo
  bash <(curl -fsSL "$url")
  echo
  read -r -p "Done. Press Enter to return..." _ <"$TTY" || true

  # Back to TUI
  term_setup
  return 0
}

wrap_down() {
  (( COUNT == 0 )) && return 0
  (( IDX++ ))
  if (( IDX >= COUNT )); then IDX=0; fi
}

wrap_up() {
  (( COUNT == 0 )) && return 0
  (( IDX-- ))
  if (( IDX < 0 )); then IDX=$(( COUNT - 1 )); fi
}

main() {
  load_items
  term_setup
  redraw

  while true; do
    case "$(read_key)" in
      up)
        wrap_up
        draw_list
        draw_footer
        ;;
      down)
        wrap_down
        draw_list
        draw_footer
        ;;
      pgup)
        IDX=$(( IDX - LIST_ROWS ))
        (( IDX < 0 )) && IDX=0
        draw_list
        draw_footer
        ;;
      pgdn)
        IDX=$(( IDX + LIST_ROWS ))
        (( IDX >= COUNT )) && IDX=$(( COUNT - 1 ))
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
        (( IDX >= COUNT )) && IDX=$(( COUNT - 1 ))
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
        sleep 0.02
        ;;
    esac
  done
}

main
