# Tools available

List of tools and how it works.

## Testing

Tools for test standarization.

### Commands Reference

| Command | When to use |
|---|---|
| `/qa-pipeline` | First time setup, or full re-run on any project |
| `/qa-pipeline --dry-run` | Preview what would change before writing anything |
| `/qa-pipeline --fix` | Setup + auto-fix any failures |
| `/qa-pipeline --stack=python` | Force a specific stack (skip auto-detect) |
| `/qa-pipeline --target=apps/web` | Limit to one app or package |
| `/qa-pipeline --unit-only` | Only unit tests (skip integration + E2E) |
| `/qa-pipeline --skip-e2e` | Skip Playwright setup |
| `/qa-fix` | Fix failing tests (dedicated repair flow) |
| `/qa-fix --dry-run` | Diagnose failures without applying fixes |
| `/qa-check` | Fast compliance check — no installs, no test runs |

---

### Standard Commands (every stack, every project)

```bash
# JS/TS
npm run test:unit
npm run test:integration
npm run test:e2e
npm run test:all

# Python
task test:unit          # taskipy (preferred)
task test:all
make test:unit          # Makefile (fallback)
make test:all

# Generic / Other
make test:unit
make test:all
```

---

### Folder Structure (enforced everywhere)

```
tests/
├── unit/           ← functions, services, isolated logic
├── integration/    ← API routes, DB, module wiring
└── e2e/            ← Playwright user flows
```

---

### Stack Support Matrix

| Stack | Unit | Integration | E2E | Commands |
|---|---|---|---|---|
| Next.js / Node / tRPC | Jest | Jest | Playwright | package.json |
| FastAPI / Django / Flask | pytest | pytest | Playwright | taskipy / Makefile |
| Go / Rust / Java / Other | go test / cargo / mvn | same | Playwright | Makefile |
| Mixed monorepo | both | both | Playwright | both |

---
