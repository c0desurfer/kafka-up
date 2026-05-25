#!/usr/bin/env bash
# ASCII rendering helpers. Source me, don't run me.
#
# Uses ANSI colors when stdout is a TTY and NO_COLOR is unset. Falls
# back to plain text otherwise. The box-drawing characters are pure
# ASCII so the output is safe on any terminal.

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  C_RESET=$'\033[0m'
  C_DIM=$'\033[2m'
  C_BOLD=$'\033[1m'
  C_RED=$'\033[31m'
  C_GREEN=$'\033[32m'
  C_YELLOW=$'\033[33m'
  C_BLUE=$'\033[34m'
  C_MAGENTA=$'\033[35m'
  C_CYAN=$'\033[36m'
  C_GRAY=$'\033[90m'
else
  C_RESET=""
  C_DIM=""
  C_BOLD=""
  C_RED=""
  C_GREEN=""
  C_YELLOW=""
  C_BLUE=""
  C_MAGENTA=""
  C_CYAN=""
  C_GRAY=""
fi

# Banner printed by kafka-up. Uses Unicode box-drawing characters,
# which render correctly in every modern terminal and in GitHub's
# monospace code blocks. 63 columns wide, fits in any reasonable
# terminal.
ui_banner() {
  printf '%s' "${C_CYAN}"
  cat <<'BANNER'
██╗  ██╗ █████╗ ███████╗██╗  ██╗ █████╗       ██╗   ██╗██████╗
██║ ██╔╝██╔══██╗██╔════╝██║ ██╔╝██╔══██╗      ██║   ██║██╔══██╗
█████╔╝ ███████║█████╗  █████╔╝ ███████║█████╗██║   ██║██████╔╝
██╔═██╗ ██╔══██║██╔══╝  ██╔═██╗ ██╔══██║╚════╝██║   ██║██╔═══╝
██║  ██╗██║  ██║██║     ██║  ██╗██║  ██║      ╚██████╔╝██║
╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝  ╚═╝╚═╝  ╚═╝       ╚═════╝ ╚═╝
BANNER
  printf '%s' "${C_RESET}"
}

ui_section() { printf '\n%s%s%s\n' "${C_BOLD}" "$*" "${C_RESET}"; }
ui_step()    { printf '  %s>%s %s\n' "${C_CYAN}" "${C_RESET}" "$*"; }
ui_ok()      { printf '  %sok%s  %s\n' "${C_GREEN}" "${C_RESET}" "$*"; }
ui_warn()    { printf '  %s!%s   %s\n' "${C_YELLOW}" "${C_RESET}" "$*"; }
ui_err()     { printf '  %sx%s   %s\n' "${C_RED}" "${C_RESET}" "$*" >&2; }
ui_hint()    { printf '      %s%s%s\n' "${C_DIM}" "$*" "${C_RESET}"; }
ui_kv()      { printf '  %s%-18s%s %s\n' "${C_DIM}" "$1" "${C_RESET}" "$2"; }

# ui_box "Title" "line 1" "line 2" ...
ui_box() {
  local title="$1"; shift
  local width=64 line padding
  printf '%s+' "${C_GRAY}"
  printf -- '-%.0s' $(seq 1 $((width-2)))
  printf '+%s\n' "${C_RESET}"
  printf '%s|%s %s%s%s' "${C_GRAY}" "${C_RESET}" "${C_BOLD}" "$title" "${C_RESET}"
  padding=$((width - 3 - ${#title}))
  printf '%*s' "$padding" ""
  printf '%s|%s\n' "${C_GRAY}" "${C_RESET}"
  printf '%s+' "${C_GRAY}"
  printf -- '-%.0s' $(seq 1 $((width-2)))
  printf '+%s\n' "${C_RESET}"
  for line in "$@"; do
    printf '%s|%s %s' "${C_GRAY}" "${C_RESET}" "$line"
    padding=$((width - 3 - ${#line}))
    [ "$padding" -gt 0 ] && printf '%*s' "$padding" ""
    printf '%s|%s\n' "${C_GRAY}" "${C_RESET}"
  done
  printf '%s+' "${C_GRAY}"
  printf -- '-%.0s' $(seq 1 $((width-2)))
  printf '+%s\n' "${C_RESET}"
}

# Render an elapsed-time stamp like "  12.3s" given a start epoch.
ui_elapsed() {
  local start="$1" now
  now=$(date +%s)
  printf '%ss' "$((now - start))"
}
