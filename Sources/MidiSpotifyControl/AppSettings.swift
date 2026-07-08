import Combine
import Foundation

final class SettingsStore: ObservableObject {
    static let fadeDurationRange = 0.5...15.0
    static let duckVolumeRange = 1...100

    private enum Keys {
        static let fadeDuration = "fadeDuration"
        static let fadeStepDelay = "fadeStepDelay"
        static let duckVolumePercent = "duckVolumePercent"
        static let selectedSourceUniqueID = "selectedSourceUniqueID"
        static let mappings = "mappings"
    }

    static let defaultMappings: [MIDIAction: MIDIMapping] = [
        .spotifyFadeIn: MIDIMapping(kind: .noteOn, note: 60, velocity: 127),
        .spotifyFadeOut: MIDIMapping(kind: .noteOn, note: 61, velocity: 127),
        .musicFadeIn: MIDIMapping(kind: .noteOn, note: 62, velocity: 127),
        .musicFadeOut: MIDIMapping(kind: .noteOn, note: 63, velocity: 127),
        .spotifyDuck: MIDIMapping(kind: .noteOn, note: 64, velocity: 127),
        .spotifyUnduck: MIDIMapping(kind: .noteOn, note: 65, velocity: 127),
        .musicDuck: MIDIMapping(kind: .noteOn, note: 66, velocity: 127),
        .musicUnduck: MIDIMapping(kind: .noteOn, note: 67, velocity: 127),
    ]

    @Published var fadeDuration: Double {
        didSet {
            let clamped = min(Self.fadeDurationRange.upperBound, max(Self.fadeDurationRange.lowerBound, fadeDuration))
            if clamped != fadeDuration {
                fadeDuration = clamped
                return
            }
            save()
        }
    }

    @Published var duckVolumePercent: Int {
        didSet {
            let clamped = min(Self.duckVolumeRange.upperBound, max(Self.duckVolumeRange.lowerBound, duckVolumePercent))
            if clamped != duckVolumePercent {
                duckVolumePercent = clamped
                return
            }
            save()
        }
    }

    @Published var selectedSourceUniqueID: Int32? {
        didSet { save() }
    }

    @Published var launchAtLogin: Bool {
        didSet {
            guard !isSyncingLaunchAtLogin else { return }
            updateLaunchAtLogin(enabled: launchAtLogin)
        }
    }

    @Published private(set) var launchAtLoginError: String?
    @Published var automationError: String?
    @Published var mappingConflictWarning: String?

    @Published private(set) var mappings: [MIDIAction: MIDIMapping]

    private let defaults: UserDefaults
    private var isSyncingLaunchAtLogin = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if let storedDuration = defaults.object(forKey: Keys.fadeDuration) as? Double {
            fadeDuration = storedDuration
        } else if let legacyStepDelay = defaults.object(forKey: Keys.fadeStepDelay) as? Double {
            fadeDuration = legacyStepDelay * 101
        } else {
            fadeDuration = AppleScriptFade.defaultFadeDuration
        }
        fadeDuration = min(Self.fadeDurationRange.upperBound, max(Self.fadeDurationRange.lowerBound, fadeDuration))

        let storedDuckVolume: Int
        if defaults.object(forKey: Keys.duckVolumePercent) != nil {
            storedDuckVolume = defaults.integer(forKey: Keys.duckVolumePercent)
        } else {
            storedDuckVolume = 30
        }
        duckVolumePercent = min(Self.duckVolumeRange.upperBound, max(Self.duckVolumeRange.lowerBound, storedDuckVolume))

        if defaults.object(forKey: Keys.selectedSourceUniqueID) != nil {
            selectedSourceUniqueID = Int32(defaults.integer(forKey: Keys.selectedSourceUniqueID))
        } else {
            selectedSourceUniqueID = nil
        }

        if let data = defaults.data(forKey: Keys.mappings),
           let decoded = try? JSONDecoder().decode([String: MIDIMapping].self, from: data) {
            mappings = Dictionary(
                uniqueKeysWithValues: decoded.compactMap { key, value in
                    MIDIAction(rawValue: key).map { ($0, value) }
                }
            )
        } else {
            mappings = Self.defaultMappings
        }

        launchAtLogin = LaunchAtLogin.isEnabled
        launchAtLoginError = nil
    }

    func refreshLaunchAtLogin() {
        isSyncingLaunchAtLogin = true
        launchAtLogin = LaunchAtLogin.isEnabled
        launchAtLoginError = LaunchAtLogin.statusMessage
        isSyncingLaunchAtLogin = false
    }

    private func updateLaunchAtLogin(enabled: Bool) {
        guard LaunchAtLogin.isSupported else {
            launchAtLoginError = "Launch at login requires installing the app as a macOS application."
            isSyncingLaunchAtLogin = true
            launchAtLogin = false
            isSyncingLaunchAtLogin = false
            return
        }

        do {
            try LaunchAtLogin.setEnabled(enabled)
            launchAtLoginError = LaunchAtLogin.statusMessage
        } catch {
            launchAtLoginError = error.localizedDescription
            isSyncingLaunchAtLogin = true
            launchAtLogin = LaunchAtLogin.isEnabled
            isSyncingLaunchAtLogin = false
        }
    }

    func mapping(for action: MIDIAction) -> MIDIMapping {
        mappings[action] ?? Self.defaultMappings[action] ?? .default
    }

    @discardableResult
    func setMapping(_ mapping: MIDIMapping, for action: MIDIAction) -> Bool {
        if let conflict = conflictingAction(for: mapping, excluding: action) {
            mappingConflictWarning = "That message is already assigned to \"\(conflict.label)\"."
            return false
        }

        mappingConflictWarning = nil
        var updated = mappings
        updated[action] = mapping
        mappings = updated
        save()
        return true
    }

    func conflictingAction(for mapping: MIDIMapping, excluding action: MIDIAction) -> MIDIAction? {
        for existingAction in MIDIAction.allCases where existingAction != action {
            if mapping(for: existingAction) == mapping {
                return existingAction
            }
        }
        return nil
    }

    private func save() {
        defaults.removeObject(forKey: Keys.fadeStepDelay)

        let encoded = Dictionary(uniqueKeysWithValues: mappings.map { ($0.key.rawValue, $0.value) })
        if let data = try? JSONEncoder().encode(encoded) {
            defaults.set(data, forKey: Keys.mappings)
        }
        defaults.set(fadeDuration, forKey: Keys.fadeDuration)
        defaults.set(duckVolumePercent, forKey: Keys.duckVolumePercent)
        if let selectedSourceUniqueID {
            defaults.set(Int(selectedSourceUniqueID), forKey: Keys.selectedSourceUniqueID)
        } else {
            defaults.removeObject(forKey: Keys.selectedSourceUniqueID)
        }
    }
}
