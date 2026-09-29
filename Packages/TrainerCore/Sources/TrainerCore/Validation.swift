import Foundation

public enum OutputValidator {
    static func exactKeys(_ value: Any, required: Set<String>, optional: Set<String> = []) throws -> [String: Any] {
        guard let object = value as? [String: Any], required.isSubset(of: Set(object.keys)),
              Set(object.keys).isSubset(of: required.union(optional)) else { throw TrainerFailure.artifactInvalid }
        return object
    }

    public static func decodeAnalysis(_ data: Data, input: String, context: [DialogueMessage]) throws -> TurnAnalysis {
        do {
            let object = try exactKeys(JSONSerialization.jsonObject(with: data), required: ["segments"], optional: ["doubleSidedReflection", "characterObservations"])
            guard let segments = object["segments"] as? [Any] else { throw TrainerFailure.invalidAnalysis }
            for value in segments {
                _ = try exactKeys(value, required: ["quote", "code", "isUncertain"], optional: ["supportingClientQuote"])
            }
            if let reflection = object["doubleSidedReflection"], !(reflection is NSNull) {
                let pair = try exactKeys(reflection, required: ["sustain", "change", "isUncertain"])
                for name in ["sustain", "change"] {
                    let side = try exactKeys(pair[name] as Any, required: ["input", "client"])
                    for field in ["input", "client"] {
                        _ = try exactKeys(side[field] as Any,
                            required: ["source", "speaker", "quote", "occurrence"], optional: ["messageIndex"])
                    }
                }
            }
            if let raw = object["characterObservations"], !(raw is NSNull) {
                guard let observations = raw as? [Any] else { throw TrainerFailure.invalidAnalysis }
                for value in observations {
                    let observation = try exactKeys(value,
                        required: ["dimension", "assessment", "evidence", "isUncertain"], optional: ["goal"])
                    for field in ["goal", "evidence"] {
                        if let reference = observation[field], !(reference is NSNull) {
                            _ = try exactKeys(reference, required: ["source", "speaker", "quote", "occurrence"],
                                              optional: ["messageIndex"])
                        }
                    }
                }
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
        let ranges = try locations(analysis, input: input)
        for segment in analysis.segments {
            if let quote = segment.supportingClientQuote {
                guard !quote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      context.contains(where: { $0.speaker == .client && $0.text.range(of: quote, options: .literal) != nil }) else {
                    throw TrainerFailure.invalidAnalysis
                }
            }
        }
        if let observations = analysis.characterObservations {
            guard observations.count <= 3, Set(observations.map(\.dimension)).count == observations.count else {
                throw TrainerFailure.invalidAnalysis
            }
            for observation in observations {
                guard observation.assessment.belongs(to: observation.dimension),
                      observation.evidence.source == .contextMessage, observation.evidence.speaker == .client else {
                    throw TrainerFailure.invalidAnalysis
                }
                try validateEvidence(observation.evidence, input: input, context: context)
                if observation.dimension == .rapport {
                    guard observation.goal == nil else { throw TrainerFailure.invalidAnalysis }
                } else {
                    guard let goal = observation.goal, goal.source == .contextMessage, goal.speaker == .client else {
                        throw TrainerFailure.invalidAnalysis
                    }
                    try validateEvidence(goal, input: input, context: context)
                }
            }
        }
        if let pair = analysis.doubleSidedReflection {
            for side in [pair.sustain, pair.change] {
                guard side.input.source == .currentInput, side.client.source == .contextMessage,
                      side.client.speaker == .client else { throw TrainerFailure.invalidAnalysis }
                try validateEvidence(side.client, input: input, context: context)
                let range = try evidenceRange(side.input, input: input, context: context)
                guard zip(analysis.segments, ranges).contains(where: { segment, segmentRange in
                    [.simpleReflection, .complexReflection].contains(segment.code)
                        && segmentRange.lowerBound <= range.lowerBound && range.upperBound <= segmentRange.upperBound
                }) else { throw TrainerFailure.invalidAnalysis }
            }
            let sustain = try evidenceRange(pair.sustain.input, input: input, context: context)
            let change = try evidenceRange(pair.change.input, input: input, context: context)
            guard !sustain.overlaps(change) else { throw TrainerFailure.invalidAnalysis }
        }
    }

    /// Prüft eine Belegstelle gegen die Texte, die tatsächlich übergeben wurden: dieselbe
    /// Strenge wie bei den Analysezitaten. Ein Beleg, der sich nicht wörtlich und an der
    /// bezeichneten Stelle wiederfinden lässt, wird abgewiesen — paraphrasierte Zitate
    /// dürfen nie in eine Rückmeldung geraten (MI-Nachtrag, Abschnitt 7.3).
    public static func validateEvidence(_ reference: EvidenceReference, input: String,
                                        context: [DialogueMessage]) throws {
        _ = try evidenceRange(reference, input: input, context: context)
    }

    static func evidenceRange(_ reference: EvidenceReference, input: String,
                              context: [DialogueMessage]) throws -> Range<String.Index> {
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
        var result: Range<String.Index>?
        for _ in 0..<reference.occurrence {
            guard let found = text.range(of: reference.quote, options: .literal, range: cursor..<text.endIndex) else {
                throw TrainerFailure.invalidAnalysis
            }
            cursor = found.upperBound
            result = found
        }
        guard let result else { throw TrainerFailure.invalidAnalysis }
        return result
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
