---
description: Scaffold tests for a new app or package — stack-aware
allowed-tools: Read, Write, Bash, Glob, Grep
---

# Test Setup Prompt

Use this prompt when adding tests to a new app or package.
Works for any stack — detection happens automatically.

---

You are setting up tests for `$ARGUMENTS`.

## Step 1 — Detect Local Stack

Read these files inside `$ARGUMENTS`:
- `package.json` → JS/TS
- `pyproject.toml` or `requirements.txt` → Python
- `Cargo.toml` / `go.mod` / `pom.xml` → Generic

Then route:
- JS/TS  → follow **JS Setup** section below
- Python → follow **Python Setup** section below
- Other  → follow **Generic Setup** section below

---

## JS / TS Setup

1. Read `$ARGUMENTS/package.json` and `$ARGUMENTS/src/`
2. Create folder structure:
   ```
   $ARGUMENTS/tests/unit/
   $ARGUMENTS/tests/integration/
   $ARGUMENTS/tests/e2e/
   ```
3. Add or update `jest.config.ts` to extend root config
4. Write one example test per type:
   - `tests/unit/example.test.ts` → pure function
   - `tests/integration/example.test.ts` → tRPC caller or API route
   - `tests/e2e/example.spec.ts` → Playwright page load
5. Add scripts to `$ARGUMENTS/package.json`:
   ```json
   "test:unit":        "jest --testPathPattern=unit --passWithNoTests",
   "test:integration": "jest --testPathPattern=integration --passWithNoTests",
   "test:e2e":         "playwright test",
   "test:all":         "npm run test:unit && npm run test:integration && npm run test:e2e"
   ```
6. Use `@repo/test-utils` for shared mocks — add new helpers there if broadly useful

---

## Python Setup

1. Read `$ARGUMENTS/pyproject.toml` (or `requirements.txt`) and `$ARGUMENTS/src/` or `$ARGUMENTS/app/`
2. Detect framework (FastAPI / Django / Flask) from imports or dependencies
3. Create folder structure:
   ```
   $ARGUMENTS/tests/__init__.py
   $ARGUMENTS/tests/conftest.py
   $ARGUMENTS/tests/unit/__init__.py
   $ARGUMENTS/tests/unit/test_example.py
   $ARGUMENTS/tests/integration/__init__.py
   $ARGUMENTS/tests/integration/test_example.py
   $ARGUMENTS/tests/e2e/example.spec.ts
   ```
4. Write `conftest.py` with the right client fixture for the detected framework
5. Add taskipy tasks to `$ARGUMENTS/pyproject.toml`:
   ```toml
   [tool.taskipy.tasks]
   "test:unit"        = "pytest tests/unit -v"
   "test:integration" = "pytest tests/integration -v"
   "test:e2e"         = "playwright test"
   "test:all"         = "task test:unit && task test:integration && task test:e2e"
   ```
   Or add targets to the root `Makefile` if no `pyproject.toml`

---

## Generic Setup

1. Identify the language from file extensions in `$ARGUMENTS/src/`
2. Create folder structure with language-appropriate file names inside:
   ```
   $ARGUMENTS/tests/unit/
   $ARGUMENTS/tests/integration/
   $ARGUMENTS/tests/e2e/
   ```
3. Write one minimal example test per type using the language's native framework
4. Add `Makefile` targets:
   ```makefile
   test:unit:        <language-native unit command>
   test:integration: <language-native integration command>
   test:e2e:         playwright test
   test:all:         test:unit test:integration test:e2e
   ```

---

## Constraints (all stacks)

- Never remove existing passing tests
- Add shared helpers to a `test-utils` module/package if broadly reusable
- Every E2E test must use Playwright — no exceptions
- Verify all commands run before reporting done
