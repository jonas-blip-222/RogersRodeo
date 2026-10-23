import SwiftUI
import UniformTypeIdentifiers
import TrainerCore

struct TranscriptDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }
    var text: String
    init(text: String) { self.text = text }
    init(configuration: ReadConfiguration) throws {
        text = String(decoding: configuration.file.regularFileContents ?? Data(), as: UTF8.self)
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: Data(text.utf8)) }
}

struct ReviewView: View {
    @Bindable var model: AppModel
    let session: SessionSnapshot
    @State private var export = false
    @State private var exportError: String?
    @State private var showingDiagnostics = false
    var review: SessionReview { ReviewBuilder.build(session) }
    var narrative: [VisitNote.Entry] { (try? VisitBuilder.narrativeEntries(in: session)) ?? [] }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Zeit zum Zurückschauen.").font(.largeTitle.weight(.semibold))
                    Text("Was hat den Kontakt erleichtert? An welcher Stelle würdest du gern etwas anderes ausprobieren?").foregroundStyle(.secondary)
                }
                // Im Rückblick zählt, womit diese Sitzung tatsächlich gelaufen ist, nicht was
                // gerade eingestellt ist. Dieselbe Regel wie in ReviewBuilder.markdown.
                DemoNotice(usesDemoResponses: session.identity.model.id == DemoModelProvider.identity.id)
                VStack(alignment: .leading, spacing: 14) {
                    Text("Dein Gespräch").font(.headline)
                    LabeledContent("Abgeschlossene Runden", value: "\(review.totalTurns)")
                    LabeledContent("Runden mit sicherer Einordnung", value: "\(review.analyzedTurns)")
                    LabeledContent("Reflexionen je Frage", value: review.reflectionQuestionRatio.map { String(format: "%.2f", $0) } ?? "Nicht berechenbar")
                    LabeledContent("Anteil komplexer Reflexionen", value: review.complexReflectionShare.map { String(format: "%.0f %%", $0 * 100) } ?? "Nicht berechenbar")
                    LabeledContent("Text durch Einordnung erfasst", value: review.characterCoverage.map { String(format: "%.0f %%", $0 * 100) } ?? "Nicht berechenbar")
                    Text("Automatische Einordnungen können fehlerhaft sein. Diese Übersicht ist keine standardisierte Kompetenzbewertung.").font(.caption).foregroundStyle(.secondary)
                }.padding(20).background(.white, in: RoundedRectangle(cornerRadius: 20))
                if !narrative.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Vorhaben und berichtete Erfahrungen").font(.headline)
                        ForEach(Array(narrative.enumerated()), id: \.offset) { _, entry in
                            VStack(alignment: .leading, spacing: 5) {
                                Text(entry.heading).font(.subheadline.weight(.semibold))
                                Text(verbatim: "„\(entry.quote)“")
                                Text(entry.sourceLabel).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Text("Eine Absicht ist keine Umsetzung. Einzelne Erfahrungen belegen noch keine langfristige Stabilität.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
                        .background(.white, in: RoundedRectangle(cornerRadius: 20))
                }
                Text(session.visitLabel).font(.subheadline).foregroundStyle(.secondary)
                if session.status == .completed {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(session.turns.count == 20 ? "60 fiktionale Minuten abgeschlossen." : "Vorzeitig abgeschlossen: \(session.turns.count) von 20 Runden.")
                        Text("Den Abstand zum nächsten Termin bestätigst du in der Vorbereitung. Ein Sitzungsende bedeutet noch keine Zielerreichung.")
                            .font(.footnote).foregroundStyle(.secondary)
                        if let closure = session.caseClosure {
                            Text("Fall beendet: \(closure.outcome.label).").font(.headline)
                            Button("Fallrückblick ansehen") { model.showCaseReview = true }.buttonStyle(.borderedProminent)
                        } else if model.mayStartFollowUp {
                            if MaintenanceProgress.evaluate(session).isMet {
                                Text("Die Kriterien für einen Abschluss mit Maintenance sind belegt. Du kannst den Fall abschließen oder weitere Termine vereinbaren.")
                                    .font(.footnote)
                            }
                            Button(session.followUpSessionID == nil ? "Nächsten Termin vorbereiten" : "Zum Folgetermin") {
                                model.prepareFollowUp()
                            }.buttonStyle(.borderedProminent).disabled(model.busy)
                            if model.mayCloseCase {
                                Button("Fall beenden") { model.showCloseConfirmation = true }
                                    .buttonStyle(.bordered).disabled(model.busy)
                            }
                        } else {
                            Text("Dieser ältere Modell- oder Regelstand kann als Protokoll gelesen werden. Starte für weitere Übungen einen neuen Fall.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
                        .background(.white, in: RoundedRectangle(cornerRadius: 20))
                }
                if let error = model.errorMessage { ErrorNotice(text: error) }
                HStack {
                    ShareLink(item: ReviewBuilder.markdown(session)) { Label("Teilen", systemImage: "square.and.arrow.up") }
                    Button("Markdown speichern", systemImage: "arrow.down.document") { export = true }
                }.buttonStyle(.bordered)
                if let exportError { ErrorNotice(text: exportError) }
                Text("Protokoll").font(.title2.weight(.semibold))
                    // Verborgener Zugang zur Entwicklerdiagnostik, wie im Gespräch.
                    .contentShape(Rectangle())
                    .onLongPressGesture(minimumDuration: 1.2) { showingDiagnostics = true }
                    .accessibilityAction(named: "Entwicklerdiagnostik") { showingDiagnostics = true }
                MessageBubble(speaker: session.content.scenario.name, text: session.openingLine, isCounselor: false)
                ForEach(session.turns, id: \.id) { turn in
                    VStack(alignment: .leading, spacing: 12) {
                        MessageBubble(speaker: "Du", text: turn.input, isCounselor: true)
                        if let analysis = turn.analysis, !analysis.segments.isEmpty {
                            ForEach(Array(analysis.segments.enumerated()), id: \.offset) { _, segment in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(verbatim: "„\(segment.quote)“")
                                    Text(segment.isUncertain ? "Einordnung unsicher" : segment.code.label).foregroundStyle(.secondary)
                                }.font(.caption)
                            }
                        } else { Text("Für diesen Beitrag liegt keine Einordnung vor. Das ist keine Entwarnung.").font(.caption).foregroundStyle(.secondary) }
                        // Die gespeicherte Rückmeldung bleibt nachvollziehbar, auch wenn sie
                        // im Gespräch längst weitergeblättert ist (MI-Nachtrag, 7.2).
                        ForEach(Array(turn.feedback.enumerated()), id: \.offset) { _, finding in
                            FeedbackNotice(finding: finding)
                        }
                        MessageBubble(speaker: session.content.scenario.name, text: turn.reply.text, isCounselor: false)
                    }
                }
            }.padding(24).frame(maxWidth: 760).frame(maxWidth: .infinity)
        }
        .navigationTitle("Rückblick mit \(session.content.scenario.name)")
        .sheet(isPresented: $showingDiagnostics) { DiagnosticsView(session: session) }
        .sheet(isPresented: $model.showCaseReview) { NavigationStack { CaseReviewView(review: CaseReview.build(session)) } }
        .confirmationDialog("Fall beenden?", isPresented: $model.showCloseConfirmation, titleVisibility: .visible) {
            Button("Fall beenden", role: .destructive) { model.closeCase() }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text(MaintenanceProgress.evaluate(session).isMet
                 ? "Die Kriterien für Maintenance sind belegt. Der Fall wird als „mit Maintenance abgeschlossen“ gespeichert und danach nicht mehr fortgesetzt."
                 : "Die Kriterien für Maintenance sind nicht belegt. Der Fall wird als „beendet ohne Maintenance“ gespeichert und danach nicht mehr fortgesetzt. Das ist keine Wertung.")
        }
        .fileExporter(isPresented: $export, document: TranscriptDocument(text: ReviewBuilder.markdown(session)), contentType: .plainText,
                      defaultFilename: "Gespraech-\(session.content.scenario.name).md") { result in
            if case .failure = result { exportError = "Das Protokoll konnte nicht exportiert werden." }
        }
    }
}


