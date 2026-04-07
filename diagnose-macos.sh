#!/bin/bash
# diagnose-macos.sh — Comprehensive diagnostic with root cause analysis
# Run while the app is open for best results.

P="[PASS]"
F="[FAIL]"
W="[WARN]"
I="[INFO]"

echo "============================================================"
echo "  OpenCode Cowork — Full Diagnostic Report"
echo "  $(date)"
echo "  Machine: $(uname -m) | $(sw_vers -productName 2>/dev/null) $(sw_vers -productVersion 2>/dev/null)"
echo "============================================================"
echo ""

# ============================================================
echo "=== 1. OPENCODE BINARY ==="
OC="$HOME/.opencode/bin/opencode"
if [ -f "$OC" ]; then
    BYTES=$(wc -c < "$OC" 2>/dev/null || echo 0)
    VER=$("$OC" --version 2>&1 | head -1)
    if [ "$BYTES" -lt 1000000 ]; then
        echo "  $F Binary is only $BYTES bytes — wrapper script, not real binary"
        echo "     WHY: The install script at https://opencode.ai/install may have"
        echo "          created a shell wrapper instead of downloading the real binary."
        echo "     FIX: rm '$OC' && curl -fsSL https://opencode.ai/install | bash"
    else
        echo "  $P OpenCode $VER ($(ls -lh "$OC" | awk '{print $5}'), Mach-O arm64)"
    fi
else
    echo "  $F Binary not found at $OC"
    echo "     FIX: curl -fsSL https://opencode.ai/install | bash"
fi
for shadow in "$HOME/.local/bin/opencode" "/usr/local/bin/opencode"; do
    [ -f "$shadow" ] && echo "  $W Shadow binary at $shadow may override — delete it"
done
echo ""

# ============================================================
echo "=== 2. BUN ==="
if command -v bun &>/dev/null; then
    echo "  $P Bun $(bun --version) at $(which bun)"
else
    echo "  $F Bun not installed"
    echo "     FIX: curl -fsSL https://bun.sh/install | bash"
fi
echo ""

# ============================================================
echo "=== 3. CONFIG FILE (opencode.json) ==="
CONFIG="$HOME/.config/opencode/opencode.json"
if [ ! -f "$CONFIG" ]; then
    echo "  $F Config file missing: $CONFIG"
    echo "     WHY: Install script failed or didn't run Step 4."
    echo "     FIX: Re-run the installer."
else
    # BOM check
    FIRST_BYTES=$(xxd -l 3 "$CONFIG" 2>/dev/null | awk '{print $2$3}')
    if echo "$FIRST_BYTES" | grep -qi "efbb" 2>/dev/null; then
        echo "  $F UTF-8 BOM detected — Go JSON parser will crash"
        echo "     FIX: Remove BOM: sed -i '' '1s/^\xEF\xBB\xBF//' '$CONFIG'"
    fi

    python3 -c "
