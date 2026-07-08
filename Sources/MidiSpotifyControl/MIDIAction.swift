import Foundation

enum ActionKind {
    case fadeIn
    case fadeOut
    case duck
    case unduck
}

enum MIDIAction: String, CaseIterable, Codable, Identifiable {
    case spotifyFadeIn
    case spotifyFadeOut
    case musicFadeIn
    case musicFadeOut
    case spotifyDuck
    case spotifyUnduck
    case musicDuck
    case musicUnduck

    var id: String { rawValue }

    var label: String {
        switch self {
        case .spotifyFadeIn: return "Spotify Fade In"
        case .spotifyFadeOut: return "Spotify Fade Out"
        case .musicFadeIn: return "Music Fade In"
        case .musicFadeOut: return "Music Fade Out"
        case .spotifyDuck: return "Spotify Duck"
        case .spotifyUnduck: return "Spotify Unduck"
        case .musicDuck: return "Music Duck"
        case .musicUnduck: return "Music Unduck"
        }
    }

    var playerApp: PlayerApp {
        switch self {
        case .spotifyFadeIn, .spotifyFadeOut, .spotifyDuck, .spotifyUnduck: return .spotify
        case .musicFadeIn, .musicFadeOut, .musicDuck, .musicUnduck: return .music
        }
    }

    var actionKind: ActionKind {
        switch self {
        case .spotifyFadeIn, .musicFadeIn: return .fadeIn
        case .spotifyFadeOut, .musicFadeOut: return .fadeOut
        case .spotifyDuck, .musicDuck: return .duck
        case .spotifyUnduck, .musicUnduck: return .unduck
        }
    }

    static let fadeActions: [MIDIAction] = [.spotifyFadeIn, .spotifyFadeOut, .musicFadeIn, .musicFadeOut]
    static let duckActions: [MIDIAction] = [.spotifyDuck, .spotifyUnduck, .musicDuck, .musicUnduck]
}

enum MIDIMessageKind: String, Codable, CaseIterable {
    case noteOn
    case controlChange
}

struct MIDIMapping: Codable, Equatable {
    var kind: MIDIMessageKind
    var note: UInt8
    var velocity: UInt8

    static let `default` = MIDIMapping(kind: .noteOn, note: 0, velocity: 1)

    var noteLabel: String {
        switch kind {
        case .noteOn:
            let names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
            let octave = Int(note) / 12 - 1
            let name = names[Int(note) % 12]
            return "\(name)\(octave)"
        case .controlChange:
            return "CC \(note)"
        }
    }
}

struct MIDISource: Identifiable, Hashable {
    let uniqueID: Int32
    let name: String

    var id: Int32 { uniqueID }
}
