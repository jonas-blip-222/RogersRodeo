import SwiftUI
import TrainerCore

enum Palette {
    static let accent = Color(red: 0.12, green: 0.38, blue: 0.34)
    static let background = Color(red: 0.97, green: 0.96, blue: 0.93)
    static let ink = Color(red: 0.13, green: 0.20, blue: 0.19)
}

struct RootView: View {
    @Bindable var model: AppModel
    @State private var deletion: UUID?
    var body: some View {
        NavigationStack {
            Group {
                if let session = model.session {
                    if model.showReview { ReviewView(model: model, session: session) }
                    else { ConversationView(model: model, session: session) }
                } else { home }
            }
            .background(Palette.background)
            .foregroundStyle(Palette.ink)
            .preferredColorScheme(.light)
            .toolbar {
                if model.session != nil {
                    ToolbarItem(placement: .navigation) {
                        Button("Übersicht", systemImage: "chevron.left") { model.close() }.disabled(model.busy)
                    }
                }
            }
            .confirmationDialog("Sitzung endgültig löschen?", isPresented: Binding(get: { deletion != nil }, set: { if !$0 { deletion = nil } }), titleVisibility: .visible) {
                Button("Sitzung löschen", role: .destructive) { if let id = deletion { model.delete(id) }; deletion = nil }
                Button("Abbrechen", role: .cancel) { deletion = nil }
            } message: { Text("Das gespeicherte Gespräch und sein Entwurf werden von diesem Gerät entfernt.") }
            .confirmationDialog("Gespräch abschließen?", isPresented: $model.showFinishConfirmation, titleVisibility: .visible) {
                Button("Entwurf verwerfen und abschließen", role: .destructive) { model.finish(discardDraft: true) }
                Button("Weiter schreiben", role: .cancel) {}
            } message: { Text("Dein noch nicht gesendeter Text wird verworfen.") }
        }
        #if os(macOS)
        .frame(minWidth: 440, idealWidth: 600, minHeight: 640)
        #endif
    }

    private var home: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("ROGERS RODEO").font(.caption.weight(.bold)).tracking(3).foregroundStyle(Palette.accent)
                    Text("Gespräche üben.\nRaum geben.").font(.largeTitle.weight(.semibold))
                    Text("Ein ruhiger Ort, um Zuhören, Nachfragen und Reflektieren auszuprobieren.").foregroundStyle(.secondary)
                }
                DemoNotice()
                ForEach(model.catalog.scenarios, id: \.id) { scenario in
                    VStack(alignment: .leading, spacing: 18) {
                        HStack(spacing: 14) {
                            Text(String(scenario.name.prefix(1))).font(.title.weight(.medium)).frame(width: 58, height: 58)
                                .background(Palette.accent.opacity(0.12), in: Circle()).accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 5) {
                                Text("\(scenario.name), \(scenario.age)").font(.title2.weight(.semibold))
                                Text("Motivierende Gesprächsführung").font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                        Text("„Meine Freundin übertreibt.“").font(.title3.weight(.medium))
                        Text("Lukas kommt auf Druck seiner Partnerin. Übe, eine Beziehung aufzubauen und Ambivalenz zu erkunden.")
                        Label("Textgespräch · bis zu 20 Gesprächsrunden", systemImage: "text.bubble").font(.footnote).foregroundStyle(.secondary)
                        Button { model.start(scenario) } label: {
                            HStack { Text(model.busy ? "Wird vorbereitet …" : "Demo-Gespräch starten"); Spacer(); Image(systemName: "arrow.right") }.padding(.vertical, 7)
                        }.buttonStyle(.borderedProminent).disabled(model.busy)
                        Text("Fiktive Figur · fachlicher Entwurf").font(.caption).foregroundStyle(.secondary)
                    }.padding(24).background(.white, in: RoundedRectangle(cornerRadius: 24))
                }
                if let error = model.errorMessage { ErrorNotice(text: error) }
                VStack(alignment: .leading, spacing: 14) {
                    HStack { Text("Deine Gespräche").font(.title3.weight(.semibold)); Spacer(); Text("Nur auf diesem Gerät").font(.caption).foregroundStyle(.secondary) }
                    if model.history.isEmpty {
                        Text("Hier findest du später deine begonnenen und abgeschlossenen Übungen.").foregroundStyle(.secondary).padding(.vertical, 8)
                    }
                    ForEach(model.history, id: \.id) { item in
                        HStack {
                            Button { model.open(item.id) } label: {
                                HStack {
                                    Image(systemName: item.status == .active ? "bubble.left" : "checkmark.bubble").font(.title3)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.scenarioName).font(.headline)
                                        Text(item.startedAt, format: .dateTime.day().month().hour().minute()).font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(item.status == .active ? "Fortsetzen" : "Ansehen").font(.subheadline)
                                }.contentShape(Rectangle())
                            }.buttonStyle(.plain)
                            Button("Löschen", systemImage: "trash", role: .destructive) { deletion = item.id }
                                .labelStyle(.iconOnly).buttonStyle(.borderless).padding(.leading, 12)
                        }.padding(18).background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 16)).disabled(model.busy)
                    }
                }
            }.padding(24).frame(maxWidth: 680).frame(maxWidth: .infinity)
        }.navigationTitle("")
    }
}

struct DemoNotice: View {
    var body: some View {
        Label {
            Text("Demo mit festen Antworten. Noch keine KI und keine fachliche Bewertung.")
        } icon: { Image(systemName: "hammer") }
            .font(.footnote).foregroundStyle(Palette.accent).padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
    }
}

struct ErrorNotice: View {
    let text: String
    var body: some View {
        Label(text, systemImage: "exclamationmark.circle").font(.subheadline)
            .foregroundStyle(.red).padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.red.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
            .accessibilityAddTraits(.updatesFrequently)
    }
}
