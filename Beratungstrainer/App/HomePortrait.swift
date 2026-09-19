import Foundation
import TrainerCore

struct HomePortrait: Decodable, Identifiable {
    let id: String
    let name: String
    let approach: String
    let imageName: String
    let headline: String
    let caption: String

    static func loadPool() throws -> [Self] {
        let bundle = AppResources.bundle
        guard let url = bundle.url(forResource: "portrait-pool", withExtension: "json") else { throw TrainerFailure.artifactInvalid }
        let pool = try JSONDecoder().decode([Self].self, from: Data(contentsOf: url))
        guard !pool.isEmpty, Set(pool.map(\.id)).count == pool.count,
              pool.allSatisfy({ !$0.id.isEmpty && !$0.name.isEmpty && !$0.headline.isEmpty &&
                  bundle.url(forResource: $0.imageName, withExtension: "png") != nil }) else { throw TrainerFailure.artifactInvalid }
        return pool
    }
}

/// Persistente Reihenfolge ohne direkte Wiederholung. Neue Motive werden nur im JSON ergänzt.
@MainActor final class HomePortraitRotation {
    private let pool: [HomePortrait]
    private let defaults: UserDefaults
    private let key = "home.lastPortraitID"

    init(pool: [HomePortrait], defaults: UserDefaults = .standard) {
        precondition(!pool.isEmpty)
        self.pool = pool; self.defaults = defaults
    }
    func next() -> HomePortrait {
        let previous = defaults.string(forKey: key)
        let index = pool.firstIndex(where: { $0.id == previous }).map { ($0 + 1) % pool.count } ?? 0
        let selected = pool[index]
        defaults.set(selected.id, forKey: key)
        return selected
    }
}
