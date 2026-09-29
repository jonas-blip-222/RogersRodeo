import Foundation

public enum OutputValidator {
    static func exactKeys(_ value: Any, required: Set<String>, optional: Set<String> = []) throws -> [String: Any] {
        guard let object = value as? [String: Any], required.isSubset(of: Set(object.keys)),
              Set(object.keys).isSubset(of: required.union(optional)) else { throw TrainerFailure.artifactInvalid }
        return object
    }

    public static func decodeAnalysis(_ data: Data, input: String, context: [DialogueMessage]) throws -> TurnAnalysis {
        do {
            let object = try exactKeys(JSONSerialization.jsonObject(with: data), required: ["segments"])
            guard let segments = object["segments"] as? [Any] else { throw TrainerFailure.invalidAnalysis }
            for value in segments {
                _ = try exactKeys(value, required: ["quote", "code", "isUncertain"], optional: ["supportingClientQuote"])
            }
            let analysis = try JSONDecoder().decode(TurnAnalysis.self, from: data)
            try validateAnalysis(analysis, input: input, context: context)
            return analysis
        } catch { throw TrainerFailure.invalidAnalysis }
    }

    public static func decodeReply(_ data: Data, visibleFacts: [VisibleFact]) throws -> ClientReply {
        do {
            _ = try exactKeys(JSONSerialization.jsonObject(with: data), required: ["text", "disclosedFactIDs"], optional: ["primaryTag"])
            let reply = try JSONDecoder().decode(ClientReply.self, from: data)
            try validateReply(reply, visibleFacts: visibleFacts)
            return reply
        } catch { throw TrainerFailure.invalidReply }
    }

    static func locations(_ analysis: TurnAnalysis, input: String) throws -> [Range<String.Index>] {
        guard analysis.segments.count <= 12 else { throw TrainerFailure.invalidAnalysis }
        var cursor = input.startIndex
        return try analysis.segments.map { segment in
            guard !segment.quote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  let range = input.range(of: segment.quote, options: .literal, range: cursor..<input.endIndex) else {
                throw TrainerFailure.invalidAnalysis
            }
            cursor = range.upperBound
            return range
        }
    }

    public static func validateAnalysis(_ analysis: TurnAnalysis, input: String, context: [DialogueMessage]) throws {
        _ = try locations(analysis, input: input)
        for segment in analysis.segments {
            if let quote = segment.supportingClientQuote {
                guard !quote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      context.contains(where: { $0.speaker == .client && $0.text.range(of: quote, options: .literal) != nil }) else {
                    throw TrainerFailure.invalidAnalysis
                }
            }
        }
    }

    /// Prüft eine Belegstelle gegen die Texte, die tatsächlich übergeben wurden: dieselbe
    /// Strenge wie bei den Analysezitaten. Ein Beleg, der sich nicht wörtlich und an der
    /// bezeichneten Stelle wiederfinden lässt, wird abgewiesen — paraphrasierte Zitate
    /// dürfen nie in eine Rückmeldung geraten (MI-Nachtrag, Abschnitt 7.3).
    public static func validateEvidence(_ reference: EvidenceReference, input: String,
                                        context: [DialogueMessage]) throws {
        let text: String
        switch reference.source {
        case .currentInput:
            guard reference.messageIndex == nil, reference.speaker == .counselor else {
                throw TrainerFailure.invalidAnalysis
            }
            text = input
        case .contextMessage:
            guard let index = reference.messageIndex, context.indices.contains(index),
                  context[index].speaker == reference.speaker else { throw TrainerFailure.invalidAnalysis }
            text = context[index].text
        }
        guard reference.occurrence >= 1,
              !reference.quote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TrainerFailure.invalidAnalysis
        }
        var cursor = text.startIndex
        for _ in 0..<reference.occurrence {
            guard let found = text.range(of: reference.quote, options: .literal, range: cursor..<text.endIndex) else {
                throw TrainerFailure.invalidAnalysis
            }
            cursor = found.upperBound
        }
    }

    public static func validateReply(_ reply: ClientReply, visibleFacts: [VisibleFact]) throws {
        let text = reply.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let ids = Set(reply.disclosedFactIDs)
        guard !text.isEmpty, text.count <= 1200, ids.count == reply.disclosedFactIDs.count,
              ids.isSubset(of: Set(visibleFacts.map(\.id))),
              text.range(of: #"(?m)^\s*(Berater(in)?|Assistant|System):"#, options: .regularExpression) == nil else {
            throw TrainerFailure.invalidReply
        }
    }

    public static func validateScenario(_ scenario: ScenarioDefinition, allowDrafts: Bool) throws {
        guard scenario.schemaVersion == 1, !scenario.id.isEmpty, !scenario.version.isEmpty,
              !scenario.name.isEmpty, (1...120).contains(scenario.age), ["Sie", "Du"].contains(scenario.address),
              scenario.approaches == ["mi"], (0...10).contains(scenario.opennessStart),
              !scenario.openingLine.isEmpty, !scenario.publicProfile.isEmpty,
              allowDrafts || scenario.status == .reviewed,
              Set(scenario.facts.map(\.id)).count == scenario.facts.count,
              scenario.facts.allSatisfy({ !$0.id.isEmpty && !$0.text.isEmpty && (0...10).contains($0.minimumOpenness) }) else {
            throw TrainerFailure.artifactInvalid
        }
    }
}
