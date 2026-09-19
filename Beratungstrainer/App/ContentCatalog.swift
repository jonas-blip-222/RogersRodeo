import CryptoKit
import Foundation
import TrainerCore

struct ContentCatalog: Decodable {
    let schemaVersion: Int
    let scenarios: [ScenarioDefinition]
    let codingGuide: String
    let tips: [Tip]

    static func load() throws -> (catalog: Self, hash: String) {
        #if SWIFT_PACKAGE
        let bundle = Bundle.main.url(forResource: "RogersRodeo_TrainerDesktop", withExtension: "bundle")
            .flatMap { Bundle(url: $0) } ?? Bundle.module
        #else
        let bundle = Bundle.main
        #endif
        guard let url = bundle.url(forResource: "catalog", withExtension: "json"),
              let hashURL = bundle.url(forResource: "catalog", withExtension: "sha256") else { throw TrainerFailure.artifactInvalid }
        let data = try Data(contentsOf: url)
        let expected = try String(contentsOf: hashURL, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
        let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard hash == expected else { throw TrainerFailure.artifactInvalid }
        let catalog = try JSONDecoder().decode(Self.self, from: data)
        guard catalog.schemaVersion == 1, !catalog.scenarios.isEmpty,
              Set(catalog.scenarios.map(\.id)).count == catalog.scenarios.count,
              !catalog.codingGuide.isEmpty, catalog.tips.isEmpty else { throw TrainerFailure.artifactInvalid }
        for scenario in catalog.scenarios {
            #if DEBUG
            try OutputValidator.validateScenario(scenario, allowDrafts: true)
            #else
            try OutputValidator.validateScenario(scenario, allowDrafts: false)
            #endif
        }
        return (catalog, hash)
    }
}
