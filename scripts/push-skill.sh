#!/usr/bin/env bash
# Push a skill from skills/<skill-name>/ into a Multica workspace.
#
# Usage:
#   ./scripts/push-skill.sh skills/<skill-name> [--workspace <id|name>] [--dry-run] [--yes] [--prune]
#
# Expected layout in the skill directory:
#   SKILL.md               (required — frontmatter + body; body becomes the skill's `content`)
#   <any other files>      (uploaded via `multica skill files upsert`, preserving their relative paths)
#
# Frontmatter (YAML) at the top of SKILL.md must contain:
#   name:         (required — also the update-lookup key)
#   description:  (optional but recommended)
#
# The script:
#   - picks a workspace (interactively or via --workspace) and scopes every call to it
#   - creates the skill if no skill with that name exists, otherwise updates it
#   - upserts every supporting file under the skill directory (except SKILL.md itself)
#   - with --prune, deletes remote files that are no longer present locally

set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)

# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

require_cmd multica jq

# --- arg parsing -----------------------------------------------------------

SKILL_DIR=""
DRY_RUN=0
AUTO_YES=0
PRUNE=0
WORKSPACE_ARG=""

usage() {
  cat <<EOF >&2
Usage: $0 <skill-dir> [--workspace <id|name>] [--dry-run] [--yes] [--prune]

  <skill-dir>            Path to the skill (e.g. skills/my-skill). Must contain SKILL.md.
  --workspace <id|name>  Target workspace (skips the interactive picker)
  --dry-run              Print the multica commands but don't run them
  --yes                  Don't prompt for final confirmation
  --prune                Delete remote files that are not present locally
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --dry-run) DRY_RUN=1 ;;
    --yes|-y)  AUTO_YES=1 ;;
    --prune)   PRUNE=1 ;;
    -w|--workspace)
      [[ $# -ge 2 ]] || die "--workspace requires a value"
      WORKSPACE_ARG=$2
      shift
      ;;
    --workspace=*) WORKSPACE_ARG=${1#*=} ;;
    --) shift; SKILL_DIR=${1:-}; break ;;
    -*) die "unknown flag: $1" ;;
    *)
      if [[ -z "$SKILL_DIR" ]]; then
        SKILL_DIR=$1
      else
        die "unexpected positional arg: $1"
      fi
      ;;
  esac
  shift
done

[[ -n "$SKILL_DIR" ]] || { usage; exit 2; }
[[ -d "$SKILL_DIR" ]] || die "skill directory not found: $SKILL_DIR"

SKILL_DIR=$(cd "$SKILL_DIR" && pwd)
SKILL_MD="$SKILL_DIR/SKILL.md"
[[ -f "$SKILL_MD" ]] || die "missing $SKILL_MD"

# --- parse SKILL.md frontmatter --------------------------------------------

# Extracts frontmatter (between the first two `---` lines) and the body.
# Writes frontmatter to $1, body to $2.
split_frontmatter() {
  local src="$1" fm_out="$2" body_out="$3"
  awk -v fm="$fm_out" -v bd="$body_out" '
    BEGIN { state = "start" }
    state == "start" {
      if ($0 == "---") { state = "fm"; next }
      # No frontmatter — treat entire file as body.
      state = "body"
      print $0 > bd
      next
    }
    state == "fm" {
      if ($0 == "---") { state = "body"; next }
      print $0 > fm
      next
    }
    state == "body" { print $0 > bd }
  ' "$src"
}

FM_FILE=$(mktemp)
BODY_FILE=$(mktemp)
trap 'rm -f "$FM_FILE" "$BODY_FILE"' EXIT

split_frontmatter "$SKILL_MD" "$FM_FILE" "$BODY_FILE"

