#!/bin/bash
# ============================================================
#  OpenCode Cowork — Model Manager (macOS / Linux)
#
#  Discovers all models from your configured provider's API and
#  lets you pick which ones to load into the app. Works with any
#  OpenAI-compatible endpoint including Open WebUI, where custom
#  workspace models (with tools stripped, etc.) appear alongside
#  base models.
#
#  Usage:
#    ./manage-models.sh          Normal mode
#    ./manage-models.sh --debug  Dump raw API response and exit
# ============================================================

set -e

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

DEBUG=0
if [ "$1" = "--debug" ] || [ "$1" = "-d" ]; then
    DEBUG=1
fi

CONFIG_FILE="$HOME/.config/opencode/opencode.json"
BUILD_CONFIG="$HOME/.opencode-cowork-build/opencode.json"

if ! command -v python3 &>/dev/null; then
    echo -e "${RED}Error:${NC} python3 is required but not found."
    exit 1
fi

if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}Error:${NC} No config found at $CONFIG_FILE"
    echo "Run the installer first."
    exit 1
fi

# Extract provider info (tab-delimited to avoid issues with spaces in names)
INFO=$(python3 <<PYEOF
import json, sys
with open("$CONFIG_FILE") as f:
    config = json.load(f)
providers = config.get('provider', {})
if not providers:
    print("ERROR:no-provider")
    sys.exit(0)
key = list(providers.keys())[0]
p = providers[key]
base_url = (p.get('options', {}) or {}).get('baseURL', '').rstrip('/')
api_key = (p.get('options', {}) or {}).get('apiKey', '')
current = list((p.get('models') or {}).keys())
name = p.get('name', key)
print(f"{key}\t{name}\t{base_url}\t{api_key}\t{','.join(current)}")
PYEOF
)

if [[ "$INFO" == ERROR* ]]; then
    echo -e "${RED}Error:${NC} No provider configured in $CONFIG_FILE"
    exit 1
fi

PROVIDER_KEY=$(echo "$INFO" | cut -f1)
PROVIDER_NAME=$(echo "$INFO" | cut -f2)
BASE_URL=$(echo "$INFO" | cut -f3)
API_KEY=$(echo "$INFO" | cut -f4)
CURRENT_CSV=$(echo "$INFO" | cut -f5)

echo ""
echo -e "${BLUE}${BOLD}+==========================================+${NC}"
echo -e "${BLUE}${BOLD}|       Model Manager — Cowork             |${NC}"
echo -e "${BLUE}${BOLD}+==========================================+${NC}"
echo ""
echo -e "Provider: ${BOLD}$PROVIDER_NAME${NC} ($PROVIDER_KEY)"
echo -e "API URL:  $BASE_URL"
echo ""

# Try /models first, fallback to /v1/models
echo -e "Fetching available models..."
TRIED_PATH=""
for p in "/models" "/v1/models"; do
    RESP=$(curl -s -f -H "Authorization: Bearer $API_KEY" "$BASE_URL$p" 2>/dev/null || true)
    if [ -n "$RESP" ]; then
        TRIED_PATH="$p"
        MODELS_JSON="$RESP"
        break
    fi
done

if [ -z "${MODELS_JSON:-}" ]; then
    echo -e "${RED}Error:${NC} Could not fetch models from the API."
    echo "  Tried: $BASE_URL/models and $BASE_URL/v1/models"
    echo "  Check your API key and that the endpoint exposes GET /models."
    echo ""
    echo -e "${DIM}Tip: run with --debug to see the raw API response${NC}"
    exit 1
fi

if [ "$DEBUG" = "1" ]; then
    echo ""
    echo -e "${YELLOW}=== DEBUG: raw response from $BASE_URL$TRIED_PATH ===${NC}"
    echo "$MODELS_JSON" | python3 -m json.tool 2>/dev/null || echo "$MODELS_JSON"
    echo -e "${YELLOW}=== end of raw response ===${NC}"
    echo ""
    exit 0
fi

# Parse available models — extract id AND name for each
# Output format: "id<TAB>name" per line (name falls back to id if absent)
PARSED=$(echo "$MODELS_JSON" | python3 <<'PYEOF'
import json, sys
try:
    data = json.load(sys.stdin)
except Exception as e:
    print(f"PARSE_ERROR:{e}", file=sys.stderr)
    sys.exit(1)

models = data.get('data', []) if isinstance(data, dict) else data
seen = set()
for m in (models or []):
    if isinstance(m, dict):
        mid = m.get('id') or m.get('model')
        if not mid:
            continue
        # Prefer the display name fields, fall back to the id
        name = m.get('name') or (m.get('info') or {}).get('name') or mid
    elif isinstance(m, str):
        mid = m
        name = m
    else:
        continue
    if mid in seen:
        continue
    seen.add(mid)
    print(f"{mid}\t{name}")
PYEOF
)

if [ -z "$PARSED" ]; then
    echo -e "${RED}Error:${NC} API returned no models (or unexpected format)."
    echo -e "${DIM}Tip: run with --debug to see the raw API response${NC}"
    exit 1
fi

