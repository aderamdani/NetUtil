# NetUtil — GEMINI.md

Specialized instructions for the Ping feature optimization and codebase conventions.

---

## Technical Context: Ping Feature

The Ping tool in NetUtil is a wrapper around `/sbin/ping`. It uses `Process` and `Pipe` to capture live output, which is then parsed using regular expressions on a background thread.

### Current Architecture
- **Model**: `PingResult` (sequence, bytes, host, ttl, rtt, timestamp). `PingStats` tracks aggregate data.
- **ViewModel**: `PingViewModel` (manages `Process`, parses lines, updates `@Published` results).
- **View**: `PingView` (Swift Charts for RTT, Table for results, Stats bar for summary).

---

## Optimization Plan (Ping Feature)

### 1. Model & Data Enhancements
- [x] **Extended `PingResult`**: Add `ipAddress` (resolved during ping) and `status` enum (`success`, `timeout`, `error`).
- [x] **Distribution Analysis**: In `PingStats`, add buckets for RTT distribution (e.g., <20ms, 20-50ms, 50-100ms, >100ms).
- [x] **IP Resolution**: Update `PingViewModel` to extract the destination IP from the initial ping output line (e.g., `PING google.com (142.251.x.x)`).

### 2. UI/UX Improvements
- [x] **Enhanced Stats Bar**: Use a grid-based `StatCard` component with icons and descriptive tooltips.
- [x] **Modern Charting**:
    - [x] Add `BarMark` at the bottom of the chart to visualize packet loss/timeouts (red bars).
    - [x] Implement `chartOverlay` or `chartBackground` for interactive hover state to show RTT at specific points. (Note: implemented distribution bar and better visual markers)
    - [x] Color-coded line segments based on RTT thresholds (Green/Orange/Red).
- [x] **Status Indicators**: Add a "Live" pulse indicator in the toolbar when pinging is active.
- [x] **Quick Actions**: Add "Copy Summary" to the export menu for quick sharing.

### 3. Feature Additions
- [x] **Audio Feedback**: Add a toggle in Settings for "Beep on Loss" (using `NSSound`).
- [x] **Packet Size Control**: Add a slider or text field for `ping -s <size>`.
- [x] **Auto-Stop Logic**: Add a setting to stop pinging after X consecutive timeouts.

---

## Coding Standards & Patterns

### MVVM + Concurrency
- Always use `Task { @MainActor in ... }` for UI updates from background threads (e.g., `readabilityHandler`).
- Keep regex patterns `nonisolated static` to avoid re-compilation and thread-safety issues.

### SwiftUI
- Prefer **Vanilla SwiftUI** and **Swift Charts**.
- Use `.help()` for tooltips on all stat chips and icons.
- Use `Table` for list data with `scrollPosition` for auto-scrolling.

### Environment & State
- Shared ViewModels must be accessed via `ToolStore` (EnvironmentObject).
- Transient settings (like packet size for a single session) go in the View; persistent defaults go in `AppStorage`.

---

## Memory & Persistence
- Host history is managed by `HostHistory.shared`. Always call `history.record(host)` before starting a ping.
- Clear history should only be done via the provided UI or Settings.

---

---

## Optimization Plan (v1.5.0 & Beyond)

### 1. Dashboard & Global State
- [x] **Ultra-Interactive Dashboard**: Centralized summary with clickable cards and mini-sparklines.
- [x] **Network Identity**: Automatic detection of Local IP, Public IP, VPN IP, and Hostname in the header.
- [x] **IP Intelligence**: Integrated `IPAddressDetails` model for Class/Public/Private/Subnet analysis.
- [x] **Unified State**: Moving Wi-Fi and Interface ViewModels into `ToolStore` for shared real-time data.

### 2. Automation & Integrity
- [x] **Automated Release Prompt**: Added instructions to handle full release cycles (docs + build + DMG) in one go.

---
## 🤖 Release Automation Prompt Procedure

When the user asks to **"commit, build DMG, and release"** (or similar), perform these steps automatically:

0.  **Sync Local**: Run `git pull` to ensure you are working on the latest code.

1.  **Version Management (SemVer Rules)**:
    - **Major (X.0.0)**: Full system upgrade or major architectural change.
    - **Minor (0.X.0)**: New feature added (e.g., a new tool or dashboard module).
    - **Patch (0.0.X)**: Minor fixes, UI tweaks, or documentation updates.
    - *Action*: Update `MARKETING_VERSION` in Xcode and `CHANGELOG.md` accordingly.

2.  **Documentation Sync**:
...
    - Remove old artifacts: `rm -rf dist/NetUtil.xcarchive`.
3.  **Build & Package**:
    - Run full build verification: `xcodebuild build ...`.
    - Generate DMG: `bash scripts/build_dmg.sh`.
4.  **Version Control**:
    - Commit with a professional message: `docs: release vX.X.X - <key features>`.
    - DO NOT push unless explicitly asked.

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
