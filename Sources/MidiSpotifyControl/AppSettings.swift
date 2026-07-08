import Combine
import Foundation

final class SettingsStore: ObservableObject {
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
        didSet { save() }
    }

    @Published var duckVolumePercent: Int {
        didSet { save() }
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

    @Published private(set) var mappings: [MIDIAction: MIDIMapping]

    private let defaults: UserDefaults
    private var isSyncingLaunchAtLogin = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if let storedDuration = defaults.object(forKey: Keys.fadeDuration) as? Double {
            fadeDuration = storedDuration
        } else if let legacyStepDelay = defaults.object(forKey: Keys.fadeStepDelay) as? Double {
            // Previous setting was per-step delay for a 0→100 fade (~101 steps).
            fadeDuration = legacyStepDelay * 101
        } else {
            fadeDuration = AppleScriptFade.defaultFadeDuration
        }

        let storedDuckVolume: Int
        if defaults.object(forKey: Keys.duckVolumePercent) != nil {
            storedDuckVolume = defaults.integer(forKey: Keys.duckVolumePercent)
        } else {
            storedDuckVolume = 30
        }
        duckVolumePercent = min(100, max(1, storedDuckVolume))

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

    func setMapping(_ mapping: MIDIMapping, for action: MIDIAction) {
        var updated = mappings
        updated[action] = mapping
        mappings = updated
        save()
    }

    private func save() {
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
