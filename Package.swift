// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MidiMusicControl",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "MidiMusicControl",
            path: "Sources/MidiSpotifyControl",
            resources: [
                .process("Resources"),
            ],
            linkerSettings: [
                .linkedFramework("CoreMIDI"),
                .linkedFramework("Cocoa"),
                .linkedFramework("ServiceManagement"),
            ]
        ),
    ]
)
