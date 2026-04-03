---
description: Fast health check — verify test contract compliance without running tests
allowed-tools: Read, Bash, Glob, Grep
---

# /test-check

Fast audit — reads the project, checks compliance with the test contract,
and reports issues WITHOUT installing anything or running tests.

Useful before committing, in CI, or before running `/test-pipeline`.

---

## Checks (run all, report all findings)

### 1. Stack Detection
- Identify stack (js / python / other)
- Report which config files were found

### 2. Folder Structure
```bash
# Must exist for every app/package:
find . -type d -name "unit"        | grep "tests/unit"
find . -type d -name "integration" | grep "tests/integration"
find . -type d -name "e2e"         | grep "tests/e2e"
```
❌ Flag any app/package missing any of the three folders.

### 3. Command Compliance

**JS/TS:**
```bash
# Every package.json must have all four scripts:
grep -r "test:unit\|test:integration\|test:e2e\|test:all" package.json
```

**Python:**
```bash
grep -A20 "\[tool.taskipy.tasks\]" pyproject.toml | grep "test:"
# OR
grep "test:" Makefile
```

❌ Flag any missing command.

### 4. Playwright Config
```bash
[ -f playwright.config.ts ] && echo "✅ found" || echo "❌ missing"
```

### 5. .env.test
```bash
[ -f .env.test ] && echo "✅ found" || echo "❌ missing"
grep "TEST_BASE_URL" .env.test || echo "❌ TEST_BASE_URL not set"
```

### 6. Empty Test Folders
```bash
find . -path "*/tests/unit" -empty
find . -path "*/tests/integration" -empty
find . -path "*/tests/e2e" -empty
```
⚠️ Warn about any empty folder (no tests yet).

### 7. Orphaned Tests
```bash
# Tests outside the standard folders:
find . -name "*.test.ts" -not -path "*/tests/*" -not -path "*/node_modules/*"
find . -name "test_*.py" -not -path "*/tests/*"
```
⚠️ Warn about tests living outside the standard structure.

---

## Output Format

```
QA CONTRACT CHECK
─────────────────
Stack:   <detected>
Target:  <path or "full project">

STRUCTURE
  ✅ apps/web/tests/unit/
  ✅ apps/web/tests/integration/
  ❌ apps/web/tests/e2e/          ← MISSING

COMMANDS
  ✅ test:unit
  ✅ test:integration
  ❌ test:e2e                     ← MISSING in package.json
  ✅ test:all

CONFIG
  ✅ playwright.config.ts
  ✅ .env.test
  ✅ TEST_BASE_URL set

WARNINGS
  ⚠️  apps/api/tests/unit/ is empty — no tests written yet
  ⚠️  src/utils/helper.test.ts is outside tests/ folder

VERDICT
  ❌ 2 issues found — run /test-pipeline to fix
  (or: ✅ All checks passed — project is contract-compliant)
```
