# NetUtil — Session Handoff

> Last updated: 2026-09-14. Read this before starting a new session.

## Current state

- Branch `main`, HEAD `a509e4b` (`revert: undo Liquid Glass redesign, restore 4.19.0 UI`). Working tree clean.
- Latest release: **v4.19.0** (tag `v4.19.0` at commit `b1f820b`) — published on GitHub with DMG + Homebrew cask.
- Push: local `main` has **no upstream configured**. Use `git push origin main` (or set upstream once).
- Build/test/lint are green.

## Recent history

- **v4.19.0 features**: Ping IPv6 + timeout, Net Quality interface binding + iCloud Private Relay, one-click reverse DNS lookup, Help how-to guides, Traceroute route-change detection, IP protocol + canonical interface-name helpers.
- **Liquid Glass redesign (P4-1/P4-2) was attempted and fully reverted** in `a509e4b` — the user judged it worse ("UI berantakan / AI slop"). **Do not resume that approach unless explicitly asked.**
  - What was tried (all undone): `.searchable` sidebar/toolbar search; migrating per-tool control bars to the system `.toolbar` (`ToolToolbar`); an "Options" popover; `ToolbarHostField`; removing `ToolControlBar`.
- Backlog: P0/P1/P2/P3 items are done. P4 (Liquid Glass) is **cancelled**.

## Open decisions / known issues

1. **Search vs history menu are redundant.** The toolbar/sidebar search and each tool's history (clock) menu both read `HostHistory`. Options discussed, none applied:
   - remove the global search (history menu already covers host recall), or
   - turn the global search into a command palette (tools/settings/help), or
   - make it fill the active tool's host.
2. **UI polish is wanted but the big refactor is off.** Prefer small, screen-specific, verifiable fixes, each with a screenshot from the user and one commit per fix. Candidates: replace hardcoded corner radii with `Metrics.*` tokens, tidy spacing, unify chip/badge styling.
3. **App icon** not changed. Brief is in `docs/ICON-BRIEF.md`; needs layered source assets + Icon Composer.

## Build / verify / release

```bash
xcodebuild -project NetUtil.xcodeproj -scheme NetUtil -destination 'platform=macOS' ARCHS='arm64' build
xcodebuild -project NetUtil.xcodeproj -scheme NetUtil -destination 'platform=macOS' test
bash scripts/hig-lint.sh
bash scripts/build_dmg.sh
```

Release checklist lives in `AGENTS.md` (bump `MARKETING_VERSION`/`CURRENT_PROJECT_VERSION`, CHANGELOG, AGENTS footer, AboutView, lint, DMG, commit/tag/push, `gh release create`, verify not draft, bump cask in `~/Developer/homebrew-tap`).

## Environment & tooling

- **RTK**: prefix shell commands with `rtk` (`rtk git …`, `rtk rg …`, `rtk find …`, `rtk read …`, `rtk wc …`). For `xcodebuild`, use `rtk proxy xcodebuild …` to keep exit codes for gates.
- **opencode global config** (`~/.config/opencode/opencode.jsonc`): `plugin: ["./plugins/rtk.ts", "token-optimizer-opencode"]`, skills path `~/.agents/skills/caveman`, plus `formatter.ruff` and `lsp.ty`. Restart opencode for config changes.
- **headroom** installed at `~/.local/bin/headroom` (uv, base + `[proxy]`), PATH added via `~/.zshenv`. Proxy not required for the app.
- **caveman** skill (in `~/.agents/skills`) sets a terse chat style; persists until "stop caveman".

## Suggested next steps

1. Ask the user for a screenshot and a concrete list of the worst screens before touching UI.
2. Do small, isolated UI fixes (one commit each); verify build + `hig-lint` + tests.
3. Decide the search consolidation (see Open decisions).
4. Icon: produce layered assets per `docs/ICON-BRIEF.md`.
