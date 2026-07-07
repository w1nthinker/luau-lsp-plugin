# luau-lsp-plugin

[Luau](https://luau.org/) language server plugin for [Claude Code](https://claude.com/claude-code), powered by [luau-lsp](https://github.com/JohnnyMorganz/luau-lsp) by JohnnyMorganz.

Gives Claude Code code intelligence, type checking, and diagnostics for `.luau` and `.lua` files — in **both Roblox and plain Luau projects**. Roblox projects (detected via `*.project.json`, `sourcemap.json`, or `wally.toml`) automatically get the full Roblox API type definitions and docs.

## Install

1. Install the `luau-lsp` binary (`brew install luau-lsp`, `rokit add JohnnyMorganz/luau-lsp`, or grab a [release](https://github.com/JohnnyMorganz/luau-lsp/releases)).
2. In Claude Code:

```
/plugin marketplace add w1nthinker/luau-lsp-plugin
/plugin install luau-lsp@luau-lsp-marketplace
```

See [plugins/luau-lsp/README.md](plugins/luau-lsp/README.md) for details.
