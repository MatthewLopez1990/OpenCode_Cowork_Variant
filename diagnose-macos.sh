#!/bin/bash
echo "============================================================"
echo "  OpenCode Cowork — Diagnostic Report"
echo "  $(date)"
echo "  Machine: $(uname -m) | $(sw_vers -productName 2>/dev/null) $(sw_vers -productVersion 2>/dev/null)"
echo "============================================================"
echo ""

PASS="✅"
FAIL="❌"
WARN="⚠️"

# ==================================================================
echo "=== 1. OpenCode Binary ==="
OC_PATH=$(which opencode 2>/dev/null)
OC_HOME="$HOME/.opencode/bin/opencode"
if [ -f "$OC_HOME" ]; then
    OC_VER=$("$OC_HOME" --version 2>&1 | head -1)
    OC_TYPE=$(file "$OC_HOME" 2>/dev/null | grep -o 'Mach-O.*' || echo 'unknown')
    OC_SIZE=$(ls -lh "$OC_HOME" | awk '{print $5}')
    echo "  $PASS Binary: $OC_HOME ($OC_SIZE, $OC_TYPE)"
    echo "  $PASS Version: $OC_VER"
    # Check for wrapper script
    BYTES=$(wc -c < "$OC_HOME" 2>/dev/null || echo 0)
    if [ "$BYTES" -lt 1000000 ]; then
        echo "  $FAIL PROBLEM: Binary is only $BYTES bytes — likely a wrapper script, not real binary"
        echo "     FIX: rm '$OC_HOME' && curl -fsSL https://opencode.ai/install | bash"
    fi
else
    echo "  $FAIL MISSING: $OC_HOME"
    echo "     FIX: curl -fsSL https://opencode.ai/install | bash"
fi
# Check for shadowing
for shadow in "$HOME/.local/bin/opencode" "/usr/local/bin/opencode"; do
    [ -f "$shadow" ] && echo "  $WARN Shadow: $shadow exists and may override — rm it"
done
echo ""

# ==================================================================
echo "=== 2. Bun ==="
if command -v bun &>/dev/null; then
    echo "  $PASS Bun $(bun --version) at $(which bun)"
else
    echo "  $FAIL MISSING"
    echo "     FIX: curl -fsSL https://bun.sh/install | bash"
fi
echo ""

# ==================================================================
echo "=== 3. Config File ==="
CONFIG="$HOME/.config/opencode/opencode.json"
if [ -f "$CONFIG" ]; then
    # Check for BOM
    FIRST=$(xxd "$CONFIG" 2>/dev/null | head -1)
    if echo "$FIRST" | grep -q "efbb bf" 2>/dev/null; then
        echo "  $FAIL BOM detected — Go JSON parser will fail"
        echo "     FIX: Rewrite without BOM"
    fi
    python3 -c "
import json, sys
try:
    cfg = json.load(open('$CONFIG'))
    print('  $PASS Valid JSON')
    keys = list(cfg.keys())
    print(f'  Keys: {keys}')

    # Check for crash-causing keys
    bad_keys = [k for k in keys if k not in ('\$schema','plugin','model','agent','provider')]
    if bad_keys:
        print(f'  $FAIL CRASH RISK: Keys {bad_keys} will crash the Go backend!')
        print(f'     FIX: Remove these keys from {\"$CONFIG\"}')

    # Provider
    for name, p in cfg.get('provider', {}).items():
        models = list(p.get('models', {}).keys())
        print(f'  Provider: {name}')
        print(f'    Name: {p.get(\"name\")}')
        print(f'    npm: {p.get(\"npm\")}')
        print(f'    baseURL: {p.get(\"options\",{}).get(\"baseURL\")}')
        ak = p.get('options',{}).get('apiKey','')
        print(f'    apiKey: {ak[:10]}... ({len(ak)} chars)' if ak else '    apiKey: MISSING')
        print(f'    Models: {len(models)} — {models}')
        if not ak:
            print(f'  $FAIL No API key configured!')

    # Default model
    model = cfg.get('model','')
    print(f'  Default model: {model}')
    # Check if default model exists in a provider
    found = False
    for name, p in cfg.get('provider', {}).items():
        if model in p.get('models', {}):
            found = True
    if not found and model:
        print(f'  $WARN Default model \"{model}\" not found in any provider!')

    # Plugin
    plugins = cfg.get('plugin', [])
    print(f'  Plugins: {plugins}')

    # Agents
    for name, a in cfg.get('agent', {}).items():
        print(f'  Agent \"{name}\": model={a.get(\"model\")}')
