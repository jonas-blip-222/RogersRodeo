import Foundation
import TrainerCore

/// Der Aufklärungstext vor der ersten Benutzung (Documentation/ENTSCHEIDUNGEN.md, E07).
///
/// E07 legt fest, dass die Aufklärung über einen einmaligen, bewusst zu bestätigenden
/// Schritt läuft und **nicht** über dauerhafte Hinweistexte in der Oberfläche. Der Text
/// steht deshalb an einer einzigen Stelle und wird von genau einer Ansicht gezeigt.
///
/// Inhaltlich deckt er die beiden in E07 benannten Punkte ab: die Datenverarbeitung (E01,
/// E06) und die fachliche Reichweite. Die Unterscheidung aus E06 ist tragend und darf beim
/// Kürzen nicht verloren gehen: `provider.data_collection: "deny"` wirkt auf die Weitergabe
/// durch den Anbieter, **nicht** auf die Übermittlung selbst. Der Text verlässt weiterhin
/// das Gerät. Zusagen, die die Entscheidungen nicht hergeben — Löschfristen, Konformität,
/// Garantien des Anbieters —, stehen bewusst nicht darin.
///
/// `reviewStatus` bleibt `.draft`, solange Jonas die Formulierung nicht abgenommen hat.
/// Derselbe Gedanke wie bei `FeedbackFinding.reviewStatus` in TrainerCore: Die Oberfläche
/// muss den Entwurfsstand kenntlich halten, statt ihn zu verschweigen.
enum DisclaimerText {
    /// Fassung des Textes. Die Bestätigung wird zusammen mit dieser Kennung gespeichert;
    /// eine wesentliche Änderung des Textes bekommt eine neue Kennung und wird dadurch
    /// erneut vorgelegt. Redaktionelle Kleinigkeiten behalten die Kennung.
    static let version = "1"

    /// Bleibt `.draft`, bis Jonas den Wortlaut fachlich abgenommen hat.
    static let reviewStatus: ContentStatus = .draft

    static let title = "Bevor du beginnst"

    /// Sichtbarer Entwurfsvermerk. Wird nur bei `.draft` gezeigt.
    static let draftBadge = "ENTWURF · FACHLICH NICHT ABGENOMMEN"

    struct Section: Identifiable {
        let id: String
        let heading: String
        let paragraphs: [String]
    }

    static let sections: [Section] = [
        Section(id: "daten", heading: "Dein Text verlässt dieses Gerät.", paragraphs: [
            "Damit Lukas antworten und dein Beitrag eingeordnet werden kann, gehen dein Text und der bisherige Gesprächsverlauf über den Dienst OpenRouter an den Anbieter, der die Anfrage bearbeitet.",
            "Die App verlangt dabei, dass nur Anbieter gewählt werden, die Übermitteltes nicht speichern und nicht für eigenes Training verwenden. Das schränkt die Weitergabe ein, nicht die Übermittlung: Der Text geht in jedem Fall aus dem Gerät heraus. Ob die Zusage eingehalten wird, lässt sich von hier aus nicht nachprüfen.",
            "Deine Gespräche werden zusätzlich auf diesem Gerät gespeichert, damit du sie nachlesen kannst.",
            "Schreib deshalb nichts aus echten Beratungen hier hinein: keine Namen, keine Fälle, kein Klienten- oder Mandatsmaterial. Denk dir aus, was du üben willst.",
        ]),
        Section(id: "reichweite", heading: "Die Übung ist vereinfacht.", paragraphs: [
            "Lukas ist eine erfundene Figur. Die Beratungsszenarien sind zu pädagogischen Zwecken vereinfacht und können die beraterische Wirklichkeit nicht abbilden.",
            "Auch die fachlichen Rückmeldungen sind Entwürfe. Diese App ersetzt weder eine Ausbildung noch ein Studium.",
        ]),
    ]

    /// Steht am Ende des Textes, weil der Text selbst noch nicht abgenommen ist. E07 hält
    /// zusätzlich fest, dass eine Bestätigung kein Nachweis des Verstehens ist und keine
    /// rechtliche Prüfung ersetzt; deshalb verspricht dieser Satz auch nichts dergleichen.
    static let draftNotice = "Dieser Text ist ein Entwurf und fachlich noch nicht abgenommen."

