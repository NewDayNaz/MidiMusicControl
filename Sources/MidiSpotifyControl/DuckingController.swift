import Foundation

final class DuckingController {
    private var preDuckVolume: [PlayerApp: Int] = [:]

    func duck(app: PlayerApp, duckVolumePercent: Int, fadeDuration: Double) {
        guard preDuckVolume[app] == nil else { return }

        if let volumeBeforeDuck = AppleScriptFade.duck(
            app: app,
            targetVolume: duckVolumePercent,
            fadeDuration: fadeDuration
        ) {
            preDuckVolume[app] = volumeBeforeDuck
        }
    }

    func unduck(app: PlayerApp, fadeDuration: Double) {
        guard let restoreVolume = preDuckVolume[app] else { return }

        AppleScriptFade.unduck(app: app, restoreVolume: restoreVolume, fadeDuration: fadeDuration)
        preDuckVolume.removeValue(forKey: app)
    }

    func isDucked(app: PlayerApp) -> Bool {
        preDuckVolume[app] != nil
    }
}
