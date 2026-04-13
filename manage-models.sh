#!/bin/bash
# ============================================================
#  OpenCode Cowork — Model Manager (macOS / Linux)
#
#  Discovers all models from your configured provider's API and
#  lets you pick which ones to load into the app. Only loaded
#  models appear in the chat selector.
#
#  Usage:  ./manage-models.sh
# ============================================================

set -e

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

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

# Extract provider info
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
MODELS_JSON=$(curl -s -f -H "Authorization: Bearer $API_KEY" "$BASE_URL/models" 2>/dev/null || echo "")
if [ -z "$MODELS_JSON" ]; then
    MODELS_JSON=$(curl -s -f -H "Authorization: Bearer $API_KEY" "$BASE_URL/v1/models" 2>/dev/null || echo "")
fi

if [ -z "$MODELS_JSON" ]; then
    echo -e "${RED}Error:${NC} Could not fetch models from the API."
    echo "  Tried: $BASE_URL/models and $BASE_URL/v1/models"
    echo "  Check that your API key is valid and the endpoint supports GET /models."
    exit 1
fi

# Parse available model IDs and build interactive list
AVAILABLE=$(echo "$MODELS_JSON" | python3 <<'PYEOF'
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(1)
models = data.get('data', []) if isinstance(data, dict) else data
ids = []
for m in (models or []):
    if isinstance(m, dict):
        mid = m.get('id') or m.get('name')
        if mid:
            ids.append(mid)
    elif isinstance(m, str):
        ids.append(m)
for mid in sorted(set(ids)):
    print(mid)
PYEOF
)

if [ -z "$AVAILABLE" ]; then
    echo -e "${RED}Error:${NC} API returned no models (or unexpected format)."
    exit 1
fi

# Build list with current status
declare -a MODEL_IDS=()
declare -a MODEL_STATE=()
while IFS= read -r mid; do
    MODEL_IDS+=("$mid")
    if echo ",$CURRENT_CSV," | grep -q ",$mid,"; then
        MODEL_STATE+=("on")
    else
        MODEL_STATE+=("off")
    fi
done <<< "$AVAILABLE"

print_menu() {
    echo ""
    echo -e "${BOLD}Available models:${NC}"
    for i in "${!MODEL_IDS[@]}"; do
        num=$((i+1))
        if [ "${MODEL_STATE[$i]}" = "on" ]; then
            echo -e "  [${GREEN}✓${NC}] $num) ${MODEL_IDS[$i]}"
        else
            echo -e "  [ ] $num) ${MODEL_IDS[$i]}"
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

# Build comma-separated list of selected model IDs
SELECTED=""
for i in "${!MODEL_IDS[@]}"; do
    if [ "${MODEL_STATE[$i]}" = "on" ]; then
        SELECTED="${SELECTED}${MODEL_IDS[$i]},"
    fi
done
SELECTED=$(echo "$SELECTED" | sed 's/,$//')

if [ -z "$SELECTED" ]; then
    echo -e "${YELLOW}Warning:${NC} No models selected. At least one model must be loaded."
    echo "No changes saved."
    exit 0
fi

# Write changes to both config locations
python3 <<PYEOF
import json

selected_ids = "$SELECTED".split(",") if "$SELECTED" else []
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

    for mid in selected_ids:
        if mid in existing_models:
            # Preserve existing config (temperature, max_tokens, custom name, etc.)
            new_models[mid] = existing_models[mid]
        else:
            # New model — sensible defaults
            new_models[mid] = {
                "name": mid,
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
print("  Saved " + str(len(selected_ids)) + " model(s)")
PYEOF

echo ""
echo -e "${GREEN}✓${NC} Configuration updated."
echo ""
echo -e "${YELLOW}Restart the app${NC} for changes to take effect:"
echo "  1. Quit the app"
echo "  2. Relaunch from /Applications (macOS) or shortcut (Linux)"
echo ""
