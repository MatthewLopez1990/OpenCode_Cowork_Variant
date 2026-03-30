#!/bin/bash
set -e

# ============================================================
#  OpenCode Cowork — macOS Installer
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

# Check for branding assets (case-insensitive)
ICON_ASSET=""
LOGO_ASSET=""
for f in "$COWORK_REPO_DIR/assets/"[Ii][Cc][Oo][Nn].[Pp][Nn][Gg]; do
    [ -f "$f" ] && ICON_ASSET="$f" && break
done
for f in "$COWORK_REPO_DIR/assets/"[Ll][Oo][Gg][Oo].[Pp][Nn][Gg]; do
    [ -f "$f" ] && LOGO_ASSET="$f" && break
done

[ -n "$ICON_ASSET" ] && echo -e "${GREEN}*${NC} Icon: $(basename "$ICON_ASSET")" || echo -e "  - No custom icon -- using defaults"
[ -n "$LOGO_ASSET" ] && echo -e "${GREEN}*${NC} Logo: $(basename "$LOGO_ASSET")" || echo -e "  - No custom logo -- using defaults"
echo ""

# -- Step 2: Prerequisites --
echo -e "${BOLD}Step 2: Installing prerequisites...${NC}"

if ! command -v bun &>/dev/null; then
    curl -fsSL https://bun.sh/install | bash
    export BUN_INSTALL="$HOME/.bun"
    export PATH="$BUN_INSTALL/bin:$PATH"
fi
echo -e "${GREEN}*${NC} Bun $(bun --version)"

# Always install/update OpenCode CLI to ensure latest version
echo -e "  Installing OpenCode CLI (latest)..."
curl -fsSL https://opencode.ai/install | bash 2>/dev/null
export PATH="$HOME/.opencode/bin:$PATH"
echo -e "${GREEN}*${NC} OpenCode CLI $(opencode --version 2>/dev/null || echo 'installed')"
echo ""

# -- Step 3: Clone, Brand, and Build --
echo -e "${BOLD}Step 3: Building $APP_NAME...${NC}"

if [ -d "$BUILD_DIR" ]; then
    cd "$BUILD_DIR" && git pull 2>/dev/null || true
else
    git clone --depth 1 "$COWORK_REPO" "$BUILD_DIR"
fi
cd "$BUILD_DIR"

# -- 3a: Copy Electron config from this fork --
echo -e "  Applying Electron configuration..."
mkdir -p "$BUILD_DIR/electron"
cp "$COWORK_REPO_DIR/electron/main.cjs" "$BUILD_DIR/electron/main.cjs"
cp "$COWORK_REPO_DIR/electron-builder.json" "$BUILD_DIR/electron-builder.json"

# -- 3b: Patch package.json --
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

# -- 3c: Apply branding assets --
echo -e "  Applying branding..."
mkdir -p "$BUILD_DIR/branding"
mkdir -p "$BUILD_DIR/packages/desktop/src-tauri/icons"

