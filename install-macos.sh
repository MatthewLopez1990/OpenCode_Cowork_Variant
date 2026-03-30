#!/bin/bash
set -e

# ============================================================
#  OpenCode Cowork — macOS Installer
#  White-label AI assistant for any enterprise
#
#  Prompts for: App name, API URL, API key, logos
#  Installs: Bun, OpenCode CLI, branded desktop app
#  Configures: AI models, oh-my-opencode plugin,
#              legal + finance commands, directory sandbox
# ============================================================

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

OPENCHAMBER_REPO="https://github.com/openchamber/openchamber.git"
COWORK_REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$HOME/.opencode-cowork-build"

echo ""
echo -e "${BLUE}${BOLD}╔══════════════════════════════════════════╗${NC}"
echo -e "${BLUE}${BOLD}║  OpenCode Cowork — Enterprise Installer   ║${NC}"
echo -e "${BLUE}${BOLD}║  White-label AI for your organization      ║${NC}"
echo -e "${BLUE}${BOLD}╚══════════════════════════════════════════╝${NC}"
echo ""

# Step 1: Branding
echo -e "${BOLD}Step 1: Organization Setup${NC}"
echo ""

APP_NAME=""
while [ -z "$APP_NAME" ]; do
    echo -ne "${YELLOW}App name (e.g., 'Acme AI Assistant'): ${NC}"
    read -r APP_NAME
    [ -z "$APP_NAME" ] && echo -e "${RED}Required.${NC}"
done

PROVIDER_DISPLAY=""
while [ -z "$PROVIDER_DISPLAY" ]; do
    echo -ne "${YELLOW}Provider display name (e.g., 'Acme AI'): ${NC}"
    read -r PROVIDER_DISPLAY
    [ -z "$PROVIDER_DISPLAY" ] && echo -e "${RED}Required.${NC}"
