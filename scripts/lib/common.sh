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

# Convert a dotenv-style file to a compact JSON object. Values keep their raw
# form except that matching surrounding single/double quotes are stripped
# (KEY="v" and KEY='v' both become {"KEY":"v"}). Missing file -> "{}".
# Invalid lines cause die().
env_file_to_json() {
  local file="$1" json='{}' line key val first last
  [[ -f "$file" ]] || { printf '%s' '{}'; return 0; }
  while IFS= read -r line; do
    [[ -z "${line// }" ]] && continue
    [[ "${line#"${line%%[![:space:]]*}"}" == \#* ]] && continue
    if [[ "$line" =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*=(.*)$ ]]; then
      key=${BASH_REMATCH[1]}
      val=${BASH_REMATCH[2]}
      if [[ ${#val} -ge 2 ]]; then
        first=${val:0:1}
        last=${val: -1}
        if { [[ "$first" == '"' && "$last" == '"' ]] || [[ "$first" == "'" && "$last" == "'" ]]; }; then
          val=${val:1:${#val}-2}
        fi
      fi
      json=$(jq -c --arg k "$key" --arg v "$val" '. + {($k): $v}' <<<"$json")
    else
      die "bad line in $file: $line"
    fi
  done < "$file"
  printf '%s' "$json"
}

# Return 0 iff the installed multica CLI's help for the given subcommand
# path (e.g. "agent create") mentions the given flag token.
cli_supports_flag() {
  local subcmd="$1" flag="$2"
  # shellcheck disable=SC2086
  command multica $subcmd --help 2>&1 | grep -q -- "$flag"
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
