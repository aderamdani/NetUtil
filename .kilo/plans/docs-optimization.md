# Plan: Documentation Optimization & Consolidation

## Goal
Consolidate all project documentation into a streamlined structure with a single skill file, eliminating redundancy and reducing total doc footprint by ~60%.

## Current State
- **~2,360 lines** across 10+ documentation files
- **CLAUDE.md** (356 lines) and **GEMINI.md** (328 lines) overlap ~70% (same Swift rules, HIG, Anti-Slop, release workflow)
- **DOCUMENTATION.md** (118 lines) duplicates architecture info from CLAUDE.md/GEMINI.md
- **SKILL.md** (142 lines) is a generic "find-skills" agent skill — unrelated to NetUtil itself
- **QA-CLINICAL-TEST.md** (402 lines) is a test report, not living documentation
- **ROADMAP.md** (146 lines) is a development tracker, not living documentation
- No `.kilo/` directory exists despite `kilo.json` config referencing it

## Target Structure

```
NetUtil/
├── AGENTS.md              # Single consolidated agent instruction file (~250 lines)
│   (replaces CLAUDE.md + GEMINI.md + DOCUMENTATION.md sections)
├── README.md              # Keep, trim to single-language + links (~60 lines)
├── CHANGELOG.md           # Keep as-is (historical record)
├── CONTRIBUTING.md        # Keep, shorten (~25 lines)
├── SECURITY.md            # Keep as-is (~26 lines)
├── LICENSE                # Keep as-is
├── ROADMAP.md             # Keep as-is (development tracker)
├── QA-CLINICAL-TEST.md    # Keep as-is (test report)
└── .kilo/
    └── skills/
        └── netutil.md     # Single skill file for Kilo agent (~150 lines)
```

## Detailed Changes

### 1. Create `AGENTS.md` — Single Agent Instruction File
**Replaces:** CLAUDE.md (356 lines) + GEMINI.md (328 lines) + DOCUMENTATION.md (118 lines)

Consolidate into one file with these sections:
- **Project Summary** — one paragraph + build commands
- **Architecture** — MVVM, ToolStore, @Observable, directory structure
- **Tools Table** — single canonical table (from CLAUDE.md, with History/Compare)
- **Release Workflow** — the 9-step checklist (deduplicated from both files)
- **Canonical toolList** — the Swift code block (single source of truth)
- **HIG Rules** — typography, layout, materials, components (deduplicated)
- **Anti-Slop Rules** — the 8 rules (deduplicated, remove repeated NEVER/ALWAYS)
- **Swift Engineering** — progressive arch, error handling, access control, quality gates
- **SwiftUI Rules** — view composition, state, deprecated API, performance, accessibility
- **Swift 6 Concurrency** — MainActor, Sendable, task management, actor safety
- **Xcode Optimization** — build settings, code-level perf, script phases
- **macOS Patterns** — window management, menu/keyboard, distribution

**Deduplication strategy:**
- HIG + Anti-Slop appear in both CLAUDE.md and GEMINI.md with near-identical wording → keep one copy
- Swift/SwiftUI/Concurrency/Xcode/macOS sections are identical in both → keep one copy
- Release workflow is identical → keep one copy
- GEMINI.md's "Ping Feature" deep-dive → move to code comments or remove (too specific for agent docs)
- GEMINI.md's "Manual Validation Checklist" → remove (covered by QA-CLINICAL-TEST.md)
- DOCUMENTATION.md architecture + toolset → merge into AGENTS.md
- DOCUMENTATION.md "Development & Testing" → merge into AGENTS.md
- Remove section numbering (## 1. Overview, ## 2. Architecture, etc.) — use clean headers

**Estimated output:** ~250 lines (vs. 802 combined)

### 2. Delete `CLAUDE.md` and `GEMINI.md`
- All content merged into AGENTS.md
- CONTRIBUTING.md references GEMINI.md → update to AGENTS.md

### 3. Delete `DOCUMENTATION.md`
- Architecture content merged into AGENTS.md
- README.md references → update link to AGENTS.md

### 4. Trim `README.md`
- Remove verbose feature lists (link to AGENTS.md tools table instead)
- Keep: badges, one-paragraph description, installation, links, license
- Remove Bahasa Indonesia section (or condense to one line linking to a future ID docs page)
- **Estimated:** ~60 lines (vs. 103)

### 5. Trim `CONTRIBUTING.md`
- Remove redundant build requirements (in AGENTS.md)
- Remove coding standards bullet list (reference AGENTS.md)
- **Estimated:** ~25 lines (vs. 41)

### 6. Delete `SKILL.md`
- Generic "find-skills" agent skill, not NetUtil-specific
- Not referenced by any build or agent config

### 7. Create `.kilo/skills/netutil.md` — Single Skill File
A Kilo-specific skill that provides:
- Project identity (name, platform, language)
- Build & release commands (condensed)
- Canonical toolList (same as AGENTS.md)
- HIG quick-reference (condensed bullet list)
- File structure map

**This replaces the need for SKILL.md** and serves as the Kilo agent's quick-reference skill.

### 8. Keep As-Is (No Changes)
- `CHANGELOG.md` — historical record, append-only
- `ROADMAP.md` — development tracker
- `QA-CLINICAL-TEST.md` — test report
- `SECURITY.md` — security policy
- `LICENSE` — MIT license

## Execution Order
1. Create `AGENTS.md` (consolidated from CLAUDE.md + GEMINI.md + DOCUMENTATION.md)
2. Create `.kilo/skills/netutil.md`
3. Trim `README.md`
4. Trim `CONTRIBUTING.md`
5. Delete `CLAUDE.md`, `GEMINI.md`, `DOCUMENTATION.md`, `SKILL.md`

## Verification
- No broken internal links in remaining files
- AGENTS.md contains all canonical info (toolList, release checklist, HIG rules)
- Build commands still documented
- `kilo.json` config still valid (references AGENTS.md implicitly)
