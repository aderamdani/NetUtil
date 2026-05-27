# NetUtil — GEMINI.md

Specialized instructions for codebase conventions, UI standards, and release procedures.

---

## Technical Context: Ping Feature

The Ping tool in NetUtil is a high-performance wrapper around `/sbin/ping`, utilizing `Process` and `Pipe` for real-time output capture and asynchronous regex parsing.

### Current Architecture & UI/UX (v1.9.0)
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

## UI/UX Standardization Rules

All diagnostic views must strictly follow this symmetrical structure:

### 1. Unified Control Bar (Header)
- **Position**: Always fixed at the top (`VStack` with 0 spacing, followed by `ScrollView`).
- **Layout**: `HStack` with 12pt spacing.
    - **Left**: Main Input (TextField) with trailing history overlay (clock icon). 250–300pt width.
    - **Center**: Variable settings (Toggles, Pickers, Steppers). Aligned contextually.
    - **Right**: Action Group: `[Report Menu]`, `[Start/Stop Button]`, `[Learning Guide Button]`.

### 2. Interpretation Header
- Located immediately below the control bar inside the `ScrollView`.
- **Left**: Dynamic Icon + Large Status Title + Subtitle Description.
- **Right**: Auxiliary visual (Health Strip for Ping, Progress for Port Scan/Traceroute).

### 3. Stat Bar
- Row of `StatCard` components.
- Standard titles: ALL CAPS, font size 10, weight black, kerning 1.
- Value spacing: Standardized padding and shadow (Opacity 0.08, Y-offset 4).

### 4. Results Container
- 12pt corner radius, background `.controlBackgroundColor` (0.5 opacity).
- Shadow: Radius 8, Y-offset 4, Opacity 0.08.
- Border: 1pt stroke, `.separatorColor` (0.1 opacity).

---

## Manual Validation Checklist

Since there are no automated tests, validate before every release:
- Test with valid hostnames (`google.com`).
- Test with invalid hostnames (`this.does.not.exist`).
- Test with unreachable IPs to verify timeout handling.
- Verify chart responsiveness during long-running infinite pings.
- Open Settings and confirm all 4 panes load without error.
- Verify AboutView tool grid shows all 13 tools.
