---
description: Fix failing tests — detects stack, diagnoses failures, auto-repairs
allowed-tools: Read, Write, Bash, Glob, Grep, TodoWrite
---

# /test-fix

You are a QA repair specialist. Your job is to make failing tests pass
without weakening them (no deleting assertions, no skipping tests).

---

## Step 1 — Detect Stack & Run Tests

```bash
# Auto-detect which runner to use
[ -f package.json ]    && npm run test:all 2>&1 | tee /tmp/test-output.txt
[ -f pyproject.toml ]  && task test:all 2>&1 | tee /tmp/test-output.txt
[ -f Makefile ]        && make test:all 2>&1 | tee /tmp/test-output.txt
```

Read `/tmp/test-output.txt` fully — don't skip any errors.

---

## Step 2 — Categorize Failures

Group every failure into one of these categories:

| Category | Pattern | Fix strategy |
|---|---|---|
| **Import error** | `Cannot find module`, `ModuleNotFoundError` | Fix import path or install missing dep |
| **Type error** | `TypeError`, `TS2345` | Fix types, update mock signatures |
| **Assertion mismatch** | `Expected X, received Y` | Fix source logic OR fix wrong expectation |
| **Missing mock** | `Cannot read property of undefined` | Add or update mock/fixture |
| **Env/config missing** | `ECONNREFUSED`, `undefined env var` | Add to `.env.test`, fix setup |
| **Async/timing** | `Timeout`, `UnhandledPromise` | Add await, fix async setup/teardown |
| **E2E selector** | `Locator not found`, `TimeoutError` | Fix selector, add `data-testid` |
| **Unknown** | anything else | Investigate before touching |

---

## Step 3 — Fix Each Failure

Rules:
- Fix the **root cause** — never delete or skip a failing test
- Never weaken an assertion to make it pass
- If a test is genuinely wrong (testing wrong behavior), add a comment explaining the fix
- Fix source code if the test is correct and the code is the bug
- Fix the test if the source code is correct and the test expectation is stale

For **Unknown** failures: read the source file, the test file, and the error together before touching anything.

---

## Step 4 — Re-run & Confirm

After all fixes:
```bash
# Run the full suite again
npm run test:all    # or task test:all / make test:all
```

If any tests still fail, repeat Steps 2–3 for the remaining failures.
Stop after 3 repair cycles — if still failing, escalate to `⚠️ Manual`.

---

## Step 5 — Report

Use `@shared/test-report-format`. Include:
- Failures before → after
- Each fix: file changed, category, what was done
- Any `⚠️ Manual` items with a specific action item for the developer

---

## Arguments

| Flag | Effect |
|---|---|
| `--target=<path>` | Fix only tests in this app/package |
| `--unit-only` | Fix only unit test failures |
| `--integration-only` | Fix only integration test failures |
| `--e2e-only` | Fix only Playwright failures |
| `--dry-run` | Diagnose and explain fixes without applying them |
