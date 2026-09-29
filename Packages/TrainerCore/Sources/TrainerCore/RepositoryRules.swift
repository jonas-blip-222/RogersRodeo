import Foundation

public struct SessionRecord: Codable, Sendable, Equatable {
    public var snapshot: SessionSnapshot
    public var pending: PendingTurn?
    public init(snapshot: SessionSnapshot, pending: PendingTurn? = nil) { self.snapshot = snapshot; self.pending = pending }
}

public enum RepositoryRules {
    public static func validateNew(_ snapshot: SessionSnapshot) throws {
        try OutputValidator.validateScenario(snapshot.content.scenario, allowDrafts: true)
        guard snapshot.schemaVersion == 1, snapshot.revision == 0, snapshot.turns.isEmpty,
              snapshot.status == .active, snapshot.endedAt == nil,
              snapshot.state == SimulationState(openness: snapshot.content.scenario.opennessStart),
              snapshot.content.scenario.approaches.contains(snapshot.approachID) else { throw TrainerFailure.artifactInvalid }
    }
    static func active(_ record: SessionRecord, revision: Int) throws {
        guard record.snapshot.status == .active else { throw TrainerFailure.sessionCompleted }
        guard record.snapshot.revision == revision else { throw TrainerFailure.revisionConflict }
    }
    public static func savePending(_ pending: PendingTurn, in record: inout SessionRecord) throws {
        try active(record, revision: pending.expectedRevision)
        guard pending.sessionID == record.snapshot.id, !pending.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              pending.input.count <= 1500, record.snapshot.turns.count < 20 else { throw TrainerFailure.artifactInvalid }
        if let existing = record.pending, existing != pending { throw TrainerFailure.revisionConflict }
        record.pending = pending
    }
    public static func discardPending(turnID: UUID, in record: inout SessionRecord) {
        if record.pending?.id == turnID { record.pending = nil }
    }
    public static func commit(_ turn: CompletedTurn, expectedRevision: Int, in record: inout SessionRecord) throws {
        if let existing = record.snapshot.turns.first(where: { $0.id == turn.id }) {
            guard existing == turn else { throw TrainerFailure.revisionConflict }
            return
        }
        try active(record, revision: expectedRevision)
        guard let pending = record.pending, pending.id == turn.id, pending.input == turn.input,
              pending.expectedRevision == expectedRevision, turn.stateBefore == record.snapshot.state,
              record.snapshot.turns.count < 20, (0...10).contains(turn.stateAfter.openness),
              turn.stateAfter.closedQuestionStreak >= 0, turn.stateAfter.recentCredits.count <= 3 else {
            throw TrainerFailure.revisionConflict
        }
        var gate = turn.stateAfter
        gate.disclosedFactIDs = turn.stateBefore.disclosedFactIDs
        let facts = ContextBuilder.visibleFacts(record.snapshot.content.scenario, state: gate)
        try OutputValidator.validateReply(turn.reply, visibleFacts: facts)
        guard turn.stateAfter.disclosedFactIDs == turn.stateBefore.disclosedFactIDs.union(turn.reply.disclosedFactIDs),
              turn.stateAfter.disclosedFactIDs.isSubset(of: Set(record.snapshot.content.scenario.facts.map(\.id))) else {
            throw TrainerFailure.invalidReply
        }
        let previousEvents = turn.stateBefore.development?.goalEvents ?? []
        let nextEvents = turn.stateAfter.development?.goalEvents ?? []
        guard Array(nextEvents.prefix(previousEvents.count)) == previousEvents,
              nextEvents.dropFirst(previousEvents.count).allSatisfy({ $0.observedInTurnID == turn.id }) else {
            throw TrainerFailure.invalidAnalysis
        }
        try CharacterTracker.validate(turn.stateAfter.development, session: record.snapshot, currentTurnID: turn.id)
        record.snapshot.turns.append(turn)
        record.snapshot.state = turn.stateAfter
        record.snapshot.revision += 1
        record.pending = nil
    }
    public static func finish(expectedRevision: Int, at date: Date, in record: inout SessionRecord) throws {
        if record.snapshot.status == .completed {
            guard record.snapshot.endedAt == date else { throw TrainerFailure.revisionConflict }
            return
        }
        try active(record, revision: expectedRevision)
        guard record.pending == nil else { throw TrainerFailure.revisionConflict }
        record.snapshot.status = .completed; record.snapshot.endedAt = date; record.snapshot.revision += 1
    }
}

public actor MemorySessionRepository: SessionRepository {
    private var records: [UUID: SessionRecord] = [:]
    public init() {}
    public func create(_ snapshot: SessionSnapshot) throws {
        try Task.checkCancellation()
        try RepositoryRules.validateNew(snapshot)
        guard records[snapshot.id] == nil else { throw TrainerFailure.revisionConflict }
        records[snapshot.id] = SessionRecord(snapshot: snapshot)
    }
    private func record(_ id: UUID) throws -> SessionRecord {
        guard let record = records[id] else { throw TrainerFailure.sessionNotFound }
        return record
    }
    public func load(id: UUID) throws -> SessionSnapshot { try record(id).snapshot }
    public func list() -> [SessionSummary] {
        records.values.map { .init(id: $0.snapshot.id, scenarioName: $0.snapshot.content.scenario.name,
                                    startedAt: $0.snapshot.startedAt, status: $0.snapshot.status) }.sorted { $0.startedAt > $1.startedAt }
    }
    public func savePending(_ pending: PendingTurn) throws {
        try Task.checkCancellation(); var value = try record(pending.sessionID)
        try RepositoryRules.savePending(pending, in: &value); records[pending.sessionID] = value
    }
    public func loadPending(sessionID: UUID) throws -> PendingTurn? { try record(sessionID).pending }
    public func discardPending(sessionID: UUID, turnID: UUID) throws {
        var value = try record(sessionID); RepositoryRules.discardPending(turnID: turnID, in: &value); records[sessionID] = value
    }
    public func commit(sessionID: UUID, expectedRevision: Int, turn: CompletedTurn) throws -> SessionSnapshot {
        try Task.checkCancellation(); var value = try record(sessionID)
        try RepositoryRules.commit(turn, expectedRevision: expectedRevision, in: &value)
        records[sessionID] = value; return value.snapshot
    }
    public func finish(sessionID: UUID, expectedRevision: Int, endedAt: Date) throws -> SessionSnapshot {
        try Task.checkCancellation(); var value = try record(sessionID)
        try RepositoryRules.finish(expectedRevision: expectedRevision, at: endedAt, in: &value)
        records[sessionID] = value; return value.snapshot
    }
    public func delete(id: UUID) { records[id] = nil }
}
