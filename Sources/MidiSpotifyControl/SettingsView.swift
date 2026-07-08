import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case general = "General"
        case mappings = "Mappings"

        var id: String { rawValue }
    }

    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var midiManager: MIDIManager

    @State private var selectedTab: Tab = .general
    @State private var transferMessage: TransferMessage?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            if let action = midiManager.learningAction {
                learnBanner(for: action)
            }

            if let warning = settingsStore.mappingConflictWarning {
                InlineMessageCard(
                    title: "Mapping conflict",
                    message: warning,
                    tone: .warning
                )
            } else if let transferMessage {
                InlineMessageCard(
                    title: transferMessage.title,
                    message: transferMessage.message,
                    tone: transferMessage.tone
                )
            }

            Picker("Section", selection: $selectedTab) {
                ForEach(Tab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)

            Group {
                switch selectedTab {
                case .general:
                    generalTab
                case .mappings:
                    mappingsTab
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(20)
        .frame(minWidth: 860, minHeight: 700)
        .onAppear {
            settingsStore.refreshLaunchAtLogin()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("MIDI Music Control")
                        .font(.system(size: 24, weight: .semibold))
                    Text("Live MIDI control for Spotify and Apple Music.")
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if selectedTab == .mappings {
                    HStack(spacing: 8) {
                        Button("Import") {
                            importMappings()
                        }
                        Button("Export") {
                            exportMappings()
                        }
                        Button("Reset Defaults") {
                            settingsStore.resetMappingsToDefaults()
                            transferMessage = TransferMessage(
                                title: "Mappings reset",
                                message: "All mappings were restored to their default values.",
                                tone: .success
                            )
                        }
                    }
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                StatusCard(
                    title: "MIDI Device",
                    value: selectedSourceName,
                    detail: midiManager.connectionStatus ?? "Choose an input to start listening.",
                    tone: midiDeviceTone
                )
                StatusCard(
                    title: "Learn Mode",
                    value: midiManager.learningAction?.shortLabel ?? "Idle",
                    detail: midiManager.learningAction == nil ? "No action is currently listening." : "Send the next MIDI message to capture it.",
                    tone: midiManager.learningAction == nil ? .neutral : .accent
                )
                StatusCard(
                    title: "Automation",
                    value: settingsStore.automationError == nil ? "Ready" : "Needs Attention",
                    detail: settingsStore.automationError ?? "Spotify and Music commands will prompt for permission the first time they run.",
                    tone: settingsStore.automationError == nil ? .success : .warning
                )
                StatusCard(
                    title: "Input Activity",
                    value: midiManager.lastReceivedMessage ?? "Waiting",
                    detail: "Last MIDI message received from the selected input.",
                    tone: midiManager.lastReceivedMessage == nil ? .neutral : .accent
                )
            }
        }
    }

    private func learnBanner(for action: MIDIAction) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "waveform.badge.magnifyingglass")
                .font(.title3)
                .foregroundStyle(.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text("Listening for \(action.label)")
                    .font(.headline)
                Text(midiManager.lastLearnedMessage ?? "Press a pad, key, or knob on your controller to capture the next MIDI message.")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Cancel") {
                midiManager.cancelLearning()
            }
            .keyboardShortcut(.cancelAction)
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.accentColor.opacity(0.35), lineWidth: 1)
        }
    }

    private var generalTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                settingsCard(title: "Startup") {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Open at login", isOn: $settingsStore.launchAtLogin)
                            .disabled(!LaunchAtLogin.isSupported)

                        if !LaunchAtLogin.isSupported {
                            supportingText("Available when the app is packaged as a macOS application (.app).")
                        } else if let message = settingsStore.launchAtLoginError {
                            supportingText(message)
                        }
                    }
                }

                settingsCard(title: "MIDI Input") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .center, spacing: 12) {
                            Picker("Input Device", selection: selectedSourceBinding) {
                                if midiManager.sources.isEmpty {
                                    Text("No devices found").tag(Optional<Int32>.none)
                                }
                                ForEach(midiManager.sources) { source in
                                    Text(source.name).tag(Optional(source.uniqueID))
                                }
                            }
                            .pickerStyle(.menu)

                            Button("Refresh Devices") {
                                midiManager.refreshSources()
                            }
                        }

                        if let setupError = midiManager.setupError {
                            InlineMessageCard(
                                title: "MIDI setup issue",
                                message: setupError,
                                tone: .warning
                            )
                        } else if let connectionStatus = midiManager.connectionStatus {
                            supportingText(connectionStatus)
                        }

                        supportingText("Choose the hardware controller this app should listen to. If your device is disconnected, reconnect it and refresh.")
                    }
                }

                settingsCard(title: "Playback Controls") {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Fade duration")
                                Spacer()
                                valuePill(String(format: "%.1fs", settingsStore.fadeDuration))
                            }

                            Slider(value: $settingsStore.fadeDuration, in: SettingsStore.fadeDurationRange, step: 0.25)
                            supportingText("Total time to complete a fade in or out, regardless of the current volume.")
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Duck volume")
                                Spacer()
                                valuePill("\(settingsStore.duckVolumePercent)%")
                            }

                            Slider(value: duckVolumeBinding, in: 1...100, step: 1)
                            supportingText("Volume level to fade down to while ducked. Unduck restores the volume from before ducking.")
                        }
                    }
                }

                settingsCard(title: "Automation Permissions") {
                    VStack(alignment: .leading, spacing: 10) {
                        if let automationError = settingsStore.automationError {
                            InlineMessageCard(
                                title: "Automation needs attention",
                                message: automationError,
                                tone: .warning
                            )
                        } else {
                            supportingText("The first fade or duck command may prompt macOS to allow control of Spotify or Music. If controls stop working later, check System Settings > Privacy & Security > Automation.")
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var mappingsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                settingsCard(title: "Mapping Guide") {
                    VStack(alignment: .leading, spacing: 8) {
                        supportingText("Each action matches an exact MIDI message and value. Use Learn to capture the next message from the selected input, or edit the numbers directly.")
                        if let message = midiManager.lastLearnedMessage {
                            supportingText(message)
                        }
                    }
                }

                MappingGroupCard(
                    app: .spotify,
                    actions: MIDIAction.allCases.filter { $0.playerApp == .spotify },
                    settingsStore: settingsStore,
                    midiManager: midiManager
                )

                MappingGroupCard(
                    app: .music,
                    actions: MIDIAction.allCases.filter { $0.playerApp == .music },
                    settingsStore: settingsStore,
                    midiManager: midiManager
                )
            }
            .padding(.vertical, 4)
        }
    }

    private func settingsCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func valuePill(_ value: String) -> some View {
        Text(value)
            .font(.callout.monospacedDigit())
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.12), in: Capsule())
    }

    private func supportingText(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var selectedSourceName: String {
        if let selectedID = settingsStore.selectedSourceUniqueID,
           let source = midiManager.sources.first(where: { $0.uniqueID == selectedID }) {
            return source.name
        }
        return midiManager.sources.isEmpty ? "No Device" : "Not Selected"
    }

    private var midiDeviceTone: MessageTone {
        if midiManager.setupError != nil {
            return .warning
        }
        if let selectedID = settingsStore.selectedSourceUniqueID,
           midiManager.sources.contains(where: { $0.uniqueID == selectedID }) {
            return .success
        }
        return .neutral
    }

    private var duckVolumeBinding: Binding<Double> {
        Binding(
            get: { Double(settingsStore.duckVolumePercent) },
            set: { settingsStore.duckVolumePercent = Int($0.rounded()) }
        )
    }

    private var selectedSourceBinding: Binding<Int32?> {
        Binding(
            get: { settingsStore.selectedSourceUniqueID },
            set: { settingsStore.selectedSourceUniqueID = $0 }
        )
    }

    private func importMappings() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.json]
        panel.title = "Import MIDI Mappings"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let data = try Data(contentsOf: url)
            try settingsStore.importMappingsData(data)
            transferMessage = TransferMessage(
                title: "Mappings imported",
                message: "Imported mappings from \(url.lastPathComponent).",
                tone: .success
            )
        } catch {
            transferMessage = TransferMessage(
                title: "Import failed",
                message: error.localizedDescription,
                tone: .warning
            )
        }
    }

    private func exportMappings() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "MidiMusicControlMappings.json"
        panel.title = "Export MIDI Mappings"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let data = try settingsStore.exportMappingsData()
            try data.write(to: url, options: .atomic)
            transferMessage = TransferMessage(
                title: "Mappings exported",
                message: "Saved mappings to \(url.lastPathComponent).",
                tone: .success
            )
        } catch {
            transferMessage = TransferMessage(
                title: "Export failed",
                message: error.localizedDescription,
                tone: .warning
            )
        }
    }
}

