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

    static func fadeScript(app: PlayerApp, action: FadeAction, fadeDuration: Double) -> String {
        let duration = String(fadeDuration)
        let appName = app.rawValue
        let volumeVar = volumeVar(for: app)

        switch action {
        case .fadeIn:
            return """
            tell application "\(appName)"
                if player state is paused then
                    set targetVol to the sound volume
                    if targetVol < 1 then set targetVol to 100
                    set the sound volume to 0
                    play
                    set stepCount to (targetVol + 1)
                    if stepCount < 1 then set stepCount to 1
                    set stepDelay to \(duration) / stepCount
                    repeat with i from 0 to targetVol by 1
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

    static func duckScript(app: PlayerApp, targetVolume: Int, fadeDuration: Double) -> String {
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
            else
                return -1
            end if
        end tell
        """
    }

    static func unduckScript(app: PlayerApp, restoreVolume: Int, fadeDuration: Double) -> String {
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

    /// Returns an error message on failure, or nil on success.
    @discardableResult
    static func executeSync(_ source: String) -> String? {
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else {
            let message = "Failed to create AppleScript."
            fputs("\(message)\n", stderr)
            return message
        }
        _ = script.executeAndReturnError(&error)
        if let error {
            let message = formatAppleScriptError(error)
            fputs("AppleScript error: \(message)\n", stderr)
            return message
        }
        return nil
    }

    static func executeSyncReturningInt(_ source: String) -> Result<Int, String> {
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else {
            return .failure("Failed to create AppleScript.")
        }
        let result = script.executeAndReturnError(&error)
        if let error {
            return .failure(formatAppleScriptError(error))
        }
        return .success(Int(result.int32Value))
    }

    private static func volumeVar(for app: PlayerApp) -> String {
        app == .spotify ? "volumespotify" : "snd"
    }

    private static func formatAppleScriptError(_ error: NSDictionary) -> String {
        let message = error[NSAppleScript.errorMessage] as? String ?? "Unknown AppleScript error."
        let number = error[NSAppleScript.errorNumber] as? Int ?? 0
        if number == -1743 {
            return "\(message) Allow automation for Spotify and Music in System Settings → Privacy & Security → Automation."
        }
        return message
    }
}