# Parse into parallel arrays
declare -a MODEL_IDS=()
declare -a MODEL_NAMES=()
declare -a MODEL_STATE=()
while IFS=$'\t' read -r mid mname; do
    [ -z "$mid" ] && continue
    MODEL_IDS+=("$mid")
    MODEL_NAMES+=("$mname")
    if echo ",$CURRENT_CSV," | grep -q ",$mid,"; then
        MODEL_STATE+=("on")
    else
        MODEL_STATE+=("off")
    fi
done <<< "$PARSED"

TOTAL=${#MODEL_IDS[@]}
LOADED=0
for s in "${MODEL_STATE[@]}"; do [ "$s" = "on" ] && LOADED=$((LOADED+1)); done
echo -e "Found ${BOLD}$TOTAL${NC} model(s) — ${BOLD}$LOADED${NC} currently loaded"

print_menu() {
    echo ""
    echo -e "${BOLD}Available models:${NC}"
    for i in "${!MODEL_IDS[@]}"; do
        num=$((i+1))
        mid="${MODEL_IDS[$i]}"
        mname="${MODEL_NAMES[$i]}"
        # Show "id (name)" only when name differs from id
        if [ "$mid" = "$mname" ]; then
            label="$mid"
        else
            label="$mid  ${DIM}($mname)${NC}"
        fi
        if [ "${MODEL_STATE[$i]}" = "on" ]; then
            echo -e "  [${GREEN}✓${NC}] $num) $label"
        else
            echo -e "  [ ] $num) $label"
        fi
    done
    echo ""
    echo -e "${YELLOW}Legend:${NC} [${GREEN}✓${NC}] = loaded, [ ] = available"
}

# Interactive loop
while true; do
    print_menu
    echo ""
    echo -e "Enter numbers to toggle (e.g. '2,3,5'), 'a' to select all, 'n' to deselect all,"
    echo -ne "or press Enter to save: "
    read -r INPUT

    if [ -z "$INPUT" ]; then
        break
    fi

    if [ "$INPUT" = "a" ] || [ "$INPUT" = "A" ]; then
        for i in "${!MODEL_STATE[@]}"; do MODEL_STATE[$i]="on"; done
        continue
    fi
    if [ "$INPUT" = "n" ] || [ "$INPUT" = "N" ]; then
        for i in "${!MODEL_STATE[@]}"; do MODEL_STATE[$i]="off"; done
        continue
    fi

    IFS=',' read -ra PICKS <<< "$INPUT"
    for p in "${PICKS[@]}"; do
        p=$(echo "$p" | tr -d ' ')
        if [[ "$p" =~ ^[0-9]+$ ]]; then
            idx=$((p-1))
            if [ "$idx" -ge 0 ] && [ "$idx" -lt "${#MODEL_IDS[@]}" ]; then
                if [ "${MODEL_STATE[$idx]}" = "on" ]; then
                    MODEL_STATE[$idx]="off"
                else
                    MODEL_STATE[$idx]="on"
                fi
            fi
        fi
    done
done

# Write selected list + names to a temp file (safer than shell delimiters)
TMPSEL=$(mktemp)
for i in "${!MODEL_IDS[@]}"; do
    if [ "${MODEL_STATE[$i]}" = "on" ]; then
        printf '%s\t%s\n' "${MODEL_IDS[$i]}" "${MODEL_NAMES[$i]}" >> "$TMPSEL"
    fi
done

if [ ! -s "$TMPSEL" ]; then
    rm -f "$TMPSEL"
    echo -e "${YELLOW}Warning:${NC} No models selected. At least one model must be loaded."
    echo "No changes saved."
    exit 0
fi

# Update both config files (user config + build dir config)
python3 <<PYEOF
import json

selections = []
with open("$TMPSEL") as f:
    for line in f:
        parts = line.rstrip('\n').split('\t', 1)
        if parts and parts[0]:
            mid = parts[0]
            mname = parts[1] if len(parts) > 1 and parts[1] else mid
            selections.append((mid, mname))

provider_key = "$PROVIDER_KEY"

def update_config(path):
    try:
        with open(path) as f:
            config = json.load(f)
    except FileNotFoundError:
        return False

    if provider_key not in config.get('provider', {}):
        return False

    existing_models = config['provider'][provider_key].get('models') or {}
    new_models = {}

    for mid, mname in selections:
        if mid in existing_models:
            # Preserve existing config (temperature, max_tokens, custom name, etc.)
            new_models[mid] = existing_models[mid]
        else:
            # New model — use API's name as display label, sensible defaults
            new_models[mid] = {
                "name": mname,
                "tool_call": True,
                "attachment": True,
                "modalities": {"input": ["text", "image"], "output": ["text"]},
                "options": {"temperature": 0.7, "max_tokens": 16384}
            }

    config['provider'][provider_key]['models'] = new_models
    with open(path, 'w') as f:
        json.dump(config, f, indent=2)
    return True

update_config("$CONFIG_FILE")
update_config("$BUILD_CONFIG")
print(f"  Saved {len(selections)} model(s)")
PYEOF

rm -f "$TMPSEL"

echo ""
echo -e "${GREEN}✓${NC} Configuration updated."
echo ""
echo -e "${YELLOW}Restart the app${NC} for changes to take effect:"
echo "  1. Quit the app"
echo "  2. Relaunch from /Applications (macOS) or shortcut (Linux)"
echo ""