import json, sys
try:
    cfg = json.load(open('$CONFIG'))
    print('  $P Valid JSON')

    # Crash-causing keys
    bad = [k for k in cfg if k not in ('\$schema','plugin','model','agent','provider')]
    if bad:
        print(f'  $F CRASH RISK: Keys {bad} will crash the OpenCode Go backend')
        print(f'     WHY: OpenCode only accepts: \$schema, plugin, model, agent, provider')
        print(f'     FIX: Remove these keys from the config file')

    # Provider
    providers = cfg.get('provider', {})
    if not providers:
        print(f'  $F No providers configured')
        print(f'     FIX: Re-run the installer with your API details')
    for name, p in providers.items():
        models = list(p.get('models', {}).keys())
        ak = p.get('options',{}).get('apiKey','')
        bu = p.get('options',{}).get('baseURL','')
        npm = p.get('npm','')
        print(f'  Provider key: \"{name}\"')
        print(f'    Display name: {p.get(\"name\",\"?\")}')
        print(f'    npm: {npm}')
        print(f'    baseURL: {bu}')
        print(f'    apiKey: {ak[:12]}... ({len(ak)} chars)' if ak else f'    $F apiKey: MISSING')
        print(f'    Models ({len(models)}): {models}')
        if not ak: print(f'  $F No API key — model calls will fail')
        if not bu: print(f'  $F No baseURL — model calls will fail')
        if not npm: print(f'  $F No npm package — provider cannot load')

    # Default model
    model = cfg.get('model','')
    print(f'  Default model: {model}')
    found_in = None
    for name, p in providers.items():
        if model in p.get('models', {}):
            found_in = name
    if found_in:
        print(f'    $P Found in provider \"{found_in}\"')
    elif model:
        print(f'    $F Model \"{model}\" not found in any provider!')
        print(f'       WHY: Model ID doesn\\'t match any provider\\'s model list')

    # Plugins
    plugins = cfg.get('plugin', [])
    print(f'  Plugins: {plugins}')

    # Agents
    for name, a in cfg.get('agent', {}).items():
        amodel = a.get('model','')
        print(f'  Agent \"{name}\": model={amodel}')
except Exception as e:
    print(f'  $F Parse error: {e}')
" 2>/dev/null
fi
echo ""

# ============================================================
echo "=== 4. NPM PROVIDER SDK ==="
SDK="$HOME/.config/opencode/node_modules/@ai-sdk/openai-compatible"
PLG="$HOME/.config/opencode/node_modules/@opencode-ai/plugin"
if [ -d "$SDK" ]; then
    VER=$(python3 -c "import json; print(json.load(open('$SDK/package.json')).get('version','?'))" 2>/dev/null)
    echo "  $P @ai-sdk/openai-compatible v$VER"
else
    echo "  $F @ai-sdk/openai-compatible NOT INSTALLED"
    echo "     WHY: The provider can't load without this npm package."
    echo "     FIX: cd ~/.config/opencode && bun add @ai-sdk/openai-compatible"
fi
if [ -d "$PLG" ]; then
    VER=$(python3 -c "import json; print(json.load(open('$PLG/package.json')).get('version','?'))" 2>/dev/null)
    echo "  $P @opencode-ai/plugin v$VER"
else
    echo "  $W @opencode-ai/plugin not installed (oh-my-opencode may not work)"
fi
echo ""

# ============================================================
echo "=== 5. BUILD DIRECTORY ==="
BD="$HOME/.opencode-cowork-build"
if [ ! -d "$BD" ]; then
    echo "  $F Build directory missing: $BD"
    echo "     FIX: Re-run the installer."
else
    echo "  $P Exists"

    # Server
    SRV="$BD/packages/web/server/index.js"
    [ -f "$SRV" ] && echo "  $P Server index.js" || echo "  $F Server index.js MISSING"

    # Provider filter on correct endpoint
    if grep -q '/api/config/providers' "$SRV" 2>/dev/null; then
        echo "  $P Provider filter: intercepts /api/config/providers"
    else
        echo "  $F Provider filter missing or on wrong endpoint"
        echo "     WHY: The SDK calls /api/config/providers, not /api/provider"
        echo "     FIX: git pull in repo, then copy server: cp repo/packages/web/server/index.js $SRV"
    fi

    # CLAUDE_TEMPLATE.md
    [ -f "$BD/packages/web/server/CLAUDE_TEMPLATE.md" ] && echo "  $P CLAUDE_TEMPLATE.md" || echo "  $W CLAUDE_TEMPLATE.md missing"

    # Config in build dir
    [ -f "$BD/opencode.json" ] && echo "  $P opencode.json in build dir" || echo "  $W opencode.json missing from build dir"

    # Compiled React bundle
    MAIN_JS=$(find "$BD/packages/web/dist/assets/" -name "main-*.js" -type f 2>/dev/null | head -1)
    [ -n "$MAIN_JS" ] && echo "  $P Compiled React: $(basename "$MAIN_JS") ($(ls -lh "$MAIN_JS" | awk '{print $5}'))" || echo "  $W No compiled React bundle found"
