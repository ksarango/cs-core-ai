# TODOS

## P2 — Post-v0

### Go public: open source core-ai
**What:** MIT license, public GitHub repo, README reframe as community registry, CONTRIBUTING.md.
**Why:** Every Claude Code team has the copy-paste problem. Going public lets other teams find core-ai without you telling them, and invites community tool contributions.
**Pros:** Community tools, shared maintenance, discoverability.
**Cons:** Support burden, public-facing docs to maintain.
**Context:** Deferred from /plan-ceo-review on 2026-04-01. Architecture already supports it — no code changes needed. Do after v0 is proven internally for a few weeks.
**Effort:** S (human: ~2h / CC: ~10min)
**Depends on:** v0 shipped and in use internally

---

### shunit2 integration tests for setup.sh
**What:** Test suite covering idempotence, --update, --force, non-writable dirs, partial failure, non-interactive mode, and --tool flag.
**Why:** setup.sh is the core of this system. Without automated tests, edge cases (partial failure, writable dirs, CLAUDE.md injection) are only verified manually.
**Pros:** Confidence before going public, catches regressions, enables contributions.
**Cons:** shunit2 setup, fixture directories to maintain.
**Context:** Not blocking v0 internal use. Blocking before going public. Create test/fixtures/ with minimal project structures in known states.
**Effort:** M (human: ~1 day / CC: ~20min)
**Depends on:** v0 shipped

---

### Auto-detect project type (v0.1 if deferred from v0)
**What:** setup.sh reads target project's package.json, detects jest/vitest in dependencies, pre-selects relevant tools in the interactive picker.
**Why:** Delight moment — installer feels like it already knows what you need. Users don't have to understand which tools apply to their stack.
**Pros:** Better first-run UX, fewer wrong tool installations.
**Cons:** Adds package.json parsing logic to setup.sh, more to test.
**Context:** Accepted scope expansion in /plan-ceo-review, but noted as aggressive for v0. If implementation time is tight, ship without auto-detect and add here. Pays off when manifest has 3+ tools.
**Effort:** S (human: ~2h / CC: ~15min)
**Depends on:** v0 shipped, manifest has 2+ tools