    static let confirmation = "Verstanden, weiter"

    /// Der vollständige Text als Fließtext. Für Tests und zum Nachlesen außerhalb der
    /// Ansicht; die Ansicht setzt dieselben Bausteine gestaltet.
    static var plainText: String {
        ([title] + sections.flatMap { [$0.heading] + $0.paragraphs } + [draftNotice])
            .joined(separator: "\n\n")
    }
}

/// Die Sperre selbst, als reine Bedingung. Wie `ProviderChange` und `FeedbackGate` bewusst
/// ohne Oberfläche und ohne Speicher prüfbar: Ob die App jemanden in den Gesprächsablauf
/// lässt, ist eine Aussage, die man einzeln nachlesen und einzeln testen können muss.
enum DisclaimerGate {
    /// Wahr, wenn ein Gespräch begonnen, geöffnet oder fortgesetzt werden darf. Ohne
    /// bestätigte Aufklärung bleibt alles davon zu (E07); `busy` ist die schon vorher
    /// geltende Bedingung, dass keine Operation läuft.
    static func allowsConversation(disclaimerAccepted: Bool, busy: Bool) -> Bool {
        disclaimerAccepted && !busy
    }
}

/// Speichert, dass die Aufklärung nach E07 bestätigt wurde — und zu welcher Fassung.
///
/// **Warum `UserDefaults` und nicht SwiftData.** Die Bestätigung ist eine einzelne
/// Geräteeinstellung ohne Bezug zu einer Sitzung, ohne Verlauf und ohne Abfragen. Der
/// SwiftData-Speicher in `Packages/TrainerStorage` trägt die Gesprächsdaten und deren
/// Revisions- und Transaktionsinvarianten; ein Ja-Wert dort erbte diese Schwere, ohne
/// etwas davon zu brauchen, und wäre zudem an das Öffnen des Stores gebunden — der
/// Disclaimer soll aber auch dann erscheinen, wenn der Store noch leer ist.
/// `HomePortraitRotation` löst die gleichartige Frage (ein kleiner Zustand, der einen
/// Neustart überleben muss) bereits so; dieselbe Lösung bleibt hier die passende.
///
/// **Warum die Fassung mitgespeichert wird.** Ein bloßes Ja ließe sich nach einer
/// Textänderung nicht mehr von einer Zustimmung zum alten Wortlaut unterscheiden. Die
/// gespeicherte Kennung muss mit der aktuellen übereinstimmen; sonst wird erneut gefragt.
@MainActor final class DisclaimerConsent {
    private let defaults: UserDefaults
    private let version: String
    private let versionKey = "disclaimer.acceptedVersion"
    private let dateKey = "disclaimer.acceptedAt"

    init(version: String = DisclaimerText.version, defaults: UserDefaults = .standard) {
        self.version = version
        self.defaults = defaults
    }

    /// Fassung, die zuletzt bestätigt wurde. Nil, wenn noch nie bestätigt wurde.
    var acceptedVersion: String? { defaults.string(forKey: versionKey) }

    /// Zeitpunkt der letzten Bestätigung. Nur zur Nachvollziehbarkeit; die Sperre hängt
    /// allein an der Fassung.
    var acceptedAt: Date? { defaults.object(forKey: dateKey) as? Date }

    /// Wahr, wenn genau die aktuelle Fassung bestätigt wurde.
    var isAccepted: Bool { acceptedVersion == version }

    func accept(at date: Date = Date()) {
        defaults.set(version, forKey: versionKey)
        defaults.set(date, forKey: dateKey)
    }

    /// Nimmt die Bestätigung zurück. Wird von der App nicht benutzt; sie hält den Test
    /// ehrlich, der den Zustand vor der ersten Benutzung herstellt.
    func reset() {
        defaults.removeObject(forKey: versionKey)
        defaults.removeObject(forKey: dateKey)
    }
}
