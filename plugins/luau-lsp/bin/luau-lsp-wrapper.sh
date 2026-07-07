#!/bin/sh
# Wrapper for luau-lsp: if the workspace looks like a Roblox project, fetch and
# pass Roblox API type definitions + docs; otherwise run plain Luau mode.
set -u

if ! command -v luau-lsp >/dev/null 2>&1; then
  echo "luau-lsp not found on PATH. Install it: https://github.com/JohnnyMorganz/luau-lsp/releases" >&2
  exit 1
fi

is_roblox_project() {
  # Rojo project file, Rojo sourcemap, or Wally manifest = Roblox project
  for f in *.project.json; do
    [ -e "$f" ] && return 0
  done
  [ -f sourcemap.json ] || [ -f wally.toml ]
}

if is_roblox_project; then
  CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/claude-luau-lsp"
  TYPES="$CACHE/globalTypes.d.luau"
  DOCS="$CACHE/api-docs.json"
  mkdir -p "$CACHE"

  # Download once, then cache. On failure fall back gracefully (plain Luau mode).
  if [ ! -s "$TYPES" ]; then
    curl -fsSL --max-time 30 -o "$TYPES" \
      "https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau" \
      || rm -f "$TYPES"
  fi
  if [ ! -s "$DOCS" ]; then
    curl -fsSL --max-time 30 -o "$DOCS" \
      "https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/api-docs/en-us.json" \
      || rm -f "$DOCS"
  fi

  set --
  [ -s "$TYPES" ] && set -- "$@" "--definitions=$TYPES"
  [ -s "$DOCS" ] && set -- "$@" "--docs=$DOCS"
  exec luau-lsp lsp "$@"
fi

# ponytail: plain Luau mode — no defs needed; luau-lsp ships builtin Luau globals
exec luau-lsp lsp
