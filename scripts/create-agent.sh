#!/usr/bin/env bash
# Create (or update) a Multica agent from an agents/<name>/ definition.
#
# Usage:
#   ./scripts/create-agent.sh agents/<agent-name> [--dry-run] [--yes]
#
# Expected files in the agent directory:
#   - agent.yaml             (name, description, model, visibility, max_concurrent_tasks)
#   - instructions.md        (body used as --instructions)
#   - target_skills.md       (one skills.sh URL or bare skill name per line)
#   - config.env             (optional — KEY=VALUE env vars; see note below)
#   - custom_args.json       (optional — JSON array of CLI args)
#
# Env note: the `multica agent create` CLI does not currently expose a
# --custom-env flag. If config.env is non-empty, the script prints the env
# payload at the end so you can copy it into the Multica web UI, and writes
# it to the run log file next to the agent dir.

set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)

# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

require_cmd multica jq

# --- arg parsing -----------------------------------------------------------

AGENT_DIR=""
DRY_RUN=0
AUTO_YES=0

usage() {
  cat <<EOF >&2
Usage: $0 <agent-dir> [--dry-run] [--yes]

  <agent-dir>   Path to the agent definition (e.g. agents/agent-builder)
  --dry-run     Print the multica commands but don't run them
  --yes         Don't prompt for final confirmation

The script picks a runtime interactively from the online runtimes in the
current Multica workspace, imports skills listed in target_skills.md, then
creates or updates the agent.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --dry-run) DRY_RUN=1 ;;
    --yes|-y)  AUTO_YES=1 ;;
    --) shift; AGENT_DIR=${1:-}; break ;;
    -*) die "unknown flag: $1" ;;
    *)
      if [[ -z "$AGENT_DIR" ]]; then
        AGENT_DIR=$1
      else
        die "unexpected positional arg: $1"
      fi
      ;;
  esac
  shift
done

[[ -n "$AGENT_DIR" ]] || { usage; exit 2; }
[[ -d "$AGENT_DIR" ]] || die "agent directory not found: $AGENT_DIR"

AGENT_DIR=$(cd "$AGENT_DIR" && pwd)

AGENT_YAML="$AGENT_DIR/agent.yaml"
INSTRUCTIONS_FILE="$AGENT_DIR/instructions.md"
SKILLS_FILE="$AGENT_DIR/target_skills.md"
ENV_FILE="$AGENT_DIR/config.env"
ARGS_FILE="$AGENT_DIR/custom_args.json"

[[ -f "$AGENT_YAML" ]]        || die "missing $AGENT_YAML"
[[ -f "$INSTRUCTIONS_FILE" ]] || die "missing $INSTRUCTIONS_FILE"
[[ -f "$SKILLS_FILE" ]]       || die "missing $SKILLS_FILE"

# --- parse agent.yaml ------------------------------------------------------

