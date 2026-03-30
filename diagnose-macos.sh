#!/bin/bash
echo "============================================================"
echo "  OpenCode Cowork — Full Diagnostic Report"
echo "  $(date)"
echo "  Machine: $(uname -m) | $(sw_vers -productName 2>/dev/null) $(sw_vers -productVersion 2>/dev/null)"
echo "============================================================"
echo ""

echo "=== 1. OpenCode Binary ==="
echo "  which opencode: $(which opencode 2>/dev/null || echo 'NOT IN PATH')"
echo "  ~/.opencode/bin/opencode: $([ -f ~/.opencode/bin/opencode ] && echo "EXISTS ($(ls -lh ~/.opencode/bin/opencode | awk '{print $5}'))" || echo 'MISSING')"
echo "  ~/.local/bin/opencode: $([ -f ~/.local/bin/opencode ] && echo "EXISTS ($(ls -lh ~/.local/bin/opencode | awk '{print $5}')) — MAY OVERRIDE" || echo 'not present')"
echo "  /usr/local/bin/opencode: $([ -f /usr/local/bin/opencode ] && echo "EXISTS — MAY OVERRIDE" || echo 'not present')"
if [ -f ~/.opencode/bin/opencode ]; then
    echo "  version: $(~/.opencode/bin/opencode --version 2>&1 | head -1)"
    echo "  type: $(file ~/.opencode/bin/opencode 2>/dev/null | grep -o 'Mach-O.*' || echo 'unknown')"
fi
# Check if it's a wrapper script
if [ -f ~/.opencode/bin/opencode ] && [ "$(wc -c < ~/.opencode/bin/opencode)" -lt 1000 ]; then
    echo "  WARNING: Binary is only $(wc -c < ~/.opencode/bin/opencode) bytes — likely a WRAPPER SCRIPT"
    echo "  Content: $(cat ~/.opencode/bin/opencode 2>/dev/null | head -3)"
fi
echo ""

echo "=== 2. Bun ==="
echo "  which bun: $(which bun 2>/dev/null || echo 'NOT IN PATH')"
echo "  version: $(bun --version 2>/dev/null || echo 'NOT FOUND')"
echo ""

echo "=== 3. Config File ==="
CONFIG="$HOME/.config/opencode/opencode.json"
if [ -f "$CONFIG" ]; then
    echo "  Path: $CONFIG"
    echo "  Size: $(ls -lh "$CONFIG" | awk '{print $5}')"
    echo "  First bytes (BOM check): $(xxd "$CONFIG" 2>/dev/null | head -1)"
    python3 -c "
import json
cfg = json.load(open('$CONFIG'))
print(f'  Valid JSON: YES')
print(f'  Top keys: {list(cfg.keys())}')
print(f'  model: {cfg.get(\"model\")}')
print(f'  plugin: {cfg.get(\"plugin\")}')
for n,p in cfg.get('provider',{}).items():
    print(f'  Provider: {n}')
    print(f'    source: config file')
    print(f'    name: {p.get(\"name\")}')
    print(f'    npm: {p.get(\"npm\")}')
    print(f'    baseURL: {p.get(\"options\",{}).get(\"baseURL\")}')
    ak = p.get('options',{}).get('apiKey','')
    print(f'    apiKey: {ak[:10]}... ({len(ak)} chars)')
    print(f'    models: {list(p.get(\"models\",{}).keys())}')
for n,a in cfg.get('agent',{}).items():
    print(f'  Agent {n}: model={a.get(\"model\")}')
" 2>/dev/null || echo "  PARSE ERROR — config is invalid"
else
    echo "  MISSING"
fi
echo ""

echo "=== 4. Config in Build Dir ==="
BUILD_CONFIG="$HOME/.opencode-cowork-build/opencode.json"
if [ -f "$BUILD_CONFIG" ]; then
    echo "  $BUILD_CONFIG: EXISTS ($(ls -lh "$BUILD_CONFIG" | awk '{print $5}'))"
    python3 -c "
import json
cfg = json.load(open('$BUILD_CONFIG'))
for n,p in cfg.get('provider',{}).items():
    print(f'  Provider: {n} — {len(p.get(\"models\",{}))} models')
" 2>/dev/null
else
    echo "  MISSING — OpenCode may not find the config"
fi
echo ""

