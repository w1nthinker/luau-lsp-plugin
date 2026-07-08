#!/bin/sh
# Wrapper for luau-lsp used by the Claude Code plugin.
#
# - Runs on macOS, Linux, and Windows. Claude Code spawns this script through
#   its shebang on POSIX; on Windows it runs it as `sh <script>` via cmd.exe,
#   so any POSIX sh on PATH (Git for Windows, MSYS2, Cygwin) works.
# - Locates the luau-lsp binary: LUAU_LSP_BIN override, PATH, project-local
#   copies, then well-known toolchain shim directories (rokit/aftman/...);
#   on Windows each location is also probed with an .exe suffix.
# - Detects Roblox projects by walking up from the working directory looking
#   for a Rojo project file, sourcemap.json, or wally.toml.
# - In Roblox mode, supplies cached Roblox API type definitions + docs. Type
#   definitions are pinned to the installed luau-lsp version when detectable
#   (immutable, downloaded once); the API docs refresh in the background at
#   most once a day so a slow network never delays server startup. Downloads
#   are atomic, so an interrupted transfer never corrupts the cache, and
#   offline starts fall back to the cached copies.
set -u

# Under Git Bash/MSYS launched from cmd.exe no profile runs, so /usr/bin may
# be missing from PATH and same-named Windows tools (find.exe) would win.
case ":$PATH:" in
  *:/usr/bin:*) ;;
  *) [ -d /usr/bin ] && PATH="/usr/bin:$PATH" ;;
esac

warn() { echo "luau-lsp plugin: $*" >&2; }

