import SwiftUI
import TrainerCore

struct ConversationView: View {
    @Bindable var model: AppModel
    let session: SessionSnapshot
    @FocusState private var composing: Bool

    var body: some View {
        VStack(spacing: 0) {
            DemoNotice().padding(.horizontal).padding(.bottom, 8)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        MessageBubble(speaker: session.content.scenario.name, text: session.content.scenario.openingLine, isCounselor: false)
                        ForEach(session.turns, id: \.id) { turn in
                            MessageBubble(speaker: "Du", text: turn.input, isCounselor: true)
                            MessageBubble(speaker: session.content.scenario.name, text: turn.reply.text, isCounselor: false)
                        }
                        if model.busy {
                            HStack(spacing: 10) { ProgressView(); Text("Antwort wird vorbereitet …").font(.subheadline) }
                                .padding(12).accessibilityElement(children: .combine)
                        }
                        Color.clear.frame(height: 1).id("bottom")
                    }.padding().frame(maxWidth: 760).frame(maxWidth: .infinity)
                }
                .defaultScrollAnchor(.bottom)
                .onChange(of: session.turns.count) { _, _ in withAnimation { proxy.scrollTo("bottom", anchor: .bottom) } }
                .onChange(of: model.busy) { _, _ in withAnimation { proxy.scrollTo("bottom", anchor: .bottom) } }
            }
            composer
        }
        .navigationTitle("Gespräch mit \(session.content.scenario.name)")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Abschließen", systemImage: "checkmark") { composing = false; model.requestFinish() }.disabled(model.busy)
            }
        }
        .task(id: model.input) {
            do { try await Task.sleep(for: .milliseconds(300)); try Task.checkCancellation(); model.saveDraft() }
            catch { /* Ein neuer Tastendruck ersetzt nur die noch nicht gestartete Speicherung. */ }
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let error = model.errorMessage {
                ErrorNotice(text: error)
                if model.maySkipAnalysis {
                    Button("Ohne Einordnung fortsetzen") { model.send(skipAnalysis: true) }.disabled(model.busy)
                }
            }
            if model.showHints {
                if let id = session.turns.last?.selectedTipID, let tip = session.content.tips.first(where: { $0.id == id }) {
                    VStack(alignment: .leading, spacing: 6) { Text(tip.title).font(.headline); Text(tip.text); Text(tip.example).italic() }
                        .font(.subheadline).padding(12).background(Palette.accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                } else {
                    Text("Für diese Übung liegen noch keine fachlich geprüften Hinweise vor.").font(.caption).foregroundStyle(.secondary)
                }
            }
            HStack {
                Button(model.showHints ? "Hinweise ausblenden" : "Hinweise einblenden", systemImage: "lightbulb") { model.showHints.toggle() }
                    .font(.caption).buttonStyle(.plain)
                Spacer()
                Text("\(session.turns.count) / 20 Runden").font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
            if session.turns.count >= 20 {
                Text("Die letzte Runde ist erreicht. Du kannst das Gespräch jetzt abschließen und ansehen.").font(.subheadline)
                Button("Zur Auswertung") { model.requestFinish() }.buttonStyle(.borderedProminent)
            } else {
                if session.turns.count == 19 { Text("Noch eine Runde, dann endet diese Übung.").font(.caption).foregroundStyle(.secondary) }
                HStack(alignment: .bottom, spacing: 12) {
                    TextField("Was möchtest du Lukas sagen?", text: $model.input, axis: .vertical)
                        .lineLimit(2...6).padding(12).background(.white, in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.accent.opacity(0.18)))
                        .focused($composing).disabled(model.busy)
                        .accessibilityIdentifier("conversation.input")
                        .onChange(of: model.input) { _, new in if new.count > 1500 { model.input = String(new.prefix(1500)) } }
                    if model.busy {
                        Button("Abbrechen", systemImage: "stop.fill") { Task { await model.cancel() } }
                            .labelStyle(.iconOnly).buttonStyle(.bordered).controlSize(.large)
                    } else {
                        Button("Senden", systemImage: "arrow.up") { composing = false; model.send() }
                            .labelStyle(.iconOnly).buttonStyle(.borderedProminent).controlSize(.large)
                            .disabled(model.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .accessibilityIdentifier("conversation.send")
                    }
                }
                if model.input.count > 1300 { Text("\(model.input.count) / 1.500 Zeichen").font(.caption).foregroundStyle(.secondary) }
            }
        }.padding().frame(maxWidth: 760).frame(maxWidth: .infinity).background(Palette.background.shadow(color: .black.opacity(0.04), radius: 8, y: -4))
    }
}

struct MessageBubble: View {
    let speaker: String
    let text: String
    let isCounselor: Bool
    var body: some View {
        HStack {
            if isCounselor { Spacer(minLength: 28) }
            VStack(alignment: .leading, spacing: 8) {
                Text(speaker).font(.caption.weight(.semibold)).foregroundStyle(isCounselor ? Color.white.opacity(0.8) : Palette.accent)
                Text(verbatim: text).textSelection(.enabled).lineSpacing(4)
            }
            .padding(18).foregroundStyle(isCounselor ? Color.white : Palette.ink)
            .background(isCounselor ? Palette.accent : .white, in: RoundedRectangle(cornerRadius: 20))
            .accessibilityElement(children: .combine)
            if !isCounselor { Spacer(minLength: 28) }
        }
    }
}
