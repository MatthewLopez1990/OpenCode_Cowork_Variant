#!/bin/bash
set -e

# ============================================================
#  OpenCode Cowork — Linux Installer
#  White-label AI assistant for any enterprise
#
#  This is a self-contained fork. The installer clones THIS repo,
#  builds the branded Electron desktop app, configures AI models,
#  and deploys sandbox rules.
# ============================================================

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

COWORK_REPO="https://github.com/MatthewLopez1990/OpenCode_Cowork_Variant.git"
COWORK_REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$HOME/.opencode-cowork-build"

echo ""
echo -e "${BLUE}${BOLD}+==========================================+${NC}"
echo -e "${BLUE}${BOLD}|  OpenCode Cowork - Enterprise Installer   |${NC}"
echo -e "${BLUE}${BOLD}|  White-label AI for your organization      |${NC}"
echo -e "${BLUE}${BOLD}+==========================================+${NC}"
echo ""

# -- Step 1: Organization Setup --
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
    echo -ne "${YELLOW}API base URL (e.g., 'https://api.yourcompany.com/api'): ${NC}"
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
echo -e "${GREEN}*${NC} Organization: $APP_NAME"
echo -e "${GREEN}*${NC} Provider: $PROVIDER_DISPLAY ($API_URL)"
echo -e "${GREEN}*${NC} Model: $DEFAULT_MODEL"

ICON_ASSET=""
LOGO_ASSET=""
[ -f "$COWORK_REPO_DIR/assets/icon.png" ] && ICON_ASSET="$COWORK_REPO_DIR/assets/icon.png"
[ -f "$COWORK_REPO_DIR/assets/logo.png" ] && LOGO_ASSET="$COWORK_REPO_DIR/assets/logo.png"

[ -n "$ICON_ASSET" ] && echo -e "${GREEN}*${NC} Icon: icon.png" || echo -e "  - No custom icon -- using defaults"
[ -n "$LOGO_ASSET" ] && echo -e "${GREEN}*${NC} Logo: logo.png" || echo -e "  - No custom logo -- using defaults"
echo ""

# -- Step 2: Prerequisites --
echo -e "${BOLD}Step 2: Installing prerequisites...${NC}"

# Git
if ! command -v git &>/dev/null; then
    echo -e "${YELLOW}Installing Git...${NC}"
    if command -v apt-get &>/dev/null; then sudo apt-get update -qq && sudo apt-get install -y -qq git
    elif command -v dnf &>/dev/null; then sudo dnf install -y git
    elif command -v pacman &>/dev/null; then sudo pacman -S --noconfirm git
    else echo -e "${RED}Install git first.${NC}"; exit 1; fi
fi
echo -e "${GREEN}*${NC} Git"

# Bun
if ! command -v bun &>/dev/null; then
    echo -e "${YELLOW}Installing Bun...${NC}"
    curl -fsSL https://bun.sh/install | bash
    export BUN_INSTALL="$HOME/.bun"
    export PATH="$BUN_INSTALL/bin:$PATH"
fi
echo -e "${GREEN}*${NC} Bun $(bun --version)"

# OpenCode CLI
if ! command -v opencode &>/dev/null; then
    echo -e "${YELLOW}Installing OpenCode CLI...${NC}"
    curl -fsSL https://opencode.ai/install | bash
    export PATH="$HOME/.opencode/bin:$PATH"
fi
echo -e "${GREEN}*${NC} OpenCode CLI"
echo ""

# -- Step 3: Clone, Brand, and Build --
echo -e "${BOLD}Step 3: Building $APP_NAME...${NC}"

if [ -d "$BUILD_DIR" ]; then
    cd "$BUILD_DIR" && git pull 2>/dev/null || true
else
    git clone --depth 1 "$COWORK_REPO" "$BUILD_DIR"
fi
cd "$BUILD_DIR"

# Copy Electron config
echo -e "  Applying Electron configuration..."
mkdir -p "$BUILD_DIR/electron"
cp "$COWORK_REPO_DIR/electron/main.cjs" "$BUILD_DIR/electron/main.cjs"
cp "$COWORK_REPO_DIR/electron-builder.json" "$BUILD_DIR/electron-builder.json"

# Patch package.json
echo -e "  Setting app name in package.json..."
python3 -c "
import json
with open('$BUILD_DIR/package.json') as f:
    pkg = json.load(f)
pkg['name'] = '$(echo "$APP_NAME" | tr '[:upper:]' '[:lower:]' | sed "s/[^a-z0-9]/-/g")'
pkg['productName'] = '$APP_NAME'
pkg['main'] = 'electron/main.cjs'
with open('$BUILD_DIR/package.json', 'w') as f:
    json.dump(pkg, f, indent=2)
"