# Nearest ancestor of $PWD containing a Roblox project marker, if any.
find_roblox_root() {
  dir=$PWD
  while :; do
    for f in "$dir"/*.project.json; do
      if [ -e "$f" ]; then
        printf '%s\n' "$dir"
        return 0
      fi
    done
    if [ -f "$dir/sourcemap.json" ] || [ -f "$dir/wally.toml" ]; then
      printf '%s\n' "$dir"
      return 0
    fi
    parent=$(dirname "$dir")
    [ "$parent" = "$dir" ] && return 1
    dir=$parent
  done
}

# Accept $1 only if it actually runs; a broken toolchain shim (e.g. a mise
# shim with no version pinned) is executable yet fails instantly, and picking
# it would crash-loop the server while shadowing a working install. The first
# reject is kept as a fallback in case an unusual binary fails the probe.
try_luau_lsp() {
  if "$1" --version >/dev/null 2>&1; then
    printf '%s\n' "$1"
    return 0
  fi
  [ -n "$FALLBACK_BIN" ] || FALLBACK_BIN=$1
  return 1
}

# Locate the luau-lsp binary. Claude Code may be launched without a login
# shell's PATH (e.g. from the desktop app), so a plain PATH lookup is not
# enough: also probe the project and common toolchain shim directories.
find_luau_lsp() {
  FALLBACK_BIN=""
  if [ -n "${LUAU_LSP_BIN:-}" ]; then
    if [ -x "$LUAU_LSP_BIN" ]; then
      printf '%s\n' "$LUAU_LSP_BIN"
      return 0
    fi
    warn "LUAU_LSP_BIN is set but not executable: $LUAU_LSP_BIN"
    return 1
  fi
  if command -v luau-lsp >/dev/null 2>&1; then
    try_luau_lsp "$(command -v luau-lsp)" && return 0
  fi
  for candidate in \
    "$1/luau-lsp" \
    "$1/bin/luau-lsp" \
    "$HOME/.rokit/bin/luau-lsp" \
    "$HOME/.aftman/bin/luau-lsp" \
    "$HOME/.foreman/bin/luau-lsp" \
    "$HOME/.local/share/mise/shims/luau-lsp" \
    ${LOCALAPPDATA:+"$LOCALAPPDATA/mise/shims/luau-lsp"}; do
    for probe in "$candidate" "$candidate.exe"; do
      if [ -x "$probe" ]; then
        try_luau_lsp "$probe" && return 0
      fi
    done
  done
  if [ -n "$FALLBACK_BIN" ]; then
    warn "$FALLBACK_BIN failed a '--version' probe (broken toolchain shim?); trying it anyway"
    printf '%s\n' "$FALLBACK_BIN"
    return 0
  fi
  return 1
}

# Atomic conditional download: replaces $2 only on a successful, non-empty
# fetch (curl -z skips the body when the remote copy is not newer). Returns 0
# if $2 is usable afterwards.
fetch() {
  url=$1
  dest=$2
  tmp="$dest.tmp.$$"
  if [ -s "$dest" ]; then
    set -- -z "$dest"
  else
    set --
  fi
  if curl -fsSL --connect-timeout 5 --max-time 60 "$@" -o "$tmp" "$url" \
    && [ -s "$tmp" ]; then
    mv -f "$tmp" "$dest"
  else
    rm -f "$tmp"
  fi
  [ -s "$dest" ]
}

# True when $1 is missing or older than $2 minutes.
older_than() {
  [ ! -f "$1" ] || [ -n "$(find "$1" -mmin +"$2" 2>/dev/null)" ]
}

ROOT=$(find_roblox_root) || ROOT=""

BIN=$(find_luau_lsp "${ROOT:-$PWD}") || {
  warn "luau-lsp not found. Install it (https://github.com/JohnnyMorganz/luau-lsp/releases) or point LUAU_LSP_BIN at the binary."
  exit 1
}

# Plain Luau project: no Roblox defs; luau-lsp ships builtin Luau globals.
[ -n "$ROOT" ] || exec "$BIN" lsp "$@"

CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/claude-luau-lsp"
mkdir -p "$CACHE"
DOCS="$CACHE/api-docs.json"
DOCS_URL="https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/api-docs/en-us.json"
REFRESH_STAMP="$CACHE/last-refresh"
ATTEMPT_STAMP="$CACHE/last-attempt"
TYPES_FALLBACK_URL="https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau"

# Pin type definitions to the installed luau-lsp version when detectable —
# a pinned copy matches the binary exactly and never needs re-checking.
VERSION=$("$BIN" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1) || VERSION=""
if [ -n "$VERSION" ]; then
  TYPES="$CACHE/globalTypes-$VERSION.d.luau"
  TYPES_URL="https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/$VERSION/scripts/globalTypes.d.luau"
else
  TYPES="$CACHE/globalTypes.d.luau"
  TYPES_URL=$TYPES_FALLBACK_URL
fi

if ! command -v curl >/dev/null 2>&1; then
  warn "curl not found; using cached Roblox API definitions only"
elif [ -s "$TYPES" ] && [ -s "$DOCS" ]; then
  # Cache complete: start immediately, refresh in the background at most
  # once a day.
  if older_than "$REFRESH_STAMP" 1440; then
    touch "$REFRESH_STAMP"
    {
      [ -z "$VERSION" ] && fetch "$TYPES_URL" "$TYPES"
      fetch "$DOCS_URL" "$DOCS"
    } >/dev/null 2>&1 </dev/null &
  fi
else
  # Cache incomplete (first run, or luau-lsp was upgraded): download before
  # starting so the server gets Roblox types. On failure (e.g. offline),
  # start without them and retry at most hourly.
  if older_than "$ATTEMPT_STAMP" 60; then
    touch "$ATTEMPT_STAMP"
    if [ ! -s "$TYPES" ]; then
      if fetch "$TYPES_URL" "$TYPES" || fetch "$TYPES_FALLBACK_URL" "$TYPES"; then
        # Drop pinned copies left over from other luau-lsp versions.
        [ -n "$VERSION" ] \
          && find "$CACHE" -maxdepth 1 -name 'globalTypes-*.d.luau' \
            ! -name "globalTypes-$VERSION.d.luau" -exec rm -f {} + 2>/dev/null
      else
        warn "could not download Roblox type definitions"
      fi
    fi
    [ -s "$DOCS" ] || fetch "$DOCS_URL" "$DOCS" \
      || warn "could not download Roblox API docs"
  fi
fi

DEFARG=""
DOCARG=""
[ -s "$TYPES" ] && DEFARG="--definitions=$TYPES"
[ -s "$DOCS" ] && DOCARG="--docs=$DOCS"
exec "$BIN" lsp ${DEFARG:+"$DEFARG"} ${DOCARG:+"$DOCARG"} "$@"
