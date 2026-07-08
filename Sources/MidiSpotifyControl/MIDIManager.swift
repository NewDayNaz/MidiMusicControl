import Combine
import CoreMIDI
import Foundation

final class MIDIManager: ObservableObject {
    @Published private(set) var sources: [MIDISource] = []
    @Published private(set) var setupError: String?
    @Published private(set) var connectionStatus: String?
    @Published var learningAction: MIDIAction?
    @Published var lastLearnedMessage: String?
    @Published private(set) var lastReceivedMessage: String?

    var onActionTriggered: ((MIDIAction) -> Void)?

    private let settingsStore: SettingsStore
    private var client = MIDIClientRef()
    private var inputPort = MIDIPortRef()
    private var connectedSourceID: Int32?
    private var cancellables = Set<AnyCancellable>()
    private var isStarted = false

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
    }

    func start() {
        guard !isStarted else { return }
        isStarted = true
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

    func stop() {
        guard isStarted else { return }
        disconnectAllSources()
        if inputPort != 0 {
            MIDIPortDispose(inputPort)
            inputPort = 0
        }
        if client != 0 {
            MIDIClientDispose(client)
            client = 0
        }
        isStarted = false
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

        if settingsStore.selectedSourceUniqueID == nil, let first = found.first {
            settingsStore.selectedSourceUniqueID = first.uniqueID
        }

        updateConnectionStatus()
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
            setupError = "Could not initialize Core MIDI (error \(status))."
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
            setupError = "Could not open MIDI input port (error \(portStatus))."
            fputs("MIDIInputPortCreateWithBlock failed: \(portStatus)\n", stderr)
            return
        }
    }

    private func reconnectSelectedSource() {
        disconnectAllSources()

        guard let selectedID = settingsStore.selectedSourceUniqueID else {
            updateConnectionStatus()
            return
        }

        let count = MIDIGetNumberOfSources()
        for index in 0..<count {
            let endpoint = MIDIGetSource(index)
            guard let uniqueID = endpointUniqueID(endpoint), uniqueID == selectedID else { continue }
            let status = MIDIPortConnectSource(inputPort, endpoint, nil)
            if status == noErr {
                connectedSourceID = selectedID
            }
            updateConnectionStatus()
            return
        }
        connectedSourceID = nil
        updateConnectionStatus()
    }

    private func disconnectAllSources() {
        let count = MIDIGetNumberOfSources()
        for index in 0..<count {
            let endpoint = MIDIGetSource(index)
            MIDIPortDisconnectSource(inputPort, endpoint)
        }
        connectedSourceID = nil
    }

    private func updateConnectionStatus() {
        guard setupError == nil else {
            connectionStatus = nil
            return
        }

        guard let selectedID = settingsStore.selectedSourceUniqueID else {
            connectionStatus = sources.isEmpty ? "No MIDI devices found." : "No MIDI input selected."
            return
        }

        if connectedSourceID == selectedID,
           let source = sources.first(where: { $0.uniqueID == selectedID }) {
            connectionStatus = "Connected to \(source.name)."
            return
        }

        if let source = sources.first(where: { $0.uniqueID == selectedID }) {
            connectionStatus = "\(source.name) is unavailable. Refresh devices or choose another input."
        } else {
            connectionStatus = "Selected MIDI device is unavailable. Refresh devices or choose another input."
        }
    }

    private func handleMessages(_ messages: [MIDIParsedMessage]) {
        for message in messages {
            switch message {
            case let .noteOn(note, velocity):
                handleNoteOn(note: note, velocity: velocity)
            case let .controlChange(controller, value):
                handleControlChange(controller: controller, value: value)
            }
        }
    }

    private static func extractMessages(from packetList: UnsafePointer<MIDIPacketList>) -> [MIDIParsedMessage] {
        var messages: [MIDIParsedMessage] = []
        var packet = packetList.pointee.packet
        for _ in 0..<packetList.pointee.numPackets {
            let length = Int(packet.length)
            let bytes = withUnsafePointer(to: &packet.data) {
                $0.withMemoryRebound(to: UInt8.self, capacity: length) {
                    Array(UnsafeBufferPointer(start: $0, count: length))
                }
            }
            messages.append(contentsOf: MIDIParser.parse(bytes))
            packet = MIDIPacketNext(&packet).pointee
        }
        return messages
    }

    private func handleNoteOn(note: UInt8, velocity: UInt8) {
        lastReceivedMessage = "Note \(note) (\(MIDIMapping(kind: .noteOn, note: note, velocity: velocity).noteLabel)), value \(velocity)"
        if let learningAction {
            let mapping = MIDIMapping(kind: .noteOn, note: note, velocity: velocity)
            if settingsStore.setMapping(mapping, for: learningAction) {
                lastLearnedMessage = "Learned \(mapping.noteLabel), value \(velocity)"
                self.learningAction = nil
            } else {
                lastLearnedMessage = settingsStore.mappingConflictWarning
            }
            return
        }

        triggerFirstMatchingAction { mapping in
            mapping.kind == .noteOn && mapping.note == note && mapping.velocity == velocity
        }
    }

    private func handleControlChange(controller: UInt8, value: UInt8) {
        lastReceivedMessage = "CC \(controller), value \(value)"
        if let learningAction {
            let mapping = MIDIMapping(kind: .controlChange, note: controller, velocity: value)
            if settingsStore.setMapping(mapping, for: learningAction) {
                lastLearnedMessage = "Learned CC \(controller), value \(value)"
                self.learningAction = nil
            } else {
                lastLearnedMessage = settingsStore.mappingConflictWarning
            }
            return
        }

        triggerFirstMatchingAction { mapping in
            mapping.kind == .controlChange && mapping.note == controller && mapping.velocity == value
        }
    }

    private func triggerFirstMatchingAction(where matches: (MIDIMapping) -> Bool) {
        for action in MIDIAction.allCases {
            let mapping = settingsStore.mapping(for: action)
            if matches(mapping) {
                onActionTriggered?(action)
                return
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
