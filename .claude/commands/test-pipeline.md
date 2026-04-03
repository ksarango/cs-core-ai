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

## Step 2 — Prepare

### Step 2.1 — Check for Existing Tests

Scan for existing test files:
- JS/TS: look for `*.test.ts`, `*.test.js`, `*.spec.ts`, `*.spec.js`, `**/__tests__/**`
- Python: look for `test_*.py`, `*_test.py`, `tests/` directories
- Generic: look for any common test file patterns

**If no tests are found for a given suite type (unit, integration, e2e):**
Write exactly **1 example test** that covers the single most critical process in the codebase —
the core business logic, primary API endpoint, or central data transformation.

Rules for the seed test:
- 1 test per missing suite type (not per file — one total per category)
- It must be a real, runnable test — not a placeholder or `it.todo()`
- Target the most important behavior, not a trivial utility
- Follow the stack's native test framework (Jest, Pytest, etc.)
- Add a comment: `// seed test — replace or expand as the project grows`

### Step 2.2 — Load Shared Contracts

Load the shared layer before delegating:
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
