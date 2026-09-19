import Foundation
import Testing
@testable import TrainerDesktop

@Test @MainActor func portraitPoolContainsResourcesAndRotationSurvivesRestart() throws {
    let pool = try HomePortrait.loadPool()
    #expect(pool.count >= 4)
    for portrait in pool {
        let image = try #require(PortraitIllustration.loadImage(named: portrait.imageName))
        #expect(image.width > 0 && image.height > 0)
    }
    let domain = "PortraitTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: domain))
    defer { defaults.removePersistentDomain(forName: domain) }
    let firstRun = HomePortraitRotation(pool: pool, defaults: defaults)
    #expect(firstRun.next().id == pool[0].id)
    // Ein neuer App-Prozess erzeugt einen neuen Rotator und liest dieselbe gespeicherte ID.
    let restarted = HomePortraitRotation(pool: pool, defaults: defaults)
    for portrait in pool.dropFirst() { #expect(restarted.next().id == portrait.id) }
    #expect(restarted.next().id == pool[0].id)
}

@Test @MainActor func rotationHandlesRemovedPortraitAndSingleEntry() throws {
    let pool = try HomePortrait.loadPool()
    let domain = "PortraitTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: domain))
    defer { defaults.removePersistentDomain(forName: domain) }
    let original = HomePortraitRotation(pool: pool, defaults: defaults)
    _ = original.next()
    let single = HomePortraitRotation(pool: [pool[1]], defaults: defaults)
    #expect(single.next().id == pool[1].id)
    #expect(single.next().id == pool[1].id)
}
