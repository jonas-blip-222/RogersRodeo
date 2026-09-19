import Foundation
import SwiftData
import TrainerCore

@Model final class StoredSession {
    @Attribute(.unique) var id: UUID
    var startedAt: Date
    var scenarioName: String
    var status: String
    var payload: Data
    init(record: SessionRecord, payload: Data) {
        id = record.snapshot.id; startedAt = record.snapshot.startedAt
        scenarioName = record.snapshot.content.scenario.name
        status = record.snapshot.status.rawValue; self.payload = payload
    }
}

/// Alle Schreibvorgänge sind synchron auf demselben Actor; kein await innerhalb einer Transaktion.
@MainActor public final class SwiftDataSessionRepository: SessionRepository {
    private let container: ModelContainer
    private let context: ModelContext
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(storeURL: URL? = nil, inMemory: Bool = false) throws {
        if let storeURL, !inMemory {
            var directory = storeURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            var values = URLResourceValues(); values.isExcludedFromBackup = true
            try directory.setResourceValues(values)
            #if os(iOS)
            try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], atPath: directory.path)
            #endif
        }
        let schema = Schema([StoredSession.self])
        let configuration: ModelConfiguration
        if let storeURL, !inMemory {
            configuration = ModelConfiguration("Conversations", schema: schema, url: storeURL, cloudKitDatabase: .none)
        } else {
            configuration = ModelConfiguration("Conversations", schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        }
        container = try ModelContainer(for: schema, configurations: [configuration])
        context = ModelContext(container); context.autosaveEnabled = false
        encoder.outputFormatting = [.sortedKeys]
        // Verlustfreie interne Datumswerte sichern exakte Commit-Wiederholungen nach Neustart.
        // Der menschenlesbare Export verwendet ISO 8601.
    }

    private func row(_ id: UUID) throws -> StoredSession? {
        var query = FetchDescriptor<StoredSession>(predicate: #Predicate { $0.id == id })
        query.fetchLimit = 1
        return try context.fetch(query).first
    }
    private func record(_ row: StoredSession) throws -> SessionRecord {
        do {
            let record = try decoder.decode(SessionRecord.self, from: row.payload)
            guard record.snapshot.schemaVersion == 1 else { throw TrainerFailure.unsupportedVersion }
            guard record.snapshot.id == row.id, record.snapshot.status.rawValue == row.status,
                  record.snapshot.startedAt == row.startedAt,
                  record.pending == nil || record.pending?.sessionID == row.id else { throw TrainerFailure.artifactInvalid }
            return record
        } catch let error as TrainerFailure { throw error }
        catch { throw TrainerFailure.artifactInvalid }
    }
    private func required(_ id: UUID) throws -> StoredSession {
        guard let value = try row(id) else { throw TrainerFailure.sessionNotFound }
        return value
    }
    private func save() throws {
        do { try Task.checkCancellation(); try context.save() }
        catch { context.rollback(); if error is CancellationError { throw error }; throw TrainerFailure.storageUnavailable }
    }
    public func create(_ snapshot: SessionSnapshot) throws {
        try RepositoryRules.validateNew(snapshot)
        guard try row(snapshot.id) == nil else { throw TrainerFailure.revisionConflict }
        let record = SessionRecord(snapshot: snapshot)
        context.insert(StoredSession(record: record, payload: try encoder.encode(record)))
        try save()
    }
    public func load(id: UUID) throws -> SessionSnapshot { try record(required(id)).snapshot }
    public func list() throws -> [SessionSummary] {
        let rows = try context.fetch(FetchDescriptor<StoredSession>(sortBy: [SortDescriptor(\.startedAt, order: .reverse)]))
        return try rows.map { row in
            let value = try record(row).snapshot
            return SessionSummary(id: value.id, scenarioName: value.content.scenario.name, startedAt: value.startedAt, status: value.status)
        }
    }
    @discardableResult private func mutate(_ id: UUID, _ update: (inout SessionRecord) throws -> Void) throws -> SessionSnapshot {
        let row = try required(id)
        var value = try record(row)
        try update(&value)
        let data = try encoder.encode(value)
        row.payload = data; row.status = value.snapshot.status.rawValue
        try save()
        return value.snapshot
    }
    public func savePending(_ pending: PendingTurn) throws {
        try mutate(pending.sessionID) { try RepositoryRules.savePending(pending, in: &$0) }
    }
    public func loadPending(sessionID: UUID) throws -> PendingTurn? { try record(required(sessionID)).pending }
    public func discardPending(sessionID: UUID, turnID: UUID) throws {
        try mutate(sessionID) { RepositoryRules.discardPending(turnID: turnID, in: &$0) }
    }
    public func commit(sessionID: UUID, expectedRevision: Int, turn: CompletedTurn) throws -> SessionSnapshot {
        try mutate(sessionID) { try RepositoryRules.commit(turn, expectedRevision: expectedRevision, in: &$0) }
    }
    public func finish(sessionID: UUID, expectedRevision: Int, endedAt: Date) throws -> SessionSnapshot {
        try mutate(sessionID) { try RepositoryRules.finish(expectedRevision: expectedRevision, at: endedAt, in: &$0) }
    }
    public func delete(id: UUID) throws {
        if let row = try row(id) { context.delete(row); try save() }
    }
}
