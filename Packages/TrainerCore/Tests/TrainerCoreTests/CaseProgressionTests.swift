import Foundation
import Testing
@testable import TrainerCore

@discardableResult
private func appendTurn(_ session: inout SessionSnapshot, id: UUID = UUID(), input: String, reply: String) -> UUID {
    let state = session.state
    session.turns.append(.init(id: id, input: input, analysis: nil,
        reply: .init(text: reply, primaryTag: nil, disclosedFactIDs: []), stateBefore: state, stateAfter: state,
        stateChangeReasons: [], selectedTipID: nil, metrics: [], completedAt: Date()))
    session.revision += 1
    return id
}

/// Lukas sagt je Einordnung einen eigenen Satz; die Analyse der nächsten Runde ordnet ihn ein.
private func say(_ session: inout SessionSnapshot, _ reply: String, as kinds: [NarrativeKind]) throws {
    if kinds.isEmpty { appendTurn(&session, input: "Erzählen Sie.", reply: reply); return }
    for (number, kind) in kinds.enumerated() {
        let text = kinds.count == 1 ? reply : "\(reply) (\(number + 1))"
        appendTurn(&session, input: "Erzählen Sie.", reply: text)
        let memory = try ContextBuilder.analysisMemory(session)
        let index = try #require(memory.messages.lastIndex { $0.text == text })
        let observation = NarrativeObservation(kind: kind,
            evidence: .init(source: .contextMessage, speaker: .client, messageIndex: index, quote: text, occurrence: 1),
            plan: [.planned, .idea].contains(kind) ? nil : memory.plans.last?.evidence)
        let observedID = UUID()
        session.state.narrative = try NarrativeTracker.advance(session.state.narrative, observations: [observation],
            input: "Weiter", context: memory.messages, session: session, turnID: observedID)
        appendTurn(&session, id: observedID, input: "Weiter", reply: "Ja.")
    }
}

private func finished(_ session: SessionSnapshot) -> SessionSnapshot {
    var value = session; value.status = .completed; value.endedAt = Date(); return value
}

private let plan = "Am Samstag möchte ich ausprobieren, früher nach Hause zu gehen."

private func caseWithFirstReport() throws -> SessionSnapshot {
    var first = TestData.session()
    try say(&first, plan, as: [.planned])
    var second = try VisitBuilder.followUp(after: finished(first), identity: first.identity, at: Date())
    try say(&second, "Am Samstag bin ich einmal früher gegangen.", as: [.completed])
    return finished(second)
}

@Test func abstandWaechstErstNachBerichteterUmsetzung() throws {
    var first = TestData.session()
    try say(&first, plan, as: [.planned])
    let done = finished(first)
    #expect(VisitInterval.allowed(after: done) == [1])
    #expect(throws: TrainerFailure.invalidInput) { try VisitBuilder.followUp(after: done, identity: done.identity, at: Date(), intervalWeeks: 4) }
    let reported = try caseWithFirstReport()
    #expect(VisitInterval.allowed(after: reported) == VisitInterval.options)
    let third = try VisitBuilder.followUp(after: reported, identity: reported.identity, at: Date(), intervalWeeks: 4)
    #expect(third.intervalWeeks == 4 && third.fictionalWeek == 5 && third.sessionNumber == 3)
    #expect(third.continuity?.priorSessions.map(\.week) == [0, 1])
    #expect(try #require(ContextBuilder.visitContext(third)).contains("vier Wochen"))
    #expect(throws: TrainerFailure.invalidInput) { try VisitBuilder.followUp(after: reported, identity: reported.identity, at: Date(), intervalWeeks: 5) }
}

