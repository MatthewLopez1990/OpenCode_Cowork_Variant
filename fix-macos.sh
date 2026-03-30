#!/bin/bash
# fix-macos.sh — Apply provider filter + icon fix to existing install
# Run from the OpenCode_Cowork_Variant repo directory.

set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
BD="$HOME/.opencode-cowork-build"
SERVER_JS="$BD/packages/web/server/index.js"

echo "=== Fix 1: Server-side provider filter ==="

if [ ! -f "$SERVER_JS" ]; then
    echo "  ERROR: $SERVER_JS not found. Run the installer first."
    exit 1
fi

# Check if the filter already exists
if grep -q 'Cowork provider filter' "$SERVER_JS" 2>/dev/null; then
    echo "  Provider filter already present in server."
else
    # Copy the updated server from repo
    cp "$REPO_DIR/packages/web/server/index.js" "$SERVER_JS"
    echo "  Copied updated server with provider filter."
fi

echo ""
echo "=== Fix 2: App icon ==="

# Find the installed app
APP_NAME=""
if [ -f "$HOME/.cowork-branding.json" ]; then
    APP_NAME=$(python3 -c "import json; print(json.load(open('$HOME/.cowork-branding.json')).get('appName',''))" 2>/dev/null)
fi

APP=""
for candidate in "/Applications/${APP_NAME}.app" "/Applications/Expedient Cowork.app" "/Applications/SF Steward.app"; do
    if [ -d "$candidate" ]; then
        APP="$candidate"
        break
    fi
done

if [ -z "$APP" ] || [ ! -d "$APP" ]; then
    echo "  ERROR: No app found in /Applications."
    echo "  Skipping icon fix."
else
    echo "  Found: $APP"
    RESOURCES="$APP/Contents/Resources"

    # Create .icns from icon.png
    ICON_PNG=""
    for candidate in "$REPO_DIR/assets/icon.png" "$REPO_DIR/assets/Icon.png" "$BD/branding/icon.png"; do
        if [ -f "$candidate" ]; then
            ICON_PNG="$candidate"
            break
        fi
    done

    if [ -z "$ICON_PNG" ]; then
        echo "  ERROR: No icon.png found in assets/."
        echo "  Place your icon at: $REPO_DIR/assets/icon.png"
    else
        echo "  Source icon: $ICON_PNG"

        # Create iconset
        TMPICON=$(mktemp -d)/AppIcon.iconset
        mkdir -p "$TMPICON"

        for size in 16 32 64 128 256 512 1024; do
            sips -z $size $size "$ICON_PNG" --out "$TMPICON/icon_${size}x${size}.png" > /dev/null 2>&1
        done
        # Also create @2x variants
        sips -z 32 32 "$ICON_PNG" --out "$TMPICON/icon_16x16@2x.png" > /dev/null 2>&1
        sips -z 64 64 "$ICON_PNG" --out "$TMPICON/icon_32x32@2x.png" > /dev/null 2>&1
        sips -z 256 256 "$ICON_PNG" --out "$TMPICON/icon_128x128@2x.png" > /dev/null 2>&1
        sips -z 512 512 "$ICON_PNG" --out "$TMPICON/icon_256x256@2x.png" > /dev/null 2>&1
        sips -z 1024 1024 "$ICON_PNG" --out "$TMPICON/icon_512x512@2x.png" > /dev/null 2>&1

        CUSTOM_ICNS=$(mktemp).icns
        iconutil -c icns "$TMPICON" -o "$CUSTOM_ICNS" 2>/dev/null

        if [ -f "$CUSTOM_ICNS" ] && [ -s "$CUSTOM_ICNS" ]; then
            echo "  Created .icns ($(ls -lh "$CUSTOM_ICNS" | awk '{print $5}'))"

            # Replace electron.icns (the one Info.plist points to)
            if [ -f "$RESOURCES/electron.icns" ]; then
                cp "$CUSTOM_ICNS" "$RESOURCES/electron.icns"
                echo "  Replaced electron.icns with custom icon."
            fi

            # Also create icon.icns
            cp "$CUSTOM_ICNS" "$RESOURCES/icon.icns"
            echo "  Created icon.icns."

            # Clear macOS icon cache
            echo "  Clearing icon cache..."
            sudo rm -rf /Library/Caches/com.apple.iconservices.store 2>/dev/null || true
            killall Dock 2>/dev/null || true
            echo "  Icon cache cleared."
        else
            echo "  ERROR: Failed to create .icns file."
        fi

        rm -rf "$(dirname "$TMPICON")" "$CUSTOM_ICNS" 2>/dev/null
    fi
fi

echo ""
echo "=== Fix 3: Restart the app ==="

# Kill existing processes
echo "  Stopping running instances..."
pkill -f "Expedient Cowork" 2>/dev/null || true
pkill -f "opencode-cowork-build" 2>/dev/null || true
sleep 2

# Relaunch
if [ -n "$APP" ] && [ -d "$APP" ]; then
    echo "  Relaunching $APP ..."
    open "$APP"
    echo "  Done! Give it a few seconds to start."
else
    echo "  Relaunch manually."
fi

echo ""
echo "============================================================"
echo "  Fixes applied. The provider filter now works server-side"
echo "  (no React recompilation needed). The icon should appear"
echo "  after the Dock restarts."
echo "============================================================"