# Branding
echo -e "  Applying branding..."
mkdir -p "$BUILD_DIR/branding"
mkdir -p "$BUILD_DIR/packages/desktop/src-tauri/icons"

if [ -n "$ICON_ASSET" ]; then
    cp "$ICON_ASSET" "$BUILD_DIR/branding/icon.png"
    cp "$ICON_ASSET" "$BUILD_DIR/packages/desktop/src-tauri/icons/icon.png"
    cp "$ICON_ASSET" "$BUILD_DIR/packages/web/public/cowork-icon.png"
    cp "$ICON_ASSET" "$BUILD_DIR/packages/web/public/favicon.png"
    echo -e "${GREEN}*${NC} Custom icon applied"
fi

if [ -n "$LOGO_ASSET" ]; then
    cp "$LOGO_ASSET" "$BUILD_DIR/packages/web/public/cowork-logo.png"
    echo -e "${GREEN}*${NC} Custom logo applied"
fi

# Patch index.html
INDEX_HTML="$BUILD_DIR/packages/web/index.html"
if [ -f "$INDEX_HTML" ]; then
    sed -i "s|<title>[^<]*</title>|<title>$APP_NAME</title>|g" "$INDEX_HTML" 2>/dev/null
    if [ -n "$LOGO_ASSET" ]; then
        sed -i 's|src="/logo-dark-512x512.svg"|src="/cowork-logo.png"|g' "$INDEX_HTML" 2>/dev/null
        sed -i 's|src="/logo-light-512x512.svg"|src="/cowork-logo.png"|g' "$INDEX_HTML" 2>/dev/null
        sed -i 's|src="[^"]*logo[^"]*\.svg"|src="/cowork-logo.png"|g' "$INDEX_HTML" 2>/dev/null
    fi
    sed -i "s|content=\"OpenCode Cowork\"|content=\"$APP_NAME\"|g" "$INDEX_HTML" 2>/dev/null
    sed -i "s|content=\"OpenChamber[^\"]*\"|content=\"$APP_NAME\"|g" "$INDEX_HTML" 2>/dev/null
    sed -i "s|alt=\"Loading\"|alt=\"$APP_NAME\"|g" "$INDEX_HTML" 2>/dev/null
    sed -i "s|const defaultAppName = '[^']*'|const defaultAppName = '$APP_NAME'|g" "$INDEX_HTML" 2>/dev/null
    sed -i "s|const defaultShortName = '[^']*'|const defaultShortName = '$APP_NAME'|g" "$INDEX_HTML" 2>/dev/null
fi

# Patch React useWindowTitle hook
WINDOW_TITLE_TS="$BUILD_DIR/packages/ui/src/hooks/useWindowTitle.ts"
if [ -f "$WINDOW_TITLE_TS" ]; then
    sed -i "s|const APP_TITLE = '[^']*'|const APP_TITLE = '$APP_NAME'|g" "$WINDOW_TITLE_TS" 2>/dev/null
    echo -e "${GREEN}✓${NC} Window title patched"
fi

# Update electron-builder
python3 -c "
import json
with open('$BUILD_DIR/electron-builder.json') as f:
    eb = json.load(f)
eb['appId'] = 'com.cowork.$(echo "$PROVIDER_NAME")'
eb['productName'] = '$APP_NAME'
with open('$BUILD_DIR/electron-builder.json', 'w') as f:
    json.dump(eb, f, indent=2)
"

# Inject sandbox rules
SERVER_JS="$BUILD_DIR/packages/web/server/index.js"
if [ -f "$SERVER_JS" ] && ! grep -q "ensureSandboxRules" "$SERVER_JS"; then
    cp "$COWORK_REPO_DIR/CLAUDE.md" "$BUILD_DIR/packages/web/server/CLAUDE_TEMPLATE.md" 2>/dev/null

    python3 - "$SERVER_JS" << 'PYEOF'
import sys

server_path = sys.argv[1]
with open(server_path, "r") as f:
    content = f.read()

sandbox_code = """
// OpenCode Cowork: Auto-inject CLAUDE.md sandbox rules
const __cowork_path = require('path');
const __cowork_fs = require('fs');
function ensureSandboxRules(directory) {
  if (!directory) return;
  const claudePath = __cowork_path.join(directory, 'CLAUDE.md');
  try {
    const templatePath = __cowork_path.join(__dirname, 'CLAUDE_TEMPLATE.md');
    let rules = '';
    if (__cowork_fs.existsSync(templatePath)) { rules = __cowork_fs.readFileSync(templatePath, 'utf8'); }
    if (!rules) return;
    __cowork_fs.writeFileSync(claudePath, rules, 'utf8');
    if (process.platform === 'win32') { try { require('child_process').execSync('attrib +H +S "' + claudePath + '"', { stdio: 'ignore', timeout: 5000 }); } catch (e) {} }
  } catch (e) {}
}
"""
content += sandbox_code
with open(server_path, "w") as f:
    f.write(content)
