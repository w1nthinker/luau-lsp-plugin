# luau-lsp

Luau language server for Claude Code, providing code intelligence, type checking, and diagnostics via [luau-lsp](https://github.com/JohnnyMorganz/luau-lsp).

Works for **both Roblox and non-Roblox Luau**:

- If the workspace is part of a Rojo project (`*.project.json`), or contains a `sourcemap.json` or `wally.toml` — searched upward from the working directory, so subdirectories of a project are detected too — the plugin automatically downloads and caches the Roblox API type definitions (`globalTypes.d.luau`) and API docs, giving full Roblox type awareness (Instances, services, DataTypes, enums).
- Otherwise it runs in plain Luau mode with the builtin Luau globals only.

Works on macOS, Linux, and Windows (see [Windows](#windows) for the one requirement).

## Supported Extensions
`.luau`, `.lua`

> Note: the official `lua-lsp` plugin targets plain Lua (`lua-language-server`). If you have both installed, disable `lua-lsp` in Roblox/Luau projects to avoid two servers claiming `.lua` files.

## Installation

Install the `luau-lsp` binary:

### Via Homebrew (macOS/Linux)
```bash
brew install luau-lsp
```

### Via Aftman/Rokit (Roblox toolchain managers)
```bash
rokit add JohnnyMorganz/luau-lsp
# or
aftman add JohnnyMorganz/luau-lsp
```

### Manual
Download a pre-built binary from the [releases page](https://github.com/JohnnyMorganz/luau-lsp/releases) and put it on your `PATH`.

## How the binary is found

Claude Code doesn't always inherit your shell's `PATH` (e.g. when launched from the desktop app), so the plugin looks for `luau-lsp` in order:

1. `LUAU_LSP_BIN` environment variable, if set (must point at an executable)
2. `PATH`
3. Project-local copies: `<project>/luau-lsp`, `<project>/bin/luau-lsp`
4. Toolchain install dirs: `~/.rokit/bin`, `~/.aftman/bin`, `~/.foreman/bin`, `~/.local/share/mise/shims` (plus `%LOCALAPPDATA%\mise\shims` on Windows)

On Windows every location is also probed with an `.exe` suffix.

## Windows

Claude Code launches plugin LSP servers by spawning the configured command directly — it can't run PowerShell or batch entry points — so the wrapper runs under a POSIX `sh`, which must be on `PATH`:

- **Git for Windows** (recommended): install from [git-scm.com](https://git-scm.com/downloads/win) and make sure `sh` is reachable from `PATH`. The installer option *"Use Git and optional Unix tools from the Command Prompt"* does this, or add `C:\Program Files\Git\bin` to `PATH` yourself. Claude Code already recommends Git for Windows for its Bash tool, so most setups have it.
- **MSYS2 / Cygwin** `sh` on `PATH` works too.
- **WSL**: run Claude Code inside WSL and everything behaves as on Linux.

If the server fails to start with an error like `'sh' is not recognized`, `sh` is missing from `PATH`.

## Caching & refresh

Roblox definitions live in `~/.cache/claude-luau-lsp/` (or `$XDG_CACHE_HOME/claude-luau-lsp/`):

- **Type definitions** are pinned to your installed `luau-lsp` version (fetched from the matching release tag), so they always match the binary and are downloaded only once per version. If the version can't be detected, the latest definitions are used and refreshed daily.
- **API docs** refresh in the background at most once a day — server startup is never delayed once a cache exists.
- Downloads are atomic (an interrupted transfer can't corrupt the cache), and offline starts fall back to the cached copies. Only the very first start in a Roblox project needs the network; without it the server still starts, just without Roblox types, and retries hourly.

## Roblox tips

- Generate a `sourcemap.json` with Rojo for require-resolution across your DataModel: `rojo sourcemap --watch default.project.json -o sourcemap.json`
- Per-project settings (aliases, strictness) go in `.luaurc` / `luau-lsp` settings as usual — the plugin only supplies the server command.

## More Information
- [luau-lsp GitHub](https://github.com/JohnnyMorganz/luau-lsp)
- [Luau language](https://luau.org/)