done
PROVIDER_NAME=$(echo "$PROVIDER_DISPLAY" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//;s/-$//')

API_URL=""
while [ -z "$API_URL" ]; do
    echo -ne "${YELLOW}API base URL (e.g., 'https://api.yourcompany.com/v1'): ${NC}"
    read -r API_URL
    [ -z "$API_URL" ] && echo -e "${RED}Required.${NC}"
done

API_KEY=""
while [ -z "$API_KEY" ]; do
    echo -ne "${YELLOW}API key: ${NC}"
    read -r API_KEY
    [ -z "$API_KEY" ] && echo -e "${RED}Required.${NC}"
done

echo -ne "Default model ID (Enter for 'gpt-4o'): "
read -r DEFAULT_MODEL
[ -z "$DEFAULT_MODEL" ] && DEFAULT_MODEL="gpt-4o"
echo -ne "Default model display name (Enter for '$DEFAULT_MODEL'): "
read -r DEFAULT_MODEL_DISPLAY
[ -z "$DEFAULT_MODEL_DISPLAY" ] && DEFAULT_MODEL_DISPLAY="$DEFAULT_MODEL"

echo ""
echo -e "Logo URLs (optional — press Enter to skip):"
echo -ne "Small logo URL (favicon/icon): "
read -r SMALL_LOGO_URL
echo -ne "Large logo URL (landing page): "
read -r LARGE_LOGO_URL

echo -e "${GREEN}✓${NC} Organization: $APP_NAME"
echo -e "${GREEN}✓${NC} Provider: $PROVIDER_DISPLAY ($API_URL)"
echo -e "${GREEN}✓${NC} Model: $DEFAULT_MODEL"
echo ""

# Step 2: Prerequisites
echo -e "${BOLD}Step 2: Installing prerequisites...${NC}"

if ! command -v bun &>/dev/null; then
    curl -fsSL https://bun.sh/install | bash
    export BUN_INSTALL="$HOME/.bun"
    export PATH="$BUN_INSTALL/bin:$PATH"
fi
echo -e "${GREEN}✓${NC} Bun $(bun --version)"

if ! command -v opencode &>/dev/null; then
    curl -fsSL https://opencode.ai/install | bash
    export PATH="$HOME/.opencode/bin:$PATH"
fi
echo -e "${GREEN}✓${NC} OpenCode CLI"
echo ""

# Step 3: Clone and build
echo -e "${BOLD}Step 3: Building $APP_NAME...${NC}"

if [ -d "$BUILD_DIR" ]; then
    cd "$BUILD_DIR" && git pull 2>/dev/null || true
else
    git clone --depth 1 "$OPENCHAMBER_REPO" "$BUILD_DIR"
fi
cd "$BUILD_DIR"

# Copy electron config from Cowork repo into the cloned OpenChamber
mkdir -p "$BUILD_DIR/electron"
[ -f "$COWORK_REPO_DIR/electron/main.cjs" ] && cp "$COWORK_REPO_DIR/electron/main.cjs" "$BUILD_DIR/electron/main.cjs"
[ -f "$COWORK_REPO_DIR/electron-builder.json" ] && cp "$COWORK_REPO_DIR/electron-builder.json" "$BUILD_DIR/electron-builder.json"

# Set app name in package.json
if [ -f "$BUILD_DIR/package.json" ]; then
    python3 -c "
import json
with open('$BUILD_DIR/package.json') as f:
    pkg = json.load(f)
pkg['name'] = '$(echo "$APP_NAME" | tr '[:upper:]' '[:lower:]' | sed "s/[^a-z0-9]/-/g")'
pkg['productName'] = '$APP_NAME'
pkg['main'] = 'electron/main.cjs'
with open('$BUILD_DIR/package.json', 'w') as f:
    json.dump(pkg, f, indent=2)
" 2>/dev/null
fi

# Save branding
echo "{\"appName\":\"$APP_NAME\",\"provider\":\"$PROVIDER_DISPLAY\"}" > "$HOME/.cowork-branding.json"

# Download logos
if [ -n "$SMALL_LOGO_URL" ]; then
    mkdir -p "$BUILD_DIR/branding"
    curl -fsSL "$SMALL_LOGO_URL" -o "$BUILD_DIR/branding/icon.png" 2>/dev/null && echo -e "${GREEN}✓${NC} Small logo applied" || echo -e "${YELLOW}!${NC} Could not download small logo"
fi
if [ -n "$LARGE_LOGO_URL" ]; then
    curl -fsSL "$LARGE_LOGO_URL" -o "$BUILD_DIR/packages/web/public/logo.png" 2>/dev/null && echo -e "${GREEN}✓${NC} Large logo applied" || echo -e "${YELLOW}!${NC} Could not download large logo"
fi

# Update HTML title
INDEX_HTML="$BUILD_DIR/packages/web/index.html"
[ -f "$INDEX_HTML" ] && sed -i '' "s|<title>[^<]*</title>|<title>$APP_NAME</title>|" "$INDEX_HTML" 2>/dev/null

echo -e "Installing dependencies..."
bun install 2>&1 | tail -1
echo -e "Building frontend..."
bun run build:web 2>&1 | tail -3
echo -e "${GREEN}✓${NC} Frontend built"

# Build native app
echo -e "Packaging desktop app..."
bunx electron-builder --config electron-builder.json --mac 2>&1 | grep -E "(Bundling|building|signing|Finished|target=)" || true

BUILT_APP=$(find "$BUILD_DIR/electron-dist" -name "*.app" -maxdepth 3 | head -1)
if [ -n "$BUILT_APP" ] && [ -d "$BUILT_APP" ]; then
    [ -d "/Applications/$APP_NAME.app" ] && rm -rf "/Applications/$APP_NAME.app"
    cp -R "$BUILT_APP" "/Applications/$APP_NAME.app"
    echo -e "${GREEN}✓${NC} $APP_NAME.app installed to /Applications"
else
    echo -e "${YELLOW}!${NC} Desktop build failed. You can still use: opencode web"
fi
echo ""

# Step 4: Configure
echo -e "${BOLD}Step 4: Configuring AI models...${NC}"

OPENCODE_CONFIG_DIR="$HOME/.config/opencode"
mkdir -p "$OPENCODE_CONFIG_DIR"

TEMPLATE="$COWORK_REPO_DIR/config/opencode.json.template"
if [ -f "$TEMPLATE" ]; then
    sed "s|__API_KEY__|$API_KEY|g; s|__API_URL__|$API_URL|g; s|__PROVIDER_NAME__|$PROVIDER_NAME|g; s|__DISPLAY_NAME__|$PROVIDER_DISPLAY|g; s|__DEFAULT_MODEL__|$DEFAULT_MODEL|g; s|__DEFAULT_MODEL_DISPLAY__|$DEFAULT_MODEL_DISPLAY|g" "$TEMPLATE" > "$OPENCODE_CONFIG_DIR/opencode.json"
fi
echo -e "${GREEN}✓${NC} AI models configured (default: $DEFAULT_MODEL)"

# npm provider SDK
cat > "$OPENCODE_CONFIG_DIR/package.json" << 'PKGJSON'
{
  "dependencies": {
    "@ai-sdk/openai-compatible": "latest",
    "@opencode-ai/plugin": "1.2.27"
  }
}
PKGJSON
echo -ne "  Installing AI provider SDK..."
(cd "$OPENCODE_CONFIG_DIR" && bun install 2>/dev/null) || (cd "$OPENCODE_CONFIG_DIR" && npm install --silent 2>/dev/null) || true
echo -e " ${GREEN}✓${NC}"

# Commands (legal + finance) — Anthropic plugins use SKILL.md in subdirectories
for CMD_TYPE in legal finance; do
    CMDS_SRC="$COWORK_REPO_DIR/commands/$CMD_TYPE"
    if [ -d "$CMDS_SRC" ]; then
        CMDS_DEST="$OPENCODE_CONFIG_DIR/commands/$CMD_TYPE"
        cp -r "$CMDS_SRC" "$OPENCODE_CONFIG_DIR/commands/" 2>/dev/null
        SKILL_COUNT=$(find "$CMDS_DEST" -name "SKILL.md" 2>/dev/null | wc -l | tr -d ' ')
        echo -e "${GREEN}✓${NC} $SKILL_COUNT $CMD_TYPE skills installed"
    fi
done

# Agent rules
[ -f "$COWORK_REPO_DIR/opencode.md" ] && cp "$COWORK_REPO_DIR/opencode.md" "$OPENCODE_CONFIG_DIR/opencode.md"

# Default project with CLAUDE.md from the repo
DEFAULT_PROJECT="$HOME/$APP_NAME Projects"
mkdir -p "$DEFAULT_PROJECT"
CLAUDE_SRC="$COWORK_REPO_DIR/CLAUDE.md"
if [ -f "$CLAUDE_SRC" ]; then
    cp "$CLAUDE_SRC" "$DEFAULT_PROJECT/CLAUDE.md"
    echo -e "${GREEN}✓${NC} Sandbox rules deployed from CLAUDE.md"
fi
# Save template for web server auto-injection into new directories
mkdir -p "$OPENCODE_CONFIG_DIR/sandbox"
cp "$CLAUDE_SRC" "$OPENCODE_CONFIG_DIR/sandbox/CLAUDE.md.template" 2>/dev/null
echo -e "${GREEN}✓${NC} Default project directory: $DEFAULT_PROJECT"

# Settings
for DIR in "$HOME/.config/sf-steward" "$HOME/.config/openchamber"; do
    mkdir -p "$DIR"
    echo "{\"defaultModel\":\"${PROVIDER_NAME}:${DEFAULT_MODEL}\"}" > "$DIR/settings.json"
done

SHELL_PROFILE="$HOME/.zshrc"
[ ! -f "$SHELL_PROFILE" ] && SHELL_PROFILE="$HOME/.bashrc"
if [ -f "$SHELL_PROFILE" ]; then
    grep -v "COWORK_API_KEY" "$SHELL_PROFILE" > "${SHELL_PROFILE}.tmp" 2>/dev/null || true
    mv "${SHELL_PROFILE}.tmp" "$SHELL_PROFILE"
    echo "export COWORK_API_KEY=\"$API_KEY\"" >> "$SHELL_PROFILE"
fi

echo ""
echo -e "${BLUE}${BOLD}╔══════════════════════════════════════════╗${NC}"
echo -e "${BLUE}${BOLD}║         Installation Complete!            ║${NC}"
echo -e "${BLUE}${BOLD}╚══════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${GREEN}✓${NC} $APP_NAME desktop app"
echo -e "  ${GREEN}✓${NC} AI models (default: $DEFAULT_MODEL)"
echo -e "  ${GREEN}✓${NC} oh-my-opencode plugin"
echo -e "  ${GREEN}✓${NC} Legal + Finance commands"
echo -e "  ${GREEN}✓${NC} Directory sandbox"
echo ""
echo -e "  Default project: $DEFAULT_PROJECT"
echo ""
echo -ne "Launch now? (y/n): "
read -r LAUNCH
if [[ "$LAUNCH" =~ ^[Yy] ]]; then
    open "/Applications/$APP_NAME.app" 2>/dev/null || echo -e "  Run: opencode web"
fi
