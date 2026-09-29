import SwiftUI
import TrainerCore

struct ConversationView: View {
    @Bindable var model: AppModel
    let session: SessionSnapshot
    @FocusState private var composing: Bool
    @State private var showingDiagnostics = false

    var body: some View {
        VStack(spacing: 0) {
            DemoNotice(usesDemoResponses: model.usesDemoResponses).padding(.horizontal).padding(.bottom, 8)
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
        .sheet(isPresented: $showingDiagnostics) { DiagnosticsView(session: session) }
    }

    private var canSend: Bool {
        !model.busy && !model.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Was gerade zum eigenen Beitrag zu sagen ist: entweder die vorläufige Rückmeldung zum
    /// laufenden Versuch — sie erscheint, sobald die Analyse validiert ist, und damit
    /// möglichst vor der Antwort von Lukas — oder die gespeicherte Rückmeldung zur letzten
    /// abgeschlossenen Runde.
    private var feedback: (findings: [FeedbackFinding], analysisAvailable: Bool)? {
        if let pending = model.currentFeedback { return (pending.findings, pending.analysisAvailable) }
        // Solange der neue Beitrag eingeordnet wird, gehört die Rückmeldung zur vorigen Runde
        // nicht mehr hierher: sie stünde direkt unter einem Text, für den sie nicht gilt.
        if model.busy { return nil }
        if let turn = session.turns.last { return (turn.feedback, turn.analysis != nil) }
        return nil
    }

    /// Warnung und Rückmeldung zum Beitrag sind etwas anderes als der Vorschlag für die
    /// nächste Reaktion und bleiben deshalb getrennt sichtbar. Der Schalter unten schaltet
    /// nur die Vorschläge; die Kernwarnungen bleiben in jedem Fall stehen
    /// (MI-Nachtrag, Abschnitt 7.1 und 7.2).
    @ViewBuilder private var feedbackSection: some View {
        if let feedback {
            let warnings = feedback.findings.filter { $0.kind == .warning }
            let observations = feedback.findings.filter { $0.kind == .observation }
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(warnings.enumerated()), id: \.offset) { _, finding in
                    FeedbackNotice(finding: finding)
                }
                ForEach(Array(observations.enumerated()), id: \.offset) { _, finding in
                    FeedbackNotice(finding: finding)
                }
                if !feedback.analysisAvailable {
                    // Keine Einordnung ist keine Entwarnung. Das muss dastehen, sonst liest
                    // sich die leere Fläche wie „alles in Ordnung“.
                    Text("Für diesen Beitrag liegt keine Einordnung vor. Das ist keine Entwarnung.")
                        .font(.caption).foregroundStyle(.secondary)
                } else if !feedback.findings.isEmpty {
                    Text("Fachlicher Entwurf, keine geprüfte Bewertung deiner Beratung.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
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
            feedbackSection
            if model.showHints {
                if let id = session.turns.last?.selectedTipID, let tip = session.content.tips.first(where: { $0.id == id }) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Für deine nächste Reaktion").font(.caption).foregroundStyle(.secondary)
                        Text(tip.title).font(.headline); Text(tip.text); Text(tip.example).italic()
                    }
                        .font(.subheadline).padding(12).background(Palette.accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                } else {
                    Text("Für diese Übung liegen noch keine fachlich geprüften Vorschläge vor.").font(.caption).foregroundStyle(.secondary)
                }
            }
            HStack {
                // Der Schalter gilt ausdrücklich nur für die Vorschläge zur nächsten
                // Reaktion. Warnung und Rückmeldung zum eigenen Beitrag bleiben sichtbar.
                Button(model.showHints ? "Vorschläge ausblenden" : "Vorschläge einblenden", systemImage: "lightbulb") { model.showHints.toggle() }
                    .font(.caption).buttonStyle(.plain)
                Spacer()
                Text("\(session.turns.count) / 20 Runden").font(.caption).foregroundStyle(.secondary).monospacedDigit()
                    // Verborgener Zugang zur Entwicklerdiagnostik. Nicht Teil des normalen
                    // Ablaufs: nur dort darf der Offenheitswert überhaupt vorkommen.
                    .contentShape(Rectangle())
                    .onLongPressGesture(minimumDuration: 1.2) { showingDiagnostics = true }
                    .accessibilityAction(named: "Entwicklerdiagnostik") { showingDiagnostics = true }
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
                        // Eingabetaste sendet, Umschalt+Eingabe bleibt der Zeilenumbruch.
                        // Ohne das fügt ein mehrzeiliges Feld bei Eingabe nur eine Zeile ein.
                        .onKeyPress(phases: .down) { press in
                            guard press.key == .return, !press.modifiers.contains(.shift), canSend else { return .ignored }
                            composing = false
                            model.send()
                            return .handled
                        }
                    if model.busy {
                        Button("Abbrechen", systemImage: "stop.fill") { Task { await model.cancel() } }
                            .labelStyle(.iconOnly).buttonStyle(.bordered).controlSize(.large)
                    } else {
                        Button("Senden", systemImage: "arrow.up") { composing = false; model.send() }
                            .labelStyle(.iconOnly).buttonStyle(.borderedProminent).controlSize(.large)
                            .disabled(!canSend)
                            .accessibilityIdentifier("conversation.send")
                    }
                }
                if model.input.count > 1300 { Text("\(model.input.count) / 1.500 Zeichen").font(.caption).foregroundStyle(.secondary) }
            }
        }.padding().frame(maxWidth: 760).frame(maxWidth: .infinity).background(Palette.background.shadow(color: .black.opacity(0.04), radius: 8, y: -4))
    }
}

/// Eine einzelne Rückmeldung in der abgenommenen Schwarz-Weiß-Gestaltung: dieselbe Fläche,
/// dieselbe Typografie wie `ErrorNotice`, keine neue Farbwelt. Unterschieden wird über
/// Sinnbild, Überschrift und Rand — eine Warnung wiegt schwerer als eine Rückmeldung.
struct FeedbackNotice: View {
    let finding: FeedbackFinding
    private var isWarning: Bool { finding.kind == .warning }
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: isWarning ? "exclamationmark.triangle" : "checkmark.circle")
                .font(.subheadline)
            VStack(alignment: .leading, spacing: 3) {
                Text(isWarning ? "Warnung · \(finding.title)" : "Zu deinem Beitrag · \(finding.title)")
                    .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Text(verbatim: finding.message).font(.subheadline).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(isWarning ? Palette.ink.opacity(0.4) : Palette.line))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isWarning ? "Warnung. \(finding.title). \(finding.message)"
                                      : "Rückmeldung zu deinem Beitrag. \(finding.title). \(finding.message)")
    }
}

