# NetUtil — GEMINI.md

Specialized instructions for codebase conventions, UI standards, and release procedures.

---

## Technical Context: Ping Feature

The Ping tool in NetUtil is a high-performance wrapper around `/sbin/ping`, utilizing `Process` and `Pipe` for real-time output capture and asynchronous regex parsing.

### Current Architecture & UI/UX (v2.0.0)
- **Model**: `PingResult` (sequence, bytes, host, ttl, rtt, status, timestamp).
- **ViewModel**: `@MainActor PingViewModel` (handles process lifecycle, unlimited timeout logic, and audio feedback via "Tink" system sound).
- **UI Style**: 
    - **Typography**: Pure San Francisco (SF) Pro standard (no rounded/monospaced variations for headers).
    - **Symmetry**: Grid-based layout with consistent card heights.
    - **Hierarchy**: Clear sectioning with bold headers and functional descriptions.
- **Interactive Visuals**:
    - **Health Strip**: GitHub-style bar representing the last 100 packets (Green/Orange/Red).
    - **Smart Interpretation**: Logic-driven status summary (Excellent, Congested, etc.) with dynamic icons.
    - **Scrollable Chart**: Interactive Swift Chart with horizontal scrolling, packet selection, and reference lines.
    - **Auto-Scroll Table**: Custom `ScrollViewReader` based table for guaranteed real-time scrolling to the latest results.
- **Reporting**:
    - **PDF Report**: Branded documents with app logo, detailed stats, and timestamped filenames.
    - **CSV Export**: Standardized timestamped file naming for systemic archiving.

---

## 🤖 Release Automation Prompt Procedure

When the user asks to **"commit, build DMG, and release"** (or similar), perform these steps automatically **without exception**. Every file in step 2 must be updated every release, no skipping.

0.  **Sync Local**: Run `git pull` to ensure you are working on the latest code.

1.  **Version Management (SemVer Rules)**:
    - **Major (X.0.0)**: Full upgrade, perombakan sistem, atau perubahan core besar.
    - **Minor (0.X.0)**: Penambahan 1 fitur atau peningkatan alat yang signifikan.
    - **Patch (0.0.X)**: Perubahan minor banget, UI polish, atau bug fix.
    - Update `MARKETING_VERSION` (both Debug + Release configs) and `CURRENT_PROJECT_VERSION` (+1) in `project.pbxproj`.

2.  **Documentation Sync (ALL files, no exceptions)**:
    - `CHANGELOG.md` → new `[X.X.X] — YYYY-MM-DD` section at top describing all changes.
    - `README.md` → reflect new/changed features in both **EN and ID** sections.
    - `DOCUMENTATION.md` → update version footer line, update toolset section if tools changed.
    - `AboutView.swift`:
      - Update version fallback string: `?? "X.X.X"`.
      - Verify `toolList` matches the **canonical list** exactly (see below).

3.  **Canonical `toolList` for `AboutView.swift`** — must always match `ContentView.swift` Tool enum:
    ```swift
    ("square.grid.2x2",                       "Mission Dashboard"),
    ("antenna.radiowaves.left.and.right",      "Advanced Ping"),
    ("point.3.connected.trianglepath.dotted",  "Traceroute"),
    ("dot.radiowaves.left.and.right",          "Multi-Ping"),
    ("checklist",                              "Port Scanner"),
    ("stopwatch",                              "HTTP Latency"),
    ("globe",                                  "DNS Lookup"),
    ("magnifyingglass.circle",                 "WHOIS"),
    ("lock.shield",                            "SSL/TLS Inspector"),
    ("network",                                "Network Interfaces"),
    ("wifi",                                   "Wi-Fi Inspector"),
    ("arrow.triangle.branch",                  "Route Table"),
    ("chart.bar.xaxis",                        "Bandwidth Monitor"),
    ```
    If a new tool is added to ContentView Tool enum, add it here too (same SF symbol, same display name).

4.  **Clean Up**: `rm -rf dist/NetUtil.xcarchive`

5.  **Build & Package**:
    ```bash
    xcodebuild -project NetUtil.xcodeproj -scheme NetUtil -configuration Release \
      -destination 'platform=macOS' ARCHS='arm64 x86_64'
    bash scripts/build_dmg.sh
    ```

6.  **Version Control & GitHub**:
    ```bash
    git commit -m "docs: release vX.X.X - <key features>"
    git push origin main
    git tag vX.X.X
    git push origin --tags
    gh release create vX.X.X dist/NetUtil-X.X.X.dmg \
      --title "vX.X.X — <short title>" --notes "..."
    ```

---

## Native macOS Anti-Slop Guidelines (v2.3+)

To maintain a professional, "Apple Artisan" aesthetic, NEVER use AI-generated web-style layouts. All views MUST strictly adhere to these Native Mac principles:

### 1. The "Material" Rule (No Fake Opacity)
- **NEVER** use `.background(Color(...).opacity(...))` for cards or containers. This is considered "AI Slop".
- **ALWAYS** use SwiftUI's native materials: `.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))`. This ensures true vibrancy that reacts to the user's macOS wallpaper.

### 2. Flat Data Hierarchy (No Box-in-Box)
- **NEVER** wrap data tables, lists, or large charts in heavily shadowed, thick-bordered boxes.
- **ALWAYS** let data flow naturally. Separate rows using simple `Divider().opacity(0.5)` with generous horizontal padding (`12pt`-`16pt`). The outer container should only have a very subtle border: `.overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))`.

### 3. Refined Typography (No Shouting)
- **NEVER** use forced ALL CAPS with heavy weights (e.g., `.font(.system(size: 10, weight: .black))`) for section titles.
- **ALWAYS** use standard system typographics: `.font(.headline)` for sections, `.font(.subheadline)` for descriptions, and `.font(.system(size: 11, design: .monospaced))` for technical data. Use Sentence Case or Title Case.

### 4. Silent Empty States & Data-Dense Headers
- **NEVER** use massive 40pt+ icons with chatty instructions (e.g., "Ready to analyze! Enter a URL...") for empty states. Use silent, `.secondary` text: `Text("No Target Selected")`.
- **NEVER** use conversational text in status headers (e.g., "All Systems Go! 2 out of 2 endpoints...").
- **ALWAYS** use data-dense, clinical terminology (e.g., "Active: 2", "Status: Secure"). 

### 5. Unified Control Bar (Fixed Top)
- **Position**: Always locked at the top (`VStack` with 0 spacing, followed by `ScrollView`).
- **Layout**: `HStack` with 12pt spacing.
    - **Left**: Main Input (TextField) with trailing history overlay (clock icon `clock.arrow.circlepath`).
    - **Center**: Variable settings (Toggles, Pickers).
    - **Right**: Action Group: `[Report Menu]`, `[Start/Stop Button]`, `[Learning Guide (questionmark.circle)]`.

---

## Manual Validation Checklist

Since there are no automated tests, validate before every release:
- Test with valid hostnames (`google.com`).
- Test with invalid hostnames (`this.does.not.exist`).
- Test with unreachable IPs to verify timeout handling.
- Verify chart responsiveness during long-running infinite pings.
- Open Settings and confirm all 4 panes load without error.
- Verify AboutView tool grid shows all 13 tools.