# Same minimal key: value reader used in create-agent.sh.
read_yaml_field() {
  local key="$1" file="$2"
  awk -v k="$key" '
    $0 ~ "^[[:space:]]*#" { next }
    {
      line = $0
      sub(/#.*/, "", line)
      if (match(line, "^[[:space:]]*" k "[[:space:]]*:[[:space:]]*")) {
        v = substr(line, RLENGTH + 1)
        sub(/^[[:space:]]+/, "", v)
        sub(/[[:space:]]+$/, "", v)
        if (v ~ /^".*"$/)           { v = substr(v, 2, length(v) - 2) }
        else if (v ~ /^'\''.*'\''$/) { v = substr(v, 2, length(v) - 2) }
        print v
        exit
      }
    }
  ' "$file"
}

SKILL_NAME=$(read_yaml_field name "$FM_FILE")
SKILL_DESC=$(read_yaml_field description "$FM_FILE")

[[ -n "$SKILL_NAME" ]] || die "SKILL.md frontmatter is missing a non-empty 'name'"

# The full SKILL.md content (frontmatter + body) is what the platform stores
# as `content`; callers see it verbatim. Upload the file as-is.
SKILL_CONTENT=$(cat "$SKILL_MD")

# --- pick workspace --------------------------------------------------------

log_info "Fetching workspaces…"
WORKSPACES_RAW=$(multica workspace list)
WS_IDS=()
WS_NAMES=()
WS_LABELS=()
while IFS=$'\t' read -r ws_id ws_name; do
  [[ -z "${ws_id:-}" ]] && continue
  WS_IDS+=("$ws_id")
  WS_NAMES+=("$ws_name")
  WS_LABELS+=("$ws_name  ($ws_id)")
done < <(printf '%s\n' "$WORKSPACES_RAW" \
  | awk 'NR>1 && NF>=2 {id=$1; $1=""; sub(/^[ \t]+/, ""); printf "%s\t%s\n", id, $0}')

[[ ${#WS_IDS[@]} -gt 0 ]] || die "no workspaces returned by 'multica workspace list'"

CURRENT_WS_ID="${MULTICA_WORKSPACE_ID:-}"

resolve_workspace() {
  local q="$1" i
  for i in "${!WS_IDS[@]}"; do
    if [[ "${WS_IDS[$i]}" == "$q" || "${WS_NAMES[$i]}" == "$q" ]]; then
      printf '%s' "${WS_IDS[$i]}"
      return 0
    fi
  done
  printf ''
}

WORKSPACE_ID=""
WORKSPACE_NAME=""
if [[ -n "$WORKSPACE_ARG" ]]; then
  WORKSPACE_ID=$(resolve_workspace "$WORKSPACE_ARG")
  [[ -n "$WORKSPACE_ID" ]] || die "workspace '$WORKSPACE_ARG' not found (try: multica workspace list)"
  log_ok "Workspace (from --workspace): $WORKSPACE_ARG"
elif [[ ${#WS_IDS[@]} -eq 1 ]]; then
  WORKSPACE_ID="${WS_IDS[0]}"
  log_info "Only one workspace available — using it automatically."
else
  default_hint=""
  if [[ -n "$CURRENT_WS_ID" ]]; then
    for i in "${!WS_IDS[@]}"; do
      if [[ "${WS_IDS[$i]}" == "$CURRENT_WS_ID" ]]; then
        default_hint=" [current: ${WS_NAMES[$i]}]"
        break
      fi
    done
  fi
  CHOSEN_WS_LABEL=$(pick_from_menu "Select a workspace to push the skill to:${default_hint}" "${WS_LABELS[@]}")
  for i in "${!WS_LABELS[@]}"; do
    if [[ "${WS_LABELS[$i]}" == "$CHOSEN_WS_LABEL" ]]; then
      WORKSPACE_ID="${WS_IDS[$i]}"
      break
    fi
  done
  [[ -n "$WORKSPACE_ID" ]] || die "internal: workspace id not resolved"
fi

for i in "${!WS_IDS[@]}"; do
  if [[ "${WS_IDS[$i]}" == "$WORKSPACE_ID" ]]; then
    WORKSPACE_NAME="${WS_NAMES[$i]}"
    break
  fi
done

log_ok "Workspace: ${WORKSPACE_NAME:-?}  ($WORKSPACE_ID)"
if [[ -n "$CURRENT_WS_ID" && "$CURRENT_WS_ID" != "$WORKSPACE_ID" ]]; then
  log_warn "MULTICA_WORKSPACE_ID in the environment ($CURRENT_WS_ID) differs from the chosen workspace; the script will override it for this run."
fi

multica() { command multica --workspace-id "$WORKSPACE_ID" "$@"; }

# --- collect local supporting files ---------------------------------------

# Build a newline-separated list of relative paths (under $SKILL_DIR),
# excluding SKILL.md and any VCS/OS junk.
LOCAL_FILES=()
while IFS= read -r -d '' f; do
  rel=${f#"$SKILL_DIR/"}
  case "$rel" in
    SKILL.md) continue ;;
    .DS_Store|*/.DS_Store) continue ;;
    .git|.git/*|*/.git/*) continue ;;
  esac
  LOCAL_FILES+=("$rel")
done < <(find "$SKILL_DIR" -type f -print0 | LC_ALL=C sort -z)

# --- find existing skill by name ------------------------------------------

SKILLS_JSON=$(multica skill list --output json)
EXISTING_SKILL_ID=$(jq -r --arg n "$SKILL_NAME" '.[] | select(.name == $n) | .id' <<<"$SKILLS_JSON" | head -n1)

ACTION=create
if [[ -n "$EXISTING_SKILL_ID" ]]; then
  ACTION=update
fi

# --- confirm --------------------------------------------------------------

cat >&2 <<EOF

About to $ACTION skill:
  workspace:    ${WORKSPACE_NAME:-?}  ($WORKSPACE_ID)
  name:         $SKILL_NAME
  description:  ${SKILL_DESC:-<none>}
  files:        ${#LOCAL_FILES[@]} supporting file(s)
  existing id:  ${EXISTING_SKILL_ID:-<new>}
  prune remote: $([ $PRUNE -eq 1 ] && echo yes || echo no)

EOF

if [[ $AUTO_YES -ne 1 && $DRY_RUN -ne 1 ]]; then
  printf 'Proceed? [y/N] ' >&2
  read -r confirm
  [[ "$confirm" =~ ^[Yy]$ ]] || die "aborted by user"
fi

# --- run ------------------------------------------------------------------

run_or_echo() {
  if [[ $DRY_RUN -eq 1 ]]; then
    printf '(dry-run) %s\n' "$*" >&2
    return 0
  fi
  "$@"
}

if [[ "$ACTION" == "create" ]]; then
  log_info "Creating skill…"
  if [[ $DRY_RUN -eq 1 ]]; then
    log_info "(dry-run) multica skill create --name $SKILL_NAME --description … --content …"
  else
    create_out=$(multica skill create \
      --name "$SKILL_NAME" \
      --description "$SKILL_DESC" \
      --content "$SKILL_CONTENT" \
      --output json)
    EXISTING_SKILL_ID=$(jq -r '.id' <<<"$create_out")
    [[ -n "$EXISTING_SKILL_ID" && "$EXISTING_SKILL_ID" != "null" ]] || die "skill create returned no id"
    log_ok "Created skill: $EXISTING_SKILL_ID"
  fi
else
  log_info "Updating skill $EXISTING_SKILL_ID…"
  if [[ $DRY_RUN -eq 1 ]]; then
    log_info "(dry-run) multica skill update $EXISTING_SKILL_ID --name … --description … --content …"
  else
    multica skill update "$EXISTING_SKILL_ID" \
      --name "$SKILL_NAME" \
      --description "$SKILL_DESC" \
      --content "$SKILL_CONTENT" \
      --output json >/dev/null
    log_ok "Updated skill: $EXISTING_SKILL_ID"
  fi
fi

# --- sync supporting files ------------------------------------------------

if [[ $DRY_RUN -eq 1 ]]; then
  for rel in "${LOCAL_FILES[@]}"; do
    log_info "(dry-run) would upsert file: $rel"
  done
  if [[ $PRUNE -eq 1 ]]; then
    log_info "(dry-run) would prune remote files not listed above"
  fi
  log_ok "Done (dry-run)."
  printf '%s\n' "${EXISTING_SKILL_ID:-<new>}"
  exit 0
fi

if [[ ${#LOCAL_FILES[@]} -gt 0 ]]; then
  log_info "Uploading ${#LOCAL_FILES[@]} file(s)…"
  for rel in "${LOCAL_FILES[@]}"; do
    content=$(cat "$SKILL_DIR/$rel")
    multica skill files upsert "$EXISTING_SKILL_ID" \
      --path "$rel" \
      --content "$content" \
      --output json >/dev/null
    log_ok "  $rel"
  done
else
  log_info "No supporting files to upload."
fi

# --- optional prune -------------------------------------------------------

if [[ $PRUNE -eq 1 ]]; then
  log_info "Pruning remote files not present locally…"
  remote_json=$(multica skill files list "$EXISTING_SKILL_ID" --output json)

  local_set=$(printf '%s\n' "${LOCAL_FILES[@]}" | awk 'NF')

  # For each remote file, delete if its path isn't in the local set.
  while IFS=$'\t' read -r fid fpath; do
    [[ -z "${fid:-}" ]] && continue
    if ! printf '%s\n' "$local_set" | grep -Fxq -- "$fpath"; then
      multica skill files delete "$EXISTING_SKILL_ID" "$fid" >/dev/null
      log_ok "  deleted $fpath"
    fi
  done < <(jq -r '.[] | "\(.id)\t\(.path)"' <<<"$remote_json")
fi

log_ok "Done."
printf '%s\n' "$EXISTING_SKILL_ID"