print("Sandbox rules injected into server")
PYEOF
    echo -e "${GREEN}*${NC} Sandbox injection ready"
fi

# Save branding
echo "{\"appName\":\"$APP_NAME\",\"provider\":\"$PROVIDER_DISPLAY\"}" > "$HOME/.cowork-branding.json"

# Install and build
echo -e "  Adding Electron dependencies..."
bun add --dev electron@latest electron-builder@24.13.3 electron-store@latest electron-context-menu@latest 2>&1 | tail -1

echo -e "  Installing dependencies..."
bun install 2>&1 | tail -1

echo -e "  Building frontend..."
bun run build:web 2>&1 | tail -3
echo -e "${GREEN}*${NC} Frontend built"

# Build Electron
echo -e "  Packaging desktop app..."
[ ! -f "$BUILD_DIR/packages/web/public/cowork-icon.png" ] && [ -f "$BUILD_DIR/branding/icon.png" ] && cp "$BUILD_DIR/branding/icon.png" "$BUILD_DIR/packages/web/public/cowork-icon.png"
[ ! -f "$BUILD_DIR/packages/web/public/cowork-icon.png" ] && touch "$BUILD_DIR/packages/web/public/cowork-icon.png"
[ ! -f "$BUILD_DIR/branding/icon.png" ] && touch "$BUILD_DIR/branding/icon.png"
bunx electron-builder --config electron-builder.json --linux AppImage 2>&1 | grep -E "(packaging|building|target=)" || true

APPIMAGE=$(find "$BUILD_DIR/electron-dist" -name "*.AppImage" 2>/dev/null | head -1)
UNPACKED=$(find "$BUILD_DIR/electron-dist" -maxdepth 1 -name "linux-unpacked" -type d 2>/dev/null | head -1)

