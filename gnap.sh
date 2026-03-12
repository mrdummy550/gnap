#!/usr/bin/env bash
# GNAP CLI — Git-Native Agent Protocol operations
# Usage: gnap.sh <command> [args]
#
# Commands:
#   read                    - Read all tasks (outputs JSON)
#   my-tasks <agent-id>     - List tasks assigned to agent
#   create <agent-id> <slug> <title> <tag> <column> [desc]
#   move <card-id> <column> <agent-id>
#   update <card-id> <field> <value> <agent-id>
#   block <card-id> <reason> <agent-id>

set -euo pipefail

REPO="farol-team/farol-team.github.io"
FILE="kanban-data.json"
API="https://api.github.com/repos/$REPO/contents/$FILE"
RAW="https://raw.githubusercontent.com/$REPO/main/$FILE"
TOKEN="${GNAP_GITHUB_TOKEN:-}"

die() { echo "ERROR: $*" >&2; exit 1; }

# Read current state (returns JSON)
cmd_read() {
  curl -sf "$RAW" || die "Failed to fetch kanban data"
}

# List tasks for an agent
cmd_my_tasks() {
  local agent="${1:?Usage: gnap.sh my-tasks <agent-id>}"
  cmd_read | python3 -c "
import sys, json
data = json.load(sys.stdin)
for c in data['cards']:
    if '$agent' in c.get('owners', []):
        print(f\"[{c['column']:10s}] {c['id']:30s} {c['title']}\")
"
}

# Get file with SHA (for writes)
_get_with_sha() {
  [ -n "$TOKEN" ] || die "GNAP_GITHUB_TOKEN not set"
  curl -sf -H "Authorization: Bearer $TOKEN" "$API"
}

# PUT updated content
_put() {
  local msg="$1" content="$2" sha="$3"
  [ -n "$TOKEN" ] || die "GNAP_GITHUB_TOKEN not set"
  curl -sf -X PUT -H "Authorization: Bearer $TOKEN" "$API" \
    -d "{\"message\":\"$msg\",\"content\":\"$content\",\"sha\":\"$sha\"}" > /dev/null
}

# Create a card
cmd_create() {
  local agent="${1:?}" slug="${2:?}" title="${3:?}" tag="${4:?}" col="${5:-next}" desc="${6:-}"
  local id="${agent}-${slug}"
  
  local resp; resp=$(_get_with_sha)
  local sha; sha=$(echo "$resp" | python3 -c "import sys,json; print(json.load(sys.stdin)['sha'])")
  local data; data=$(echo "$resp" | python3 -c "
import sys, json, base64
r = json.load(sys.stdin)
d = json.loads(base64.b64decode(r['content']))
card = {'id':'$id','column':'$col','tag':'$tag','title':'$title','desc':'$desc','owners':['$agent'],'blocked':False,'order':len(d['cards'])}
d['cards'].append(card)
print(base64.b64encode(json.dumps(d,indent=2).encode()).decode())
")
  
  _put "${agent}: create ${slug}" "$data" "$sha"
  echo "Created: $id → $col"
}

# Move a card
cmd_move() {
  local card_id="${1:?}" col="${2:?}" agent="${3:?}"
  
  local resp; resp=$(_get_with_sha)
  local sha; sha=$(echo "$resp" | python3 -c "import sys,json; print(json.load(sys.stdin)['sha'])")
  local data; data=$(echo "$resp" | python3 -c "
import sys, json, base64
r = json.load(sys.stdin)
d = json.loads(base64.b64decode(r['content']))
found = False
for c in d['cards']:
    if c['id'] == '$card_id':
        c['column'] = '$col'
        found = True
        break
if not found: print('NOT_FOUND', file=sys.stderr); sys.exit(1)
print(base64.b64encode(json.dumps(d,indent=2).encode()).decode())
")
  
  _put "${agent}: move ${card_id} → ${col}" "$data" "$sha"
  echo "Moved: $card_id → $col"
}

# Update a card field
cmd_update() {
  local card_id="${1:?}" field="${2:?}" value="${3:?}" agent="${4:?}"
  
  local resp; resp=$(_get_with_sha)
  local sha; sha=$(echo "$resp" | python3 -c "import sys,json; print(json.load(sys.stdin)['sha'])")
  local data; data=$(echo "$resp" | python3 -c "
import sys, json, base64
r = json.load(sys.stdin)
d = json.loads(base64.b64decode(r['content']))
for c in d['cards']:
    if c['id'] == '$card_id':
        c['$field'] = '$value'
        break
print(base64.b64encode(json.dumps(d,indent=2).encode()).decode())
")
  
  _put "${agent}: update ${card_id} ${field}" "$data" "$sha"
  echo "Updated: $card_id.$field = $value"
}

# Block a card
cmd_block() {
  local card_id="${1:?}" reason="${2:?}" agent="${3:?}"
  
  local resp; resp=$(_get_with_sha)
  local sha; sha=$(echo "$resp" | python3 -c "import sys,json; print(json.load(sys.stdin)['sha'])")
  local data; data=$(echo "$resp" | python3 -c "
import sys, json, base64
r = json.load(sys.stdin)
d = json.loads(base64.b64decode(r['content']))
for c in d['cards']:
    if c['id'] == '$card_id':
        c['blocked'] = True
        c['desc'] = '$reason'
        break
print(base64.b64encode(json.dumps(d,indent=2).encode()).decode())
")
  
  _put "${agent}: block ${card_id}" "$data" "$sha"
  echo "Blocked: $card_id — $reason"
}

# Dispatch
case "${1:-help}" in
  read)      cmd_read ;;
  my-tasks)  cmd_my_tasks "${2:-}" ;;
  create)    cmd_create "${2:-}" "${3:-}" "${4:-}" "${5:-}" "${6:-next}" "${7:-}" ;;
  move)      cmd_move "${2:-}" "${3:-}" "${4:-}" ;;
  update)    cmd_update "${2:-}" "${3:-}" "${4:-}" "${5:-}" ;;
  block)     cmd_block "${2:-}" "${3:-}" "${4:-}" ;;
  *)
    echo "GNAP CLI — Git-Native Agent Protocol"
    echo ""
    echo "Usage: gnap.sh <command> [args]"
    echo ""
    echo "Commands:"
    echo "  read                              Read all tasks"
    echo "  my-tasks <agent-id>               List your tasks"
    echo "  create <agent> <slug> <title> <tag> [col] [desc]"
    echo "  move <card-id> <column> <agent>"
    echo "  update <card-id> <field> <value> <agent>"
    echo "  block <card-id> <reason> <agent>"
    ;;
esac