echo "=== 5. npm SDK ==="
echo "  @ai-sdk/openai-compatible: $([ -d ~/.config/opencode/node_modules/@ai-sdk/openai-compatible ] && echo "INSTALLED ($(python3 -c "import json; print(json.load(open('$HOME/.config/opencode/node_modules/@ai-sdk/openai-compatible/package.json')).get('version','?'))" 2>/dev/null))" || echo 'MISSING')"
echo "  @opencode-ai/plugin: $([ -d ~/.config/opencode/node_modules/@opencode-ai/plugin ] && echo "INSTALLED ($(python3 -c "import json; print(json.load(open('$HOME/.config/opencode/node_modules/@opencode-ai/plugin/package.json')).get('version','?'))" 2>/dev/null))" || echo 'MISSING')"
# Also check build dir
echo "  In build dir node_modules: $([ -d ~/.opencode-cowork-build/node_modules/@ai-sdk ] && echo 'YES' || echo 'NO')"
echo ""

echo "=== 6. Build Directory ==="
BD="$HOME/.opencode-cowork-build"
echo "  exists: $([ -d "$BD" ] && echo 'YES' || echo 'NO')"
echo "  electron/main.cjs: $([ -f "$BD/electron/main.cjs" ] && echo 'YES' || echo 'MISSING')"
echo "  CLAUDE_TEMPLATE.md: $([ -f "$BD/packages/web/server/CLAUDE_TEMPLATE.md" ] && echo 'YES' || echo 'MISSING')"
echo "  ensureSandboxRules in server: $(grep -c 'ensureSandboxRules' "$BD/packages/web/server/index.js" 2>/dev/null || echo '0')"
echo "  provider filter in compiled JS: $(grep -c 'source.*config\|expedient-ai' "$BD/packages/web/dist/assets/index-"*.js 2>/dev/null || echo 'not found')"
echo "  useConfigStore filter: $(grep 'filter.*provider\|\.filter.*source' "$BD/packages/ui/src/stores/useConfigStore.ts" 2>/dev/null | head -1 | tr -d ' ')"
echo "  --- Compiled JS filter snippet ---"
for jsfile in "$BD/packages/web/dist/assets/index-"*.js; do
    if [ -f "$jsfile" ]; then
        echo "  JS bundle: $(basename "$jsfile") ($(ls -lh "$jsfile" | awk '{print $5}'))"
        # Extract 100 chars around any provider filter
        grep -oP '.{0,50}(source.*config|expedient-ai|filter.*provider|processedProviders).{0,50}' "$jsfile" 2>/dev/null | head -5 | while read snippet; do
            echo "    MATCH: ...${snippet}..."
        done
        # Check if the old expedient-ai hardcoded filter is still there
        if grep -q 'expedient-ai' "$jsfile" 2>/dev/null; then
            echo "    WARNING: 'expedient-ai' string found in compiled bundle!"
        fi
        if grep -q '"config"' "$jsfile" 2>/dev/null && grep -q 'source' "$jsfile" 2>/dev/null; then
            echo "    OK: 'source' and 'config' strings found (new filter likely active)"
        fi
    fi
done
echo ""

echo "=== 7. App Bundle ==="
# Try to find the app from branding, then fallback to common names
BRAND_APP=""
if [ -f ~/.cowork-branding.json ]; then
    BRAND_APP=$(python3 -c "import json; print(json.load(open('$HOME/.cowork-branding.json')).get('appName',''))" 2>/dev/null)
fi
APP=""
for candidate in "/Applications/${BRAND_APP}.app" "/Applications/Expedient Cowork.app" "/Applications/SF Steward.app"; do
    if [ -d "$candidate" ]; then
        APP="$candidate"
        break
    fi
