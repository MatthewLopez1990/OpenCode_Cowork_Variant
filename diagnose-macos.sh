#!/bin/bash
echo "=== OpenCode Cowork macOS Diagnostic ==="
echo ""
echo "1. OpenCode binary:"
echo "   which: $(which opencode 2>/dev/null || echo 'NOT IN PATH')"
echo "   ~/.opencode/bin/opencode: $(ls ~/.opencode/bin/opencode 2>/dev/null && echo 'EXISTS' || echo 'MISSING')"
echo "   ~/.local/bin/opencode: $(ls ~/.local/bin/opencode 2>/dev/null && echo 'EXISTS (may override!)' || echo 'not present')"
if [ -f ~/.opencode/bin/opencode ]; then
    echo "   version: $(~/.opencode/bin/opencode --version 2>&1)"
    echo "   type: $(file ~/.opencode/bin/opencode 2>/dev/null | grep -o 'Mach-O.*')"
    echo "   size: $(ls -lh ~/.opencode/bin/opencode | awk '{print $5}')"
fi
if [ -f ~/.local/bin/opencode ]; then
    echo "   ~/.local/bin/opencode size: $(ls -lh ~/.local/bin/opencode | awk '{print $5}')"
    echo "   content (if wrapper): $(head -3 ~/.local/bin/opencode 2>/dev/null)"
fi
echo ""

echo "2. Config file:"
CONFIG="$HOME/.config/opencode/opencode.json"
if [ -f "$CONFIG" ]; then
    echo "   EXISTS ($(ls -lh "$CONFIG" | awk '{print $5}'))"
    python3 -c "
import json
cfg = json.load(open('$CONFIG'))
for n,p in cfg.get('provider',{}).items():
    print(f'   Provider: {n}')
    print(f'     baseURL: {p.get(\"options\",{}).get(\"baseURL\")}')
    ak = p.get('options',{}).get('apiKey','')
    print(f'     apiKey: {ak[:10]}... ({len(ak)} chars)')
    print(f'     models: {len(p.get(\"models\",{}))}')
print(f'   Default model: {cfg.get(\"model\")}')
print(f'   Plugin: {cfg.get(\"plugin\")}')
" 2>/dev/null
else
    echo "   MISSING"
fi
echo ""

echo "3. npm SDK:"
echo "   @ai-sdk/openai-compatible: $(ls ~/.config/opencode/node_modules/@ai-sdk/openai-compatible/package.json 2>/dev/null && echo 'INSTALLED' || echo 'MISSING')"
echo "   @opencode-ai/plugin: $(ls ~/.config/opencode/node_modules/@opencode-ai/plugin/package.json 2>/dev/null && echo 'INSTALLED' || echo 'MISSING')"
echo ""

echo "4. Build directory:"
echo "   exists: $(ls -d ~/.opencode-cowork-build 2>/dev/null && echo 'YES' || echo 'NO')"
echo "   config in build: $(ls ~/.opencode-cowork-build/opencode.json 2>/dev/null && echo 'YES' || echo 'NO')"
echo "   CLAUDE_TEMPLATE: $(ls ~/.opencode-cowork-build/packages/web/server/CLAUDE_TEMPLATE.md 2>/dev/null && echo 'YES' || echo 'NO')"
echo ""

echo "5. App:"
echo "   installed: $(ls -d '/Applications/Expedient Cowork.app' 2>/dev/null && echo 'YES' || echo 'NO')"
echo "   icon.icns: $(ls '/Applications/Expedient Cowork.app/Contents/Resources/icon.icns' 2>/dev/null && echo 'YES' || echo 'MISSING')"
echo "   electron.icns: $(ls '/Applications/Expedient Cowork.app/Contents/Resources/electron.icns' 2>/dev/null && echo 'YES (DEFAULT)' || echo 'not present')"
echo ""

echo "6. Running processes:"
ps aux | grep -E "opencode.*serve|bun.*server" | grep -v grep | awk '{print "   " $11, $12, $13}' | head -3
echo ""

echo "7. Server response (if running):"
WEB_PORT=$(lsof -i -P 2>/dev/null | grep bun | grep LISTEN | awk '{print $9}' | sed 's/.*://' | head -1)
if [ -n "$WEB_PORT" ]; then
    echo "   Web port: $WEB_PORT"
    RESP=$(curl -s "http://localhost:$WEB_PORT/api/provider" 2>/dev/null)
    echo "$RESP" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    if isinstance(d, dict) and 'all' in d:
        exp = [p for p in d['all'] if 'expedient' in p.get('id','').lower()]
        print(f'   Total providers: {len(d[\"all\"])}')
        if exp:
            print(f'   EXPEDIENT: LOADED ({len(exp[0].get(\"models\",{}))} models)')
        else:
            print('   EXPEDIENT: NOT FOUND')
    elif isinstance(d, dict) and 'error' in d:
        print(f'   Error: {d[\"error\"]}')
    else:
        print(f'   Response type: {type(d).__name__}')
except:
    print('   Could not parse response')
" 2>/dev/null
else
    echo "   Not running"
fi
echo ""
echo "=== Done ==="
