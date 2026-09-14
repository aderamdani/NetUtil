import SwiftUI

/// First-run welcome, shown once (gated by @AppStorage hasCompletedOnboarding
/// in ContentView). Privacy-forward: states the no-telemetry stance and points
/// to the full per-tool host breakdown in Settings > Privacy.
struct OnboardingView: View {
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: Metrics.spacingXL) {
            VStack(spacing: Metrics.spacingSM) {
                Image(systemName: "network")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
                Text("Welcome to NetUtil")
                    .font(.title.weight(.bold))
                Text("28 network tools, native to macOS. No accounts, no telemetry, zero third-party dependencies.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: Metrics.spacingMD) {
                featureRow(icon: "stethoscope", title: "Diagnose",
                           detail: "Ping, traceroute, and a guided Connection Doctor pinpoint where a network breaks.")
                featureRow(icon: "chart.bar.xaxis", title: "Monitor",
                           detail: "Live bandwidth, Wi-Fi signal, and traffic statistics — sampled only while you're watching.")
                featureRow(icon: "lock.shield", title: "Audit",
                           detail: "Inspect SSL certificates, scan ports, and look up WHOIS and DNS records.")
            }

            privacyCard

            Button(action: onDismiss) {
                Text("Get Started").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
        }
        .padding(Metrics.spacingXL)
        .frame(width: 520)
    }

    private func featureRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: Metrics.spacingMD) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Metrics.spacingXS) {
                Text(title).font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(detail)")
    }

    private var privacyCard: some View {
        HStack(alignment: .top, spacing: Metrics.spacingMD) {
            Image(systemName: "hand.raised.fill")
                .font(.title3)
                .foregroundStyle(.green)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Metrics.spacingXS) {
                Text("Your data stays yours").font(.headline)
                Text("Nothing is tracked. Tools only reach the hosts you'd expect — like ipinfo.io for IP geolocation and Cloudflare for speed tests. See the full per-tool breakdown anytime in Settings > Privacy.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Metrics.spacingLG)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Metrics.cornerRadiusLG))
        .overlay(RoundedRectangle(cornerRadius: Metrics.cornerRadiusLG).stroke(Color(.separatorColor).opacity(0.1), lineWidth: 0.5))
    }
}