APP_BIN_NAME=$(echo "$APP_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/ /-/g')

if [ -n "$APPIMAGE" ]; then
    mkdir -p "$HOME/.local/bin"
    cp "$APPIMAGE" "$HOME/.local/bin/$APP_BIN_NAME"
    chmod +x "$HOME/.local/bin/$APP_BIN_NAME"
    echo -e "${GREEN}*${NC} $APP_NAME AppImage installed to ~/.local/bin/$APP_BIN_NAME"
elif [ -d "$UNPACKED" ]; then
    INSTALL_DIR="$HOME/.local/share/$APP_BIN_NAME"
    rm -rf "$INSTALL_DIR" 2>/dev/null
    cp -R "$UNPACKED" "$INSTALL_DIR"
    chmod +x "$INSTALL_DIR/$APP_BIN_NAME" 2>/dev/null || true
    mkdir -p "$HOME/.local/bin"
    ln -sf "$INSTALL_DIR/$APP_BIN_NAME" "$HOME/.local/bin/$APP_BIN_NAME"
    echo -e "${GREEN}*${NC} $APP_NAME installed to $INSTALL_DIR"
else
    echo -e "${YELLOW}Desktop build failed. You can use: opencode web${NC}"
fi

# Desktop entry
ICON_DEST="$HOME/.local/share/icons/$APP_BIN_NAME.png"
if [ -n "$ICON_ASSET" ]; then
    mkdir -p "$HOME/.local/share/icons"
    cp "$ICON_ASSET" "$ICON_DEST"
fi

mkdir -p "$HOME/.local/share/applications"
cat > "$HOME/.local/share/applications/$APP_BIN_NAME.desktop" << DEOF
[Desktop Entry]
Name=$APP_NAME
Comment=$APP_NAME - AI Assistant
Exec=$HOME/.local/bin/$APP_BIN_NAME
Icon=$ICON_DEST
Type=Application
Categories=Office;
Terminal=false
DEOF
echo -e "${GREEN}*${NC} Desktop entry created"
echo ""

# -- Step 4: Configure AI --
echo -e "${BOLD}Step 4: Configuring AI models...${NC}"

OPENCODE_CONFIG_DIR="$HOME/.config/opencode"
mkdir -p "$OPENCODE_CONFIG_DIR"

TEMPLATE="$COWORK_REPO_DIR/config/opencode.json.template"
if [ -f "$TEMPLATE" ]; then
    sed "s|__API_KEY__|$API_KEY|g; s|__API_URL__|$API_URL|g; s|__PROVIDER_NAME__|$PROVIDER_NAME|g; s|__DISPLAY_NAME__|$PROVIDER_DISPLAY|g; s|__DEFAULT_MODEL__|$DEFAULT_MODEL|g; s|__DEFAULT_MODEL_DISPLAY__|$DEFAULT_MODEL_DISPLAY|g" "$TEMPLATE" > "$OPENCODE_CONFIG_DIR/opencode.json"
fi
echo -e "${GREEN}*${NC} AI models configured (default: $DEFAULT_MODEL)"

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
if [ -d "$OPENCODE_CONFIG_DIR/node_modules/@ai-sdk" ]; then
    echo -e " ${GREEN}*${NC}"
else
    echo -e " ${YELLOW}(will retry on first launch)${NC}"
fi

# Commands (legal + finance)
mkdir -p "$OPENCODE_CONFIG_DIR/commands"
for CMD_TYPE in legal finance; do
    CMDS_SRC="$COWORK_REPO_DIR/commands/$CMD_TYPE"
    if [ -d "$CMDS_SRC" ]; then
        rm -rf "$OPENCODE_CONFIG_DIR/commands/$CMD_TYPE" 2>/dev/null
        cp -r "$CMDS_SRC" "$OPENCODE_CONFIG_DIR/commands/$CMD_TYPE"
        SKILL_COUNT=$(find "$OPENCODE_CONFIG_DIR/commands/$CMD_TYPE" -name "SKILL.md" 2>/dev/null | wc -l | tr -d ' ')
        echo -e "${GREEN}*${NC} $SKILL_COUNT $CMD_TYPE skills installed"
    fi
done

# Agent rules
[ -f "$COWORK_REPO_DIR/opencode.md" ] && cp "$COWORK_REPO_DIR/opencode.md" "$OPENCODE_CONFIG_DIR/opencode.md"

# Default project with CLAUDE.md
DEFAULT_PROJECT="$HOME/$APP_NAME Projects"
mkdir -p "$DEFAULT_PROJECT"
CLAUDE_SRC="$COWORK_REPO_DIR/CLAUDE.md"
if [ -f "$CLAUDE_SRC" ]; then
    cp "$CLAUDE_SRC" "$DEFAULT_PROJECT/CLAUDE.md"
    echo -e "${GREEN}*${NC} Sandbox rules deployed"
fi
mkdir -p "$OPENCODE_CONFIG_DIR/sandbox"
cp "$CLAUDE_SRC" "$OPENCODE_CONFIG_DIR/sandbox/CLAUDE.md.template" 2>/dev/null

echo -e "${GREEN}*${NC} Default project: $DEFAULT_PROJECT"

# Settings
for DIR in "$HOME/.config/sf-steward" "$HOME/.config/openchamber"; do
    mkdir -p "$DIR"
    echo "{\"defaultModel\":\"${PROVIDER_NAME}:${DEFAULT_MODEL}\"}" > "$DIR/settings.json"
done

SHELL_PROFILE="$HOME/.bashrc"
[ -f "$HOME/.zshrc" ] && SHELL_PROFILE="$HOME/.zshrc"
if [ -f "$SHELL_PROFILE" ]; then
    grep -v "COWORK_API_KEY" "$SHELL_PROFILE" > "${SHELL_PROFILE}.tmp" 2>/dev/null || true
    mv "${SHELL_PROFILE}.tmp" "$SHELL_PROFILE"
    echo "export COWORK_API_KEY=\"$API_KEY\"" >> "$SHELL_PROFILE"
    [[ ":$PATH:" != *":$HOME/.local/bin:"* ]] && echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$SHELL_PROFILE"
    [[ ":$PATH:" != *":$HOME/.bun/bin:"* ]] && echo 'export PATH="$HOME/.bun/bin:$PATH"' >> "$SHELL_PROFILE"
fi

echo ""
echo -e "${BLUE}${BOLD}+==========================================+${NC}"
echo -e "${BLUE}${BOLD}|         Installation Complete!            |${NC}"
echo -e "${BLUE}${BOLD}+==========================================+${NC}"
echo ""
echo -e "  ${GREEN}*${NC} $APP_NAME desktop app"
echo -e "  ${GREEN}*${NC} AI models (default: $DEFAULT_MODEL)"
echo -e "  ${GREEN}*${NC} oh-my-opencode plugin"
echo -e "  ${GREEN}*${NC} Legal + Finance commands"
echo -e "  ${GREEN}*${NC} Directory sandbox"
echo ""
echo -e "  Default project: $DEFAULT_PROJECT"
echo ""
echo -ne "Launch now? (y/n): "
read -r LAUNCH
if [[ "$LAUNCH" =~ ^[Yy] ]]; then
    nohup "$HOME/.local/bin/$APP_BIN_NAME" > /dev/null 2>&1 &
    disown
    echo -e "  ${GREEN}$APP_NAME is running. You can close this terminal.${NC}"
fi
