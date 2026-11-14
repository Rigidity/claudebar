import SwiftUI

struct MenuBarLabel: View {
    let snapshot: UsageSnapshot?
    let hasError: Bool

    var body: some View {
        if let snapshot, !hasError {
            Image(nsImage: MenuBarImage.make(session: snapshot.session, weekly: snapshot.weekly))
        } else {
            Image(systemName: hasError ? "exclamationmark.triangle" : "gauge.with.dots.needle.33percent")
        }
    }
}

struct UsagePanel: View {
    @ObservedObject var store: UsageStore
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var loginItemError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Claude Usage").font(.headline)

            if let error = store.error ?? loginItemError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let snapshot = store.snapshot {
                WindowRow(title: "Session", window: snapshot.session, emptyText: "No active session")
                WindowRow(title: "Weekly", window: snapshot.weekly, emptyText: "Unavailable")
                WindowRow(title: "Fable weekly", window: snapshot.fableWeekly, emptyText: "No Fable limit on this plan")
            } else if store.error == nil {
                ProgressView().frame(maxWidth: .infinity)
            }

            Divider()

            HStack(spacing: 12) {
                if let lastUpdated = store.lastUpdated {
                    Text("Updated \(lastUpdated.formatted(date: .omitted, time: .shortened))")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    store.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .disabled(store.isLoading)
                .help("Refresh")

                Menu {
                    Toggle("Launch at Login", isOn: Binding(
                        get: { launchAtLogin },
                        set: { setLaunchAtLogin($0) }
                    ))
                    Divider()
                    Button("Quit ClaudeBar") { NSApplication.shared.terminate(nil) }
                        .keyboardShortcut("q")
                } label: {
                    Image(systemName: "ellipsis")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("More")
            }
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(width: 300)
        .onAppear { launchAtLogin = LaunchAtLogin.isEnabled }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try LaunchAtLogin.set(enabled)
            loginItemError = nil
        } catch {
            loginItemError = "Couldn't change the login item: \(error.localizedDescription)"
        }
        launchAtLogin = LaunchAtLogin.isEnabled
    }
}

private struct WindowRow: View {
    let title: String
    let window: LimitWindow?
    let emptyText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title).font(.subheadline.weight(.semibold))
                Spacer()
                if let window {
                    Text("\(Int(window.usedPercent.rounded()))% used").font(.subheadline.monospacedDigit())
                }
            }

            if let window {
                let tint = window.paceLevel().color
                PaceBar(used: window.usedPercent, expected: window.expectedPercent(), tint: tint)
                HStack {
                    PaceText(delta: window.paceDelta(), tint: tint)
                    Spacer()
                    if let resetsAt = window.resetsAt {
                        Text("Resets \(resetsAt, style: .relative)")
                            .foregroundStyle(.secondary)
                            .help(resetsAt.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()
                                .hour().minute()))
                    }
                }
                .font(.caption)
                if let hit = window.projectedLimitDate() {
                    Text("At this pace: 100% by \(Self.format(hit))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text(emptyText).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    /// Time only for today, otherwise weekday and time ("Sat 7:05 AM").
    private static func format(_ date: Date) -> String {
        Calendar.current.isDateInToday(date)
            ? date.formatted(date: .omitted, time: .shortened)
            : date.formatted(.dateTime.weekday(.abbreviated).hour().minute())
    }
}

/// Usage bar with a tick marking where usage would be at an even pace.
/// Usage past the tick is hatched, so the size of a deficit is visible at a glance.
private struct PaceBar: View {
    let used: Double
    let expected: Double?
    let tint: Color

    var body: some View {
        Canvas { context, size in
            let w = size.width, h = size.height
            let track = Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: h / 2)
            context.fill(track, with: .style(.quaternary))

            let usedX = w * min(used, 100) / 100
            var fill = context
            fill.clip(to: Path(roundedRect: CGRect(x: 0, y: 0, width: usedX, height: h), cornerRadius: h / 2))

            if let expected, used > expected {
                let paceX = w * expected / 100
                fill.fill(Path(CGRect(x: 0, y: 0, width: paceX, height: h)), with: .color(tint))

                var hatch = fill
                hatch.clip(to: Path(CGRect(x: paceX, y: 0, width: usedX - paceX, height: h)))
                hatch.fill(Path(CGRect(x: paceX, y: 0, width: usedX - paceX, height: h)),
                           with: .color(tint.opacity(0.45)))
                var stripes = Path()
                for x in stride(from: paceX - h, through: usedX, by: 5) {
                    stripes.move(to: CGPoint(x: x, y: h))
                    stripes.addLine(to: CGPoint(x: x + h, y: 0))
                }
                hatch.stroke(stripes, with: .color(tint), lineWidth: 2)
            } else {
                fill.fill(Path(CGRect(x: 0, y: 0, width: usedX, height: h)), with: .color(tint))
            }

            if let expected {
                let x = min(max(w * expected / 100, 1), w - 1)
                context.fill(Path(CGRect(x: x - 1, y: 0, width: 2, height: h)), with: .style(.primary))
            }
        }
        .frame(height: 8)
    }
}

private struct PaceText: View {
    let delta: Double?
    let tint: Color

    var body: some View {
        if let delta {
            let amount = Int(abs(delta).rounded())
            if amount == 0 {
                Text("On pace").foregroundStyle(.secondary)
            } else if delta > 0 {
                Text("\(amount)% in reserve").foregroundStyle(tint)
            } else {
                Text("\(amount)% in deficit").foregroundStyle(tint)
            }
        }
    }
}

extension PaceLevel {
    var color: Color { Color(nsColor: nsColor) }
}
