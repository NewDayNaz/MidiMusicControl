import XCTest
@testable import MidiMusicControl

final class SettingsStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        suiteName = "MidiMusicControlTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
    }

    func testClampsFadeDurationOnLoad() {
        defaults.set(99.0, forKey: "fadeDuration")
        let store = SettingsStore(defaults: defaults)
        XCTAssertEqual(store.fadeDuration, SettingsStore.fadeDurationRange.upperBound)
    }

    func testRejectsDuplicateMapping() {
        let store = SettingsStore(defaults: defaults)
        let mapping = MIDIMapping(kind: .noteOn, note: 36, velocity: 127)

        XCTAssertTrue(store.setMapping(mapping, for: .spotifyFadeIn))
        XCTAssertFalse(store.setMapping(mapping, for: .spotifyFadeOut))
        XCTAssertNotNil(store.mappingConflictWarning)
        XCTAssertEqual(store.mapping(for: .spotifyFadeOut), SettingsStore.defaultMappings[.spotifyFadeOut])
    }

    func testMigratesLegacyFadeStepDelay() {
        defaults.set(0.03, forKey: "fadeStepDelay")
        let store = SettingsStore(defaults: defaults)
        XCTAssertEqual(store.fadeDuration, 0.03 * 101, accuracy: 0.001)
    }
}