except Exception as e:
    print(f'  $FAIL PARSE ERROR: {e}')
" 2>/dev/null
else
    echo "  $FAIL MISSING: $CONFIG"
    echo "     FIX: Re-run the installer"
fi
echo ""

# ==================================================================
echo "=== 4. npm Provider SDK ==="
SDK_DIR="$HOME/.config/opencode/node_modules/@ai-sdk/openai-compatible"
if [ -d "$SDK_DIR" ]; then
    VER=$(python3 -c "import json; print(json.load(open('$SDK_DIR/package.json')).get('version','?'))" 2>/dev/null)
    echo "  $PASS @ai-sdk/openai-compatible v$VER"
else
    echo "  $FAIL MISSING: @ai-sdk/openai-compatible not installed"
    echo "     FIX: cd ~/.config/opencode && bun add @ai-sdk/openai-compatible"
fi
PLUGIN_DIR="$HOME/.config/opencode/node_modules/@opencode-ai/plugin"
if [ -d "$PLUGIN_DIR" ]; then
    VER=$(python3 -c "import json; print(json.load(open('$PLUGIN_DIR/package.json')).get('version','?'))" 2>/dev/null)
    echo "  $PASS @opencode-ai/plugin v$VER"
else
    echo "  $WARN @opencode-ai/plugin not installed (oh-my-opencode may not work)"
fi
echo ""

# ==================================================================
echo "=== 5. Build Directory ==="
BD="$HOME/.opencode-cowork-build"
if [ ! -d "$BD" ]; then
    echo "  $FAIL MISSING: $BD"
    echo "     FIX: Re-run the installer"
else
    echo "  $PASS Exists: $BD"

    # Server
    SRV="$BD/packages/web/server/index.js"
    if [ -f "$SRV" ]; then
        echo "  $PASS Server: index.js exists"
        # Check for provider filter on CORRECT endpoint
        if grep -q '/api/config/providers' "$SRV" 2>/dev/null; then
            echo "  $PASS Server provider filter: intercepts /api/config/providers (correct)"
        elif grep -q '/api/provider' "$SRV" 2>/dev/null && ! grep -q '/api/config/providers' "$SRV" 2>/dev/null; then
            echo "  $FAIL Server provider filter: intercepts /api/provider (WRONG endpoint!)"
            echo "     The SDK uses /api/config/providers, not /api/provider"
            echo "     FIX: Update server from repo: cp repo/packages/web/server/index.js $SRV"
        else
            echo "  $FAIL No server-side provider filter found"
        fi
        # Sandbox
        TMPL="$BD/packages/web/server/CLAUDE_TEMPLATE.md"
        [ -f "$TMPL" ] && echo "  $PASS CLAUDE_TEMPLATE.md deployed" || echo "  $WARN CLAUDE_TEMPLATE.md missing"
    else
        echo "  $FAIL Server index.js MISSING"
    fi

    # Config in build dir
    [ -f "$BD/opencode.json" ] && echo "  $PASS opencode.json in build dir" || echo "  $WARN opencode.json missing in build dir"

    # Compiled React
    MAIN_JS=$(find "$BD/packages/web/dist/assets/" -name "main-*.js" -type f 2>/dev/null | head -1)
    if [ -n "$MAIN_JS" ]; then
        SIZE=$(ls -lh "$MAIN_JS" | awk '{print $5}')
        echo "  $PASS Compiled React: $(basename "$MAIN_JS") ($SIZE)"
        # Check if the broken filter is in compiled code
        if grep -q 'source.*config' "$MAIN_JS" 2>/dev/null; then
            echo "  $WARN Compiled JS still has source=config filter (SDK strips this field)"
        fi
    else
        echo "  $WARN No main-*.js found in dist/assets/"
    fi
