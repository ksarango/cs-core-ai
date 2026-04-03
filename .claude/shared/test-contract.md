# Shared Test Contract

Every QA agent — regardless of stack — MUST follow this contract.
This is the single source of truth for structure, naming, and commands.

---

## Universal Test Types

| Type | What it tests | Tools (JS/TS) | Tools (Python) | Tools (Generic) |
|---|---|---|---|---|
| Unit | Pure functions, services, isolated logic | Jest | pytest | language-native |
| Integration | API routes, DB queries, module wiring | Jest | pytest | language-native |
| E2E | Full user flows in a real browser | Playwright | Playwright | Playwright |

---

## Universal Folder Structure

Every app, service, or package MUST have:

```
tests/
├── unit/
│   └── example.test.<ext>      ← .ts / .py / language ext
├── integration/
│   └── example.test.<ext>
└── e2e/
    └── example.spec.ts          ← always .ts — Playwright is always TS
```

One `__init__.py` per folder for Python projects.

---

## Universal Commands

Every project MUST expose these four commands:

| Command | JS/TS | Python | Generic |
|---|---|---|---|
| `test:unit` | `jest --testPathPattern=unit` | `pytest tests/unit` | `make test:unit` |
| `test:integration` | `jest --testPathPattern=integration` | `pytest tests/integration` | `make test:integration` |
| `test:e2e` | `playwright test` | `playwright test` | `playwright test` |
| `test:all` | run all three in sequence | run all three in sequence | `make test:all` |

**How commands are exposed:**

| Stack | Mechanism |
|---|---|
| JS/TS | `package.json` → `scripts` |
| Python | `pyproject.toml` → `[tool.taskipy.tasks]`, fallback to `Makefile` |
| Generic | `Makefile` |

All four commands must work in CI with no extra steps beyond:
1. Install dependencies
2. Set `.env.test` variables
3. Run the command

---

## Universal Config Files

| File | Purpose | Required for |
|---|---|---|
| `playwright.config.ts` | E2E browser config | All stacks |
| `.env.test` | Test environment variables | All stacks |
| `jest.config.ts` | Unit + integration runner | JS/TS only |
| `pyproject.toml` | Python test + task config | Python only |
| `Makefile` | Command layer | Generic (primary), others (optional) |
| `tests/conftest.py` | Shared pytest fixtures | Python only |
| `packages/test-utils/` | Shared JS mocks/helpers | JS/TS only |

---

## Universal .env.test Minimum

```env
NODE_ENV=test           # or APP_ENV=test for Python
TEST_BASE_URL=http://localhost:3000
```

Each stack may add more — but these two are required everywhere.

---

## Enforcement

Run `/test-check` at any time to verify this contract without running tests.
The CI workflow (`qa.yml`) enforces it on every pull request.