if [ -n "$ICON_ASSET" ]; then
    # Auto-resize to all required sizes
    sips -z 512 512 "$ICON_ASSET" --out "$BUILD_DIR/branding/icon-512.png" 2>/dev/null
    sips -z 256 256 "$ICON_ASSET" --out "$BUILD_DIR/branding/icon-256.png" 2>/dev/null
    sips -z 180 180 "$ICON_ASSET" --out "$BUILD_DIR/branding/icon-180.png" 2>/dev/null
    sips -z 32 32 "$ICON_ASSET" --out "$BUILD_DIR/branding/icon-32.png" 2>/dev/null
    sips -z 16 16 "$ICON_ASSET" --out "$BUILD_DIR/branding/icon-16.png" 2>/dev/null
    cp "$ICON_ASSET" "$BUILD_DIR/branding/icon.png"

    # Create .icns for macOS (required by electron-builder)
    ICONSET_DIR="$BUILD_DIR/branding/app.iconset"
    mkdir -p "$ICONSET_DIR"
    sips -z 16 16 "$ICON_ASSET" --out "$ICONSET_DIR/icon_16x16.png" 2>/dev/null
    sips -z 32 32 "$ICON_ASSET" --out "$ICONSET_DIR/icon_16x16@2x.png" 2>/dev/null
    sips -z 32 32 "$ICON_ASSET" --out "$ICONSET_DIR/icon_32x32.png" 2>/dev/null
    sips -z 64 64 "$ICON_ASSET" --out "$ICONSET_DIR/icon_32x32@2x.png" 2>/dev/null
    sips -z 128 128 "$ICON_ASSET" --out "$ICONSET_DIR/icon_128x128.png" 2>/dev/null
    sips -z 256 256 "$ICON_ASSET" --out "$ICONSET_DIR/icon_128x128@2x.png" 2>/dev/null
    sips -z 256 256 "$ICON_ASSET" --out "$ICONSET_DIR/icon_256x256.png" 2>/dev/null
    sips -z 512 512 "$ICON_ASSET" --out "$ICONSET_DIR/icon_256x256@2x.png" 2>/dev/null
    sips -z 512 512 "$ICON_ASSET" --out "$ICONSET_DIR/icon_512x512.png" 2>/dev/null
    sips -z 1024 1024 "$ICON_ASSET" --out "$ICONSET_DIR/icon_512x512@2x.png" 2>/dev/null
    iconutil -c icns "$ICONSET_DIR" -o "$BUILD_DIR/packages/desktop/src-tauri/icons/icon.icns" 2>/dev/null || true
    rm -rf "$ICONSET_DIR"

    # Copy to all standard locations
    cp "$BUILD_DIR/branding/icon-512.png" "$BUILD_DIR/packages/desktop/src-tauri/icons/icon.png" 2>/dev/null
    cp "$BUILD_DIR/branding/icon-32.png" "$BUILD_DIR/packages/web/public/favicon.png" 2>/dev/null
    cp "$BUILD_DIR/branding/icon-16.png" "$BUILD_DIR/packages/web/public/favicon-16.png" 2>/dev/null
    cp "$BUILD_DIR/branding/icon-32.png" "$BUILD_DIR/packages/web/public/favicon-32.png" 2>/dev/null
    cp "$BUILD_DIR/branding/icon-512.png" "$BUILD_DIR/packages/web/public/pwa-512.png" 2>/dev/null
    cp "$BUILD_DIR/branding/icon-180.png" "$BUILD_DIR/packages/web/public/apple-touch-icon.png" 2>/dev/null
    # For electron-builder extraResources
    cp "$BUILD_DIR/branding/icon-512.png" "$BUILD_DIR/packages/web/public/cowork-icon.png" 2>/dev/null
    echo -e "${GREEN}*${NC} Custom icon applied (resized + .icns created)"
fi

if [ -n "$LOGO_ASSET" ]; then
    cp "$LOGO_ASSET" "$BUILD_DIR/packages/web/public/cowork-logo.png" 2>/dev/null
    echo -e "${GREEN}*${NC} Custom logo applied"
fi

# -- 3d: Patch index.html with branding --
echo -e "  Patching HTML with branding..."
INDEX_HTML="$BUILD_DIR/packages/web/index.html"
if [ -f "$INDEX_HTML" ]; then
    # Replace title
    sed -i '' "s|<title>[^<]*</title>|<title>$APP_NAME</title>|g" "$INDEX_HTML" 2>/dev/null

    # Replace the loading screen logo
    if [ -n "$LOGO_ASSET" ]; then
        sed -i '' 's|src="/cowork-logo.png"|src="/cowork-logo.png"|g' "$INDEX_HTML" 2>/dev/null
        sed -i '' 's|src="/logo-dark-512x512.svg"|src="/cowork-logo.png"|g' "$INDEX_HTML" 2>/dev/null
        sed -i '' 's|src="/logo-light-512x512.svg"|src="/cowork-logo.png"|g' "$INDEX_HTML" 2>/dev/null
        sed -i '' 's|src="[^"]*logo[^"]*\.svg"|src="/cowork-logo.png"|g' "$INDEX_HTML" 2>/dev/null
    fi

    # Update meta tags and JavaScript app name
    sed -i '' "s|content=\"OpenCode Cowork\"|content=\"$APP_NAME\"|g" "$INDEX_HTML" 2>/dev/null
    sed -i '' "s|content=\"OpenChamber[^\"]*\"|content=\"$APP_NAME\"|g" "$INDEX_HTML" 2>/dev/null
    sed -i '' "s|alt=\"Loading\"|alt=\"$APP_NAME\"|g" "$INDEX_HTML" 2>/dev/null
    # Replace the JavaScript defaultAppName variable (controls title bar)
    sed -i '' "s|const defaultAppName = '[^']*'|const defaultAppName = '$APP_NAME'|g" "$INDEX_HTML" 2>/dev/null
    sed -i '' "s|const defaultShortName = '[^']*'|const defaultShortName = '$APP_NAME'|g" "$INDEX_HTML" 2>/dev/null
fi

