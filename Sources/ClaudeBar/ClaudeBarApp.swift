import SwiftUI

@main
struct ClaudeBarApp: App {
    @StateObject private var store = UsageStore()

    var body: some Scene {
        MenuBarExtra {
            UsagePanel(store: store)
        } label: {
            MenuBarLabel(snapshot: store.snapshot, hasError: store.error != nil)
        }
        .menuBarExtraStyle(.window)
    }
}
