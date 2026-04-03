---
description: Audit and improve existing tests — stack-aware, works on any project
allowed-tools: Read, Write, Bash, Glob, Grep
---

# Test Review Prompt

Use this when asking Claude to audit and improve existing tests.
Target: `$ARGUMENTS` (or the entire project if no argument given).

---

## Step 1 — Detect Stack & Collect Stats

Run stack detection, then gather:
```bash
# JS/TS
find . -name "*.test.ts" -o -name "*.test.js" -o -name "*.spec.ts" | wc -l

# Python
find . -name "test_*.py" -o -name "*_test.py" | wc -l

# Count by type
find . -path "*/tests/unit/*" | wc -l
find . -path "*/tests/integration/*" | wc -l
find . -path "*/tests/e2e/*" | wc -l
```

Report before/after counts at the end.

---

## Universal Review Checklist

### Structure ← check first
- [ ] `tests/unit/`, `tests/integration/`, `tests/e2e/` exist
- [ ] Test files are in the right folder for their type
- [ ] No tests living in `src/` or `app/` mixed with source code
- [ ] Shared fixtures/mocks are centralized (not copy-pasted)

### Coverage ← check second
- [ ] Unit tests exist for all services, utilities, and core logic
- [ ] Integration tests cover at least one real API call or DB interaction
- [ ] E2E tests cover the primary user-facing flow (login, main action, error state)

### Quality — JS/TS (skip if Python)
- [ ] Each `it()` / `test()` has a clear description starting with a verb
- [ ] No test shares mutable state with another test
- [ ] Mocks are reset with `afterEach(() => jest.clearAllMocks())`
- [ ] Async tests use `async/await` — no raw `.then()` chains
- [ ] No `console.log` left in test files

### Quality — Python (skip if JS/TS)
- [ ] Each `def test_*` has a clear name describing what it asserts
- [ ] Fixtures are in `conftest.py`, not repeated inside test files
- [ ] No test modifies global state without restoring it
- [ ] Async tests use `@pytest.mark.asyncio`
- [ ] No `print()` left in test files

### Quality — Universal
- [ ] Each test has one clear assertion focus
- [ ] No test depends on execution order (tests are independent)
- [ ] Tests don't hit external services (network calls are mocked or use test DB)
- [ ] E2E tests use `data-testid` or semantic selectors — no brittle CSS paths

---

## Actions

For each issue found:
1. Fix it automatically if possible
2. If it requires domain knowledge, add an inline comment:
   - JS/TS:  `// TODO(qa-review): <reason>`
   - Python: `# TODO(qa-review): <reason>`

Add missing tests for any source file that has zero coverage.

---

## Output

Use `@shared/test-report-format` to produce the final report.
Include: issues found, issues fixed, tests added, tests before → after.
