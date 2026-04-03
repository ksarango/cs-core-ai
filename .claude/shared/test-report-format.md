# Shared Report Format

Every QA agent MUST end its run with a report in this exact format.
The pipeline uses this to merge multi-stack reports into one summary.

---

## Agent Report Template

```
╔══════════════════════════════════════════╗
║          QA Agent Report                 ║
║  Stack: <JS/TS | Python | Generic>       ║
╚══════════════════════════════════════════╝

📦 Target:   <app or package path, or "full project">
🔍 Detected: <framework + API layer>

TEST RESULTS
────────────
✅ Unit:        <X passed> / <Y total>  [<tool used>]
✅ Integration: <X passed> / <Y total>  [<tool used>]
✅ E2E:         <X passed> / <Y total>  [Playwright]

  (use ❌ for failed, ⚠️ for skipped)

CHANGES MADE
────────────
📁 Created:  <list of new files, one per line>
📝 Modified: <list of modified files, one per line>
📦 Installed: <list of packages installed>

ISSUES
──────
🔧 Fixed:   <list of issues auto-fixed>
⚠️  Manual:  <list of items needing human review>
             (each with a clear action item)

COMMANDS READY
──────────────
  test:unit         ✅
  test:integration  ✅
  test:e2e          ✅
  test:all          ✅
```

---
