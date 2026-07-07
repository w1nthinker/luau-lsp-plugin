# luau-lsp

Luau language server for Claude Code, providing code intelligence, type checking, and diagnostics via [luau-lsp](https://github.com/JohnnyMorganz/luau-lsp).

Works for **both Roblox and non-Roblox Luau**:

- If the workspace contains a Rojo project (`*.project.json`), `sourcemap.json`, or `wally.toml`, the plugin automatically downloads and caches the Roblox API type definitions (`globalTypes.d.luau`) and API docs, giving full Roblox type awareness (Instances, services, DataTypes, enums).
- Otherwise it runs in plain Luau mode with the builtin Luau globals only.

Cached Roblox definitions live in `~/.cache/claude-luau-lsp/`. Delete that directory to force a refresh after a Roblox API update.

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

## Roblox tips

- Generate a `sourcemap.json` with Rojo for require-resolution across your DataModel: `rojo sourcemap --watch default.project.json -o sourcemap.json`
- Per-project settings (aliases, strictness) go in `.luaurc` / `luau-lsp` settings as usual — the plugin only supplies the server command.

## More Information
- [luau-lsp GitHub](https://github.com/JohnnyMorganz/luau-lsp)
- [Luau language](https://luau.org/)