@Test func vereinbarungImGespraechWirdAlsVorschlagErkannt() throws {
    var session = try caseWithFirstReport()
    _ = appendTurn(&session, input: "Wie oft möchten Sie kommen? Ich hätte in vier Wochen Zeit.", reply: "Passt. Dann in vier Wochen.")
    let found = try #require(IntervalSuggestion.find(in: session))
    #expect(found.weeks == 4 && found.speaker == .client && found.quote == "Dann in vier Wochen.")
    _ = appendTurn(&session, input: "Oder lieber in einem Monat?", reply: "Gut.")
    #expect(IntervalSuggestion.find(in: session)?.weeks == 4)
    _ = appendTurn(&session, input: "Sehen wir uns in drei Monaten?", reply: "Ja.")
    #expect(IntervalSuggestion.find(in: session)?.weeks == 13)
    _ = appendTurn(&session, input: "Dann bis nächste Woche!", reply: "Bis dann.")
    #expect(IntervalSuggestion.find(in: session)?.weeks == 1)
    var early = TestData.session()
    _ = appendTurn(&early, input: "Sehen wir uns in drei Monaten?", reply: "Ja.")
    #expect(IntervalSuggestion.find(in: early) == nil) // Vor einer Umsetzung nur eine Woche.
}

@Test func fortsetzungsphaseFolgtEinemFestenMusterUnabhaengigVonOffenheit() throws {
    let reported = try caseWithFirstReport()
    var other = reported; other.state.openness = 10; other.state.recentCredits = [.complexReflection]
    let a = try #require(try VisitBuilder.followUp(after: reported, identity: reported.identity, at: Date(), intervalWeeks: 2).continuity?.experience)
    let b = try #require(try VisitBuilder.followUp(after: other, identity: other.identity, at: .distantFuture, intervalWeeks: 2).continuity?.experience)
    #expect(a.variant == b.variant && a.variant.isProgression)
    #expect(a.catalogVersion == "0.2-draft" && a.intervalWeeks == 2 && a.plan.quote == plan)
    #expect(a.roleContext.contains("zwei Wochen") || a.roleContext.contains("2 Wochen"))
    // Über mehrere Termine entsteht genau eines der Verlaufsmuster.
    var current = reported, variants: [ExperienceVariant] = []
    for _ in 0..<4 {
        var next = try VisitBuilder.followUp(after: current, identity: current.identity, at: Date(), intervalWeeks: 4)
        let variant = try #require(next.continuity?.experience?.variant)
        variants.append(variant)
        if variant == .gaveUp { break }
        try say(&next, "Ich habe seitdem meistens früher Schluss gemacht.", as: variant == .slipOpen ? [] : [.continued])
        current = finished(next)
    }
    #expect(ExperienceSelector.patterns.contains { pattern in Array(variants.prefix(pattern.count)) == Array(pattern.prefix(variants.count)) })
    #expect(current.continuity?.pastExperiences?.count == variants.count - (variants.last == .gaveUp ? 1 : 0))
}

@Test func maintenanceVerlangtDreiBerichteDreizehnWochenUndSchwierigkeit() throws {
    func chain(weeks: [Int], kinds: [[NarrativeKind]]) throws -> SessionSnapshot {
        var current = try caseWithFirstReport()
        for (week, kinds) in zip(weeks, kinds) {
            var next = try VisitBuilder.followUp(after: current, identity: current.identity, at: Date(), intervalWeeks: week)
            try say(&next, "Seit dem letzten Mal bin ich meistens früher gegangen, einmal war es echt schwer.", as: kinds)
            current = finished(next)
        }
        return current
    }
    let met = try chain(weeks: [4, 4, 13], kinds: [[.continued], [.continued, .setback], [.continued]])
    let progress = MaintenanceProgress.evaluate(met)
    #expect(progress.reports.map(\.week) == [5, 9, 22] && progress.difficulty != nil && progress.isMet)
    #expect(!MaintenanceProgress.evaluate(try chain(weeks: [2, 2, 2], kinds: [[.continued], [.continued, .setback], [.continued]])).isMet)
    #expect(!MaintenanceProgress.evaluate(try chain(weeks: [4, 4, 13], kinds: [[.continued], [.continued], [.continued]])).isMet)
    // Ein Ausrutscher mit offenem Ausgang lässt die Kette ruhen; Weitermachen macht ihn zur bewältigten Schwierigkeit.
    let resting = try chain(weeks: [4, 4, 4, 13], kinds: [[.continued], [.setback], [.continued], [.continued]])
    #expect(MaintenanceProgress.evaluate(resting).isMet)
    // Aufgeben setzt die Zählung zurück.
    let reset = try chain(weeks: [4, 4, 4, 13], kinds: [[.continued, .setback], [.withdrawn], [.continued], [.continued]])
    #expect(MaintenanceProgress.evaluate(reset).reports.count == 2 && !MaintenanceProgress.evaluate(reset).isMet)
    // Unsichere Einordnungen zählen nicht.
    var uncertain = met
    let records = met.state.narrative!.records.map { var r = $0; r.isUncertain = true; return r }
    uncertain.state.narrative = NarrativeMemory(records: records)
    #expect(MaintenanceProgress.evaluate(uncertain).reports.isEmpty)
}