fi
echo ""

# ============================================================
echo "=== 6. APP BUNDLE ==="
BRAND_APP=""
[ -f "$HOME/.cowork-branding.json" ] && BRAND_APP=$(python3 -c "import json; print(json.load(open('$HOME/.cowork-branding.json')).get('appName',''))" 2>/dev/null)
APP=""
for c in "/Applications/${BRAND_APP}.app"; do
    [ -d "$c" ] && APP="$c" && break
done

if [ -z "$APP" ]; then
    echo "  $F No app found in /Applications"
else
    echo "  $P Installed: $APP"
    RES="$APP/Contents/Resources"
    PLIST_ICON=$(defaults read "$APP/Contents/Info.plist" CFBundleIconFile 2>/dev/null || echo "?")
    echo "  Info.plist CFBundleIconFile: $PLIST_ICON"

    if [ -f "$RES/$PLIST_ICON" ]; then
        ICON_SIZE=$(ls -lh "$RES/$PLIST_ICON" | awk '{print $5}')
        ICON_MD5=$(md5 -q "$RES/$PLIST_ICON" 2>/dev/null)

        # Check if it's the Electron default
        ELECTRON_ICNS=$(find "$BD/node_modules" -path "*/electron/dist/Electron.app/Contents/Resources/electron.icns" 2>/dev/null | head -1)
        DEFAULT_MD5=""
        [ -n "$ELECTRON_ICNS" ] && DEFAULT_MD5=$(md5 -q "$ELECTRON_ICNS" 2>/dev/null)

        if [ -n "$DEFAULT_MD5" ] && [ "$ICON_MD5" = "$DEFAULT_MD5" ]; then
            echo "  $F ICON IS DEFAULT ELECTRON ICON ($ICON_SIZE, hash matches default)"
            echo "     WHY: The install script's iconutil or post-build copy failed."
            echo "     The .icns creation may have errored silently (|| true swallows errors)."
            echo "     FIX: Run these commands:"
            echo "       ISET=\$(mktemp -d)/App.iconset && mkdir -p \"\$ISET\""
            echo "       for s in 16 32 128 256 512; do sips -z \$s \$s ~/OpenCode_Cowork_Variant/assets/icon.png --out \"\$ISET/icon_\${s}x\${s}.png\" >/dev/null 2>&1; done"
            echo "       sips -z 32 32 ~/OpenCode_Cowork_Variant/assets/icon.png --out \"\$ISET/icon_16x16@2x.png\" >/dev/null 2>&1"
            echo "       sips -z 64 64 ~/OpenCode_Cowork_Variant/assets/icon.png --out \"\$ISET/icon_32x32@2x.png\" >/dev/null 2>&1"
            echo "       sips -z 256 256 ~/OpenCode_Cowork_Variant/assets/icon.png --out \"\$ISET/icon_128x128@2x.png\" >/dev/null 2>&1"
            echo "       sips -z 512 512 ~/OpenCode_Cowork_Variant/assets/icon.png --out \"\$ISET/icon_256x256@2x.png\" >/dev/null 2>&1"
            echo "       sips -z 1024 1024 ~/OpenCode_Cowork_Variant/assets/icon.png --out \"\$ISET/icon_512x512@2x.png\" >/dev/null 2>&1"
            echo "       iconutil -c icns \"\$ISET\" -o /tmp/custom.icns && cp /tmp/custom.icns \"$RES/$PLIST_ICON\""
            echo "       sudo rm -rf /Library/Caches/com.apple.iconservices.store && killall Dock"
        else
            echo "  $P Custom icon active ($ICON_SIZE, hash differs from default)"
        fi
    else
        echo "  $F Icon file $PLIST_ICON MISSING from Resources"
    fi
fi
echo ""

