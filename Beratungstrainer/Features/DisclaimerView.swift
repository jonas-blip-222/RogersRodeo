import SwiftUI
import TrainerCore

/// Einmalige Aufklärung vor der ersten Benutzung (Documentation/ENTSCHEIDUNGEN.md, E07).
///
/// Die Ansicht liegt vor allem anderen und lässt sich nicht umgehen: kein Abbrechen, kein
/// Wegwischen, keine zweite Schaltfläche. Erst die Bestätigung gibt die App frei. Das ist
/// der ganze Sinn von E07 — dafür verzichtet die Oberfläche danach auf Dauerhinweise.
///
/// Der Wortlaut steht in `DisclaimerText`. Hier wird nur gesetzt.
struct DisclaimerView: View {
    let accept: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                ForEach(DisclaimerText.sections) { section in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(section.heading)
                            .font(.headline)
                            .fixedSize(horizontal: false, vertical: true)
                        ForEach(Array(section.paragraphs.enumerated()), id: \.offset) { _, paragraph in
                            Text(paragraph)
                                .font(.subheadline)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20).background(.white, in: RoundedRectangle(cornerRadius: 20))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Palette.line))
                }
                Text(DisclaimerText.draftNotice)
                    .font(.footnote).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button(action: accept) {
                    HStack {
                        Text(DisclaimerText.confirmation)
                        Spacer()
                        Image(systemName: "arrow.right")
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 20).padding(.vertical, 17)
                    .foregroundStyle(.white).background(Palette.ink, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("disclaimer.accept")
            }
            .padding(24).frame(maxWidth: 560).frame(maxWidth: .infinity)
        }
        .background(Palette.background)
        .foregroundStyle(Palette.ink)
        .preferredColorScheme(.light)
        #if os(macOS)
        .frame(minWidth: 390, idealWidth: 540, minHeight: 700)
        #endif
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            if DisclaimerText.reviewStatus == .draft {
                Text(DisclaimerText.draftBadge)
                    .font(.caption2.weight(.semibold)).tracking(1.7)
                    .foregroundStyle(.secondary)
            }
            Text(DisclaimerText.title)
                .font(.system(.largeTitle, design: .serif).weight(.semibold)).tracking(-1)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
