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
    var review: SessionReview { ReviewBuilder.build(session) }
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
                HStack {
                    ShareLink(item: ReviewBuilder.markdown(session)) { Label("Teilen", systemImage: "square.and.arrow.up") }
                    Button("Markdown speichern", systemImage: "arrow.down.document") { export = true }
                }.buttonStyle(.bordered)
                if let exportError { ErrorNotice(text: exportError) }
                Text("Protokoll").font(.title2.weight(.semibold))
                MessageBubble(speaker: session.content.scenario.name, text: session.content.scenario.openingLine, isCounselor: false)
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
                        } else { Text("Für diesen Beitrag liegt keine Einordnung vor.").font(.caption).foregroundStyle(.secondary) }
                        MessageBubble(speaker: session.content.scenario.name, text: turn.reply.text, isCounselor: false)
                    }
                }
            }.padding(24).frame(maxWidth: 760).frame(maxWidth: .infinity)
        }
        .navigationTitle("Rückblick mit \(session.content.scenario.name)")
        .fileExporter(isPresented: $export, document: TranscriptDocument(text: ReviewBuilder.markdown(session)), contentType: .plainText,
                      defaultFilename: "Gespraech-\(session.content.scenario.name).md") { result in
            if case .failure = result { exportError = "Das Protokoll konnte nicht exportiert werden." }
        }
    }
}
