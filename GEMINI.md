# NetUtil — GEMINI.md

Specialized instructions for the Ping feature optimization and codebase conventions.

---
## Technical Context: Ping Feature

The Ping tool in NetUtil is a high-performance wrapper around `/sbin/ping`, utilizing `Process` and `Pipe` for real-time output capture and asynchronous regex parsing.

### Current Architecture & UI/UX (v1.7.2)
- **Model**: `PingResult` (sequence, bytes, host, ttl, rtt, status, timestamp).
- **ViewModel**: `@MainActor PingViewModel` (handles process lifecycle, unlimited timeout logic, and audio feedback via "Tink" system sound).
- **UI Style**: 
    - **Typography**: Pure San Francisco (SF) Pro standard (no rounded/monospaced variations for headers).
    - **Symmetry**: Grid-based layout with consistent card heights (160pt tool/140pt connectivity).
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

## Optimization Plan (v1.7.2 & Beyond)

### 1. Ping & Diagnostics
- [x] **Smart Interpretation**: Connection quality assessment for educational value.
- [x] **Health Strip**: Instant 100-packet stability visualization.
- [x] **Scrollable RTT Chart**: Historical data navigation.
- [x] **Premium Audio Feedback**: Modern "Tink" sound on packet loss.
- [x] **Unlimited Session**: Removed auto-stop logic; manual control only.
- [x] **Branded PDF Export**: Professional reporting with app identity.

### 2. Dashboard & Global State
...
- [x] **UI/UX Overhaul**: Premium refactoring for clarity, hierarchy, and macOS native aesthetics.
- [x] **Ultra-Interactive Dashboard**: Centralized summary with clickable cards and mini-sparklines.
- [x] **Network Identity**: Automatic detection of Local IP, Public IP, VPN IP, and Hostname in the header.
- [x] **IP Intelligence**: Integrated `IPAddressDetails` model for Class/Public/Private/Subnet analysis.
- [x] **Unified State**: Moving Wi-Fi and Interface ViewModels into `ToolStore` for shared real-time data.

### 2. Automation & Integrity
- [x] **Automated Release Prompt**: Added instructions to handle full release cycles (docs + build + DMG) in one go.
- [x] **Versioning Rules**: Explicit SemVer logic (Major/Minor/Patch) for automated releases.
- [x] **Git Integration**: Automated `git pull`, `git push`, and `git tag` procedures.

---
## 🤖 Release Automation Prompt Procedure

When the user asks to **"commit, build DMG, and release"** (or similar), perform these steps automatically:

0.  **Sync Local**: Run `git pull` to ensure you are working on the latest code.

1.  **Version Management (SemVer Rules)**:
    - **Major (X.0.0)**: Full upgrade, perombakan sistem, atau perubahan core besar.
    - **Minor (0.X.0)**: Penambahan 1 fitur atau peningkatan alat yang signifikan.
    - **Patch (0.0.X)**: Perubahan minor banget, UI polish, atau bug fix.
    - *Action*: Update `MARKETING_VERSION` in Xcode and `CHANGELOG.md` accordingly.

2.  **Documentation Sync**:
    - Update `CHANGELOG.md` with latest features.
    - Sync `README.md` and `DOCUMENTATION.md` versions.
    - Update `AboutView.swift` tool lists and acknowledgments.

3.  **Clean Up**:
    - Remove old artifacts: `rm -rf dist/NetUtil.xcarchive` (Hapus xcarchive lama di dist).

4.  **Build & Package**:
    - Run full build verification: `xcodebuild build -project NetUtil.xcodeproj -scheme NetUtil -configuration Release -destination 'platform=macOS' ARCHS='arm64 x86_64'`.
    - Generate DMG: `bash scripts/build_dmg.sh`.

5.  **Version Control & GitHub**:
    - Commit with a professional message: `docs: release vX.X.X - <key features>`.
    - Push code and tags: 
      - `git push origin main`
      - `git tag vX.X.X`
      - `git push origin --tags`
    - **Fallback (Manual Release)**: Jika CI GitHub Actions gagal (billing issue), jalankan:
      `gh release create vX.X.X dist/NetUtil-X.X.X.dmg --title "vX.X.X" --notes "Release notes summary"`

---

## Release Automation Procedure (Automated via GitHub Actions)

To trigger a new official release:
1. **Update Version**: Sync `MARKETING_VERSION` in Xcode and update `CHANGELOG.md`.
2. **Commit Changes**: Commit the version bump and changelog update.
3. **Push Tag**: Push a new tag (e.g., `git tag v1.3.0 && git push origin v1.3.0`).
4. **GitHub Actions**: The `release.yml` workflow will automatically:
    - Build the application in Release mode.
    - Generate the branded DMG installer.
    - Create a GitHub Release with auto-generated release notes.
    - Attach the DMG file to the release assets.
    - Send a notification (if `DISCORD_WEBHOOK` is configured in Secrets).

---
- Since there are no automated tests, manual validation is required:
    - Test with valid hostnames (`google.com`).
    - Test with invalid hostnames (`this.does.not.exist`).
    - Test with unreachable IPs to verify timeout handling.
    - Verify chart responsiveness during long-running infinite pings.