done
# Also scan for any cowork-like apps
echo "  All matching apps in /Applications:"
ls -d /Applications/*.app 2>/dev/null | grep -iE "cowork|steward|opencode|openchamber" | while read a; do
    echo "    $a"
done
if [ -n "$APP" ] && [ -d "$APP" ]; then
    echo "  installed: YES"
    echo "  icon.icns: $([ -f "$APP/Contents/Resources/icon.icns" ] && echo "YES ($(ls -lh "$APP/Contents/Resources/icon.icns" | awk '{print $5}'))" || echo 'MISSING')"
    echo "  electron.icns: $([ -f "$APP/Contents/Resources/electron.icns" ] && echo "YES — THIS OVERRIDES custom icon" || echo 'not present (good)')"
    echo "  Info.plist icon: $(defaults read "$APP/Contents/Info.plist" CFBundleIconFile 2>/dev/null || echo 'NOT SET')"
    echo "  All icns files:"
    find "$APP/Contents/Resources/" -name "*.icns" 2>/dev/null | while read f; do
        echo "    $(basename "$f"): $(ls -lh "$f" | awk '{print $5}')"
    done
else
    echo "  NOT INSTALLED"
fi
echo ""

echo "=== 8. CLAUDE.md ==="
# Use branding to find the right project dir
BRAND_APPNAME=""
if [ -f ~/.cowork-branding.json ]; then
    BRAND_APPNAME=$(python3 -c "import json; print(json.load(open('$HOME/.cowork-branding.json')).get('appName',''))" 2>/dev/null)
fi
for projdir in "$HOME/${BRAND_APPNAME} Projects" "$HOME/Expedient Cowork Projects" "$HOME/SF Steward Projects"; do
    if [ -d "$projdir" ]; then
        echo "  Project dir: $projdir — EXISTS"
        echo "  CLAUDE.md: $([ -f "$projdir/CLAUDE.md" ] && echo "EXISTS ($(wc -l < "$projdir/CLAUDE.md" | tr -d ' ') lines)" || echo 'MISSING')"
        break
    fi
done
echo ""

echo "=== 9. Branding ==="
echo "  ~/.cowork-branding.json: $(cat ~/.cowork-branding.json 2>/dev/null || echo 'MISSING')"
echo ""

echo "=== 10. Running Processes ==="
ps aux | grep -E "opencode|bun.*server|Expedient" | grep -v grep | awk '{printf "  PID %-6s %s %s %s\n", $2, $11, $12, $13}' | head -5
echo ""

echo "=== 11. Listening Ports ==="
lsof -i -P 2>/dev/null | grep -E "bun|opencode|node" | grep LISTEN | awk '{printf "  %-10s port %s\n", $1, $9}' | head -5
echo ""

echo "=== 12. Server API Response (CRITICAL) ==="
WEB_PORT=$(lsof -i -P 2>/dev/null | grep bun | grep LISTEN | awk '{print $9}' | sed 's/.*://' | head -1)
if [ -n "$WEB_PORT" ]; then
    echo "  Web server port: $WEB_PORT"

    echo "  --- /api/provider ---"
    PROV_RESP=$(curl -s -m 10 "http://localhost:$WEB_PORT/api/provider" 2>/dev/null)
    echo "$PROV_RESP" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    if isinstance(d, dict) and 'all' in d:
        total = len(d['all'])
        config_provs = [p for p in d['all'] if p.get('source') == 'config']
        exp = [p for p in d['all'] if 'expedient' in p.get('id','').lower()]
        print(f'    Total providers: {total}')
        print(f'    Config-sourced: {len(config_provs)}')
        for p in config_provs:
            print(f'      {p[\"id\"]}: {p[\"name\"]} ({len(p.get(\"models\",{}))} models, source={p.get(\"source\")})')
        if exp and not any(p.get('source')=='config' for p in exp):
            print(f'    WARNING: expedient-ai exists but source={exp[0].get(\"source\")} (not config)')
        defaults = d.get('default', {})
        exp_default = defaults.get('expedient-ai', 'NOT SET')
        print(f'    expedient-ai default model: {exp_default}')
    elif isinstance(d, dict) and 'error' in d:
        print(f'    ERROR: {d[\"error\"]}')
    else:
        print(f'    Unexpected response type: {type(d).__name__}')
except Exception as e:
    print(f'    Parse error: {e}')
" 2>/dev/null

    echo "  --- /api/config (what OpenCode sees) ---"
    curl -s -m 10 "http://localhost:$WEB_PORT/api/config" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    print(f'    Config keys: {list(d.keys())}')
    if 'provider' in d:
        for n,p in d['provider'].items():
            print(f'    Provider in config: {n}')
    if 'model' in d:
        print(f'    Default model: {d[\"model\"]}')
except:
    print('    Could not parse')
" 2>/dev/null

    echo "  --- Direct API test (can we reach Expedient?) ---"
    API_RESP=$(curl -s -m 10 -X POST "https://ai.spencerfane.com/api/chat/completions" \
      -H "Authorization: Bearer $(python3 -c "import json; print(json.load(open('$HOME/.config/opencode/opencode.json'))['provider']['expedient-ai']['options']['apiKey'])" 2>/dev/null)" \
      -H "Content-Type: application/json" \
      -d '{"model":"exp-gpt54-opencode","messages":[{"role":"user","content":"Say OK"}],"max_tokens":5}' 2>/dev/null)
    echo "$API_RESP" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    if 'choices' in d:
        print(f'    API WORKS: \"{d[\"choices\"][0][\"message\"][\"content\"]}\"')
    elif 'error' in d:
        print(f'    API ERROR: {d[\"error\"]}')
    else:
        print(f'    Unknown response: {str(d)[:100]}')
except:
    print(f'    Not JSON or timeout')
" 2>/dev/null
else
    echo "  Web server NOT RUNNING"
fi
echo ""

echo "=== 13. Settings (what theme/model the UI uses) ==="
SETTINGS="$HOME/.config/openchamber/settings.json"
if [ -f "$SETTINGS" ]; then
    python3 -c "
import json
s = json.load(open('$SETTINGS'))
print(f'  defaultModel: {s.get(\"defaultModel\", \"NOT SET\")}')
print(f'  darkThemeId: {s.get(\"darkThemeId\", \"NOT SET\")}')
print(f'  activeProjectId: {s.get(\"activeProjectId\", \"NOT SET\")}')
" 2>/dev/null
else
    echo "  $SETTINGS: MISSING"
fi
echo ""

echo "=== 14. PATH ==="
echo "  \$PATH entries with opencode:"
echo "$PATH" | tr ':' '\n' | grep -i opencode | while read p; do
    echo "    $p: $([ -d "$p" ] && echo 'EXISTS' || echo 'NOT FOUND')"
done
echo ""

echo "=== 15. Asset Files ==="
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
echo "  assets/icon.png: $([ -f "$REPO_DIR/assets/icon.png" ] && echo "$(ls -lh "$REPO_DIR/assets/icon.png" | awk '{print $5}') — $(file "$REPO_DIR/assets/icon.png" | grep -o 'PNG image.*')" || echo 'MISSING')"
echo "  assets/Icon.png: $([ -f "$REPO_DIR/assets/Icon.png" ] && echo "$(ls -lh "$REPO_DIR/assets/Icon.png" | awk '{print $5}')" || echo 'not present')"
echo "  assets/logo.png: $([ -f "$REPO_DIR/assets/logo.png" ] && echo "$(ls -lh "$REPO_DIR/assets/logo.png" | awk '{print $5}') — $(file "$REPO_DIR/assets/logo.png" | grep -o 'PNG image.*')" || echo 'MISSING')"
echo "  assets/Logo.png: $([ -f "$REPO_DIR/assets/Logo.png" ] && echo "$(ls -lh "$REPO_DIR/assets/Logo.png" | awk '{print $5}')" || echo 'not present')"
echo ""

echo "=== 16. Raw Provider API Response (first 80 lines) ==="
if [ -n "$WEB_PORT" ]; then
    curl -s -m 10 "http://localhost:$WEB_PORT/api/provider" 2>/dev/null | python3 -m json.tool 2>/dev/null | head -80
else
    echo "  Web server not running — skipped"
fi
echo ""

echo "=== 17. Electron main.cjs Config ==="
if [ -f "$BD/electron/main.cjs" ]; then
    echo "  App name from main.cjs:"
    grep -i "appName\|productName\|app\.name\|BrowserWindow\|loadURL" "$BD/electron/main.cjs" 2>/dev/null | head -5 | while read line; do
        echo "    $line"
    done
    echo "  Icon references in main.cjs:"
    grep -i "icon\|\.icns\|\.ico\|\.png" "$BD/electron/main.cjs" 2>/dev/null | head -5 | while read line; do
        echo "    $line"
    done
else
    echo "  MISSING"
fi
echo ""

echo "=== 18. Cowork Logo in Build ==="
echo "  packages/web/public/cowork-logo.png: $([ -f "$BD/packages/web/public/cowork-logo.png" ] && echo "EXISTS ($(ls -lh "$BD/packages/web/public/cowork-logo.png" | awk '{print $5}'))" || echo 'MISSING')"
echo "  packages/web/public/favicon.ico: $([ -f "$BD/packages/web/public/favicon.ico" ] && echo "EXISTS ($(ls -lh "$BD/packages/web/public/favicon.ico" | awk '{print $5}'))" || echo 'MISSING or default')"
echo "  dist/cowork-logo.png: $([ -f "$BD/packages/web/dist/cowork-logo.png" ] && echo "EXISTS" || echo 'MISSING (not copied to dist!)')"
echo "  Icon in extraResources: $(ls "$BD/build/"*.icns 2>/dev/null | head -1 || echo 'NONE')"
echo ""

echo "============================================================"
echo "  Diagnostic complete. Share this entire output."
echo "============================================================"
