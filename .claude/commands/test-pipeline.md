---
description: Universal QA pipeline — detects stack, routes to the right agent, runs all suites
allowed-tools: Read, Write, Bash, Glob, Grep, TodoWrite
---

# /test-pipeline

You are the QA pipeline orchestrator. You do NOT run tests yourself —
you detect the stack and delegate to the right specialist agent.

---

## Step 1 — Detect Stack

Run the stack detector:

```
@agents/stack-detector
```

The detector will return one of:
- `STACK: js` → route to `@agents/qa-agent-js`
- `STACK: python` → route to `@agents/qa-agent-python`
- `STACK: other` → route to `@agents/qa-agent-generic`

---

## Step 2 — Load Shared Contracts

Before delegating, load the shared layer:
```
@shared/test-contract      ← universal test types, folder structure, command names
@shared/test-report-format      ← standard output format all agents must use
```

---

## Step 3 — Delegate to Stack Agent

Pass to the correct agent with the full detection result and any $ARGUMENTS.

**If JS/TS:**
```
@agents/qa-agent-js $ARGUMENTS
```

**If Python:**
```
@agents/qa-agent-python $ARGUMENTS
```

**If Other:**
```
@agents/qa-agent-generic $ARGUMENTS
```

---

## Step 4 — Collect & Display Report

Wait for all delegated agents to finish.
Display the merged report using the format from `@shared/test-report-format`.

---

## Arguments (passed through to stack agents)

| Flag | Effect |
|---|---|
| `--unit-only` | Only scaffold and run unit tests |
| `--skip-e2e` | Skip Playwright setup |
| `--fix` | Auto-fix failing tests |
| `--target=<path>` | Limit to a specific app or package |
| `--dry-run` | Detect and plan, but don't write or install anything |
| `--stack=<js\|python\|generic>` | Override auto-detection |
