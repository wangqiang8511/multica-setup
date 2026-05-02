# Shared shell helpers for the MetaSetup scripts.
# Intended to be `source`d, not executed directly.

set -o errexit
set -o nounset
set -o pipefail

# --- logging ---------------------------------------------------------------

_log() { printf '%s %s\n' "$1" "$2" >&2; }
log_info()  { _log "•" "$*"; }
log_warn()  { _log "!" "$*"; }
log_error() { _log "✗" "$*"; }
log_ok()    { _log "✓" "$*"; }

die() { log_error "$*"; exit 1; }

# --- dependency checks -----------------------------------------------------

require_cmd() {
  local cmd
  for cmd in "$@"; do
    command -v "$cmd" >/dev/null 2>&1 || die "required command not found: $cmd"
  done
}

# --- interactive picking ---------------------------------------------------

# pick_from_menu <prompt> <line1> <line2> ...
# Prints the selected line on stdout.
pick_from_menu() {
  local prompt="$1"; shift
  local -a options=("$@")
  local n=${#options[@]}
  [[ $n -gt 0 ]] || die "pick_from_menu: no options provided"

  if [[ $n -eq 1 ]]; then
    log_info "$prompt (only one option: ${options[0]})"
    printf '%s\n' "${options[0]}"
    return 0
  fi

  {
    echo "$prompt"
    local i
    for i in "${!options[@]}"; do
      printf '  [%d] %s\n' "$((i + 1))" "${options[$i]}"
    done
  } >&2

  local choice
  while true; do
    printf '> ' >&2
    if ! read -r choice; then
      die "no selection — aborting"
    fi
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= n )); then
      printf '%s\n' "${options[$((choice - 1))]}"
      return 0
    fi
    log_warn "invalid choice: $choice"
  done
}

# --- file parsers ----------------------------------------------------------

# Read KEY=VALUE pairs from a dotenv-style file, ignoring comments/blank lines.
# Prints one `KEY=VALUE` line per variable (unescaped — raw passthrough).
read_env_file() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  # Strip comment-only and blank lines. Do NOT try to shell-expand.
  while IFS= read -r line; do
    [[ -z "${line// }" ]] && continue
    [[ "${line#"${line%%[![:space:]]*}"}" == \#* ]] && continue
    printf '%s\n' "$line"
  done < "$file"
}

# Read a target_skills.md file and emit one entry per line:
#   - full URL  -> printed as "url <URL>"
#   - bare name -> printed as "name <NAME>"
# Comments (#) and blank lines are ignored.
read_target_skills() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  while IFS= read -r line; do
    # trim
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" ]] && continue
    [[ "$line" == \#* ]] && continue
    if [[ "$line" == http://* || "$line" == https://* ]]; then
      printf 'url %s\n' "$line"
    else
      printf 'name %s\n' "$line"
    fi
  done < "$file"
}

# --- JSON helpers (jq wrappers) --------------------------------------------

# json_array_from_lines — read lines on stdin, emit a JSON array of strings.
json_array_from_lines() {
  jq -Rsc 'split("\n") | map(select(length > 0))'
}
