import SwiftUI

struct MenuBarLabel: View {
    let snapshot: UsageSnapshot?
    let hasError: Bool

    var body: some View {
        if let snapshot, !hasError {
            let parts = [snapshot.session, snapshot.weekly].compactMap { $0 }
                .map { "\($0.id == "session" ? "S" : "W") \(Int($0.usedPercent.rounded()))%" }
            Text(parts.isEmpty ? "—" : parts.joined(separator: " · "))
        } else {
            Image(systemName: hasError ? "exclamationmark.triangle" : "gauge.with.dots.needle.33percent")
        }
    }
}

struct UsagePanel: View {
    @ObservedObject var store: UsageStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Claude Usage").font(.headline)

            if let error = store.error {
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

            HStack {
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
                .disabled(store.isLoading)
                .help("Refresh")
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }
            .buttonStyle(.borderless)
        }
        .padding(16)
        .frame(width: 300)
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
                PaceBar(used: window.usedPercent, expected: window.expectedPercent())
                HStack {
                    PaceText(delta: window.paceDelta())
                    Spacer()
                    if let resetsAt = window.resetsAt {
                        Text("Resets \(resetsAt, style: .relative)")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.caption)
            } else {
                Text(emptyText).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

/// Usage bar with a tick marking where usage would be at an even pace.
private struct PaceBar: View {
    let used: Double
    let expected: Double?

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule()
                    .fill(color)
                    .frame(width: geo.size.width * min(used, 100) / 100)
                if let expected {
                    Rectangle()
                        .fill(.primary)
                        .frame(width: 2, height: 12)
                        .offset(x: geo.size.width * expected / 100 - 1)
                }
            }
        }
        .frame(height: 8)
    }

    private var color: Color {
        if used >= 90 { return .red }
        if let expected, used > expected { return .orange }
        return .accentColor
    }
}

private struct PaceText: View {
    let delta: Double?

    var body: some View {
        if let delta {
            let amount = Int(abs(delta).rounded())
            if amount == 0 {
                Text("On pace").foregroundStyle(.secondary)
            } else if delta > 0 {
                Text("\(amount)% in reserve").foregroundStyle(.green)
            } else {
                Text("\(amount)% in deficit").foregroundStyle(.red)
            }
        }
    }
}
