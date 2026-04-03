---
description: QA agent router — legacy alias, now delegates to the stack-specific agent
allowed-tools: Read, Bash, Glob
---

# QA Agent (Router)

> This file is a compatibility router. Direct invocations of `@agents/qa-agent`
> are automatically re-routed to the correct stack-specific agent.

## Routing

1. Read `@agents/stack-detector` output (or run detection if not yet done)
2. Route based on STACK result:
   - `STACK: js`     → delegate entirely to `@agents/qa-agent-js`
   - `STACK: python` → delegate entirely to `@agents/qa-agent-python`
   - `STACK: other`  → delegate to `@agents/qa-agent-generic`

Pass all `$ARGUMENTS` through unchanged to the delegated agent.

## Direct Shortcuts (still supported)

```bash
# These all route through here then to the right stack agent:
/qa-agent --target=apps/web
/qa-agent --unit-only
/qa-agent --fix
/qa-agent --stack=python --target=services/api
```

For the full pipeline (detect + install + scaffold + run), prefer `/test-pipeline`.