# Minimal YAML reader: `key: value` lines only. Strips surrounding quotes.
read_yaml_field() {
  local key="$1" file="$2" val
  val=$(awk -v k="$key" '
    $0 ~ "^[[:space:]]*#" { next }
    {
      line = $0
      sub(/#.*/, "", line)
      if (match(line, "^[[:space:]]*" k "[[:space:]]*:[[:space:]]*")) {
        v = substr(line, RLENGTH + 1)
        sub(/^[[:space:]]+/, "", v)
        sub(/[[:space:]]+$/, "", v)
        # strip matching quotes
        if (v ~ /^".*"$/)   { v = substr(v, 2, length(v) - 2) }
        else if (v ~ /^'\''.*'\''$/) { v = substr(v, 2, length(v) - 2) }
        print v
        exit
      }
    }
  ' "$file")
  printf '%s' "$val"
}

AGENT_NAME=$(read_yaml_field name "$AGENT_YAML")
AGENT_DESC=$(read_yaml_field description "$AGENT_YAML")
AGENT_MODEL=$(read_yaml_field model "$AGENT_YAML")
AGENT_VISIBILITY=$(read_yaml_field visibility "$AGENT_YAML")
AGENT_MAX_CONCURRENT=$(read_yaml_field max_concurrent_tasks "$AGENT_YAML")

[[ -n "$AGENT_NAME" ]] || die "agent.yaml is missing a non-empty 'name'"

AGENT_VISIBILITY=${AGENT_VISIBILITY:-private}
AGENT_MAX_CONCURRENT=${AGENT_MAX_CONCURRENT:-6}

INSTRUCTIONS=$(cat "$INSTRUCTIONS_FILE")

# custom_args.json — validate it's a JSON array.
CUSTOM_ARGS_JSON="[]"
if [[ -f "$ARGS_FILE" ]]; then
  if ! CUSTOM_ARGS_JSON=$(jq -c '.' "$ARGS_FILE" 2>/dev/null); then
    die "custom_args.json is not valid JSON"
  fi
  if [[ "$(jq -r 'type' <<<"$CUSTOM_ARGS_JSON")" != "array" ]]; then
    die "custom_args.json must be a JSON array"
  fi
fi

# --- pick runtime ----------------------------------------------------------

log_info "Fetching online runtimes…"
RUNTIMES_JSON=$(multica runtime list --output json)

# Build parallel arrays: ids, labels.
mapfile -t RUNTIME_IDS    < <(jq -r '.[] | select(.status == "online") | .id' <<<"$RUNTIMES_JSON")
mapfile -t RUNTIME_LABELS < <(jq -r '.[] | select(.status == "online") | "\(.name)  [\(.provider)]  (\(.id))"' <<<"$RUNTIMES_JSON")

[[ ${#RUNTIME_IDS[@]} -gt 0 ]] || die "no online runtimes found in this workspace"

CHOSEN_LABEL=$(pick_from_menu "Select a runtime:" "${RUNTIME_LABELS[@]}")
CHOSEN_RUNTIME_ID=""
for i in "${!RUNTIME_LABELS[@]}"; do
  if [[ "${RUNTIME_LABELS[$i]}" == "$CHOSEN_LABEL" ]]; then
    CHOSEN_RUNTIME_ID="${RUNTIME_IDS[$i]}"
    break
  fi
done
[[ -n "$CHOSEN_RUNTIME_ID" ]] || die "internal: runtime id not resolved"
log_ok "Runtime: $CHOSEN_LABEL"

# --- import / resolve skills ----------------------------------------------

log_info "Resolving skills from target_skills.md…"
EXISTING_SKILLS_JSON=$(multica skill list --output json)

# map name -> id
existing_skill_id_by_name() {
  local name="$1"
  jq -r --arg n "$name" '.[] | select(.name == $n) | .id' <<<"$EXISTING_SKILLS_JSON" | head -n1
}

SKILL_IDS=()
while IFS=' ' read -r kind value; do
  [[ -z "${kind:-}" ]] && continue
  case "$kind" in
    url)
      # Derive the likely skill name from the last path segment of the URL
      # so we can reuse an already-installed skill by that name instead of
      # re-importing (and creating a duplicate) on every run.
      derived_name="${value%/}"; derived_name="${derived_name##*/}"
      sid=""
      if [[ -n "$derived_name" ]]; then
        sid=$(existing_skill_id_by_name "$derived_name")
      fi
      if [[ -n "$sid" ]]; then
        log_info "Skill '$derived_name' already in workspace ($sid) — reusing"
        SKILL_IDS+=("$sid")
      else
        log_info "Importing skill from $value"
        if [[ $DRY_RUN -eq 1 ]]; then
          log_info "  (dry-run) multica skill import --url $value"
          continue
        fi
        imp_json=$(multica skill import --url "$value" --output json)
        sid=$(jq -r '.id // empty' <<<"$imp_json")
        [[ -n "$sid" ]] || die "skill import returned no id for $value"
        SKILL_IDS+=("$sid")
        EXISTING_SKILLS_JSON=$(multica skill list --output json)
      fi
      ;;
    name)
      sid=$(existing_skill_id_by_name "$value")
      if [[ -z "$sid" ]]; then
        die "skill '$value' is not in this workspace and no URL was given. Add a skills.sh URL in target_skills.md."
      fi
      SKILL_IDS+=("$sid")
      ;;
    *) die "bad line in target_skills.md: $kind $value" ;;
  esac
done < <(read_target_skills "$SKILLS_FILE")

# Dedupe in case the same skill was referenced twice (e.g. URL + bare name).
if [[ ${#SKILL_IDS[@]} -gt 0 ]]; then
  mapfile -t SKILL_IDS < <(printf '%s\n' "${SKILL_IDS[@]}" | awk '!seen[$0]++')
fi

log_ok "${#SKILL_IDS[@]} skill(s) resolved"

# --- env preview -----------------------------------------------------------

ENV_LINES=()
if [[ -f "$ENV_FILE" ]]; then
  while IFS= read -r line; do ENV_LINES+=("$line"); done < <(read_env_file "$ENV_FILE")
fi

if [[ ${#ENV_LINES[@]} -gt 0 ]]; then
  log_warn "config.env contains ${#ENV_LINES[@]} var(s)."
  log_warn "The multica CLI has no --custom-env flag; set these via the web UI:"
  for kv in "${ENV_LINES[@]}"; do
    printf '    %s\n' "$kv" >&2
  done
fi

# --- find existing agent by name ------------------------------------------

AGENTS_JSON=$(multica agent list --output json)
EXISTING_AGENT_ID=$(jq -r --arg n "$AGENT_NAME" '.[] | select(.name == $n and (.archived_at // null) == null) | .id' <<<"$AGENTS_JSON" | head -n1)

ACTION=create
if [[ -n "$EXISTING_AGENT_ID" ]]; then
  ACTION=update
fi

# --- confirm --------------------------------------------------------------

cat >&2 <<EOF

About to $ACTION agent:
  name:                 $AGENT_NAME
  description:          ${AGENT_DESC:-<none>}
  model:                ${AGENT_MODEL:-<runtime default>}
  visibility:           $AGENT_VISIBILITY
  max_concurrent_tasks: $AGENT_MAX_CONCURRENT
  runtime:              $CHOSEN_LABEL
  skills:               ${#SKILL_IDS[@]}
  custom_args:          $CUSTOM_ARGS_JSON
  existing id:          ${EXISTING_AGENT_ID:-<new>}

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
  log_info "Creating agent…"
  create_out=$(run_or_echo multica agent create \
    --name "$AGENT_NAME" \
    --description "$AGENT_DESC" \
    --instructions "$INSTRUCTIONS" \
    --runtime-id "$CHOSEN_RUNTIME_ID" \
    --visibility "$AGENT_VISIBILITY" \
    --max-concurrent-tasks "$AGENT_MAX_CONCURRENT" \
    ${AGENT_MODEL:+--model "$AGENT_MODEL"} \
    --custom-args "$CUSTOM_ARGS_JSON" \
    --output json)
  if [[ $DRY_RUN -ne 1 ]]; then
    EXISTING_AGENT_ID=$(jq -r '.id' <<<"$create_out")
    log_ok "Created agent: $EXISTING_AGENT_ID"
  fi
else
  log_info "Updating agent $EXISTING_AGENT_ID…"
  run_or_echo multica agent update "$EXISTING_AGENT_ID" \
    --name "$AGENT_NAME" \
    --description "$AGENT_DESC" \
    --instructions "$INSTRUCTIONS" \
    --runtime-id "$CHOSEN_RUNTIME_ID" \
    --visibility "$AGENT_VISIBILITY" \
    --max-concurrent-tasks "$AGENT_MAX_CONCURRENT" \
    --model "$AGENT_MODEL" \
    --custom-args "$CUSTOM_ARGS_JSON" \
    --output json >/dev/null
  log_ok "Updated agent: $EXISTING_AGENT_ID"
fi

# --- skill assignment -----------------------------------------------------

if [[ ${#SKILL_IDS[@]} -gt 0 && $DRY_RUN -ne 1 ]]; then
  SKILL_CSV=$(IFS=,; echo "${SKILL_IDS[*]}")
  log_info "Assigning ${#SKILL_IDS[@]} skill(s)…"
  multica agent skills set "$EXISTING_AGENT_ID" --skill-ids "$SKILL_CSV" --output json >/dev/null
  log_ok "Skills assigned"
elif [[ $DRY_RUN -eq 1 ]]; then
  log_info "(dry-run) would assign skills: ${SKILL_IDS[*]:-<none>}"
fi

log_ok "Done."
printf '%s\n' "$EXISTING_AGENT_ID"
