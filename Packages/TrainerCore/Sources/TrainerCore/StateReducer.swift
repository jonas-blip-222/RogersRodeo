import Foundation

public struct Reduction: Sendable {
    public let state: SimulationState
    public let reasons: [String]
}

public enum StateReducer {
    public static func reduce(_ before: SimulationState, analysis: TurnAnalysis?, input: String,
                              context: [DialogueMessage]) throws -> Reduction {
        guard (0...10).contains(before.openness), before.closedQuestionStreak >= 0,
              before.recentCredits.count <= 3 else { throw TrainerFailure.artifactInvalid }
        var next = before
        var reasons: [String] = []
        var penalty = 0
        var credit: CounselorCode?
        if let analysis, !analysis.segments.isEmpty {
            try OutputValidator.validateAnalysis(analysis, input: input, context: context)
            let ranges = try OutputValidator.locations(analysis, input: input)
            var cursor = input.startIndex
            for (segment, range) in zip(analysis.segments, ranges) {
                if !input[cursor..<range.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    next.closedQuestionStreak = 0
                }
                cursor = range.upperBound
                if segment.isUncertain {
                    next.closedQuestionStreak = 0
                    reasons.append("uncertain_segment")
                    continue
                }
                if segment.code == .closedQuestion {
                    next.closedQuestionStreak += 1
                    if next.closedQuestionStreak >= 3 { penalty = max(penalty, 1); reasons.append("closed_question_streak") }
                } else if segment.code != .other { next.closedQuestionStreak = 0 }
                switch segment.code {
                case .confrontation: penalty = max(penalty, 2); reasons.append("confrontation")
                case .adviceWithoutPermission: penalty = max(penalty, 1); reasons.append("advice_without_permission")
                case .complexReflection, .affirmation, .autonomy, .collaboration:
                    if [.complexReflection, .affirmation].contains(segment.code), segment.supportingClientQuote == nil {
                        reasons.append("missing_support")
                    } else if before.recentCredits.contains(where: { $0 == segment.code }) {
                        reasons.append("repeat_credit_suppressed")
                    } else if credit == nil { credit = segment.code }
                default: break
                }
            }
            if !input[cursor..<input.endIndex].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                next.closedQuestionStreak = 0
            }
        } else { next.closedQuestionStreak = 0; reasons.append("analysis_unavailable") }
        if penalty > 0 { credit = nil }
        let delta = penalty > 0 ? -penalty : (credit == nil ? 0 : 1)
        if let credit { reasons.append("positive:\(credit.rawValue)") }
        let raw = before.openness + delta
        next.openness = min(10, max(0, raw))
        if raw != next.openness { reasons.append("clamped") }
        if reasons.isEmpty { reasons = ["neutral"] }
        next.recentCredits = Array((before.recentCredits + [credit]).suffix(3))
        return Reduction(state: next, reasons: reasons)
    }
}

public enum ContextBuilder {
    public static func messages(_ session: SessionSnapshot) -> [DialogueMessage] {
        [.init(speaker: .client, text: session.content.scenario.openingLine,
               origin: .init(turnID: nil, speaker: .client))] + session.turns.suffix(6).flatMap {
            [DialogueMessage(speaker: .counselor, text: $0.input, origin: .init(turnID: $0.id, speaker: .counselor)),
             DialogueMessage(speaker: .client, text: $0.reply.text, origin: .init(turnID: $0.id, speaker: .client))]
        }
    }
    public static func visibleFacts(_ scenario: ScenarioDefinition, state: SimulationState) -> [VisibleFact] {
        scenario.facts.filter { $0.minimumOpenness <= state.openness || state.disclosedFactIDs.contains($0.id) }
            .sorted { $0.id < $1.id }.map { .init(id: $0.id, text: $0.text, wasDisclosed: state.disclosedFactIDs.contains($0.id)) }
    }
    public static func behavior(_ openness: Int) -> String {
        switch openness {
        case ...2: "Du bist skeptisch und antwortest knapp, in ein bis zwei Sätzen."
        case 3...5: "Du erzählst etwas ausführlicher, relativierst aber noch und kannst Zweifel andeuten."
        default: "Du kannst persönlich über Gefühle sprechen. Du musst weder zustimmen noch etwas verändern wollen."
        }
    }
}

public enum TipSelector {
    public static func select(tag: ClientTag?, approach: String, tips: [Tip], previousID: String?) -> Tip? {
        guard let tag else { return nil }
        let matching = tips.filter { $0.reviewStatus == .reviewed && $0.approachID == approach && $0.triggerTag == tag }
            .sorted { $0.priority == $1.priority ? $0.id < $1.id : $0.priority > $1.priority }
        return matching.first(where: { $0.id != previousID }) ?? matching.first
    }
}
