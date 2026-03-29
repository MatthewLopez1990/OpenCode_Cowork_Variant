#!/bin/bash
# ============================================================
#  OpenCode Cowork — Linux Uninstaller
# ============================================================

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'

APP_NAME="OpenCode Cowork"
BRANDING_FILE="$HOME/.cowork-branding.json"
[ -f "$BRANDING_FILE" ] && APP_NAME=$(python3 -c "import json; print(json.load(open('$BRANDING_FILE')).get('appName','OpenCode Cowork'))" 2>/dev/null || echo "$APP_NAME")
APP_CMD=$(echo "$APP_NAME" | tr ' ' '-' | tr '[:upper:]' '[:lower:]')

echo ""
echo -e "${RED}$APP_NAME — Uninstaller${NC}"
echo ""
echo -e "${YELLOW}This will remove $APP_NAME. Project files will NOT be touched.${NC}"
echo -ne "Proceed? (y/n): "
read -r CONFIRM
[[ ! "$CONFIRM" =~ ^[Yy] ]] && echo "Cancelled." && exit 0

echo ""

pkill -f "$APP_NAME" 2>/dev/null; pkill -f opencode 2>/dev/null
sleep 2
echo -e "${GREEN}✓${NC} Processes stopped"

# Remove binary
[ -f "$HOME/.local/bin/$APP_CMD" ] && rm -f "$HOME/.local/bin/$APP_CMD" && echo -e "${GREEN}✓${NC} Removed binary"

# Remove desktop entry
[ -f "$HOME/.local/share/applications/$APP_CMD.desktop" ] && rm -f "$HOME/.local/share/applications/$APP_CMD.desktop" && echo -e "${GREEN}✓${NC} Removed desktop entry"

# Remove build
[ -d "$HOME/.opencode-cowork-build" ] && rm -rf "$HOME/.opencode-cowork-build" && echo -e "${GREEN}✓${NC} Removed build directory"

# Remove config
for DIR in "$HOME/.config/opencode" "$HOME/.config/sf-steward" "$HOME/.config/openchamber"; do
    [ -d "$DIR" ] && rm -rf "$DIR" && echo -e "${GREEN}✓${NC} Removed $DIR"
done

rm -f "$HOME/.cowork-branding.json"

SHELL_PROFILE="$HOME/.bashrc"
[ -f "$HOME/.zshrc" ] && SHELL_PROFILE="$HOME/.zshrc"
[ -f "$SHELL_PROFILE" ] && grep -v "COWORK_API_KEY" "$SHELL_PROFILE" > "${SHELL_PROFILE}.tmp" && mv "${SHELL_PROFILE}.tmp" "$SHELL_PROFILE"

echo ""
echo -e "${GREEN}✓ $APP_NAME has been removed. Project files untouched.${NC}"
echo ""
