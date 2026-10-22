import Foundation
import Testing
@testable import TrainerCore

private let chosenPlan = "Am Samstag möchte ich ausprobieren, früher nach Hause zu gehen."
private func planSession(kind: NarrativeKind = .planned, uncertain: Bool = false) throws -> SessionSnapshot {
    var session = TestData.session()
    session.openingMessage = chosenPlan
    let id = UUID()
    let observation = NarrativeObservation(kind: kind,
        evidence: .init(source: .contextMessage, speaker: .client, messageIndex: 0, quote: chosenPlan, occurrence: 1), isUncertain: uncertain)
    let before = session.state
    session.state.narrative = try NarrativeTracker.advance(nil, observations: [observation], input: "Weiter",
        context: ContextBuilder.messages(session), session: session, turnID: id)
    session.turns.append(.init(id: id, input: "Weiter", analysis: nil,
        reply: .init(text: "Das möchte ich versuchen.", primaryTag: nil, disclosedFactIDs: []),
        stateBefore: before, stateAfter: session.state, stateChangeReasons: [], selectedTipID: nil, metrics: [], completedAt: Date()))
    session.revision = 1; session.status = .completed; session.endedAt = Date()
    return session
}

@Test func ideeUndUnsicherheitErzeugenKeinenZwischenverlauf() throws {
    #expect(try ExperienceSelector.select(after: planSession(kind: .idea)) == nil)
    #expect(try ExperienceSelector.select(after: planSession(uncertain: true)) == nil)
    var noPlan = try planSession(); noPlan.state.narrative = nil
    #expect(try ExperienceSelector.select(after: noPlan) == nil)
}

@Test func erfahrungsvarianteHaengtNichtVonOffenheitOderUhrzeitAb() throws {
    let original = try planSession()
    let a = try #require(try ExperienceSelector.select(after: original))
    var other = original; other.state.openness = 10; other.startedAt = .distantFuture
    other.state.closedQuestionStreak = 99; other.state.recentCredits = [.complexReflection, .autonomy]
    let b = try #require(try ExperienceSelector.select(after: other))
    #expect(a.variant == b.variant && a.plan == b.plan)
    #expect(a.plan.quote == chosenPlan)
    #expect(a.catalogVersion == "0.1-draft")
}

@Test func versteckteErfahrungStehtNurInDerRolleNichtInAnalyseOderNotiz() throws {
    let first = try planSession()
    let next = try VisitBuilder.followUp(after: first, identity: first.identity, at: Date())
    let experience = try #require(next.continuity?.experience)
    let analysis = try #require(ContextBuilder.visitContext(next))
    let role = try #require(ContextBuilder.roleVisitContext(next))
    #expect(!analysis.contains("Kuratierter fiktiver Zwischenverlauf"))
    #expect(role.contains(experience.roleContext))
    let note = try #require(next.continuity?.preparation)
    #expect(note.entries.contains { $0.quote == chosenPlan && $0.heading.contains("noch nicht umgesetzt") })
    #expect(!note.entries.contains { $0.quote.contains(experience.variant.instruction) })
    #expect(!ReviewBuilder.markdown(next).contains(experience.variant.instruction))
    #expect(next.state.openness == first.state.openness)
    #expect(next.state.development == first.state.development)
}

@Test func planBleibtUeberTerminErinnerbarUndErfahrungIstKeinMaintenanceStatus() throws {
    let first = try planSession()
    var next = try VisitBuilder.followUp(after: first, identity: first.identity, at: Date())
    let memory = try ContextBuilder.analysisMemory(next)
    #expect(memory.plans.count == 1)
    let reference = try #require(memory.plans.first?.evidence)
    #expect(memory.messages[reference.messageIndex!].origin?.sessionID == first.id)
    let spokenID = UUID(), before = next.state
    next.turns.append(.init(id: spokenID, input: "Wie war Ihr Versuch?", analysis: nil,
        reply: .init(text: "Am Samstag bin ich einmal früher gegangen.", primaryTag: nil, disclosedFactIDs: []),
        stateBefore: before, stateAfter: before, stateChangeReasons: [], selectedTipID: nil, metrics: [], completedAt: Date()))
    let context = try ContextBuilder.analysisMemory(next)
    let quote = "Am Samstag bin ich einmal früher gegangen."
    let index = try #require(context.messages.firstIndex { $0.text == quote })
    let observedID = UUID()
    next.state.narrative = try NarrativeTracker.advance(next.state.narrative, observations: [
        .init(kind: .completed, evidence: .init(source: .contextMessage, speaker: .client, messageIndex: index, quote: quote, occurrence: 1),
              plan: context.plans.first?.evidence)
    ], input: "Weiter", context: context.messages, session: next, turnID: observedID)
    next.turns.append(.init(id: observedID, input: "Weiter", analysis: nil,
        reply: .init(text: "Es war ein Versuch.", primaryTag: nil, disclosedFactIDs: []), stateBefore: before,
        stateAfter: next.state, stateChangeReasons: [], selectedTipID: nil, metrics: [], completedAt: Date()))
    next.status = .completed; next.endedAt = Date()
    let third = try VisitBuilder.followUp(after: next, identity: next.identity, at: Date())
    #expect(third.state.narrative?.records.last?.kind == .completed)
    #expect(third.state.openness == first.state.openness)
    #expect(third.continuity?.experience == nil) // Kein erneuter Ausgang für denselben alten Plan.
    #expect(third.continuity?.preparation.entries.contains { $0.quote == quote && $0.sessionID == next.id } == true)
    #expect(NarrativeKind.allCases.allSatisfy { $0.rawValue != "maintenance" })
    let decoded = try JSONDecoder().decode(SessionSnapshot.self, from: JSONEncoder().encode(third))
    try NarrativeTracker.validate(decoded.state.narrative, session: decoded, currentTurnID: UUID())
}