fi
echo ""

# ==================================================================
echo "=== 6. App Bundle ==="
BRAND_APP=""
[ -f "$HOME/.cowork-branding.json" ] && BRAND_APP=$(python3 -c "import json; print(json.load(open('$HOME/.cowork-branding.json')).get('appName',''))" 2>/dev/null)
APP=""
for candidate in "/Applications/${BRAND_APP}.app" "/Applications/Expedient Cowork.app"; do
    [ -d "$candidate" ] && APP="$candidate" && break
done

if [ -z "$APP" ] || [ ! -d "$APP" ]; then
    echo "  $FAIL No app found in /Applications"
else
    echo "  $PASS Installed: $APP"
    RES="$APP/Contents/Resources"

    # Icon check
    PLIST_ICON=$(defaults read "$APP/Contents/Info.plist" CFBundleIconFile 2>/dev/null || echo 'NOT SET')
    echo "  Info.plist CFBundleIconFile: $PLIST_ICON"

    if [ -f "$RES/$PLIST_ICON" ]; then
        ICON_SIZE=$(ls -lh "$RES/$PLIST_ICON" | awk '{print $5}')
        echo "  $PASS $PLIST_ICON exists ($ICON_SIZE)"

        # Is it the Electron default or custom?
        ICON_MD5=$(md5 -q "$RES/$PLIST_ICON" 2>/dev/null)
        ELECTRON_ICNS=$(find "$BD/node_modules" -path "*/electron/dist/Electron.app/Contents/Resources/electron.icns" 2>/dev/null | head -1)
        if [ -n "$ELECTRON_ICNS" ]; then
            DEFAULT_MD5=$(md5 -q "$ELECTRON_ICNS" 2>/dev/null)
            if [ "$ICON_MD5" = "$DEFAULT_MD5" ]; then
                echo "  $FAIL ICON IS THE DEFAULT ELECTRON ICON (hash matches)"
                echo "     FIX: The .icns creation or replacement failed."
                echo "     Run: see icon fix section below"
            else
                echo "  $PASS Icon is custom (hash differs from default)"
            fi
        fi
    else
        echo "  $FAIL $PLIST_ICON is MISSING from Resources"
    fi

    # List all icns
    echo "  All .icns in Resources:"
    find "$RES" -name "*.icns" 2>/dev/null | while read f; do
        echo "    $(basename "$f"): $(ls -lh "$f" | awk '{print $5}')"
    done
fi
echo ""

# ==================================================================
echo "=== 7. Running Processes ==="
ps aux | grep -E "opencode|bun.*server|Expedient|Cowork" | grep -v grep | awk '{printf "  PID %-6s %s\n", $2, $11}' | head -5
echo ""

# ==================================================================
echo "=== 8. Server API Tests (CRITICAL) ==="
WEB_PORT=$(lsof -i -P 2>/dev/null | grep bun | grep LISTEN | awk '{print $9}' | sed 's/.*://' | head -1)
if [ -z "$WEB_PORT" ]; then
    echo "  $FAIL Bun web server NOT RUNNING"
    echo "     FIX: Open the app or run: cd $BD && bun packages/web/server/index.js"
