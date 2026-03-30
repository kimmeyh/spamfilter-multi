#!/bin/bash
# Helper script for winwright MCP testing
# Usage: source ww-test-helper.sh
# Then: ww_call <tool> '<json_args>'

export WW_SESSION="vZpZDo7vmaLlg22k2Nrshg"
export WW_APP="ac7f314a-c3c2-492b-86a1-8a11d15cc69f"
export WW_CALL_ID=100

ww_call() {
  local tool="$1"
  local args="$2"
  WW_CALL_ID=$((WW_CALL_ID + 1))
  curl -s -X POST http://localhost:8765/mcp \
    -H "Content-Type: application/json" \
    -H "Mcp-Session-Id: $WW_SESSION" \
    -d "{\"jsonrpc\":\"2.0\",\"id\":$WW_CALL_ID,\"method\":\"tools/call\",\"params\":{\"name\":\"$tool\",\"arguments\":$args}}" 2>&1 | grep "^data:" | sed 's/^data: //'
}

ww_click() {
  local selector="$1"
  ww_call "ww_click" "{\"appId\":\"$WW_APP\",\"selector\":\"$selector\"}"
}

ww_tree() {
  local depth="${1:-15}"
  local max="${2:-200}"
  ww_call "ww_dump_tree" "{\"appId\":\"$WW_APP\",\"format\":\"text\",\"maxDepth\":$depth,\"maxElements\":$max,\"compact\":true}" | node -e "
let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{
  try{const r=JSON.parse(d);const t=JSON.parse(r.result.content[0].text);console.log(t.content.replace(/\\\\r\\\\n/g,'\n'));}catch(e){console.log(d);}
})
"
}

ww_screenshot() {
  local path="$1"
  ww_call "ww_screenshot" "{\"appId\":\"$WW_APP\",\"path\":\"$path\"}"
}

echo "WinWright test helper loaded. Session=$WW_SESSION, App=$WW_APP"
