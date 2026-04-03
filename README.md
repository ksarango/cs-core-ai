# core-ai

Shared Claude Code tools for any project. One command installs slash commands into `.claude/commands/` and keeps them updated as the registry grows.

## Install

```sh
sh <(curl -fsSL https://raw.githubusercontent.com/CondorSoft/core-ai/main/setup.sh)
```

The installer:
1. Fetches the tool registry (`tools.json`)
2. Auto-detects your stack and pre-selects relevant tools
3. Shows an interactive picker — choose tools by number, type `all`, or press Enter for recommended
4. Installs selected tools into `.claude/commands/`
5. Updates `CLAUDE.md` with a usage block (idempotent — safe to re-run)

## Available tools

| Tool | What it does |
|------|-------------|
| `test-check` | Fast audit — checks test contract compliance (folder structure, scripts, config) without running tests. |
| `test-pipeline` | Universal QA pipeline — detects stack (JS/Python/other), delegates to the right agent, runs all test suites. |
| `test-fix` | Fix failing tests — categorizes failures by type, auto-repairs without weakening or deleting assertions. |

## CLI flags

```sh
# Install a specific tool directly (CI-safe, non-interactive)
sh setup.sh --tool <tool-name>

# Overwrite existing files (useful after a tool update)
sh setup.sh --force

# Check for newer versions of installed tools
sh setup.sh --update
```

## How it works

### The registry (`tools.json`)

Every tool is described by a flat JSON entry:

```json
{
  "name": "tool-name",
  "description": "What the tool does",
  "version": "0.1.0",
  "file": ".claude/commands/tool-name.md",
  "tags": "tag1,tag2",
  "requires": "dependency"
}
```

The installer fetches this file, parses it with `grep`/`sed` (no `jq` dependency), and downloads each selected tool's `.md` file into your project's `.claude/commands/` directory.

### Version tracking (`.core-ai-versions`)

After installation, each tool is recorded in `.core-ai-versions`:

```
tool-name@0.1.0
```

Re-running the installer skips already-installed versions. `--update` checks each entry against the registry and prompts you to upgrade tools that have newer versions available. Re-installs merge into this file rather than overwriting it.

### CLAUDE.md injection

The installer appends a block to your project's `CLAUDE.md` listing the installed tools and how to use them. The block is wrapped in HTML comment markers (`<!-- core-ai:start -->` / `<!-- core-ai:end -->`). Re-running replaces the block in-place — no duplicates.

### Security

- `CORE_AI_REPO` must use `https://` — `file://` and `ftp://` are rejected
- Tool names are validated against `[a-zA-Z0-9_-]` before any filesystem use
- Tool file paths must start with `.claude/` — no path traversal
- Downloads are atomic: written to `.tmp` then `mv`'d on success, cleaned up on failure

## Using a tool

After install, use a tool as a Claude Code slash command:

```
/tool-name
```

## Updating tools

```sh
sh <(curl -fsSL https://raw.githubusercontent.com/CondorSoft/core-ai/main/setup.sh) --update
```

## Uninstalling

Remove all installed tools:

```sh
sh <(curl -fsSL https://raw.githubusercontent.com/CondorSoft/core-ai/main/uninstall.sh)
```

Remove a specific tool:

```sh
sh uninstall.sh --tool <tool-name>
```

Skip the confirmation prompt (useful in CI):

```sh
sh uninstall.sh --yes
```

The uninstaller removes each tool's `.md` file, deletes `.claude/.core-ai-versions`, strips the `core-ai` block from `CLAUDE.md`, and removes `.claude/commands/` if it is left empty.

## Mirror / private registry

Point at your own host:

```sh
CORE_AI_REPO=https://your.host/core-ai sh setup.sh
```

The `https://` requirement still applies.

## Contributing

See [TODOS.md](TODOS.md) for planned work. The big ones: shunit2 integration tests for `setup.sh` and going public as an open-source community registry.
