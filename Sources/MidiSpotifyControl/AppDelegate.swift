import Cocoa
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?

    let settingsStore = SettingsStore()
    private let duckingController = DuckingController()
    private(set) lazy var midiManager = MIDIManager(settingsStore: settingsStore)

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()
        wireMIDIActions()
        midiManager.start()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let image = Self.loadMenuBarIcon() {
            statusItem?.button?.image = image
        } else {
            statusItem?.button?.image = NSImage(
                systemSymbolName: "music.note.list",
                accessibilityDescription: "MIDI Music Control"
            )
        }
        statusItem?.menu = buildMenu()
    }

    private static func loadMenuBarIcon() -> NSImage? {
        for bundle in [Bundle.main, Bundle.module] {
            for name in ["MenuBarIcon@2x", "MenuBarIcon"] {
                guard let url = bundle.url(forResource: name, withExtension: "png"),
                      let data = try? Data(contentsOf: url),
                      let rep = NSBitmapImageRep(data: data) else { continue }

                let image = NSImage(size: NSSize(width: 18, height: 18))
                rep.size = NSSize(width: 18, height: 18)
                image.addRepresentation(rep)
                image.isTemplate = true
                return image
            }
        }
        return nil
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    private func wireMIDIActions() {
        midiManager.onActionTriggered = { [weak self] action in
            guard let self else { return }
            let settings = self.settingsStore

            switch action.actionKind {
            case .fadeIn:
                AppleScriptFade.run(
                    app: action.playerApp,
                    action: .fadeIn,
                    fadeDuration: settings.fadeDuration
                )
            case .fadeOut:
                AppleScriptFade.run(
                    app: action.playerApp,
                    action: .fadeOut,
                    fadeDuration: settings.fadeDuration
                )
            case .duck:
                DispatchQueue.global(qos: .userInitiated).async {
                    self.duckingController.duck(
                        app: action.playerApp,
                        duckVolumePercent: settings.duckVolumePercent,
                        fadeDuration: settings.fadeDuration
                    )
                }
            case .unduck:
                DispatchQueue.global(qos: .userInitiated).async {
                    self.duckingController.unduck(
                        app: action.playerApp,
                        fadeDuration: settings.fadeDuration
                    )
                }
            }
        }
    }

    @objc private func openSettings() {
        if let settingsWindow {
            settingsWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = SettingsView(settingsStore: settingsStore, midiManager: midiManager)
        let hostingView = NSHostingView(rootView: view)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 720),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "MIDI Music Control"
        window.contentView = hostingView
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        settingsWindow = window
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