else
    echo "  Bun web server: port $WEB_PORT"

    # Test 1: /api/config/providers (what the SDK actually calls)
    echo ""
    echo "  --- GET /api/config/providers (SDK endpoint) ---"
    SDK_RESP=$(curl -s -m 10 "http://localhost:$WEB_PORT/api/config/providers" 2>/dev/null)
    if [ -z "$SDK_RESP" ]; then
        echo "  $FAIL No response (timeout or error)"
    else
        echo "$SDK_RESP" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    if isinstance(d, dict):
        keys = list(d.keys())
        print(f'  Response keys: {keys}')
        # Check 'providers' key (what SDK returns)
        provs = d.get('providers', d.get('all', []))
        if isinstance(provs, list):
            total = len(provs)
            config_provs = [p for p in provs if p.get('source') == 'config']
            print(f'  Total providers: {total}')
            print(f'  Config-sourced: {len(config_provs)}')
            if total > 10 and len(config_provs) <= 5:
                print(f'  $FAIL SERVER FILTER NOT WORKING: {total} providers returned (should be {len(config_provs)})')
                print(f'     The server should filter to only config providers')
            elif len(config_provs) == 0 and total > 0:
                # Check if source field exists at all
                has_source = any('source' in p for p in provs[:5])
                if not has_source:
                    print(f'  $WARN Providers have no \"source\" field — filter cannot work')
                    print(f'     This endpoint may not include source info')
                else:
                    print(f'  $FAIL No config providers found among {total}')
            for p in config_provs:
                models = list(p.get('models', {}).keys()) if isinstance(p.get('models'), dict) else p.get('models', [])
                print(f'    {p[\"id\"]}: {p.get(\"name\",\"?\")} ({len(models)} models, source={p.get(\"source\")})')
        defaults = d.get('default', {})
        if defaults:
            print(f'  Defaults: {defaults}')
    elif isinstance(d, list):
        total = len(d)
        config_provs = [p for p in d if p.get('source') == 'config']
        print(f'  Response is array: {total} providers ({len(config_provs)} config-sourced)')
    else:
        print(f'  Unexpected type: {type(d).__name__}')
except Exception as e:
    print(f'  $FAIL Parse error: {e}')
    print(f'  Raw (first 200 chars): {sys.stdin.read()[:200]}')
" 2>/dev/null
    fi

    # Test 2: /api/provider (raw Go backend, for comparison)
    echo ""
    echo "  --- GET /api/provider (Go backend endpoint) ---"
    curl -s -m 10 "http://localhost:$WEB_PORT/api/provider" 2>/dev/null | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    if isinstance(d, dict):
        provs = d.get('all', d.get('providers', []))
        total = len(provs)
        config_provs = [p for p in provs if p.get('source') == 'config']
        print(f'  Total: {total}, Config-sourced: {len(config_provs)}')
        for p in config_provs:
            print(f'    {p[\"id\"]}: {p.get(\"name\")} ({len(p.get(\"models\",{}))} models)')
    elif isinstance(d, list):
        print(f'  Array of {len(d)} providers')
except Exception as e:
    print(f'  Error: {e}')
" 2>/dev/null

    # Test 3: Direct API test
    echo ""
    echo "  --- Direct API test (Expedient gateway) ---"
    API_KEY=$(python3 -c "import json; print(json.load(open('$HOME/.config/opencode/opencode.json'))['provider'][list(json.load(open('$HOME/.config/opencode/opencode.json'))['provider'].keys())[0]]['options']['apiKey'])" 2>/dev/null)
    API_URL=$(python3 -c "import json; print(json.load(open('$HOME/.config/opencode/opencode.json'))['provider'][list(json.load(open('$HOME/.config/opencode/opencode.json'))['provider'].keys())[0]]['options']['baseURL'])" 2>/dev/null)
    DEFAULT_MODEL=$(python3 -c "import json; print(json.load(open('$HOME/.config/opencode/opencode.json')).get('model',''))" 2>/dev/null)
    if [ -n "$API_KEY" ] && [ -n "$API_URL" ]; then
        API_RESP=$(curl -s -m 10 -X POST "${API_URL}/chat/completions" \
          -H "Authorization: Bearer $API_KEY" \
          -H "Content-Type: application/json" \
          -d "{\"model\":\"$DEFAULT_MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"Say OK\"}],\"max_tokens\":5}" 2>/dev/null)
        echo "$API_RESP" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    if 'choices' in d:
        print(f'  $PASS API works: \"{d[\"choices\"][0][\"message\"][\"content\"]}\"')
    elif 'error' in d:
        print(f'  $FAIL API error: {d[\"error\"]}')
    else:
        print(f'  $WARN Unknown response: {str(d)[:100]}')