# ============================================================
echo "=== 7. SETTINGS & PROJECT ==="
for SDIR in "$HOME/.config/openchamber" "$HOME/.config/sf-steward"; do
    SF="$SDIR/settings.json"
    [ ! -f "$SF" ] && continue
    echo "  $SDIR/settings.json:"
    python3 -c "
import json
s = json.load(open('$SF'))
dm = s.get('defaultModel','NOT SET')
print(f'    defaultModel: {dm}')
projects = s.get('projects', [])
active = s.get('activeProjectId','')
print(f'    projects: {len(projects)}')
for p in projects:
    is_active = ' (ACTIVE)' if p.get('id') == active else ''
    print(f'      {p.get(\"path\",\"?\")}{is_active}')
if not projects:
    print(f'    $F NO PROJECTS — sessions cannot be created!')
    print(f'       WHY: The settings file has no project entries. Without a project,')
    print(f'            the app doesn\\'t know which directory to create sessions in.')
    print(f'       FIX: Re-run the installer (latest version adds project automatically)')
if not active and projects:
    print(f'    $W No activeProjectId set — app may not select a project')
" 2>/dev/null
done
echo ""

# ============================================================
echo "=== 8. BRANDING ==="
if [ -f "$HOME/.cowork-branding.json" ]; then
    echo "  $P $(cat "$HOME/.cowork-branding.json")"
else
    echo "  $W ~/.cowork-branding.json missing"
fi
echo ""

# ============================================================
echo "=== 9. SANDBOX (CLAUDE.md) ==="
if [ -n "$BRAND_APP" ] && [ -d "$HOME/$BRAND_APP Projects" ]; then
    PDIR="$HOME/$BRAND_APP Projects"
    echo "  $P Project dir: $PDIR"
    [ -f "$PDIR/CLAUDE.md" ] && echo "  $P CLAUDE.md: $(wc -l < "$PDIR/CLAUDE.md" | tr -d ' ') lines" || echo "  $W CLAUDE.md missing"
else
    echo "  $W No project directory found"
fi
echo ""

# ============================================================
echo "=== 10. RUNNING PROCESSES ==="
PROCS=$(ps aux | grep -E "opencode|bun.*server|opencode-cowork-build" | grep -v grep)
if [ -z "$PROCS" ]; then
    echo "  $W No app processes running — start the app for full diagnostics"
else
    echo "$PROCS" | awk '{printf "  PID %-6s %s\n", $2, $11}' | head -6
fi
echo ""

# ============================================================
echo "=== 11. SERVER API TESTS ==="
WEB_PORT=$(lsof -i -P 2>/dev/null | grep bun | grep LISTEN | awk '{print $9}' | sed 's/.*://' | head -1)
if [ -z "$WEB_PORT" ]; then
    echo "  $W Bun web server NOT RUNNING — start the app first"
    echo "     Cannot test API endpoints."
else
    echo "  Bun server: port $WEB_PORT"

    # --- Provider endpoint (SDK path) ---
    echo ""
    echo "  --- GET /api/config/providers (SDK endpoint) ---"
    PROV_RESP=$(curl -s -m 10 "http://localhost:$WEB_PORT/api/config/providers" 2>/dev/null)
    echo "$PROV_RESP" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    provs = d.get('providers', d.get('all', []))
    total = len(provs) if isinstance(provs, list) else 0
    config = [p for p in provs if p.get('source') == 'config'] if isinstance(provs, list) else []
    if total == 0:
        print(f'  $F No providers returned')
        print(f'     WHY: OpenCode backend may not be ready or config is invalid')
    elif total > 10 and len(config) < total:
        print(f'  $F Server filter NOT working: {total} providers (should be {len(config)})')
        print(f'     WHY: The /api/config/providers route is not filtering properly')
    else:
        print(f'  $P {total} provider(s) returned ({len(config)} config-sourced)')
    for p in (config if config else provs[:3]):
        models = p.get('models', {})
        mc = len(models) if isinstance(models, dict) else len(models) if isinstance(models, list) else 0
        print(f'    {p.get(\"id\",\"?\")}: {p.get(\"name\",\"?\")} ({mc} models)')
except Exception as e:
    print(f'  $F Parse error: {e}')
" 2>/dev/null

    # --- Agent endpoint ---
    echo ""
    echo "  --- GET /api/agent ---"
    curl -s -m 10 "http://localhost:$WEB_PORT/api/agent" 2>/dev/null | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    if isinstance(d, list):
        visible = [a for a in d if not a.get('hidden') and not a.get('options',{}).get('hidden')]
        print(f'  $P {len(d)} agents ({len(visible)} visible)')
        for a in visible:
            print(f'    {a.get(\"name\",\"?\")}: model={a.get(\"model\",\"?\")}')
        if not visible:
            print(f'  $W No visible agents')
            print(f'     WHY: oh-my-opencode plugin may not have loaded yet')
            print(f'     FIX: Close and reopen the app (plugin loads on startup)')
    else:
        print(f'  $W Unexpected response: {type(d).__name__}')
except:
    print(f'  $F Could not parse agent response')
" 2>/dev/null

    # --- Direct API test ---
    echo ""
    echo "  --- Direct API test ---"
    API_KEY=$(python3 -c "
import json
cfg = json.load(open('$HOME/.config/opencode/opencode.json'))
prov = list(cfg.get('provider',{}).values())[0]
print(prov['options']['apiKey'])
" 2>/dev/null)
    API_URL=$(python3 -c "
import json
cfg = json.load(open('$HOME/.config/opencode/opencode.json'))
prov = list(cfg.get('provider',{}).values())[0]
print(prov['options']['baseURL'])
" 2>/dev/null)
    DEF_MODEL=$(python3 -c "import json; print(json.load(open('$HOME/.config/opencode/opencode.json')).get('model',''))" 2>/dev/null)

    if [ -n "$API_KEY" ] && [ -n "$API_URL" ]; then
        RESP=$(curl -s -m 10 -X POST "${API_URL}/chat/completions" \
          -H "Authorization: Bearer $API_KEY" \
          -H "Content-Type: application/json" \
          -d "{\"model\":\"$DEF_MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"Say OK\"}],\"max_tokens\":5}" 2>/dev/null)
        echo "$RESP" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    if 'choices' in d:
        print(f'  $P API works: \"{d[\"choices\"][0][\"message\"][\"content\"]}\"')
    elif 'error' in d:
        print(f'  $F API error: {d[\"error\"]}')
        print(f'     WHY: API key may be expired or model ID is wrong')
    else:
        print(f'  $W Response: {str(d)[:100]}')
except:
    print(f'  $F Not JSON or timeout — API endpoint may be down')
" 2>/dev/null
    fi

    # --- Model object inspection ---
    echo ""
    echo "  --- Model objects (do they have id/providerID?) ---"
    echo "$PROV_RESP" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    provs = d.get('providers', d.get('all', []))
    for p in provs[:2]:
        models = p.get('models', {})
        if isinstance(models, dict):
            for mid, mobj in list(models.items())[:2]:
                has_id = 'id' in mobj
                has_pid = 'providerID' in mobj
                status = mobj.get('status','?')
                print(f'    {mid}: id={mobj.get(\"id\",\"MISSING\")}, providerID={mobj.get(\"providerID\",\"MISSING\")}, status={status}')
                if not has_id:
                    print(f'    $F Model has no \"id\" field — auto-selection will fail!')
                if not has_pid:
                    print(f'    $F Model has no \"providerID\" — message send will fail!')
        elif isinstance(models, list):
            for m in models[:2]:
                print(f'    {m.get(\"id\",\"MISSING\")}: providerID={m.get(\"providerID\",\"MISSING\")}')
except: print(f'  Could not inspect models')
" 2>/dev/null

    # --- Session + message test ---
    echo ""
    echo "  --- Session creation + message send test ---"
    PROJECT_DIR=""
    [ -n "$BRAND_APP" ] && [ -d "$HOME/$BRAND_APP Projects" ] && PROJECT_DIR="$HOME/$BRAND_APP Projects"
    if [ -z "$PROJECT_DIR" ]; then
        echo "  $W No project directory to test with"
    else
        # Get provider and model IDs
        PROV_ID=$(echo "$PROV_RESP" | python3 -c "
import json, sys
d = json.load(sys.stdin)
provs = d.get('providers', d.get('all', []))
if provs: print(provs[0].get('id',''))
" 2>/dev/null)
        MODEL_ID=$(python3 -c "import json; print(json.load(open('$HOME/.config/opencode/opencode.json')).get('model',''))" 2>/dev/null)
        echo "  Using: provider=$PROV_ID model=$MODEL_ID dir=$PROJECT_DIR"

        # Step 1: Create session
        SESS_RESP=$(curl -s -m 10 -X POST "http://localhost:$WEB_PORT/api/session" \
          -H "Content-Type: application/json" \
          -H "x-opencode-directory: $PROJECT_DIR" \
          -d "{}" 2>/dev/null)
        SESS_ID=$(echo "$SESS_RESP" | python3 -c "import json,sys; print(json.load(sys.stdin).get('id',''))" 2>/dev/null)

        if [ -z "$SESS_ID" ]; then
            echo "  $F Session creation failed"
            echo "  Raw response: $(echo "$SESS_RESP" | head -c 200)"
            echo "     WHY: OpenCode backend rejected the session creation request."
        else
            echo "  $P Session created: ${SESS_ID:0:12}..."

            # Step 2: Send a message
            echo "  Sending test message..."
            # Step 2: Send message and check HTTP status
            echo "  Sending test message..."
            MSG_HTTP=$(curl -s -o /dev/null -w "%{http_code}" -m 30 -X POST "http://localhost:$WEB_PORT/api/session/$SESS_ID/message" \
              -H "Content-Type: application/json" \
              -H "x-opencode-directory: $PROJECT_DIR" \
              -d "{\"parts\":[{\"type\":\"text\",\"text\":\"Say hi\"}],\"providerID\":\"$PROV_ID\",\"modelID\":\"$MODEL_ID\"}" 2>/dev/null)
            if [ "$MSG_HTTP" = "200" ]; then
                echo "  $P Message accepted (HTTP 200 — response comes via SSE)"
            elif [ "$MSG_HTTP" = "503" ] || [ "$MSG_HTTP" = "504" ]; then
                echo "  $F Message failed (HTTP $MSG_HTTP — OpenCode backend unavailable)"
            elif [ -n "$MSG_HTTP" ]; then
                echo "  $F Message failed (HTTP $MSG_HTTP)"
            else
                echo "  $F Message send failed (no HTTP response)"
            fi

            # Step 3: Check SSE stream for actual AI response (wait up to 15s)
            echo "  Checking SSE stream for AI response..."
            SSE_DATA=$(curl -s -m 15 -N "http://localhost:$WEB_PORT/api/event?sessionID=$SESS_ID" \
              -H "Accept: text/event-stream" \
              -H "x-opencode-directory: $PROJECT_DIR" 2>/dev/null | head -c 2000)
            if [ -n "$SSE_DATA" ]; then
                EVENT_COUNT=$(echo "$SSE_DATA" | grep -c "^data:" 2>/dev/null | tr -d '[:space:]' || echo 0)
                HAS_CONTENT=$(echo "$SSE_DATA" | grep -c "content\|assistant\|text" 2>/dev/null | tr -d '[:space:]' || echo 0)
                HAS_ERROR=$(echo "$SSE_DATA" | grep -ci "error" 2>/dev/null | tr -d '[:space:]' || echo 0)
                if [ "$HAS_ERROR" -gt 0 ]; then
                    echo "  $F SSE stream contains errors:"
                    echo "$SSE_DATA" | grep -i "error" | head -3 | while read line; do echo "    $line"; done
                    echo "     WHY: The Go backend accepted the message but failed to call the API."
                    echo "          This usually means the provider npm module can't be loaded or"
                    echo "          the API endpoint rejected the request."
                elif [ "$HAS_CONTENT" -gt 0 ]; then
                    echo "  $P SSE stream has AI content ($EVENT_COUNT events)"
                else
                    echo "  $W SSE stream active but no AI content yet ($EVENT_COUNT events)"
                fi
            else
                echo "  $F SSE stream returned nothing in 15 seconds"
                echo "     WHY: The Go backend may have crashed after accepting the message,"
                echo "          or the model provider (npm module) failed to initialize."
                echo "          Check if @ai-sdk/openai-compatible is in the right location."
            fi

            # Step 4: Check session state after message
            echo "  Checking session state..."
            SESS_STATE=$(curl -s -m 5 "http://localhost:$WEB_PORT/api/session/$SESS_ID" \
              -H "x-opencode-directory: $PROJECT_DIR" 2>/dev/null)
            echo "$SESS_STATE" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    msgs = d.get('messages', [])
    print(f'  Session has {len(msgs)} message(s)')
    for m in msgs[-2:]:
        role = m.get('role','?')
        parts = m.get('parts', [])
        txt = ''
        for p in parts:
            if isinstance(p, dict) and p.get('type') == 'text':
                txt = p.get('text','')[:80]
        if txt:
            print(f'    {role}: {txt}')
        else:
            print(f'    {role}: (no text content)')
except: pass
" 2>/dev/null
        fi
    fi

    # --- OpenCode backend health ---
    echo ""
    echo "  --- OpenCode backend health ---"
    OC_PORT=$(lsof -i -P 2>/dev/null | grep opencode | grep LISTEN | awk '{print $9}' | sed 's/.*://' | head -1)
    if [ -n "$OC_PORT" ]; then
        echo "  OpenCode port: $OC_PORT"
        OC_HEALTH=$(curl -s -m 5 "http://localhost:$OC_PORT/global/health" 2>/dev/null)
        if [ -n "$OC_HEALTH" ]; then
            echo "  $P Backend healthy"
        else
            echo "  $F Backend not responding to health check"
        fi
    else
        echo "  $F OpenCode process not listening on any port"
    fi
fi
echo ""

# ============================================================
echo "=== 12. ASSET FILES ==="
REPO="$(cd "$(dirname "$0")" && pwd)"
for f in icon.png logo.png; do
    ASSET="$REPO/assets/$f"
    if [ -f "$ASSET" ]; then
        W=$(sips -g pixelWidth "$ASSET" 2>/dev/null | awk '/pixelWidth/{print $2}')
        H=$(sips -g pixelHeight "$ASSET" 2>/dev/null | awk '/pixelHeight/{print $2}')
        echo "  $f: $(ls -lh "$ASSET" | awk '{print $5}'), ${W}x${H}"
        if [ "$f" = "icon.png" ]; then
            if [ -z "$W" ] || [ "$W" = "0" ] || echo "$W" | grep -qi "nil" 2>/dev/null; then
                echo "  $F ICON FORMAT INVALID — sips cannot read dimensions"
                echo "     WHY: The file may be a JPEG/WebP/SVG renamed to .png,"
                echo "          or a corrupted PNG. macOS sips can only process"
                echo "          standard PNG, JPEG, TIFF, and BMP files."
                echo "     FIX: Open the file in Preview, Export as PNG, and replace it."
                echo "     Actual format: $(file "$ASSET" 2>/dev/null | sed 's/.*: //')"
            elif [ "$W" -lt 512 ] 2>/dev/null; then
                echo "  $W ICON SMALL (${W}x${H}) — will be upscaled (may look blurry)"
            else
                echo "  $P Icon size OK (${W}x${H})"
            fi
        fi
    else
        echo "  $W $f missing from assets/"
    fi
done
echo ""

echo "============================================================"
echo "  Diagnostic complete."
echo "============================================================"