# Also patch the React useWindowTitle hook (compiled into JS bundle)
WINDOW_TITLE_TS="$BUILD_DIR/packages/ui/src/hooks/useWindowTitle.ts"
if [ -f "$WINDOW_TITLE_TS" ]; then
    sed -i '' "s|const APP_TITLE = '[^']*'|const APP_TITLE = '$APP_NAME'|g" "$WINDOW_TITLE_TS" 2>/dev/null
    echo -e "${GREEN}✓${NC} Window title patched"
fi

# -- 3e: Update electron-builder.json with correct paths --
echo -e "  Updating build configuration..."
python3 -c "
import json
with open('$BUILD_DIR/electron-builder.json') as f:
    eb = json.load(f)
eb['appId'] = 'com.cowork.$(echo "$PROVIDER_NAME")'
eb['productName'] = '$APP_NAME'
eb['extraResources'] = [
    {'from': 'packages/web/public/cowork-icon.png', 'to': 'icon.png'},
    {'from': 'branding/icon.png', 'to': 'icon-original.png'}
]
if 'mac' not in eb: eb['mac'] = {}
eb['mac']['icon'] = 'packages/desktop/src-tauri/icons/icon.icns'
eb['mac']['category'] = 'public.app-category.productivity'
if 'win' not in eb: eb['win'] = {}
eb['win']['icon'] = 'packages/desktop/src-tauri/icons/icon.png'
with open('$BUILD_DIR/electron-builder.json', 'w') as f:
    json.dump(eb, f, indent=2)
"

# -- 3f: Deploy sandbox rules --
echo -e "  Deploying sandbox rules..."
SERVER_JS="$BUILD_DIR/packages/web/server/index.js"
# ALWAYS copy the template (the server reads it at runtime)
cp "$COWORK_REPO_DIR/CLAUDE.md" "$BUILD_DIR/packages/web/server/CLAUDE_TEMPLATE.md" 2>/dev/null
echo -e "${GREEN}✓${NC} CLAUDE_TEMPLATE.md deployed to server"

# Only inject the JS function if it doesn't already exist (SF Steward fork already has it)
if [ -f "$SERVER_JS" ] && ! grep -q "ensureSandboxRules" "$SERVER_JS"; then

    # Inject the sandbox function into the server code
    python3 - "$SERVER_JS" << 'PYEOF'
import sys

server_path = sys.argv[1]
with open(server_path, "r") as f:
    content = f.read()

sandbox_code = """
// OpenCode Cowork: Auto-inject CLAUDE.md sandbox rules into every project directory
const __cowork_path = require('path');
const __cowork_fs = require('fs');

function ensureSandboxRules(directory) {
  if (!directory) return;
  const claudePath = __cowork_path.join(directory, 'CLAUDE.md');
  try {
    // Read the template from alongside this server file
    const templatePath = __cowork_path.join(__dirname, 'CLAUDE_TEMPLATE.md');
    let rules = '';
    if (__cowork_fs.existsSync(templatePath)) {
      rules = __cowork_fs.readFileSync(templatePath, 'utf8');
    }
    if (!rules) return;
    __cowork_fs.writeFileSync(claudePath, rules, 'utf8');
    if (process.platform === 'win32') {
      try {
        require('child_process').execSync('attrib +H +S "' + claudePath + '"', { stdio: 'ignore', timeout: 5000 });
      } catch (e) {}
    }
    console.log('[Sandbox] Created CLAUDE.md in ' + directory);
  } catch (e) {}
}

"""

# Append at the end of the file
content += sandbox_code

with open(server_path, "w") as f:
    f.write(content)

print("Sandbox rules injected into server")
PYEOF
    echo -e "${GREEN}*${NC} Sandbox injection ready"
fi

# -- 3g: Save branding config --
echo "{\"appName\":\"$APP_NAME\",\"provider\":\"$PROVIDER_DISPLAY\"}" > "$HOME/.cowork-branding.json"

# -- 3h: Install dependencies and build --
echo -e "  Adding Electron dependencies..."
cd "$BUILD_DIR"
bun add --dev electron@latest electron-builder@24.13.3 electron-store@latest electron-context-menu@latest 2>&1 | tail -1

echo -e "  Installing all dependencies..."
bun install 2>&1 | tail -1

echo -e "  Building frontend..."
bun run build:web 2>&1 | tail -3
echo -e "${GREEN}*${NC} Frontend built"

