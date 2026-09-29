import SwiftUI
import ImageIO
import TrainerCore

enum Palette {
    static let accent = Color(white: 0.07)
    static let background = Color(white: 0.965)
    static let ink = Color(white: 0.07)
    static let line = Color.black.opacity(0.09)
}

struct RootView: View {
    @Bindable var model: AppModel
    @State private var deletion: UUID?
    @State private var showingHistory = false
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
        .frame(minWidth: 390, idealWidth: 540, minHeight: 700)
        #endif
    }

    private var home: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Rogers Rodeo").font(.title2.weight(.bold)).tracking(-0.8)
                        Text("Raum für gute Gespräche.").font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "quote.bubble").font(.title3)
                        .frame(width: 46, height: 46).background(.white, in: Circle())
                        .overlay(Circle().stroke(Palette.line)).accessibilityHidden(true)
                }
                HStack(spacing: 4) {
                    sectionButton("Entdecken", selected: !showingHistory) { showingHistory = false }
                    sectionButton("Meine Gespräche", selected: showingHistory) { showingHistory = true }
                }.padding(5).background(.white, in: Capsule()).overlay(Capsule().stroke(Palette.line))
                if showingHistory {
                    history
                } else {
                    portraitCard
                    ForEach(model.catalog.scenarios, id: \.id) { scenario in practiceCard(scenario) }
                    DemoNotice()
                }
                if let error = model.errorMessage { ErrorNotice(text: error) }
            }.padding(24).frame(maxWidth: 560).frame(maxWidth: .infinity)
        }.navigationTitle("")
    }

    private func sectionButton(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.subheadline.weight(.medium)).frame(maxWidth: .infinity).padding(.vertical, 11)
                .foregroundStyle(selected ? .white : Palette.ink)
                .background(selected ? Palette.ink : .clear, in: Capsule())
                // Ohne diese Form ist nur der gezeichnete Text antippbar; die nicht ausgewählte
                // Schaltfläche hat keinen Hintergrund und reagiert daneben sonst nicht.
                .contentShape(Capsule())
        }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var portraitCard: some View {
        VStack(spacing: 0) {
            HStack {
                Text("DIE HALTUNG DAHINTER").font(.caption2.weight(.semibold)).tracking(1.7)
                Spacer()
                Image(systemName: "sparkle").font(.caption)
            }.foregroundStyle(.secondary).padding(.horizontal, 24).padding(.top, 24)
            PortraitIllustration(portrait: model.homePortrait)
                .frame(height: 230).padding(.top, 4)
            Text(model.homePortrait.name).font(.subheadline.weight(.semibold)).multilineTextAlignment(.center).padding(.horizontal, 20).padding(.top, 4)
            Text(model.homePortrait.approach).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.horizontal, 20).padding(.top, 5)
            Text(model.homePortrait.headline)
                .font(.system(.largeTitle, design: .serif).weight(.semibold)).tracking(-1)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                .padding(.top, 20).padding(.horizontal, 20)
            Text(model.homePortrait.caption)
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 26)
        }.frame(maxWidth: .infinity).background(.white, in: RoundedRectangle(cornerRadius: 28))
            .overlay(RoundedRectangle(cornerRadius: 28).stroke(Palette.line))
            .shadow(color: .black.opacity(0.025), radius: 16, y: 8)
    }

    private func practiceCard(_ scenario: ScenarioDefinition) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("DEIN ÜBUNGSRAUM").font(.caption2.weight(.semibold)).tracking(1.7)
                Spacer()
                Text("TEXT · DEMO").font(.caption2.weight(.medium))
            }.foregroundStyle(.secondary)
            Text("\(scenario.name), \(scenario.age)").font(.title2.weight(.semibold)).tracking(-0.5)
            Text("„Meine Freundin übertreibt.“").font(.headline)
            Text("Motivierende Gesprächsführung üben – mit einem Gegenüber, das noch nicht überzeugt ist.")
                .font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Button { model.start(scenario) } label: {
                HStack { Text(model.busy ? "Wird vorbereitet …" : "Demo-Gespräch starten"); Spacer(); Image(systemName: "arrow.up.right") }
                    .font(.subheadline.weight(.semibold)).padding(.horizontal, 20).padding(.vertical, 17)
                    .foregroundStyle(.white).background(Palette.ink, in: Capsule())
            }.buttonStyle(.plain).disabled(model.busy)
            Text("Fiktive Figur · bis zu 20 Runden · fachlicher Entwurf")
                .font(.caption).foregroundStyle(.secondary)
        }.padding(24).background(.white, in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Palette.line))
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Deine Gespräche").font(.title2.weight(.semibold))
            Text("Ein Gedanke, den du wieder aufgreifen möchtest?").font(.subheadline).foregroundStyle(.secondary)
            if model.history.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: "bubble.left.and.bubble.right").font(.largeTitle)
                    Text("Hier ist noch Raum.").font(.headline)
                    Text("Deine begonnenen und abgeschlossenen Übungen findest du später hier.")
                        .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }.frame(maxWidth: .infinity).padding(32).background(.white, in: RoundedRectangle(cornerRadius: 24))
            }
            ForEach(model.history, id: \.id) { item in
                HStack {
                    Button { model.open(item.id) } label: {
                        HStack(spacing: 14) {
                            Image(systemName: item.status == .active ? "bubble.left" : "checkmark.bubble").font(.title3)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(item.scenarioName).font(.headline)
                                Text(item.startedAt, format: .dateTime.day().month().hour().minute()).font(.caption).foregroundStyle(.secondary)
                                Text(item.status == .active ? "Fortsetzen" : "Rückblick ansehen").font(.caption.weight(.medium))
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right")
                        }.contentShape(Rectangle())
                    }.buttonStyle(.plain)
                    Button("Löschen", systemImage: "trash") { deletion = item.id }
                        .labelStyle(.iconOnly).buttonStyle(.borderless).padding(.leading, 12)
                }.padding(20).background(.white, in: RoundedRectangle(cornerRadius: 20))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Palette.line)).disabled(model.busy)
            }
            Label("Nur auf diesem Gerät gespeichert", systemImage: "lock").font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct PortraitIllustration: View {
    let portrait: HomePortrait
    static func loadImage(named name: String) -> CGImage? {
        guard let url = AppResources.bundle.url(forResource: name, withExtension: "png"),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
    var body: some View {
        if let image = Self.loadImage(named: portrait.imageName) {
            Image(decorative: image, scale: 1).resizable().scaledToFit()
                .accessibilityLabel("Cartoonporträt: \(portrait.name)")
                .accessibilityHidden(false)
        } else {
            Label("Porträt konnte nicht geladen werden", systemImage: "photo")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct DemoNotice: View {
    var body: some View {
        Label {
            Text("Demo mit festen Antworten. Noch keine KI und keine fachliche Bewertung.")
        } icon: { Image(systemName: "info.circle") }
            .font(.footnote).foregroundStyle(.secondary).padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.line))
    }
}

struct ErrorNotice: View {
    let text: String
    var body: some View {
        Label(text, systemImage: "exclamationmark.circle").font(.subheadline)
            .foregroundStyle(Palette.ink).padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.ink.opacity(0.4)))
            .accessibilityAddTraits(.updatesFrequently)
    }
}
