#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0

pass() { ((PASS++)); echo "  PASS: $1"; }
fail() { ((FAIL++)); echo "  FAIL: $1 — $2"; }

assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        pass "$desc"
    else
        fail "$desc" "expected '$expected', got '$actual'"
    fi
}

assert_contains() {
    local desc="$1" needle="$2" haystack="$3"
    if echo "$haystack" | grep -qF "$needle"; then
        pass "$desc"
    else
        fail "$desc" "expected to contain '$needle'"
    fi
}

# ── plugin.json validation ──────────────────────────────────────────

echo "plugin.json"
python3 -c "import json; d=json.load(open('plugin.json')); assert d['id']=='webcamViewer'; assert d['name']=='Webcam Viewer'" \
    && pass "valid JSON with correct id and name" \
    || fail "plugin.json" "invalid or wrong id/name"

python3 -c "
import json
d = json.load(open('plugin.json'))
required = ['id','name','description','version','author','type','license','component','settings','requires','permissions']
missing = [f for f in required if f not in d]
assert not missing, f'missing fields: {missing}'
" && pass "all required fields present" \
  || fail "plugin.json" "missing required fields"

# ── version from plugin.json ───────────────────────────────────────

echo "version"
VERSION=$(jq -r .version plugin.json)
if echo "$VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    pass "semver format ($VERSION)"
else
    fail "plugin.json version" "'$VERSION' is not valid semver"
fi

# ── QML file references ─────────────────────────────────────────────

echo "file references"
COMPONENT=$(python3 -c "import json; print(json.load(open('plugin.json'))['component'])")
SETTINGS=$(python3 -c "import json; print(json.load(open('plugin.json'))['settings'])")
COMPONENT="${COMPONENT#./}"
SETTINGS="${SETTINGS#./}"

[ -f "$COMPONENT" ] && pass "component file exists ($COMPONENT)" || fail "component" "$COMPONENT not found"
[ -f "$SETTINGS" ] && pass "settings file exists ($SETTINGS)" || fail "settings" "$SETTINGS not found"

# ── pluginId consistency ─────────────────────────────────────────────

echo "pluginId consistency"
EXPECTED_ID=$(python3 -c "import json; print(json.load(open('plugin.json'))['id'])")

QML_ID=$(grep -oP 'pluginId:\s*"\K[^"]+' "$COMPONENT")
assert_eq "main QML pluginId matches plugin.json" "$EXPECTED_ID" "$QML_ID"

SETTINGS_ID=$(grep -oP 'pluginId:\s*"\K[^"]+' "$SETTINGS")
assert_eq "settings QML pluginId matches plugin.json" "$EXPECTED_ID" "$SETTINGS_ID"

# ── summary ──────────────────────────────────────────────────────────

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