# -- 3i: Build Electron app --
echo -e "  Packaging desktop app (this may take a few minutes)..."
# Ensure branding placeholders exist for extraResources
[ ! -f "$BUILD_DIR/packages/web/public/cowork-icon.png" ] && [ -f "$BUILD_DIR/branding/icon.png" ] && cp "$BUILD_DIR/branding/icon.png" "$BUILD_DIR/packages/web/public/cowork-icon.png"
[ ! -f "$BUILD_DIR/packages/web/public/cowork-icon.png" ] && touch "$BUILD_DIR/packages/web/public/cowork-icon.png"
[ ! -f "$BUILD_DIR/branding/icon.png" ] && touch "$BUILD_DIR/branding/icon.png"

ELECTRON_LOG=$(bunx electron-builder --config electron-builder.json --mac 2>&1)
echo "$ELECTRON_LOG" | grep -E "(signing|building|target=|error|Error)" || true

BUILT_APP=$(find "$BUILD_DIR/electron-dist" -name "*.app" -maxdepth 3 2>/dev/null | head -1)
DESKTOP_APP_INSTALLED=false
if [ -n "$BUILT_APP" ] && [ -d "$BUILT_APP" ]; then
    [ -d "/Applications/$APP_NAME.app" ] && rm -rf "/Applications/$APP_NAME.app"
    cp -R "$BUILT_APP" "/Applications/$APP_NAME.app"
    echo -e "${GREEN}*${NC} $APP_NAME.app installed to /Applications"
    DESKTOP_APP_INSTALLED=true
else
    echo -e "${YELLOW}!${NC} Desktop app build skipped -- will use browser mode"
fi
echo ""

# -- Step 4: Configure AI --
echo -e "${BOLD}Step 4: Configuring AI models...${NC}"

OPENCODE_CONFIG_DIR="$HOME/.config/opencode"
mkdir -p "$OPENCODE_CONFIG_DIR"

TEMPLATE="$COWORK_REPO_DIR/config/opencode.json.template"
if [ -f "$TEMPLATE" ]; then
    sed "s|__API_KEY__|$API_KEY|g; s|__API_URL__|$API_URL|g; s|__PROVIDER_NAME__|$PROVIDER_NAME|g; s|__DISPLAY_NAME__|$PROVIDER_DISPLAY|g; s|__DEFAULT_MODEL__|$DEFAULT_MODEL|g; s|__DEFAULT_MODEL_DISPLAY__|$DEFAULT_MODEL_DISPLAY|g" "$TEMPLATE" > "$OPENCODE_CONFIG_DIR/opencode.json"
    # Also copy to the build directory (OpenCode reads config from CWD)
    cp "$OPENCODE_CONFIG_DIR/opencode.json" "$BUILD_DIR/opencode.json" 2>/dev/null
fi

# Check for additional models in config/models.json
MODELS_FILE="$COWORK_REPO_DIR/config/models.json"
if [ -f "$MODELS_FILE" ]; then
    python3 -c "
import json, sys
try:
    with open('$OPENCODE_CONFIG_DIR/opencode.json') as f:
        config = json.load(f)
    with open('$MODELS_FILE') as f:
        extra = json.load(f)
    provider_key = '$PROVIDER_NAME'
    if provider_key in config.get('provider', {}):
        models = extra.get('models', {})
        for model_id, model_cfg in models.items():
            config['provider'][provider_key]['models'][model_id] = model_cfg
        with open('$OPENCODE_CONFIG_DIR/opencode.json', 'w') as f:
            json.dump(config, f, indent=2)
        print(f'Added {len(models)} extra models from models.json')
except Exception as e:
    print(f'Note: Could not add extra models: {e}', file=sys.stderr)
"
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
(cd "$OPENCODE_CONFIG_DIR" && bun install 2>/dev/null) || true
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

SHELL_PROFILE="$HOME/.zshrc"
[ ! -f "$SHELL_PROFILE" ] && SHELL_PROFILE="$HOME/.bashrc"
if [ -f "$SHELL_PROFILE" ]; then
    grep -v "COWORK_API_KEY" "$SHELL_PROFILE" > "${SHELL_PROFILE}.tmp" 2>/dev/null || true
    mv "${SHELL_PROFILE}.tmp" "$SHELL_PROFILE"
    echo "export COWORK_API_KEY=\"$API_KEY\"" >> "$SHELL_PROFILE"
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
    if [ "$DESKTOP_APP_INSTALLED" = true ]; then
        open "/Applications/$APP_NAME.app"
        echo -e "  ${GREEN}$APP_NAME is running.${NC}"
    else
        echo -e "  Starting in browser mode..."
        cd "$BUILD_DIR"
        nohup bun run packages/web/server/index.js > /dev/null 2>&1 &
        sleep 3
        open "http://localhost:3000" 2>/dev/null
        echo -e "  ${GREEN}$APP_NAME is running in your browser.${NC}"
    fi
fi
