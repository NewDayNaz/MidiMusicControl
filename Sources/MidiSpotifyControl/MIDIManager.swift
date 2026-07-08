import Combine
import CoreMIDI
import Foundation

private enum ParsedMIDIMessage {
    case noteOn(note: UInt8, velocity: UInt8)
    case controlChange(controller: UInt8, value: UInt8)
}

final class MIDIManager: ObservableObject {
    @Published private(set) var sources: [MIDISource] = []
    @Published var learningAction: MIDIAction?
    @Published var lastLearnedMessage: String?

    var onActionTriggered: ((MIDIAction) -> Void)?

    private let settingsStore: SettingsStore
    private var client = MIDIClientRef()
    private var inputPort = MIDIPortRef()
    private var connectedSourceID: Int32?
    private var cancellables = Set<AnyCancellable>()

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
    }

    func start() {
        setupClient()
        refreshSources()
        reconnectSelectedSource()

        settingsStore.$selectedSourceUniqueID
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.reconnectSelectedSource()
            }
            .store(in: &cancellables)
    }

    func refreshSources() {
        var found: [MIDISource] = []
        let count = MIDIGetNumberOfSources()
        for index in 0..<count {
            let endpoint = MIDIGetSource(index)
            guard let name = endpointName(endpoint),
                  let uniqueID = endpointUniqueID(endpoint) else { continue }
            found.append(MIDISource(uniqueID: uniqueID, name: name))
        }
        sources = found

        if let selected = settingsStore.selectedSourceUniqueID,
           !found.contains(where: { $0.uniqueID == selected }),
           let first = found.first {
            settingsStore.selectedSourceUniqueID = first.uniqueID
        } else if settingsStore.selectedSourceUniqueID == nil, let first = found.first {
            settingsStore.selectedSourceUniqueID = first.uniqueID
        }
    }

    func beginLearning(for action: MIDIAction) {
        learningAction = action
        lastLearnedMessage = "Press a pad or key on your controller…"
    }

    func cancelLearning() {
        learningAction = nil
        lastLearnedMessage = nil
    }

    private func setupClient() {
        let status = MIDIClientCreateWithBlock("MidiMusicControl" as CFString, &client) { [weak self] _ in
            DispatchQueue.main.async {
                self?.refreshSources()
            }
        }
        guard status == noErr else {
            fputs("MIDIClientCreateWithBlock failed: \(status)\n", stderr)
            return
        }

        let portStatus = MIDIInputPortCreateWithBlock(client, "Input" as CFString, &inputPort) { [weak self] packetList, _ in
            let messages = Self.extractMessages(from: packetList)
            DispatchQueue.main.async {
                self?.handleMessages(messages)
            }
        }
        guard portStatus == noErr else {
            fputs("MIDIInputPortCreateWithBlock failed: \(portStatus)\n", stderr)
            return
        }
    }

    private func reconnectSelectedSource() {
        disconnectAllSources()

        guard let selectedID = settingsStore.selectedSourceUniqueID else { return }
        let count = MIDIGetNumberOfSources()
        for index in 0..<count {
            let endpoint = MIDIGetSource(index)
            guard let uniqueID = endpointUniqueID(endpoint), uniqueID == selectedID else { continue }
            let status = MIDIPortConnectSource(inputPort, endpoint, nil)
            if status == noErr {
                connectedSourceID = selectedID
            }
            return
        }
        connectedSourceID = nil
    }

    private func disconnectAllSources() {
        let count = MIDIGetNumberOfSources()
        for index in 0..<count {
            let endpoint = MIDIGetSource(index)
            MIDIPortDisconnectSource(inputPort, endpoint)
        }
        connectedSourceID = nil
    }

    private func handleMessages(_ messages: [ParsedMIDIMessage]) {
        for message in messages {
            switch message {
            case let .noteOn(note, velocity):
                handleNoteOn(note: note, velocity: velocity)
            case let .controlChange(controller, value):
                handleControlChange(controller: controller, value: value)
            }
        }
    }

    private static func extractMessages(from packetList: UnsafePointer<MIDIPacketList>) -> [ParsedMIDIMessage] {
        var messages: [ParsedMIDIMessage] = []
        var packet = packetList.pointee.packet
        for _ in 0..<packetList.pointee.numPackets {
            let length = Int(packet.length)
            let bytes = withUnsafePointer(to: &packet.data) {
                $0.withMemoryRebound(to: UInt8.self, capacity: length) {
                    Array(UnsafeBufferPointer(start: $0, count: length))
                }
            }
            messages.append(contentsOf: parseMIDIMessage(bytes))
            packet = MIDIPacketNext(&packet).pointee
        }
        return messages
    }

    private static func parseMIDIMessage(_ bytes: [UInt8]) -> [ParsedMIDIMessage] {
        var messages: [ParsedMIDIMessage] = []
        var index = 0
        while index < bytes.count {
            let status = bytes[index]
            let messageType = status & 0xF0

            switch messageType {
            case 0x90:
                guard index + 2 < bytes.count else { return messages }
                let note = bytes[index + 1]
                let velocity = bytes[index + 2]
                if velocity > 0 {
                    messages.append(.noteOn(note: note, velocity: velocity))
                }
                index += 3
            case 0x80:
                index += 3
            case 0xB0:
                guard index + 2 < bytes.count else { return messages }
                let controller = bytes[index + 1]
                let value = bytes[index + 2]
                messages.append(.controlChange(controller: controller, value: value))
                index += 3
            default:
                index += 1
            }
        }
        return messages
    }

    private func handleNoteOn(note: UInt8, velocity: UInt8) {
        if let learningAction {
            let mapping = MIDIMapping(kind: .noteOn, note: note, velocity: velocity)
            settingsStore.setMapping(mapping, for: learningAction)
            lastLearnedMessage = "Learned \(mapping.noteLabel), value \(velocity)"
            self.learningAction = nil
            return
        }

        for action in MIDIAction.allCases {
            let mapping = settingsStore.mapping(for: action)
            guard mapping.kind == .noteOn else { continue }
            if mapping.note == note && mapping.velocity == velocity {
                onActionTriggered?(action)
            }
        }
    }

    private func handleControlChange(controller: UInt8, value: UInt8) {
        if let learningAction {
            let mapping = MIDIMapping(kind: .controlChange, note: controller, velocity: value)
            settingsStore.setMapping(mapping, for: learningAction)
            lastLearnedMessage = "Learned CC \(controller), value \(value)"
            self.learningAction = nil
            return
        }

        for action in MIDIAction.allCases {
            let mapping = settingsStore.mapping(for: action)
            guard mapping.kind == .controlChange else { continue }
            if mapping.note == controller && mapping.velocity == value {
                onActionTriggered?(action)
            }
        }
    }

    private func endpointName(_ endpoint: MIDIEndpointRef) -> String? {
        var param: Unmanaged<CFString>?
        let status = MIDIObjectGetStringProperty(endpoint, kMIDIPropertyName, &param)
        guard status == noErr, let param else { return nil }
        return param.takeRetainedValue() as String
    }

    private func endpointUniqueID(_ endpoint: MIDIEndpointRef) -> Int32? {
        var uniqueID: Int32 = 0
        let status = MIDIObjectGetIntegerProperty(endpoint, kMIDIPropertyUniqueID, &uniqueID)
        guard status == noErr else { return nil }
        return uniqueID
    }
}