except:
    print(f'  $FAIL Not JSON or timeout')
" 2>/dev/null
    else
        echo "  $WARN Could not extract API credentials from config"
    fi

    # Test 4: Agent list
    echo ""
    echo "  --- Agent list ---"
    AGENT_RESP=$(curl -s -m 10 "http://localhost:$WEB_PORT/api/agent" 2>/dev/null)
    echo "$AGENT_RESP" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    if isinstance(d, list):
        visible = [a for a in d if not a.get('hidden') and not a.get('options',{}).get('hidden')]
        internal = [a for a in d if a.get('hidden') or a.get('options',{}).get('hidden')]
        print(f'  Total agents: {len(d)} ({len(visible)} visible, {len(internal)} internal)')
        for a in visible:
            print(f'    {a.get(\"name\",\"?\")}: model={a.get(\"model\",\"?\")}')
        if len(visible) == 0:
            print(f'  $WARN No visible agents — oh-my-opencode plugin may not be loaded')
    elif isinstance(d, dict):
        print(f'  Response keys: {list(d.keys())}')
    else:
        print(f'  Unexpected: {type(d).__name__}')
except Exception as e:
    print(f'  Error: {e}')
" 2>/dev/null
fi
echo ""

# ==================================================================
echo "=== 9. Settings ==="
for DIR in "$HOME/.config/sf-steward" "$HOME/.config/openchamber"; do
    SETTINGS="$DIR/settings.json"
    if [ -f "$SETTINGS" ]; then
        python3 -c "
import json
s = json.load(open('$SETTINGS'))
print(f'  {\"$SETTINGS\"}:')
print(f'    defaultModel: {s.get(\"defaultModel\", \"NOT SET\")}')
print(f'    darkThemeId: {s.get(\"darkThemeId\", \"NOT SET\")}')
" 2>/dev/null
    fi
done
echo ""

# ==================================================================
echo "=== 10. Branding ==="
if [ -f "$HOME/.cowork-branding.json" ]; then
    echo "  $PASS $(cat "$HOME/.cowork-branding.json")"
else
    echo "  $WARN ~/.cowork-branding.json MISSING"
fi
echo ""

# ==================================================================
echo "=== 11. Sandbox (CLAUDE.md) ==="
PROJ_DIR=""
[ -n "$BRAND_APP" ] && [ -d "$HOME/$BRAND_APP Projects" ] && PROJ_DIR="$HOME/$BRAND_APP Projects"
if [ -n "$PROJ_DIR" ]; then
    echo "  $PASS Project dir: $PROJ_DIR"
    [ -f "$PROJ_DIR/CLAUDE.md" ] && echo "  $PASS CLAUDE.md: $(wc -l < "$PROJ_DIR/CLAUDE.md" | tr -d ' ') lines" || echo "  $WARN CLAUDE.md missing in project dir"
else
    echo "  $WARN No project directory found"
fi
echo ""

# ==================================================================
echo "=== 12. Icon Fix (if needed) ==="
echo "  To manually fix the dock icon:"
echo "    1. Find your icon.png (512x512+ square PNG)"
echo "    2. Run these commands:"
echo "       ICONSET=\$(mktemp -d)/App.iconset && mkdir -p \"\$ICONSET\""
echo "       for s in 16 32 64 128 256 512 1024; do sips -z \$s \$s icon.png --out \"\$ICONSET/icon_\${s}x\${s}.png\" >/dev/null 2>&1; done"
echo "       iconutil -c icns \"\$ICONSET\" -o custom.icns"
echo "       cp custom.icns \"$APP/Contents/Resources/\$(defaults read \"$APP/Contents/Info.plist\" CFBundleIconFile 2>/dev/null)\""
echo "       sudo rm -rf /Library/Caches/com.apple.iconservices.store && killall Dock"
echo ""

echo "============================================================"
echo "  Diagnostic complete."
echo "============================================================"