/// Verborgene Entwicklerdiagnostik. Der Offenheitsverlauf und die gespeicherten
/// `stateChangeReasons` liegen längst vor, werden aber nirgends angezeigt — bewusst, denn
/// Offenheit misst die Bereitschaft der Figur, Persönliches zu erzählen, und ist keine Note
/// für die Beratung (MI-Nachtrag, Abschnitt 5.3). Diese Ansicht ist der einzige Ort in der
/// App, an dem die Zahl vorkommen darf.
struct DiagnosticsView: View {
    let session: SessionSnapshot
    @Environment(\.dismiss) private var dismiss
    @ViewBuilder private func characterRecord(_ record: CharacterRecord?, dimension: CharacterDimension) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(dimension.label): \(record?.label ?? "Nicht erhoben")")
            if let record {
                Text(verbatim: "Beleg: „\(record.evidence.quote)“")
                if let id = record.evidence.origin.turnID,
                   let index = session.turns.firstIndex(where: { $0.id == id }) {
                    Text("Lukas' Antwort in Runde \(index + 1)")
                } else { Text("Lukas' Eröffnungsäußerung") }
            }
        }.font(.caption)
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Interne Werte der Simulation. Kein Lernfeedback und keine Bewertung der Beratung. Der Offenheitswert beschreibt allein, wie viel die Figur gerade von sich preisgibt.")
                        .font(.footnote).foregroundStyle(.secondary)
                    LabeledContent("Regeln", value: session.identity.rulesVersion)
                    LabeledContent("Prompt", value: session.identity.promptVersion)
                    LabeledContent("Textbausteine", value: FeedbackTemplates.version)
                    LabeledContent("Modell", value: session.identity.model.id)
                    LabeledContent("Offenheit zu Beginn", value: "\(session.content.scenario.opennessStart)")
                    LabeledContent("Offenheit jetzt", value: "\(session.state.openness)")
                    if let development = session.state.development {
                        Text("Zuletzt belegte Aussagen zur Figur").font(.headline)
                        Text("Getrennte Beobachtungen, keine Punkte. Sie beziehen sich auf frühere Äußerungen und sind kein Beweis des aktuellen Zustands oder einer Wirkung deiner letzten Intervention.")
                            .font(.caption).foregroundStyle(.secondary)
                        ForEach(Array(development.goals.enumerated()), id: \.offset) { _, goal in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(verbatim: "Zielbeleg: „\(goal.goal.quote)“").font(.subheadline)
                                characterRecord(goal.readiness, dimension: .readiness)
                                characterRecord(goal.confidence, dimension: .confidence)
                            }
                        }
                        characterRecord(development.rapport, dimension: .rapport)
                    } else {
                        Text("Veränderungsbereitschaft, Zuversicht und Arbeitsbeziehung: noch nicht erhoben.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if session.turns.isEmpty {
                        Text("Noch keine abgeschlossene Runde.").font(.subheadline).foregroundStyle(.secondary)
                    }
                    ForEach(Array(session.turns.enumerated()), id: \.element.id) { index, turn in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Runde \(index + 1)").font(.subheadline.weight(.semibold))
                            Text("Offenheit \(turn.stateBefore.openness) → \(turn.stateAfter.openness)").monospacedDigit()
                            Text("Geschlossene Fragen in Folge: \(turn.stateAfter.closedQuestionStreak)").monospacedDigit()
                            Text("Gründe: \(turn.stateChangeReasons.joined(separator: ", "))")
                            Text("Letzte Gutschriften: \(turn.stateAfter.recentCredits.map { $0?.rawValue ?? "—" }.joined(separator: ", "))")
                            Text("Rückmeldung: \(turn.feedback.isEmpty ? "keine" : turn.feedback.map(\.ruleID).joined(separator: ", "))")
                            Text("Einordnung: \(turn.analysis == nil ? "nicht vorhanden" : "\(turn.analysis?.segments.count ?? 0) Segmente")")
                        }
                        .font(.caption).textSelection(.enabled)
                        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                        .background(.white, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.line))
                    }
                }.padding(24).frame(maxWidth: 560).frame(maxWidth: .infinity)
            }
            .background(Palette.background)
            .foregroundStyle(Palette.ink)
            .navigationTitle("Diagnose")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 520)
        #endif
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
