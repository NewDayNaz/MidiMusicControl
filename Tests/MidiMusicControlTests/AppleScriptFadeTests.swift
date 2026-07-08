import XCTest
@testable import MidiMusicControl

final class AppleScriptFadeTests: XCTestCase {
    func testFadeInSetsVolumeToZeroBeforePlay() {
        let script = AppleScriptFade.fadeScript(app: .spotify, action: .fadeIn, fadeDuration: 3.0)
        let lines = script.split(separator: "\n", omittingEmptySubsequences: false)

        let volumeZeroLine = lines.firstIndex { $0.contains("set the sound volume to 0") }
        let playLine = lines.firstIndex { $0.trimmingCharacters(in: .whitespaces) == "play" }

        XCTAssertNotNil(volumeZeroLine)
        XCTAssertNotNil(playLine)
        XCTAssertLessThan(volumeZeroLine!, playLine!)
    }

    func testFadeInRampsFromZeroToTargetVolume() {
        let script = AppleScriptFade.fadeScript(app: .music, action: .fadeIn, fadeDuration: 2.5)

        XCTAssertTrue(script.contains("repeat with i from 0 to targetVol by 1"))
        XCTAssertTrue(script.contains("set targetVol to the sound volume"))
    }

    func testDuckReturnsNegativeOneWhenPaused() {
        let script = AppleScriptFade.duckScript(app: .spotify, targetVolume: 30, fadeDuration: 2.0)
        XCTAssertTrue(script.contains("return -1"))
    }
}
