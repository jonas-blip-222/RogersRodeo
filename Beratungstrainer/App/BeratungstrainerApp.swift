import SwiftUI

@main struct BeratungstrainerApp: App {
    @State private var model: AppModel?
    @State private var startupError: String?
    @State private var startupStarted = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            if let model { RootView(model: model).tint(Palette.accent) }
            else if let startupError {
                ContentUnavailableView("Start nicht möglich", systemImage: "exclamationmark.triangle", description: Text(startupError))
                    .padding()
            } else {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Modellzugang wird geprüft …")
                    Text("Falls macOS nach dem Schlüsselbund fragt, geben Sie den vorhandenen Zugang frei.")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding()
                    .task {
                        guard !startupStarted else { return }
                        startupStarted = true
                        // Schlüsselbund kann auf eine Benutzerfreigabe warten. Dabei muss
                        // das App-Fenster bereits sichtbar und der Hauptthread frei sein.
                        let hasKey = await Task.detached {
                            OpenRouterKey.lookup(service: OpenRouterConfiguration().keychainService) != nil
                        }.value
                        do { model = try AppModel(hasModelKey: hasKey) }
                        catch { startupError = error.localizedDescription }
                    }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background, let model { Task { await model.background() } }
            if phase == .active { model?.foreground() }
        }
    }
}
