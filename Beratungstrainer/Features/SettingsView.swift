import SwiftUI

/// Zugang zu OpenRouter. Bewusst nur dieser eine Anbieter und keine frei eintragbare
/// Serveradresse: alles, was in Documentation/ENTSCHEIDUNGEN.md E01 bis E03 gemessen wurde,
/// gilt für genau diese Kombination aus Anbieter, Modell und Anfragekörper.
///
/// Der Schlüssel ist hier nur als Eingabepuffer sichtbar. Nach dem Sichern wird er nie
/// wieder vollständig angezeigt, sondern nur noch maskiert mit seinen letzten vier Zeichen.
struct SettingsView: View {
    @Bindable var model: AppModel
    @Environment(\.dismiss) private var dismiss
    /// Eingabepuffer. Wird nach erfolgreichem Sichern sofort geleert.
    @State private var entry = ""
    @State private var checking = false
    @State private var outcome: OpenRouterKeyOutcome?
    @State private var removed = false
    @State private var confirmRemoval = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    status
                    input
                    if let outcome { notice(outcome) }
                    if removed { removalNotice }
                    if model.storedKeyDisplay != nil { removal }
                    explanation
                }
                .padding(24).frame(maxWidth: 560).frame(maxWidth: .infinity)
            }
            .background(Palette.background)
            .foregroundStyle(Palette.ink)
            .navigationTitle("Zugang")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }.disabled(checking)
                }
            }
            .confirmationDialog("Schlüssel entfernen?", isPresented: $confirmRemoval,
                                titleVisibility: .visible) {
                Button("Schlüssel entfernen", role: .destructive) {
                    Task {
                        outcome = nil
                        _ = await model.removeKey()
                        removed = true
                    }
                }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("Die App läuft danach wieder mit festen Demo-Antworten. Du kannst den Schlüssel jederzeit neu einfügen.")
            }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 520)
        #endif
    }

    // MARK: Zustand

    private var status: some View {
        card {
            if let display = model.storedKeyDisplay {
                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Schlüssel hinterlegt").font(.headline)
                        Text(verbatim: display).font(.subheadline.monospaced())
                        Text("Nur die letzten vier Zeichen werden angezeigt.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                } icon: { Image(systemName: "key.fill") }
            } else if model.usesEnvironmentKey {
                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Schlüssel aus der Umgebung").font(.headline)
                        Text("Dieser Start benutzt OPENROUTER_API_KEY. Im Schlüsselbund liegt kein Eintrag.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                } icon: { Image(systemName: "terminal") }
            } else {
                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Kein Schlüssel hinterlegt").font(.headline)
                        Text("Die App läuft mit festen Demo-Antworten. Keine KI und keine fachliche Bewertung.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                } icon: { Image(systemName: "lock.open") }
            }
        }
    }

    // MARK: Eingabe

    private var input: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                Text(model.storedKeyDisplay == nil ? "Schlüssel einfügen" : "Schlüssel ersetzen")
                    .font(.headline)
                SecureField("OpenRouter-Schlüssel", text: $entry)
                    .textFieldStyle(.plain)
                    .padding(12).background(.white, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.line))
                    .disableAutocorrection(true)
                    .disabled(checking)
                    .accessibilityIdentifier("settings.key")
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                Button {
                    Task { await store() }
                } label: {
                    HStack(spacing: 10) {
                        if checking { ProgressView().controlSize(.small) }
                        Text(checking ? "Wird geprüft …" : "Sichern und prüfen")
                        Spacer()
                        if !checking { Image(systemName: "checkmark") }
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 20).padding(.vertical, 15)
                    .foregroundStyle(.white).background(Palette.ink, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(checking || entry.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("settings.save")
                Text("Beim Sichern wird der Schlüssel einmal gegen OpenRouter geprüft. Diese Prüfung erzeugt keine Modellantwort und kostet nichts.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Prüfen, dann speichern, dann umschalten. Nur bei angenommenem Schlüssel wird
    /// überhaupt etwas abgelegt; der Eingabepuffer wird danach sofort geleert.
    private func store() async {
        checking = true; outcome = nil; removed = false
        let result = await model.saveKey(entry)
        if result.isSuccess { entry = "" }
        outcome = result
        checking = false
    }

    private func notice(_ outcome: OpenRouterKeyOutcome) -> some View {
        Label(outcome.message, systemImage: outcome.isSuccess ? "checkmark.circle" : "exclamationmark.circle")
            .font(.subheadline).padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.ink.opacity(0.4)))
            .accessibilityAddTraits(.updatesFrequently)
    }

    private var removalNotice: some View {
        Label("Der Schlüssel wurde vom Gerät entfernt. Die App läuft wieder mit festen Demo-Antworten.",
              systemImage: "checkmark.circle")
            .font(.subheadline).padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.ink.opacity(0.4)))
            .accessibilityAddTraits(.updatesFrequently)
    }

    // MARK: Entfernen

    private var removal: some View {
        Button("Schlüssel entfernen", systemImage: "trash", role: .destructive) {
            confirmRemoval = true
        }
        .font(.subheadline).disabled(checking)
        .accessibilityIdentifier("settings.remove")
    }

    // MARK: Erklärung

    private var explanation: some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                Label("Der Schlüssel liegt im Schlüsselbund dieses Geräts. Er wird nicht gesichert, nicht übertragen und nirgends protokolliert.",
                      systemImage: "lock")
                Label("Mit hinterlegtem Schlüssel gehen deine Eingaben an ein Sprachmodell im Internet. Gib dort keine echten Fall- oder Klientendaten ein.",
                      systemImage: "network")
                Label("Gespräche, die du vorher mit einer anderen Antwortquelle begonnen hast, kannst du nachlesen, aber nicht fortsetzen.",
                      systemImage: "clock.arrow.circlepath")
            }
            .font(.footnote).foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20).background(.white, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Palette.line))
    }
}
