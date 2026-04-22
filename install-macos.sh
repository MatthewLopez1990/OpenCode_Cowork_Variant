#!/bin/bash
set -e

# ============================================================
#  OpenCode Cowork — macOS Installer
#  White-label AI assistant for any enterprise.
#  Installer handles branding, building, and configuration.
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
echo -e "${BLUE}${BOLD}+==========================================+${NC}"
echo ""

# ── Step 1: Organization Setup ──────────────────────────────
# Any value pre-populated via env (COWORK_APP_NAME, COWORK_API_KEY,
# COWORK_DEFAULT_MODEL, COWORK_DEFAULT_MODEL_DISPLAY, COWORK_ICON_PATH,
# COWORK_LOGO_PATH) skips the corresponding prompt — used by the GUI installer
# to run this script headlessly.
echo -e "${BOLD}Step 1: Organization Setup${NC}"
echo ""

APP_NAME="${COWORK_APP_NAME:-}"
while [ -z "$APP_NAME" ]; do
    echo -ne "${YELLOW}App name (e.g., 'Acme AI Assistant'): ${NC}"
    read -r APP_NAME
    [ -z "$APP_NAME" ] && echo -e "${RED}Required.${NC}"
done

API_KEY="${COWORK_API_KEY:-}"
while [ -z "$API_KEY" ]; do
    echo -ne "${YELLOW}OpenRouter API key (starts with 'sk-or-v1-'): ${NC}"
    read -r API_KEY
    [ -z "$API_KEY" ] && echo -e "${RED}Required.${NC}"
done

DEFAULT_MODEL="${COWORK_DEFAULT_MODEL:-}"
if [ -z "$DEFAULT_MODEL" ]; then
    echo -ne "${YELLOW}Default model ID (e.g., 'anthropic/claude-sonnet-4.5'): ${NC}"
    read -r DEFAULT_MODEL
    while [ -z "$DEFAULT_MODEL" ]; do
        echo -e "${RED}Required. Browse models at https://openrouter.ai/models${NC}"
        echo -ne "${YELLOW}Default model ID: ${NC}"
        read -r DEFAULT_MODEL
    done
fi

DEFAULT_MODEL_DISPLAY="${COWORK_DEFAULT_MODEL_DISPLAY:-}"
if [ -z "$DEFAULT_MODEL_DISPLAY" ] && [ -z "${COWORK_APP_NAME:-}" ]; then
    echo -ne "Default model display name (Enter for '$DEFAULT_MODEL'): "
    read -r DEFAULT_MODEL_DISPLAY
fi
[ -z "$DEFAULT_MODEL_DISPLAY" ] && DEFAULT_MODEL_DISPLAY="$DEFAULT_MODEL"

