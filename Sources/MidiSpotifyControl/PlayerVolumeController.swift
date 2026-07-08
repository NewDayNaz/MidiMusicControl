import Foundation

final class PlayerVolumeController {
    var onAutomationError: ((String?) -> Void)?

    private var duckState: [PlayerApp: DuckState] = [:]
    private let spotifyQueue = DispatchQueue(label: "com.midimusiccontrol.volume.spotify")
    private let musicQueue = DispatchQueue(label: "com.midimusiccontrol.volume.music")

    private enum DuckState {
        case ducking
        case ducked(restoreVolume: Int)
        case unducking
    }

    func fade(app: PlayerApp, action: FadeAction, fadeDuration: Double) {
        queue(for: app).async {
            self.duckState.removeValue(forKey: app)
            let script = AppleScriptFade.fadeScript(app: app, action: action, fadeDuration: fadeDuration)
            if let error = AppleScriptFade.executeSync(script) {
                self.reportError(error)
            } else {
                self.clearAutomationError()
            }
        }
    }

    func duck(app: PlayerApp, duckVolumePercent: Int, fadeDuration: Double) {
        queue(for: app).async {
            guard self.duckState[app] == nil else { return }
            self.duckState[app] = .ducking

            let script = AppleScriptFade.duckScript(
                app: app,
                targetVolume: duckVolumePercent,
                fadeDuration: fadeDuration
            )
            switch AppleScriptFade.executeSyncReturningInt(script) {
            case .success(let volume) where volume >= 0:
                self.duckState[app] = .ducked(restoreVolume: volume)
                self.clearAutomationError()
            case .success:
                self.duckState.removeValue(forKey: app)
            case .failure(let error):
                self.duckState.removeValue(forKey: app)
                self.reportError(error)
            }
        }
    }

    func unduck(app: PlayerApp, fadeDuration: Double) {
        queue(for: app).async {
            guard case .ducked(let restoreVolume) = self.duckState[app] else { return }
            self.duckState[app] = .unducking

            let script = AppleScriptFade.unduckScript(
                app: app,
                restoreVolume: restoreVolume,
                fadeDuration: fadeDuration
            )
            if let error = AppleScriptFade.executeSync(script) {
                self.duckState[app] = .ducked(restoreVolume: restoreVolume)
                self.reportError(error)
                return
            }
            self.duckState.removeValue(forKey: app)
            self.clearAutomationError()
        }
    }

    private func queue(for app: PlayerApp) -> DispatchQueue {
        app == .spotify ? spotifyQueue : musicQueue
    }

    private func reportError(_ message: String) {
        DispatchQueue.main.async {
            self.onAutomationError?(message)
        }
    }

    private func clearAutomationError() {
        DispatchQueue.main.async {
            self.onAutomationError?(nil)
        }
    }
}
