#!/bin/bash
# ============================================================
#  OpenCode Cowork — macOS Uninstaller
#  Removes the app, configuration, and all artifacts.
#  Does NOT remove Bun, Git, or your project files.
# ============================================================

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'

APP_NAME="OpenCode Cowork"
BRANDING_FILE="$HOME/.cowork-branding.json"
[ -f "$BRANDING_FILE" ] && APP_NAME=$(python3 -c "import json; print(json.load(open('$BRANDING_FILE')).get('appName','OpenCode Cowork'))" 2>/dev/null) || true

echo ""
echo -e "${RED}╔══════════════════════════════════════════╗${NC}"
echo -e "${RED}║       $APP_NAME — Uninstaller              ║${NC}"
echo -e "${RED}╚══════════════════════════════════════════╝${NC}"
echo ""

echo -e "${YELLOW}This will remove:${NC}"
echo "  - $APP_NAME desktop app (/Applications)"
echo "  - Build directory (~/.opencode-cowork-build)"
echo "  - OpenCode CLI (~/.opencode)"
echo "  - Configuration (~/.config/opencode, sf-steward, openchamber)"
echo "  - COWORK_API_KEY from shell profile"
echo ""
echo -e "${YELLOW}This will NOT remove:${NC}"
echo "  - Bun or Git"
echo "  - Your project files"
echo ""
echo -ne "Proceed with uninstall? (y/n): "
read -r CONFIRM
[[ ! "$CONFIRM" =~ ^[Yy] ]] && echo "Cancelled." && exit 0
echo ""

# Step 1: Stop processes
echo -e "Step 1: Stopping processes..."
pkill -f "$APP_NAME" 2>/dev/null
pkill -f opencode 2>/dev/null
sleep 2
echo -e "${GREEN}✓${NC} Processes stopped"

# Step 2: Remove app
echo -e "Step 2: Removing desktop app..."
if [ -d "/Applications/$APP_NAME.app" ]; then
    rm -rf "/Applications/$APP_NAME.app"
    echo -e "${GREEN}✓${NC} Removed /Applications/$APP_NAME.app"
else
    echo -e "  - /Applications/$APP_NAME.app (not found)"
fi

# Step 3: Remove OpenCode CLI
echo -e "Step 3: Removing OpenCode CLI..."
if [ -d "$HOME/.opencode" ]; then
    rm -rf "$HOME/.opencode"
    echo -e "${GREEN}✓${NC} Removed ~/.opencode"
else
    echo -e "  - ~/.opencode (not found)"
fi

# Step 4: Remove build directory
echo -e "Step 4: Removing build directory..."
if [ -d "$HOME/.opencode-cowork-build" ]; then
    rm -rf "$HOME/.opencode-cowork-build"
    echo -e "${GREEN}✓${NC} Removed ~/.opencode-cowork-build"
else
    echo -e "  - ~/.opencode-cowork-build (not found)"
fi

# Step 5: Remove configuration
echo -e "Step 5: Removing configuration..."
for DIR in "$HOME/.config/opencode" "$HOME/.config/sf-steward" "$HOME/.config/sf-steward-code" "$HOME/.config/openchamber"; do
    if [ -d "$DIR" ]; then
        rm -rf "$DIR"
        echo -e "${GREEN}✓${NC} Removed $DIR"
    fi
done

# Remove branding and home-level config
rm -f "$HOME/.cowork-branding.json" 2>/dev/null
rm -f "$HOME/.opencode.json" 2>/dev/null

# Clear macOS icon cache
sudo rm -rf /Library/Caches/com.apple.iconservices.store 2>/dev/null || true
killall Dock 2>/dev/null || true
echo -e "${GREEN}✓${NC} Icon cache cleared"

# Step 6: Remove API key from shell profile
echo -e "Step 6: Cleaning shell profile..."
SHELL_PROFILE="$HOME/.zshrc"
[ ! -f "$SHELL_PROFILE" ] && SHELL_PROFILE="$HOME/.bashrc"
if [ -f "$SHELL_PROFILE" ]; then
    if grep -q "COWORK_API_KEY" "$SHELL_PROFILE" 2>/dev/null; then
        grep -v "COWORK_API_KEY" "$SHELL_PROFILE" > "${SHELL_PROFILE}.tmp"
        mv "${SHELL_PROFILE}.tmp" "$SHELL_PROFILE"
        echo -e "${GREEN}✓${NC} Removed COWORK_API_KEY from $SHELL_PROFILE"
    fi
fi

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║          Uninstall Complete                ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
echo ""
echo -e "  $APP_NAME has been removed from this machine."
echo -e "  Your project files were not touched."
echo ""