# Backend is OpenRouter (hidden from the client). The provider is surfaced
# in the UI using the APP_NAME so the end user sees the white-label brand,
# not "OpenRouter". The provider key is a slug of the app name.
PROVIDER_KEY=$(echo "$APP_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//;s/-$//')
[ -z "$PROVIDER_KEY" ] && PROVIDER_KEY="provider"
API_URL="https://openrouter.ai/api/v1"

echo ""
echo -e "${GREEN}*${NC} App: $APP_NAME"
echo -e "${GREEN}*${NC} Provider (shown to users): $APP_NAME"
echo -e "${GREEN}*${NC} Model: $DEFAULT_MODEL"

# Check for branding assets — env-var paths take precedence over /assets/
ICON_ASSET=""
LOGO_ASSET=""
if [ -n "${COWORK_ICON_PATH:-}" ] && [ -f "${COWORK_ICON_PATH}" ]; then
    ICON_ASSET="${COWORK_ICON_PATH}"
else
    for f in "$COWORK_REPO_DIR/assets/"[Ii][Cc][Oo][Nn].[Pp][Nn][Gg]; do
        [ -f "$f" ] && ICON_ASSET="$f" && break
    done
fi
if [ -n "${COWORK_LOGO_PATH:-}" ] && [ -f "${COWORK_LOGO_PATH}" ]; then
    LOGO_ASSET="${COWORK_LOGO_PATH}"
else
    for f in "$COWORK_REPO_DIR/assets/"[Ll][Oo][Gg][Oo].[Pp][Nn][Gg]; do
        [ -f "$f" ] && LOGO_ASSET="$f" && break
    done
fi
[ -n "$ICON_ASSET" ] && echo -e "${GREEN}*${NC} Icon: $(basename "$ICON_ASSET")" || echo -e "  - No custom icon — using defaults"
[ -n "$LOGO_ASSET" ] && echo -e "${GREEN}*${NC} Logo: $(basename "$LOGO_ASSET")" || echo -e "  - No custom logo — using defaults"
echo ""

# ── Step 2: Prerequisites ───────────────────────────────────
echo -e "${BOLD}Step 2: Installing prerequisites...${NC}"

if ! command -v bun &>/dev/null; then
    curl -fsSL https://bun.sh/install | bash
    export BUN_INSTALL="$HOME/.bun"
    export PATH="$BUN_INSTALL/bin:$PATH"
fi
echo -e "${GREEN}*${NC} Bun $(bun --version)"

rm -f "$HOME/.local/bin/opencode" 2>/dev/null || true
echo -e "  Installing OpenCode CLI..."
curl -fsSL https://opencode.ai/install | bash 2>/dev/null || true
export PATH="$HOME/.opencode/bin:$PATH"
echo -e "${GREEN}*${NC} OpenCode CLI $(opencode --version 2>/dev/null || echo 'installed')"
echo ""

# ── Step 3: Clone, Brand, Build ─────────────────────────────
echo -e "${BOLD}Step 3: Building $APP_NAME...${NC}"

if [ -d "$BUILD_DIR" ]; then
    cd "$BUILD_DIR" && git pull 2>/dev/null || true
else
    git clone --depth 1 "$COWORK_REPO" "$BUILD_DIR"
fi
cd "$BUILD_DIR"

# 3a: Copy Electron config from repo
echo -e "  Applying Electron configuration..."
mkdir -p "$BUILD_DIR/electron"
cp "$COWORK_REPO_DIR/electron/main.cjs" "$BUILD_DIR/electron/main.cjs"
cp "$COWORK_REPO_DIR/electron-builder.json" "$BUILD_DIR/electron-builder.json"

# 3b: Patch package.json
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

# 3c: Apply branding
echo -e "  Applying branding..."
mkdir -p "$BUILD_DIR/branding"

# Icon: try to create custom .icns, fallback to defaults already in repo
if [ -n "$ICON_ASSET" ]; then
    ICON_W=$(sips -g pixelWidth "$ICON_ASSET" 2>/dev/null | awk '/pixelWidth/{print $2}')
    if [ -n "$ICON_W" ] && ! echo "$ICON_W" | grep -qi "nil" 2>/dev/null; then
        # Valid image — create master at 1024x1024
        sips -z 1024 1024 "$ICON_ASSET" --out "$BUILD_DIR/branding/icon-master.png" >/dev/null 2>&1 || cp "$ICON_ASSET" "$BUILD_DIR/branding/icon-master.png" || true
        MASTER="$BUILD_DIR/branding/icon-master.png"

        # Create .icns
        ISET="$BUILD_DIR/branding/app.iconset"
        mkdir -p "$ISET"
        sips -z 16 16 "$MASTER" --out "$ISET/icon_16x16.png" >/dev/null 2>&1 || true
        sips -z 32 32 "$MASTER" --out "$ISET/icon_16x16@2x.png" >/dev/null 2>&1 || true
        sips -z 32 32 "$MASTER" --out "$ISET/icon_32x32.png" >/dev/null 2>&1 || true
        sips -z 64 64 "$MASTER" --out "$ISET/icon_32x32@2x.png" >/dev/null 2>&1 || true
        sips -z 128 128 "$MASTER" --out "$ISET/icon_128x128.png" >/dev/null 2>&1 || true
        sips -z 256 256 "$MASTER" --out "$ISET/icon_128x128@2x.png" >/dev/null 2>&1 || true
        sips -z 256 256 "$MASTER" --out "$ISET/icon_256x256.png" >/dev/null 2>&1 || true
        sips -z 512 512 "$MASTER" --out "$ISET/icon_256x256@2x.png" >/dev/null 2>&1 || true
        sips -z 512 512 "$MASTER" --out "$ISET/icon_512x512.png" >/dev/null 2>&1 || true
        cp "$MASTER" "$ISET/icon_512x512@2x.png" 2>/dev/null || true
        if iconutil -c icns "$ISET" -o "$BUILD_DIR/packages/desktop/src-tauri/icons/icon.icns" 2>/dev/null; then
            echo -e "${GREEN}*${NC} Custom .icns created"
        else
            echo -e "${YELLOW}!${NC} Custom icon failed — using default icons"
        fi
        rm -rf "$ISET" 2>/dev/null || true

        # Copy to web public
        sips -z 512 512 "$MASTER" --out "$BUILD_DIR/packages/web/public/cowork-icon.png" >/dev/null 2>&1 || true
        sips -z 32 32 "$MASTER" --out "$BUILD_DIR/packages/web/public/favicon.png" >/dev/null 2>&1 || true
        cp "$MASTER" "$BUILD_DIR/packages/desktop/src-tauri/icons/icon.png" 2>/dev/null || true
    else
        echo -e "${YELLOW}!${NC} Icon file not recognized by sips — using default icons"
        echo -e "  (Tip: open your icon in Preview → File → Export as PNG)"
    fi
fi

if [ -n "$LOGO_ASSET" ]; then
    cp "$LOGO_ASSET" "$BUILD_DIR/packages/web/public/cowork-logo.png" 2>/dev/null || true
    echo -e "${GREEN}*${NC} Custom logo applied"
fi

# 3d: Patch HTML + TypeScript
INDEX_HTML="$BUILD_DIR/packages/web/index.html"
if [ -f "$INDEX_HTML" ]; then
    sed -i '' "s|<title>[^<]*</title>|<title>$APP_NAME</title>|g" "$INDEX_HTML" 2>/dev/null || true
    sed -i '' "s|content=\"OpenChamber[^\"]*\"|content=\"$APP_NAME\"|g" "$INDEX_HTML" 2>/dev/null || true
    sed -i '' "s|content=\"SF Steward[^\"]*\"|content=\"$APP_NAME\"|g" "$INDEX_HTML" 2>/dev/null || true
    sed -i '' "s|const defaultAppName = '[^']*'|const defaultAppName = '$APP_NAME'|g" "$INDEX_HTML" 2>/dev/null || true
    sed -i '' "s|const defaultShortName = '[^']*'|const defaultShortName = '$APP_NAME'|g" "$INDEX_HTML" 2>/dev/null || true
fi
WINDOW_TITLE_TS="$BUILD_DIR/packages/ui/src/hooks/useWindowTitle.ts"
if [ -f "$WINDOW_TITLE_TS" ]; then
    sed -i '' "s|const APP_TITLE = '[^']*'|const APP_TITLE = '$APP_NAME'|g" "$WINDOW_TITLE_TS" 2>/dev/null || true
fi

# 3e: Update electron-builder.json
python3 -c "
import json
with open('$BUILD_DIR/electron-builder.json') as f:
    eb = json.load(f)
eb['appId'] = 'com.cowork.app'
eb['productName'] = '$APP_NAME'
with open('$BUILD_DIR/electron-builder.json', 'w') as f:
    json.dump(eb, f, indent=2)
"

# 3f: Deploy sandbox
cp "$COWORK_REPO_DIR/CLAUDE.md" "$BUILD_DIR/packages/web/server/CLAUDE_TEMPLATE.md" 2>/dev/null || true

# 3g: Branding config
echo "{\"appName\":\"$APP_NAME\",\"provider\":\"$PROVIDER_DISPLAY\"}" > "$HOME/.cowork-branding.json"

# 3h: Install deps and build
echo -e "  Adding Electron dependencies..."
bun add --dev electron@latest electron-builder@24.13.3 electron-store@latest electron-context-menu@latest 2>&1 | tail -1
echo -e "  Installing all dependencies..."
bun install 2>&1 | tail -1
echo -e "  Building frontend..."
bun run build:web 2>&1 | tail -3
echo -e "${GREEN}*${NC} Frontend built"

# 3i: Build Electron app
echo -e "  Packaging desktop app..."
# Ensure extraResources files exist
[ ! -f "$BUILD_DIR/packages/web/public/cowork-icon.png" ] && cp "$BUILD_DIR/packages/desktop/src-tauri/icons/icon.png" "$BUILD_DIR/packages/web/public/cowork-icon.png" 2>/dev/null || true
bunx electron-builder --config electron-builder.json --mac 2>&1 | grep -E "(signing|building|target=|error|Error)" || true

BUILT_APP=$(find "$BUILD_DIR/electron-dist" -name "*.app" -maxdepth 3 2>/dev/null | head -1)
if [ -n "$BUILT_APP" ] && [ -d "$BUILT_APP" ]; then
    [ -d "/Applications/$APP_NAME.app" ] && rm -rf "/Applications/$APP_NAME.app"
    cp -R "$BUILT_APP" "/Applications/$APP_NAME.app"
    echo -e "${GREEN}*${NC} $APP_NAME.app installed to /Applications"

    # Clear icon cache and Electron app data (stale Zustand state)
    sudo rm -rf /Library/Caches/com.apple.iconservices.store 2>/dev/null || true
    killall Dock 2>/dev/null || true
    rm -rf "$HOME/Library/Application Support/$APP_NAME" 2>/dev/null || true
else
    echo -e "${YELLOW}!${NC} Desktop app build skipped — use browser mode"
fi
echo ""

# ── Step 4: Configure AI ────────────────────────────────────
echo -e "${BOLD}Step 4: Configuring AI models...${NC}"

OPENCODE_CONFIG_DIR="$HOME/.config/opencode"
mkdir -p "$OPENCODE_CONFIG_DIR"

# Create config from template. The OpenRouter baseURL is hardcoded in the
# template itself; the provider key and display name come from the app name
# so clients never see "OpenRouter" anywhere in the UI.
TEMPLATE="$COWORK_REPO_DIR/config/opencode.json.template"
if [ -f "$TEMPLATE" ]; then
    sed "s|__PROVIDER_KEY__|$PROVIDER_KEY|g; s|__API_KEY__|$API_KEY|g; s|__APP_NAME__|$APP_NAME|g; s|__DEFAULT_MODEL__|$DEFAULT_MODEL|g; s|__DEFAULT_MODEL_DISPLAY__|$DEFAULT_MODEL_DISPLAY|g" "$TEMPLATE" > "$OPENCODE_CONFIG_DIR/opencode.json"
    cp "$OPENCODE_CONFIG_DIR/opencode.json" "$BUILD_DIR/opencode.json" 2>/dev/null || true
fi

# Merge extra models
MODELS_FILE="$COWORK_REPO_DIR/config/models.json"
if [ -f "$MODELS_FILE" ]; then
    python3 -c "
import json, sys
try:
    with open('$OPENCODE_CONFIG_DIR/opencode.json') as f:
        config = json.load(f)
    with open('$MODELS_FILE') as f:
        extra = json.load(f)
    models = extra.get('models', {})
    config['provider']['$PROVIDER_KEY']['models'].update(models)
    with open('$OPENCODE_CONFIG_DIR/opencode.json', 'w') as f:
        json.dump(config, f, indent=2)
    cp_dst = '$BUILD_DIR/opencode.json'
    with open(cp_dst, 'w') as f:
        json.dump(config, f, indent=2)
    print(f'  Added {len(models)} extra models')
except Exception as e:
    print(f'  Note: {e}', file=sys.stderr)
" 2>/dev/null || true
fi
echo -e "${GREEN}*${NC} AI models configured (default: $DEFAULT_MODEL)"

# npm SDK
cat > "$OPENCODE_CONFIG_DIR/package.json" << 'PKGJSON'
{"dependencies":{"@ai-sdk/openai-compatible":"latest","@opencode-ai/plugin":"1.2.27"}}
PKGJSON
(cd "$OPENCODE_CONFIG_DIR" && bun install 2>/dev/null) || true
echo -e "${GREEN}*${NC} Provider SDK installed"

# Commands
mkdir -p "$OPENCODE_CONFIG_DIR/commands"
for CMD_TYPE in legal finance; do
    CMDS_SRC="$COWORK_REPO_DIR/commands/$CMD_TYPE"
    if [ -d "$CMDS_SRC" ]; then
        rm -rf "$OPENCODE_CONFIG_DIR/commands/$CMD_TYPE" 2>/dev/null || true
        cp -r "$CMDS_SRC" "$OPENCODE_CONFIG_DIR/commands/$CMD_TYPE"
    fi
done
echo -e "${GREEN}*${NC} Legal + Finance skills installed"

# Agent rules + sandbox
[ -f "$COWORK_REPO_DIR/opencode.md" ] && cp "$COWORK_REPO_DIR/opencode.md" "$OPENCODE_CONFIG_DIR/opencode.md"
DEFAULT_PROJECT="$HOME/$APP_NAME Projects"
mkdir -p "$DEFAULT_PROJECT"
[ -f "$COWORK_REPO_DIR/CLAUDE.md" ] && cp "$COWORK_REPO_DIR/CLAUDE.md" "$DEFAULT_PROJECT/CLAUDE.md"
mkdir -p "$OPENCODE_CONFIG_DIR/sandbox"
cp "$COWORK_REPO_DIR/CLAUDE.md" "$OPENCODE_CONFIG_DIR/sandbox/CLAUDE.md.template" 2>/dev/null || true
echo -e "${GREEN}*${NC} Default project: $DEFAULT_PROJECT"

# Settings — MERGE with existing (don't destroy other app settings)
PROJECT_UUID=$(uuidgen | tr '[:upper:]' '[:lower:]')
PROJECT_TS=$(python3 -c "import time; print(int(time.time()*1000))")
for DIR in "$HOME/.config/sf-steward" "$HOME/.config/openchamber"; do
    mkdir -p "$DIR"
    python3 -c "
import json, os
path = '$DIR/settings.json'
existing = {}
if os.path.exists(path):
    try:
        existing = json.load(open(path))
    except: pass
existing['defaultModel'] = '$PROVIDER_KEY/$DEFAULT_MODEL'
projects = existing.get('projects', [])
new_path = '$DEFAULT_PROJECT'
if not any(p.get('path') == new_path for p in projects):
    projects.append({'id': '$PROJECT_UUID', 'path': new_path, 'addedAt': $PROJECT_TS, 'lastOpenedAt': $PROJECT_TS})
existing['projects'] = projects
existing['activeProjectId'] = '$PROJECT_UUID'
with open(path, 'w') as f:
    json.dump(existing, f, indent=2)
"
done
echo -e "${GREEN}*${NC} Settings configured (merged with existing)"

# Shell profile
SHELL_PROFILE="$HOME/.zshrc"
[ ! -f "$SHELL_PROFILE" ] && SHELL_PROFILE="$HOME/.bashrc"
if [ -f "$SHELL_PROFILE" ]; then
    grep -v -E "COWORK_API_KEY|OPENROUTER_API_KEY" "$SHELL_PROFILE" > "${SHELL_PROFILE}.tmp" 2>/dev/null || true
    mv "${SHELL_PROFILE}.tmp" "$SHELL_PROFILE"
    echo "export OPENROUTER_API_KEY=\"$API_KEY\"" >> "$SHELL_PROFILE"
fi

echo ""
echo -e "${BLUE}${BOLD}+==========================================+${NC}"
echo -e "${BLUE}${BOLD}|         Installation Complete!            |${NC}"
echo -e "${BLUE}${BOLD}+==========================================+${NC}"
echo ""
echo -e "  ${GREEN}*${NC} $APP_NAME desktop app"
echo -e "  ${GREEN}*${NC} AI models (default: $DEFAULT_MODEL)"
echo -e "  ${GREEN}*${NC} oh-my-openagent plugin"
echo -e "  ${GREEN}*${NC} Legal + Finance commands"
echo -e "  ${GREEN}*${NC} Directory sandbox"
echo ""
echo -e "  Default project: $DEFAULT_PROJECT"
echo ""
echo -ne "Launch now? (y/n): "
read -r LAUNCH
if [[ "$LAUNCH" =~ ^[Yy] ]]; then
    if [ -d "/Applications/$APP_NAME.app" ]; then
        open "/Applications/$APP_NAME.app"
        echo -e "  ${GREEN}$APP_NAME is running.${NC}"
    fi
fi
