import SwiftUI

@main
@MainActor
struct TouchGuardApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(model: model)
        } label: {
            Image(systemName: model.protectionStatus.symbolName)
                .accessibilityLabel(model.protectionStatus.title)
        }
        .menuBarExtraStyle(.window)
    }
}