@Test func ungueltigeErfahrungsbelegeVerwerfenNurDieOptionaleAnalyse() throws {
    let session = try planSession()
    let analysis = TurnAnalysis(segments: [.init(quote: "Hallo", code: .other, isUncertain: false)],
        characterObservations: [], goalUpdates: [], narrativeObservations: [
            .init(kind: .completed, evidence: .init(source: .currentInput, speaker: .counselor,
                messageIndex: nil, quote: "Hallo", occurrence: 1))])
    let accepted = try CharacterTracker.acceptingIndependentMemory(analysis, before: session.state.development,
        input: "Hallo", context: ContextBuilder.messages(session), session: session, turnID: UUID())
    #expect(accepted.analysis.segments == analysis.segments)
    #expect(accepted.analysis.memoryStatus == .unavailable)
    #expect(accepted.narrative == session.state.narrative)
}

@Test func wiederholterBelegErzeugtKeinenNeuenVersuch() throws {
    let session = try planSession()
    let context = ContextBuilder.messages(session)
    let observation = NarrativeObservation(kind: .planned, evidence:
        .init(source: .contextMessage, speaker: .client, messageIndex: 0, quote: chosenPlan, occurrence: 1))
    let repeated = try NarrativeTracker.advance(session.state.narrative, observations: [observation], input: "Weiter",
        context: context, session: session, turnID: UUID())
    #expect(repeated == session.state.narrative)
}

private actor LastReplyPlanProvider: TrainerModelProvider {
    var rejectsReply = false
    var visitContexts: [String] = []
    func reject(_ value: Bool) { rejectsReply = value }
    func descriptor() -> ModelDescriptor { TestData.model }
    func prepare() {}
    func unload() {}
    func analyze(_ request: AnalysisRequest) -> ModelResult<TurnAnalysis> {
        let index = request.recentMessages.firstIndex { $0.text == chosenPlan }
        let observations = index.map { [NarrativeObservation(kind: .planned, evidence:
            .init(source: .contextMessage, speaker: .client, messageIndex: $0, quote: chosenPlan, occurrence: 1))] } ?? []
        return .init(value: .init(segments: [], narrativeObservations: observations),
            metrics: .init(durationSeconds: 0), contextMessagesUsed: request.recentMessages)
    }
    func reply(_ request: ReplyRequest) throws -> ModelResult<ClientReply> {
        if let context = request.visitContext { visitContexts.append(context) }
        if rejectsReply { throw TrainerFailure.invalidReply }
        return .init(value: .init(text: chosenPlan, primaryTag: nil, disclosedFactIDs: []),
                     metrics: .init(durationSeconds: 0), contextMessagesUsed: request.recentMessages)
    }
}

@Test func planAusLetzterAntwortWirdOhneExtraAufrufImFolgeterminBeruecksichtigt() async throws {
    let repository = MemorySessionRepository(), provider = LastReplyPlanProvider()
    let coordinator = ConversationCoordinator(repository: repository, provider: provider)
    var first = try await coordinator.create(content: TestData.content, contentHash: "test")
    first = try await coordinator.send(sessionID: first.id, input: "Was möchten Sie versuchen?")
    #expect(first.state.narrative == nil) // Die Antwort wurde erst gerade erzeugt.
    first = try await repository.finish(sessionID: first.id, expectedRevision: first.revision, endedAt: Date())
    let second = try await coordinator.createFollowUp(after: first.id)
    #expect(second.continuity?.experience == nil)
    await provider.reject(true)
    await #expect(throws: TrainerFailure.invalidReply) {
        _ = try await coordinator.send(sessionID: second.id, input: "Wie war der Versuch?")
    }
    let unchanged = try await repository.load(id: second.id)
    #expect(unchanged.continuity?.experience == nil && unchanged.state.narrative == nil)
    #expect(unchanged.turns.isEmpty)
    await provider.reject(false)
    let saved = try await coordinator.send(sessionID: second.id, input: "Wie war der Versuch?")
    let experience = try #require(saved.continuity?.experience)
    #expect(experience.plan.origin.turnID == first.turns.first?.id)
    #expect(saved.turns.first?.introducedExperience == experience)
    #expect(saved.state.narrative?.records.first?.kind == .planned)
    let contexts = await provider.visitContexts
    #expect(contexts.count == 3) // Zwei gescheiterte Antworten, eine erfolgreiche.
    #expect(contexts.allSatisfy { $0.contains(experience.script) })
    #expect(try await repository.commit(sessionID: second.id, expectedRevision: 0, turn: saved.turns[0]) == saved)
}
