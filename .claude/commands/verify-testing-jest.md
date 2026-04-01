Run Jest coverage analysis and report files below the coverage threshold.
v0: Jest only. Vitest support is not available in this version.

### Step 1: Detect test runner

Check in this order — stop at first match:
- `jest.config.js`, `jest.config.ts`, `jest.config.mjs`, or `jest.config.cjs` present → Jest confirmed
- `package.json` contains a `"jest"` key → Jest confirmed
- `vitest.config.*` present → stop and report:
  "Vitest detected. Vitest support is not available in this version of
  /verify-testing-jest. Run `npx vitest run --coverage` manually for now."
- None found → stop and report:
  "No Jest config found. Add a jest.config file or a jest key in package.json."

### Step 2: Determine coverage threshold

Check in this order — stop at first match:
1. Read jest.config. If `coverageThreshold.global.lines` is set, use that value.
2. Otherwise, use 70% as the default.

Report which is in use: "Using threshold: X% (from jest.config)" or
"Using threshold: 70% (default)"

### Step 3: Run coverage

Run: `npx jest --coverage --coverageReporters=json-summary --silent`

If the command exits with a non-zero status: show the exact stderr output
and ask "Want me to help debug the test run failure?" Stop — do not proceed.

After command succeeds: check that `coverage/coverage-summary.json` exists.
If it does not exist: report "Coverage file not generated. Ensure
`coverageReporters` in jest.config includes `json-summary`. Try adding it and
re-running /verify-testing-jest." Stop.

If the file exists but is not valid JSON: report "coverage-summary.json is
malformed. Delete coverage/ and re-run `npx jest --coverage
--coverageReporters=json-summary` to regenerate." Stop.

### Step 4: Parse coverage/coverage-summary.json

Expected structure (Jest 27+):

```json
{
  "total": {
    "lines":     { "total": 523, "covered": 412, "skipped": 0, "pct": 78.77 },
    "statements":{ "total": 601, "covered": 470, "skipped": 0, "pct": 78.2  },
    "functions": { "total": 89,  "covered": 64,  "skipped": 0, "pct": 71.91 },
    "branches":  { "total": 201, "covered": 140, "skipped": 0, "pct": 69.65 }
  },
  "src/utils/format.ts": {
    "lines":     { "total": 24, "covered": 12, "skipped": 0, "pct": 50 },
    "statements":{ "total": 28, "covered": 14, "skipped": 0, "pct": 50 },
    "functions": { "total": 5,  "covered": 2,  "skipped": 0, "pct": 40 },
    "branches":  { "total": 8,  "covered": 3,  "skipped": 0, "pct": 37.5 }
  }
}
```

Use `lines.pct` as the primary metric. Skip the `"total"` key in the per-file table.

### Step 5: Report

- Global: "Global coverage: 78.77% lines — PASS (threshold: 70%)" or "FAIL — 3.77% below threshold"
- Table of files below threshold, sorted by lines.pct ascending (lowest first):

  | File                    | Lines | Branches | Functions |
  |-------------------------|-------|----------|-----------|
  | src/utils/format.ts     | 50%   | 37.5%    | 40%       |

- Summary: "N of M files below threshold"

If all files pass: "Coverage looks good — M files, Y% global coverage. Nothing to do."

If files are below threshold: list the 3 lowest (by lines.pct) and say:
"Want me to look at one of these files and propose tests for the uncovered
functions? If yes, say which file."

Wait for the user to respond. Then read the file and propose test cases inline
in the chat. Do NOT write files to disk — just propose. The user writes or
directs what to do with the proposal.
