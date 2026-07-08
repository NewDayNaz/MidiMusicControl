import Foundation

enum PlayerApp: String {
    case spotify = "Spotify"
    case music = "Music"
}

enum FadeAction {
    case fadeIn
    case fadeOut
}

enum AppleScriptFade {
    /// Total time for a full fade, in seconds.
    static let defaultFadeDuration = 3.0

    static func run(app: PlayerApp, action: FadeAction, fadeDuration: Double = defaultFadeDuration) {
        let script = fadeScript(app: app, action: action, fadeDuration: fadeDuration)
        DispatchQueue.global(qos: .userInitiated).async {
            _ = execute(script)
        }
    }

    /// Fades down to `targetVolume` while playing. Returns the pre-duck volume, if any.
    static func duck(app: PlayerApp, targetVolume: Int, fadeDuration: Double) -> Int? {
        let script = duckScript(app: app, targetVolume: targetVolume, fadeDuration: fadeDuration)
        return executeReturningInt(script)
    }

    static func unduck(app: PlayerApp, restoreVolume: Int, fadeDuration: Double) {
        let script = unduckScript(app: app, restoreVolume: restoreVolume, fadeDuration: fadeDuration)
        DispatchQueue.global(qos: .userInitiated).async {
            _ = execute(script)
        }
    }

    private static func volumeVar(for app: PlayerApp) -> String {
        app == .spotify ? "volumespotify" : "snd"
    }

    private static func fadeScript(app: PlayerApp, action: FadeAction, fadeDuration: Double) -> String {
        let duration = String(fadeDuration)
        let appName = app.rawValue
        let volumeVar = volumeVar(for: app)

        switch action {
        case .fadeIn:
            return """
            tell application "\(appName)"
                if player state is paused then
                    set \(volumeVar) to the sound volume
                    set \(volumeVar) to 0
                    play
                    set stepCount to (100 - \(volumeVar) + 1)
                    if stepCount < 1 then set stepCount to 1
                    set stepDelay to \(duration) / stepCount
                    repeat with i from \(volumeVar) to 100 by 1
                        set the sound volume to i
                        delay stepDelay
                    end repeat
                end if
            end tell
            """
        case .fadeOut:
            return """
            tell application "\(appName)"
                if player state is not paused then
                    set \(volumeVar) to the sound volume
                    set stepCount to (\(volumeVar) + 1)
                    if stepCount < 1 then set stepCount to 1
                    set stepDelay to \(duration) / stepCount
                    repeat with i from \(volumeVar) to 0 by -1
                        set the sound volume to i
                        delay stepDelay
                    end repeat
                    pause
                end if
            end tell
            """
        }
    }

    private static func duckScript(app: PlayerApp, targetVolume: Int, fadeDuration: Double) -> String {
        let appName = app.rawValue
        let volumeVar = volumeVar(for: app)
        return """
        tell application "\(appName)"
            if player state is not paused then
                set \(volumeVar) to the sound volume
                set targetVol to \(targetVolume)
                if \(volumeVar) > targetVol then
                    set stepCount to (\(volumeVar) - targetVol + 1)
                    if stepCount < 1 then set stepCount to 1
                    set stepDelay to \(fadeDuration) / stepCount
                    repeat with i from \(volumeVar) to targetVol by -1
                        set the sound volume to i
                        delay stepDelay
                    end repeat
                end if
                return \(volumeVar)
            end if
        end tell
        """
    }

    private static func unduckScript(app: PlayerApp, restoreVolume: Int, fadeDuration: Double) -> String {
        let appName = app.rawValue
        let volumeVar = volumeVar(for: app)
        return """
        tell application "\(appName)"
            if player state is not paused then
                set \(volumeVar) to the sound volume
                set targetVol to \(restoreVolume)
                if \(volumeVar) < targetVol then
                    set stepCount to (targetVol - \(volumeVar) + 1)
                    if stepCount < 1 then set stepCount to 1
                    set stepDelay to \(fadeDuration) / stepCount
                    repeat with i from \(volumeVar) to targetVol by 1
                        set the sound volume to i
                        delay stepDelay
                    end repeat
                end if
            end if
        end tell
        """
    }

    @discardableResult
    private static func execute(_ source: String) -> NSAppleEventDescriptor? {
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else {
            fputs("Failed to create AppleScript.\n", stderr)
            return nil
        }
        let result = script.executeAndReturnError(&error)
        if let error {
            fputs("AppleScript error: \(error)\n", stderr)
            return nil
        }
        return result
    }

    private static func executeReturningInt(_ source: String) -> Int? {
        guard let result = execute(source) else { return nil }
        return Int(result.int32Value)
    }
}