private struct MappingGroupCard: View {
    let app: PlayerApp
    let actions: [MIDIAction]
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var midiManager: MIDIManager

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(app.rawValue)
                    .font(.headline)
                Text("Configure fade and duck actions for \(app.rawValue).")
                    .foregroundStyle(.secondary)
            }

            MappingHeaderRow()

            VStack(spacing: 10) {
                ForEach(actions) { action in
                    MappingEditorRow(
                        action: action,
                        mapping: binding(for: action),
                        defaultMapping: SettingsStore.defaultMappings[action] ?? .default,
                        isLearning: midiManager.learningAction == action,
                        onLearn: { midiManager.beginLearning(for: action) },
                        onCancelLearn: { midiManager.cancelLearning() }
                    )
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func binding(for action: MIDIAction) -> Binding<MIDIMapping> {
        Binding(
            get: { settingsStore.mapping(for: action) },
            set: { newValue in
                _ = settingsStore.setMapping(newValue, for: action)
            }
        )
    }
}

private struct MappingHeaderRow: View {
    var body: some View {
        HStack(spacing: MappingRowLayout.columnSpacing) {
            Text("Action")
                .mappingColumnLabel()
                .frame(width: MappingRowLayout.actionColumnWidth, alignment: .leading)
            Text("Type")
                .mappingColumnLabel()
                .frame(width: MappingRowLayout.typeColumnWidth, alignment: .leading)
            Text("Note / CC")
                .mappingColumnLabel()
                .frame(width: MappingRowLayout.noteColumnWidth, alignment: .leading)
            Text("Value")
                .mappingColumnLabel()
                .frame(width: MappingRowLayout.valueColumnWidth, alignment: .leading)
            Text("Actions")
                .mappingColumnLabel()
            Spacer(minLength: 0)
        }
    }
}

private struct MappingEditorRow: View {
    let action: MIDIAction
    @Binding var mapping: MIDIMapping
    let defaultMapping: MIDIMapping
    let isLearning: Bool
    let onLearn: () -> Void
    let onCancelLearn: () -> Void

    var body: some View {
        HStack(spacing: MappingRowLayout.columnSpacing) {
            VStack(alignment: .leading, spacing: 2) {
                Text(action.shortLabel)
                    .font(.headline)
                Text(action.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: MappingRowLayout.actionColumnWidth, alignment: .leading)

            Picker("", selection: $mapping.kind) {
                Text("Note").tag(MIDIMessageKind.noteOn)
                Text("CC").tag(MIDIMessageKind.controlChange)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: MappingRowLayout.typeColumnWidth, alignment: .leading)

            HStack(spacing: 8) {
                MIDIValueStepper(value: noteBinding, range: 0...127)
                Text(mapping.noteLabel)
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .frame(width: MappingRowLayout.noteColumnWidth, alignment: .leading)

            MIDIValueStepper(value: velocityBinding, range: 0...127)
                .frame(width: MappingRowLayout.valueColumnWidth, alignment: .leading)

            HStack(spacing: 8) {
                if isLearning {
                    Button("Cancel") {
                        onCancelLearn()
                    }
                    .keyboardShortcut(.cancelAction)
                } else {
                    Button("Learn") {
                        onLearn()
                    }
                }

                Button("Reset") {
                    mapping = defaultMapping
                }
                .disabled(mapping == defaultMapping)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(rowBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isLearning ? Color.accentColor : Color.clear, lineWidth: 2)
        }
    }

    private var rowBackground: Color {
        isLearning ? Color.accentColor.opacity(0.10) : Color.primary.opacity(0.03)
    }

    private var noteBinding: Binding<Int> {
        Binding(
            get: { Int(mapping.note) },
            set: { mapping.note = UInt8(clamping: $0) }
        )
    }

    private var velocityBinding: Binding<Int> {
        Binding(
            get: { Int(mapping.velocity) },
            set: { mapping.velocity = UInt8(clamping: $0) }
        )
    }
}

private enum MessageTone {
    case neutral
    case success
    case warning
    case accent

    var color: Color {
        switch self {
        case .neutral:
            return .secondary
        case .success:
            return .green
        case .warning:
            return .orange
        case .accent:
            return .accentColor
        }
    }

    var iconName: String {
        switch self {
        case .neutral:
            return "circle"
        case .success:
            return "checkmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .accent:
            return "dot.radiowaves.left.and.right"
        }
    }
}

private struct TransferMessage {
    let title: String
    let message: String
    let tone: MessageTone
}

private struct StatusCard: View {
    let title: String
    let value: String
    let detail: String
    let tone: MessageTone

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Image(systemName: tone.iconName)
                    .foregroundStyle(tone.color)
            }

            Text(value)
                .font(.title3.weight(.semibold))
                .lineLimit(2)
            Text(detail)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct InlineMessageCard: View {
    let title: String
    let message: String
    let tone: MessageTone

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: tone.iconName)
                .foregroundStyle(tone.color)
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(message)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(tone.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private enum MappingRowLayout {
    static let actionColumnWidth: CGFloat = 160
    static let noteColumnWidth: CGFloat = 170
    static let typeColumnWidth: CGFloat = 120
    static let valueColumnWidth: CGFloat = 84
    static let columnSpacing: CGFloat = 12
}

private extension MIDIAction {
    var shortLabel: String {
        switch actionKind {
        case .fadeIn:
            return "Fade In"
        case .fadeOut:
            return "Fade Out"
        case .duck:
            return "Duck"
        case .unduck:
            return "Unduck"
        }
    }
}

private extension Text {
    func mappingColumnLabel() -> some View {
        font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }
}

private struct MIDIValueStepper: NSViewRepresentable {
    @Binding var value: Int
    let range: ClosedRange<Int>

    func makeNSView(context: Context) -> NSStackView {
        let field = makeField(coordinator: context.coordinator)
        let stepper = makeStepper(coordinator: context.coordinator)

        let stack = NSStackView(views: [field, stepper])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 4
        stack.setHuggingPriority(.required, for: .vertical)
        stack.setContentHuggingPriority(.required, for: .vertical)

        context.coordinator.field = field
        context.coordinator.stepper = stepper

        sync(value: value, field: field, stepper: stepper)
        return stack
    }

    func updateNSView(_ stack: NSStackView, context: Context) {
        guard let field = context.coordinator.field,
              let stepper = context.coordinator.stepper else { return }
        sync(value: value, field: field, stepper: stepper)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    private func makeField(coordinator: Coordinator) -> NSTextField {
        let field = NSTextField()
        field.translatesAutoresizingMaskIntoConstraints = false
        field.isBordered = true
        field.isBezeled = true
        field.bezelStyle = .roundedBezel
        field.controlSize = .small
        field.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
        field.alignment = .right
        field.delegate = coordinator
        field.widthAnchor.constraint(equalToConstant: 48).isActive = true
        return field
    }

    private func makeStepper(coordinator: Coordinator) -> NSStepper {
        let stepper = NSStepper()
        stepper.translatesAutoresizingMaskIntoConstraints = false
        stepper.controlSize = .small
        stepper.minValue = Double(range.lowerBound)
        stepper.maxValue = Double(range.upperBound)
        stepper.target = coordinator
        stepper.action = #selector(Coordinator.stepperChanged(_:))
        return stepper
    }

    private func sync(value: Int, field: NSTextField, stepper: NSStepper) {
        let clamped = min(range.upperBound, max(range.lowerBound, value))
        if field.integerValue != clamped {
            field.integerValue = clamped
        }
        if stepper.integerValue != clamped {
            stepper.integerValue = clamped
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: MIDIValueStepper
        weak var field: NSTextField?
        weak var stepper: NSStepper?

        init(parent: MIDIValueStepper) {
            self.parent = parent
        }

        @objc func stepperChanged(_ sender: NSStepper) {
            let clamped = min(parent.range.upperBound, max(parent.range.lowerBound, sender.integerValue))
            parent.value = clamped
            field?.integerValue = clamped
            sender.integerValue = clamped
        }

        func controlTextDidEndEditing(_ obj: Notification) {
            commit(from: obj.object as? NSTextField)
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                commit(from: control as? NSTextField)
                control.window?.makeFirstResponder(nil)
                return true
            }
            return false
        }

        private func commit(from field: NSTextField?) {
            guard let field else { return }
            let clamped = min(parent.range.upperBound, max(parent.range.lowerBound, field.integerValue))
            parent.value = clamped
            field.integerValue = clamped
            stepper?.integerValue = clamped
        }
    }
}
