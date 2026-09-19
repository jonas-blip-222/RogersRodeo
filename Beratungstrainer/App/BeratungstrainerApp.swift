import SwiftUI

@main struct BeratungstrainerApp: App {
    @State private var model: AppModel?
    private let startupError: String?
    @Environment(\.scenePhase) private var scenePhase

    init() {
        do { _model = State(initialValue: try AppModel()); startupError = nil }
        catch { _model = State(initialValue: nil); startupError = error.localizedDescription }
    }
    var body: some Scene {
        WindowGroup {
            if let model { RootView(model: model).tint(Palette.accent) }
            else {
                ContentUnavailableView("Start nicht möglich", systemImage: "exclamationmark.triangle", description: Text(startupError ?? "Die lokalen Daten konnten nicht geöffnet werden."))
                    .padding()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background, let model { Task { await model.background() } }
            if phase == .active { model?.foreground() }
        }
    }
}
