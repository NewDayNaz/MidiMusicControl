import XCTest
@testable import MidiMusicControl

final class MIDIParserTests: XCTestCase {
    func testNoteOnMessage() {
        let messages = MIDIParser.parse([0x90, 60, 127])
        XCTAssertEqual(messages, [.noteOn(note: 60, velocity: 127)])
    }

    func testNoteOnWithZeroVelocity() {
        let messages = MIDIParser.parse([0x90, 60, 0])
        XCTAssertEqual(messages, [.noteOn(note: 60, velocity: 0)])
    }

    func testControlChangeMessage() {
        let messages = MIDIParser.parse([0xB0, 7, 100])
        XCTAssertEqual(messages, [.controlChange(controller: 7, value: 100)])
    }

    func testRunningStatusNoteOn() {
        let messages = MIDIParser.parse([0x90, 60, 127, 61, 127])
        XCTAssertEqual(messages, [
            .noteOn(note: 60, velocity: 127),
            .noteOn(note: 61, velocity: 127),
        ])
    }

    func testRunningStatusControlChange() {
        let messages = MIDIParser.parse([0xB0, 1, 0, 2, 64])
        XCTAssertEqual(messages, [
            .controlChange(controller: 1, value: 0),
            .controlChange(controller: 2, value: 64),
        ])
    }

    func testNoteOffIsIgnored() {
        let messages = MIDIParser.parse([0x80, 60, 0])
        XCTAssertTrue(messages.isEmpty)
    }

    func testSysExIsSkipped() {
        let messages = MIDIParser.parse([0xF0, 0x7E, 0x7F, 0xF7, 0x90, 64, 127])
        XCTAssertEqual(messages, [.noteOn(note: 64, velocity: 127)])
    }
}
