#!/bin/sh
# Smoke tests for luau-lsp-wrapper.sh. No network needed: the Roblox scenario
# pre-seeds the cache and a fresh refresh stamp so the wrapper skips curl.
set -eu

WRAPPER=$(cd "$(dirname "$0")/.." && pwd)/plugins/luau-lsp/bin/luau-lsp-wrapper.sh
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

# Stub luau-lsp that records its argv instead of serving LSP.
STUB_DIR="$TMP/stub-bin"
mkdir -p "$STUB_DIR"
cat > "$STUB_DIR/luau-lsp" <<'EOF'
#!/bin/sh
if [ "${1:-}" = "--version" ]; then
  echo "1.68.1"
  exit 0
fi
printf '%s\n' "$@" > "$ARGS_OUT"
EOF
chmod +x "$STUB_DIR/luau-lsp"

# Isolate from the real machine: private cache and HOME (no toolchain shims).
export XDG_CACHE_HOME="$TMP/cache"
export HOME="$TMP/home"
mkdir -p "$HOME"
BASE_PATH="/usr/bin:/bin"

# 1. No binary anywhere -> clear failure
mkdir -p "$TMP/plain"
if (cd "$TMP/plain" && PATH="$BASE_PATH" "$WRAPPER" 2>/dev/null); then
  fail "expected failure when luau-lsp is missing"
fi

# 2. Plain Luau project -> lsp mode with no definition args
export ARGS_OUT="$TMP/args-plain"
(cd "$TMP/plain" && PATH="$STUB_DIR:$BASE_PATH" "$WRAPPER")
[ "$(cat "$ARGS_OUT")" = "lsp" ] || fail "plain mode args: $(cat "$ARGS_OUT")"

# 3. Roblox project, marker in a parent dir -> definitions + docs passed
mkdir -p "$TMP/roblox/src"
touch "$TMP/roblox/wally.toml"
CACHE="$XDG_CACHE_HOME/claude-luau-lsp"
mkdir -p "$CACHE"
echo "-- stub types" > "$CACHE/globalTypes-1.68.1.d.luau"
echo "{}" > "$CACHE/api-docs.json"
touch "$CACHE/last-refresh"
export ARGS_OUT="$TMP/args-roblox"
(cd "$TMP/roblox/src" && PATH="$STUB_DIR:$BASE_PATH" "$WRAPPER")
grep -q -- "--definitions=$CACHE/globalTypes-1.68.1.d.luau" "$ARGS_OUT" \
  || fail "missing --definitions: $(cat "$ARGS_OUT")"
grep -q -- "--docs=$CACHE/api-docs.json" "$ARGS_OUT" \
  || fail "missing --docs: $(cat "$ARGS_OUT")"

# 4. LUAU_LSP_BIN override is used even with an empty PATH lookup
cp "$STUB_DIR/luau-lsp" "$TMP/override-lsp"
export ARGS_OUT="$TMP/args-override"
(cd "$TMP/plain" && PATH="$BASE_PATH" LUAU_LSP_BIN="$TMP/override-lsp" "$WRAPPER")
[ "$(cat "$ARGS_OUT")" = "lsp" ] || fail "override args: $(cat "$ARGS_OUT")"

# 5. Project-local bin/luau-lsp found without a PATH entry
mkdir -p "$TMP/plain/bin"
cp "$STUB_DIR/luau-lsp" "$TMP/plain/bin/luau-lsp"
export ARGS_OUT="$TMP/args-local"
(cd "$TMP/plain" && PATH="$BASE_PATH" "$WRAPPER")
[ "$(cat "$ARGS_OUT")" = "lsp" ] || fail "project-local args: $(cat "$ARGS_OUT")"

# 6. Windows-style toolchain install: only luau-lsp.exe exists (rokit dir)
mkdir -p "$TMP/exe" "$HOME/.rokit/bin"
cp "$STUB_DIR/luau-lsp" "$HOME/.rokit/bin/luau-lsp.exe"
export ARGS_OUT="$TMP/args-exe"
(cd "$TMP/exe" && PATH="$BASE_PATH" "$WRAPPER")
[ "$(cat "$ARGS_OUT")" = "lsp" ] || fail ".exe probe args: $(cat "$ARGS_OUT")"
rm -rf "$HOME/.rokit"

echo "all smoke tests passed"
