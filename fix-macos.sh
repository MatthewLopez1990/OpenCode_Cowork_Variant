#!/bin/bash
# fix-macos.sh — Apply provider filter + icon fix to existing install
# Run from the OpenCode_Cowork_Variant repo directory.

set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
BD="$HOME/.opencode-cowork-build"
SERVER_JS="$BD/packages/web/server/index.js"

echo "=== Fix 1: Server-side provider filter ==="
echo "  (Intercepts /api/config/providers — the endpoint the SDK actually uses)"

if [ ! -f "$SERVER_JS" ]; then
    echo "  ERROR: $SERVER_JS not found. Run the installer first."
    exit 1
fi

# Always copy the latest server (has correct /api/config/providers filter)
cp "$REPO_DIR/packages/web/server/index.js" "$SERVER_JS"
echo "  Updated server with provider filter on /api/config/providers"

echo ""
echo "=== Fix 2: Rebuild React UI (removes broken source filter) ==="
# The old compiled JS has .filter(source=config) which fails because the SDK
# strips the source property. The updated TypeScript removes this filter.
# Copy the updated source and rebuild.
STORE_TS="$BD/packages/ui/src/stores/useConfigStore.ts"
if [ -f "$STORE_TS" ]; then
    cp "$REPO_DIR/packages/ui/src/stores/useConfigStore.ts" "$STORE_TS"
    echo "  Updated useConfigStore.ts (removed broken source filter)"
    echo "  Rebuilding frontend..."
    (cd "$BD" && bun run build:web 2>&1 | tail -3)
    echo "  Frontend rebuilt"
else
    echo "  WARN: $STORE_TS not found, skipping React rebuild"
fi

echo ""
echo "=== Fix 3: App icon ==="

APP_NAME=""
[ -f "$HOME/.cowork-branding.json" ] && APP_NAME=$(python3 -c "import json; print(json.load(open('$HOME/.cowork-branding.json')).get('appName',''))" 2>/dev/null)

APP=""
for candidate in "/Applications/${APP_NAME}.app" "/Applications/Expedient Cowork.app"; do
    [ -d "$candidate" ] && APP="$candidate" && break
done

if [ -z "$APP" ] || [ ! -d "$APP" ]; then
    echo "  No app found in /Applications. Skipping."
else
    echo "  Found: $APP"
    RESOURCES="$APP/Contents/Resources"
    PLIST_ICON=$(defaults read "$APP/Contents/Info.plist" CFBundleIconFile 2>/dev/null || echo "icon.icns")

    ICON_PNG=""
    for candidate in "$REPO_DIR/assets/icon.png" "$REPO_DIR/assets/Icon.png" "$BD/branding/icon.png"; do
        [ -f "$candidate" ] && ICON_PNG="$candidate" && break
    done

    if [ -z "$ICON_PNG" ]; then
        echo "  No icon.png found. Place your icon at: $REPO_DIR/assets/icon.png"
    else
        echo "  Source: $ICON_PNG ($(sips -g pixelWidth "$ICON_PNG" 2>/dev/null | awk '/pixelWidth/{print $2}')px)"

        TMPSET=$(mktemp -d)/AppIcon.iconset
        mkdir -p "$TMPSET"
        for size in 16 32 64 128 256 512 1024; do
            sips -z $size $size "$ICON_PNG" --out "$TMPSET/icon_${size}x${size}.png" >/dev/null 2>&1
        done
        sips -z 32 32 "$ICON_PNG" --out "$TMPSET/icon_16x16@2x.png" >/dev/null 2>&1
        sips -z 64 64 "$ICON_PNG" --out "$TMPSET/icon_32x32@2x.png" >/dev/null 2>&1
        sips -z 256 256 "$ICON_PNG" --out "$TMPSET/icon_128x128@2x.png" >/dev/null 2>&1
        sips -z 512 512 "$ICON_PNG" --out "$TMPSET/icon_256x256@2x.png" >/dev/null 2>&1
        sips -z 1024 1024 "$ICON_PNG" --out "$TMPSET/icon_512x512@2x.png" >/dev/null 2>&1

        TMPICNS=$(mktemp).icns
        if iconutil -c icns "$TMPSET" -o "$TMPICNS" 2>/dev/null && [ -s "$TMPICNS" ]; then
            # Replace whatever Info.plist points to
            cp "$TMPICNS" "$RESOURCES/$PLIST_ICON"
            echo "  Replaced $PLIST_ICON ($(ls -lh "$RESOURCES/$PLIST_ICON" | awk '{print $5}'))"

            # Clear icon cache
            echo "  Clearing icon cache (may need password)..."
            sudo rm -rf /Library/Caches/com.apple.iconservices.store 2>/dev/null || true
            killall Dock 2>/dev/null || true
            echo "  Done"
        else
            echo "  ERROR: iconutil failed to create .icns"
            echo "  Check that icon.png is a valid PNG (run: file $ICON_PNG)"
        fi
        rm -rf "$(dirname "$TMPSET")" "$TMPICNS" 2>/dev/null
    fi
fi

echo ""
echo "=== Fix 4: Restart ==="
echo "  Stopping..."
pkill -f "$APP_NAME" 2>/dev/null || true
pkill -f "opencode-cowork-build" 2>/dev/null || true
sleep 2

if [ -n "$APP" ] && [ -d "$APP" ]; then
    echo "  Launching $APP ..."
    open "$APP"
    echo "  Started. Give it 5-10 seconds."
else
    echo "  Relaunch manually."
fi

echo ""
echo "============================================================"
echo "  All fixes applied."
echo "  - Provider filter: /api/config/providers (correct endpoint)"
echo "  - React filter: removed (SDK strips source field)"
echo "  - Icon: replaced in app bundle"
echo "============================================================"
