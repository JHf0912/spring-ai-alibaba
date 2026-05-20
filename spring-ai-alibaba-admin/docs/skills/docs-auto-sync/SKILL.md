---
name: docs-auto-sync
description: Detect documentation drift by comparing code artifacts against docs/. Scans Controllers, Entity classes, SQL schemas, and pom.xml to find mismatches with api-list.md, data-model.md, and CLAUDE.md. Read-only — reports only, never auto-fixes.
allowed-tools: Read, Grep, Glob, Agent
origin: project
---

# Documentation Auto-Sync Checker

Read-only skill that detects when code has changed but documentation hasn't caught up. Produces a structured drift report without modifying any files.

## When to Activate

- After modifying any Controller, Entity, DTO, or SQL schema
- Before submitting a PR that touches API endpoints or data models
- When onboarding to a new codebase and need to assess doc freshness
- Periodically as a health check on docs/ accuracy
- When the user asks "does the doc match the code?"

## What It Checks

| Code Artifact | Documentation | What's Compared |
|---------------|---------------|-----------------|
| Controller endpoints | `docs/api-list.md` | Method, path, params, return type |
| Entity/DO fields | `docs/data-model.md` | Fields, types, PK/FK, enums |
| SQL schemas | `docs/data-model.md` | Table structure, columns, constraints |
| `pom.xml` dependencies | `docs/external-deps.svg` | Key dependency versions |
| Module structure | `CLAUDE.md` | Module list, build commands, architecture claims |

## Execution Steps

### Step 1: Inventory Changed Files

```bash
# Check git diff for recently changed files
git diff --name-only HEAD~5...HEAD -- '*.java' '*.sql' '*.xml' '*.yml'

# Or check uncommitted changes
git diff --name-only
git diff --cached --name-only
```

Categorize changes into:
- **Controller files** → will check against `api-list.md`
- **Entity/DTO files** → will check against `data-model.md`
- **SQL files** → will check against `data-model.md`
- **pom.xml files** → will check against `external-deps` and `CLAUDE.md`

If no git changes detected, do a full scan of all Controllers and Entity classes.

### Step 2: Check Controllers vs api-list.md

For each `*Controller.java` file:

1. Read the Controller source
2. Extract all endpoint definitions:
   - `@GetMapping`, `@PostMapping`, `@PutMapping`, `@DeleteMapping`, `@PatchMapping`
   - Class-level `@RequestMapping` prefix
   - Method parameters (`@RequestBody`, `@RequestParam`, `@PathVariable`)
   - Return type
3. Find the corresponding section in `docs/api-list.md`
4. Compare:

| Check | How |
|-------|-----|
| Missing endpoint | Code has it, doc doesn't |
| Ghost endpoint | Doc has it, code doesn't |
| Wrong HTTP method | GET vs POST mismatch |
| Wrong path | Path string differs |
| Wrong param type | `@RequestParam` vs `@PathVariable` mismatch |
| Missing param | Code has param, doc doesn't list it |
| Wrong return type | Actual return differs from doc |

**Red flags to always check:**
- `@PathVariable` without matching `{param}` in path → runtime bug
- `@RequestParam` on POST body → likely should be `@RequestBody`
- Controller methods with no `@RequestMapping` variant → dead code

### Step 3: Check Entity/DO vs data-model.md

For each `*DO.java` or `*Entity.java` file:

1. Read the Entity source
2. Extract all fields with their types and annotations
3. Find the corresponding table in `docs/data-model.md`
4. Compare:

| Check | How |
|-------|-----|
| Missing field | Code has it, doc doesn't |
| Ghost field | Doc has it, code doesn't |
| Wrong type | `String` vs `Long`, `LocalDateTime` vs `Date` |
| Missing annotation | `@Id`, `@Column`, `@Table` not documented |
| Missing enum values | Status field values not listed in doc |
| Missing FK reference | `@ManyToOne` or FK field not documented as FK |

### Step 4: Check SQL vs data-model.md

For each `*.sql` file in `docker/middleware/init/mysql/`:

1. Read the SQL file
2. Extract `CREATE TABLE` statements with columns, types, constraints
3. Find the corresponding table in `docs/data-model.md`
4. Compare:

| Check | How |
|-------|-----|
| Missing table | SQL has it, doc doesn't |
| Missing column | SQL has column, doc doesn't |
| Wrong type | `VARCHAR(64)` vs `VARCHAR(255)` |
| Missing constraint | PK, UK, FK, INDEX not documented |
| Missing enum | SQL comment lists values, doc doesn't |

### Step 5: Check pom.xml vs CLAUDE.md

1. Read the root `pom.xml` and admin `pom.xml`
2. Extract key version properties (`spring-boot.version`, `spring-ai.version`, etc.)
3. Compare with claims in `CLAUDE.md` (e.g., "Spring Boot 3.3.6")
4. Flag version mismatches

### Step 6: Cross-Reference Completeness

Check that every entity referenced in the API has a data model definition:

```
For each endpoint in api-list.md:
  - Extract entity names from request/response types
  - Verify each entity exists in data-model.md
  - Flag entities used in API but missing from data model
```

## Output Format

Always produce a structured report:

```markdown
## Docs Sync Report — {date}

### Summary
- Controllers scanned: N
- Endpoints checked: N
- Entities checked: N
- Discrepancies found: N (HIGH: x, MEDIUM: y, LOW: z)

### HIGH — Code bugs or broken endpoints
| # | File:Line | Endpoint | Issue |
|---|-----------|----------|-------|
| 1 | DatasetController.java:160 | GET /api/dataset/dataItem | @PathVariable without {id} in path — runtime crash |

### MEDIUM — Doc missing entries
| # | Doc File | Missing Entry | Source |
|---|----------|---------------|--------|
| 1 | api-list.md | GET /api/new-endpoint | NewController.java:42 |

### LOW — Cosmetic mismatches
| # | Doc File | Section | Issue |
|---|----------|---------|-------|
| 1 | data-model.md | prompt table | Doc says VARCHAR(32), code says VARCHAR(64) |

### Entities Missing from data-model.md
| Entity | Used In | Source File |
|--------|---------|-------------|
| NewEntity | NewController | entity/NewEntityDO.java |

### Doc Files Checked
- [x] docs/api-list.md — last updated: {date}
- [x] docs/data-model.md — last updated: {date}
- [x] CLAUDE.md — last updated: {date}
```

## Severity Definitions

| Level | Definition | Example |
|-------|-----------|---------|
| **HIGH** | Code will crash or behave incorrectly | `@PathVariable` without path segment, wrong HTTP method |
| **MEDIUM** | Doc is incomplete or misleading | Missing endpoint, missing entity definition |
| **LOW** | Cosmetic inconsistency | Javadoc mismatch, field description differs |

## Scan Scope Options

The user may request different scopes:

| Scope | What to Check |
|-------|---------------|
| `full` | All Controllers, all Entities, all SQL, CLAUDE.md |
| `changed` | Only files with uncommitted or recent git changes |
| `api` | Only Controllers vs api-list.md |
| `data` | Only Entity/SQL vs data-model.md |
| `single <file>` | One specific Controller or Entity |

Default: `changed` (if git changes exist) or `full` (if no changes detected).

## Rules

- **Read-only**: Never edit any file. Report only.
- **No false positives**: If unsure about a mismatch, mark it as "needs review" not "confirmed".
- **Be specific**: Always include file path, line number, and the exact mismatch.
- **Prioritize**: HIGH issues first — they block correctness. LOW issues last.
- **Fresh scan**: Always read the actual file content, never rely on cached assumptions.