struct VisitPreparationView: View {
    @Bindable var model: AppModel
    let previous: SessionSnapshot
    let note: VisitNote
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Vor dem nächsten Gespräch").font(.largeTitle.weight(.semibold))
                Text("Sitzung \(previous.sessionNumber + 1) · fiktional \(VisitInterval.label(model.followUpWeeks)) später")
                    .font(.headline)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Abstand zum nächsten Termin").font(.headline)
                    if model.allowedIntervals.count > 1 {
                        Picker("Abstand", selection: $model.followUpWeeks) {
                            ForEach(model.allowedIntervals, id: \.self) { Text(VisitInterval.label($0)).tag($0) }
                        }.disabled(model.busy)
                        if let suggestion = model.intervalSuggestion {
                            Text(verbatim: "Im Gespräch genannt: „\(suggestion.quote)“")
                            Text("Runde \(suggestion.turnNumber) · \(suggestion.speaker == .client ? "Klient" : "Beratung") · automatisch erkannt, bitte prüfen")
                                .font(.caption).foregroundStyle(.secondary)
                        } else {
                            Text("Keine Vereinbarung im Gespräch erkannt. Wähle den Abstand, den ihr besprochen habt; ohne Vereinbarung gilt eine Woche.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Eine Woche. Größere Abstände sind erst möglich, nachdem Lukas von einer Umsetzung berichtet hat.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white, in: RoundedRectangle(cornerRadius: 18))
                Text("Kurze Dokumentation aus den bisherigen Gesprächen. Zitate sind wörtlich; automatische Zieleinordnungen können unsicher sein.")
                    .font(.subheadline).foregroundStyle(.secondary)
                if note.entries.isEmpty { Text("Im letzten Termin wurden noch keine Gesprächsrunden abgeschlossen.") }
                ForEach(Array(note.entries.enumerated()), id: \.offset) { _, entry in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(entry.heading).font(.headline)
                        Text(verbatim: "„\(entry.quote)“")
                        Text(entry.sourceLabel).font(.caption).foregroundStyle(.secondary)
                    }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
                        .background(.white, in: RoundedRectangle(cornerRadius: 18))
                }
                if note.omittedGoals > 0 {
                    Text("Weitere \(note.omittedGoals) frühere Ziele stehen im Gesprächsverlauf.").font(.footnote)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Vereinbarungen und nächste Schritte").font(.headline)
                    Text(note.hasConfirmedGoal ? "Bestätigte Ziele sind oben belegt. Konkrete nächste Schritte werden daraus nicht automatisch abgeleitet." : "Keine sichere Zielvereinbarung dokumentiert. Fehlende nächste Schritte werden nicht ergänzt.")
                    Text("Offen für den Einstieg").font(.headline).padding(.top, 8)
                    Text("Was beschäftigt Sie heute? Was möchten Sie aus dem letzten Gespräch wieder aufgreifen?")
                    Text("Die Notiz verrät keine noch nicht berichteten Zwischenereignisse. Lukas kann im Gespräch erzählen, was er seit dem letzten Termin erlebt hat.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                DemoNotice(usesDemoResponses: previous.identity.model.id == DemoModelProvider.identity.id)
                if let error = model.errorMessage { ErrorNotice(text: error) }
                Button(model.busy ? "Wird vorbereitet …" : "Sitzung \(previous.sessionNumber + 1) beginnen") {
                    model.startFollowUp()
                }.buttonStyle(.borderedProminent).disabled(model.busy)
                Button("Zurück zum Protokoll") { model.preparation = nil }.disabled(model.busy)
            }.padding(24).frame(maxWidth: 760).frame(maxWidth: .infinity)
        }.navigationTitle("Nächster Termin mit \(previous.content.scenario.name)")
    }
}

/// Fallrückblick über alle Termine (E11). Belege statt Wertung; keine Punkteskala.
struct CaseReviewView: View {
    let review: CaseReview
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(review.outcomeText).font(.title2.weight(.semibold))
                Text("Automatische Einordnungen können fehlerhaft sein. Dieser Rückblick ist keine Kompetenzbewertung.")
                    .font(.footnote).foregroundStyle(.secondary)
                section("Termine") {
                    ForEach(review.visits, id: \.number) { visit in
                        Text("Sitzung \(visit.number) · Woche \(visit.week) (fiktional) · \(visit.turns) Runden")
                    }
                }
                section("Ziele") { entries(review.goals, empty: "Keine belegten Ziele.") }
                section("Vorhaben, Erfahrungen und Rückbewegungen") { entries(review.narrative, empty: "Keine belegten Vorhaben.") }
                section("Berichte über fortgesetzte Umsetzung") {
                    if review.progress.reports.isEmpty { Text("Keine aufeinanderfolgenden Berichte belegt.") }
                    ForEach(Array(review.progress.reports.enumerated()), id: \.offset) { _, report in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(verbatim: "„\(report.evidence.quote)“")
                            Text("Sitzung \(report.sessionNumber) · Woche \(report.week)").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    if let difficulty = review.progress.difficulty {
                        Text(verbatim: "Bewältigte Schwierigkeit: „\(difficulty.quote)“")
                    }
                    Text("Maintenance verlangt drei aufeinanderfolgende Berichte über mindestens 13 fiktionale Wochen und eine bewältigte Schwierigkeit.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                ShareLink(item: review.markdown) { Label("Fallrückblick teilen", systemImage: "square.and.arrow.up") }
                    .buttonStyle(.bordered)
            }.padding(24).frame(maxWidth: 760).frame(maxWidth: .infinity)
        }
        .navigationTitle("Fallrückblick mit \(review.scenarioName)")
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
    }
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            content()
        }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 20))
    }
    @ViewBuilder private func entries(_ values: [VisitNote.Entry], empty: String) -> some View {
        if values.isEmpty { Text(empty) }
        ForEach(Array(values.enumerated()), id: \.offset) { _, entry in
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.heading).font(.subheadline.weight(.semibold))
                Text(verbatim: "„\(entry.quote)“")
                Text(entry.sourceLabel).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