@Test func verändertesVorhabenSetztDieKetteNichtZurueck() throws {
    var current = try caseWithFirstReport()
    var next = try VisitBuilder.followUp(after: current, identity: current.identity, at: Date(), intervalWeeks: 4)
    try say(&next, "Ich bin meistens früher gegangen, einmal ging es schief.", as: [.continued, .setback])
    try say(&next, "Ab jetzt möchte ich auch freitags früher gehen.", as: [.planned])
    current = finished(next)
    let fourth = try VisitBuilder.followUp(after: current, identity: current.identity, at: Date(), intervalWeeks: 13)
    #expect(fourth.continuity?.experience?.plan.quote == "Ab jetzt möchte ich auch freitags früher gehen.")
    #expect(MaintenanceProgress.evaluate(fourth).reports.count == 1)
}

@Test func rolleKenntAbstandswunschUndDarfAbschlussAnsprechenAnalyseNicht() throws {
    let reported = try caseWithFirstReport()
    let next = try VisitBuilder.followUp(after: reported, identity: reported.identity, at: Date(), intervalWeeks: 4)
    let role = try #require(ContextBuilder.roleVisitContext(next))
    let analysis = try #require(ContextBuilder.visitContext(next))
    #expect(role.contains("eigenen Wunsch zum Abstand") && role.contains("ob du die Termine noch brauchst"))
    #expect(!analysis.contains("Wunsch") && !analysis.contains("Kuratierter"))
}

@Test func fallendeIstEndgueltigWiederholbarUndOhneBelegeKeinMaintenance() async throws {
    let repo = MemorySessionRepository(), provider = ControlledProvider()
    let coordinator = ConversationCoordinator(repository: repo, provider: provider)
    let first = try await coordinator.create(content: TestData.content, contentHash: "test", openingLine: "Hallo.")
    _ = try await coordinator.send(sessionID: first.id, input: "Hallo")
    let current = try await repo.load(id: first.id)
    await #expect(throws: TrainerFailure.sessionCompleted) { try await repo.closeCase(sessionID: first.id, at: Date()) }
    let done = try await repo.finish(sessionID: first.id, expectedRevision: current.revision, endedAt: Date())
    let closed = try await coordinator.closeCase(sessionID: done.id)
    #expect(closed.caseClosure?.outcome == .endedWithoutMaintenance)
    let again = try await repo.closeCase(sessionID: done.id, at: .distantFuture)
    #expect(again.caseClosure == closed.caseClosure && again.revision == closed.revision)
    await #expect(throws: TrainerFailure.sessionCompleted) { try await coordinator.createFollowUp(after: done.id) }
    let review = CaseReview.build(closed)
    #expect(review.outcomeText == "Beendet ohne Maintenance" && review.visits.count == 1)
    #expect(review.markdown.contains("Keine Kompetenzbewertung"))
}

@Test func nurDerLetzteTerminBeendetDenFall() throws {
    let reported = try caseWithFirstReport()
    var record = SessionRecord(snapshot: reported)
    record.snapshot.followUpSessionID = UUID()
    #expect(throws: TrainerFailure.sessionCompleted) { try RepositoryRules.closeCase(at: Date(), in: &record) }
    var closed = reported; closed.caseClosure = .init(outcome: .endedWithoutMaintenance, closedAt: Date())
    #expect(throws: TrainerFailure.sessionCompleted) { try VisitBuilder.followUp(after: closed, identity: closed.identity, at: Date()) }
}
