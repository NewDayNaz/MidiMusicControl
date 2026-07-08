import Cocoa
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?

    let settingsStore = SettingsStore()
    private let volumeController = PlayerVolumeController()
    private(set) lazy var midiManager = MIDIManager(settingsStore: settingsStore)

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()
        wireMIDIActions()
        midiManager.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        midiManager.stop()
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
        for name in ["MenuBarIcon@2x", "MenuBarIcon"] {
            for url in menuBarIconCandidateURLs(named: name) {
                guard let data = try? Data(contentsOf: url),
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

    private static func menuBarIconCandidateURLs(named name: String) -> [URL] {
        let executableURL = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
        let executableDirectory = executableURL.deletingLastPathComponent()

        return [
            Bundle.main.resourceURL?.appendingPathComponent(name).appendingPathExtension("png"),
            executableDirectory.appendingPathComponent("Resources").appendingPathComponent(name).appendingPathExtension("png"),
            executableDirectory.appendingPathComponent("MidiMusicControl_MidiMusicControl.bundle").appendingPathComponent(name).appendingPathExtension("png"),
        ].compactMap { $0 }
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
        volumeController.onAutomationError = { [weak self] message in
            self?.settingsStore.automationError = message
        }

        midiManager.onActionTriggered = { [weak self] action in
            guard let self else { return }
            let settings = self.settingsStore

            switch action.actionKind {
            case .fadeIn:
                self.volumeController.fade(
                    app: action.playerApp,
                    action: .fadeIn,
                    fadeDuration: settings.fadeDuration
                )
            case .fadeOut:
                self.volumeController.fade(
                    app: action.playerApp,
                    action: .fadeOut,
                    fadeDuration: settings.fadeDuration
                )
            case .duck:
                self.volumeController.duck(
                    app: action.playerApp,
                    duckVolumePercent: settings.duckVolumePercent,
                    fadeDuration: settings.fadeDuration
                )
            case .unduck:
                self.volumeController.unduck(
                    app: action.playerApp,
                    fadeDuration: settings.fadeDuration
                )
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
        let hostingController = NSHostingController(rootView: view)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 920, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "MIDI Music Control"
        window.contentViewController = hostingController
        window.toolbarStyle = .unifiedCompact
        window.titlebarAppearsTransparent = true
        window.setContentSize(NSSize(width: 920, height: 760))
        window.minSize = NSSize(width: 860, height: 700)
        window.setFrameAutosaveName("MidiMusicControlSettings")
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
