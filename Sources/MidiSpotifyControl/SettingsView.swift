import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var midiManager: MIDIManager

    var body: some View {
        Form {
            Section {
                Toggle("Open at login", isOn: $settingsStore.launchAtLogin)
                    .disabled(!LaunchAtLogin.isSupported)

                if !LaunchAtLogin.isSupported {
                    Text("Available when the app is packaged as a macOS application (.app).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if let message = settingsStore.launchAtLoginError {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Startup")
            }

            Section {
                Picker("MIDI Input", selection: selectedSourceBinding) {
                    if midiManager.sources.isEmpty {
                        Text("No devices found").tag(Optional<Int32>.none)
                    }
                    ForEach(midiManager.sources) { source in
                        Text(source.name).tag(Optional(source.uniqueID))
                    }
                }

                Button("Refresh Devices") {
                    midiManager.refreshSources()
                }
            } header: {
                Text("MIDI Input")
            }

            Section {
                HStack {
                    Text("Fade duration")
                    Spacer()
                    Text(String(format: "%.1fs", settingsStore.fadeDuration))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Slider(value: $settingsStore.fadeDuration, in: 0.5...15, step: 0.25)
                Text("Total time to complete a fade in or out, regardless of the current volume.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Fade Speed")
            }

            Section {
                HStack {
                    Text("Duck volume")
                    Spacer()
                    Text("\(settingsStore.duckVolumePercent)%")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Slider(
                    value: duckVolumeBinding,
                    in: 1...100,
                    step: 1
                )
                Text("Volume level to fade down to while ducked. Unduck restores the volume from before ducking.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Ducking")
            }

            Section {
                ForEach(MIDIAction.fadeActions) { action in
                    MappingRow(
                        action: action,
                        mapping: mappingBinding(for: action),
                        isLearning: midiManager.learningAction == action,
                        onLearn: { midiManager.beginLearning(for: action) },
                        onCancelLearn: { midiManager.cancelLearning() }
                    )
                }
            } header: {
                Text("Fade Mappings")
            }

            Section {
                ForEach(MIDIAction.duckActions) { action in
                    MappingRow(
                        action: action,
                        mapping: mappingBinding(for: action),
                        isLearning: midiManager.learningAction == action,
                        onLearn: { midiManager.beginLearning(for: action) },
                        onCancelLearn: { midiManager.cancelLearning() }
                    )
                }

                if let message = midiManager.lastLearnedMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Duck Mappings")
            } footer: {
                Text("Each action matches an exact note/CC and value. Use Learn to capture the next MIDI message from the selected input.")
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 720)
        .padding()
        .onAppear {
            settingsStore.refreshLaunchAtLogin()
        }
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

    private func mappingBinding(for action: MIDIAction) -> Binding<MIDIMapping> {
        Binding(
            get: { settingsStore.mapping(for: action) },
            set: { settingsStore.setMapping($0, for: action) }
        )
    }
}

private struct MappingRow: View {
    let action: MIDIAction
    @Binding var mapping: MIDIMapping
    let isLearning: Bool
    let onLearn: () -> Void
    let onCancelLearn: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(action.label)
                .font(.headline)
                .padding(.bottom, 2)

            HStack(spacing: MappingRowLayout.columnSpacing) {
                Text(mapping.kind == .noteOn ? "Note" : "CC")
                    .mappingColumnLabel()
                    .frame(width: MappingRowLayout.noteColumnWidth, alignment: .leading)
                Text("Type")
                    .mappingColumnLabel()
                    .frame(width: MappingRowLayout.typeColumnWidth, alignment: .leading)
                Text("Value")
                    .mappingColumnLabel()
                    .frame(width: MappingRowLayout.valueColumnWidth, alignment: .leading)
                Spacer(minLength: 0)
            }

            HStack(alignment: .center, spacing: MappingRowLayout.columnSpacing) {
                HStack(spacing: 6) {
                    MIDIValueStepper(value: noteBinding, range: 0...127)
                    Text(mapping.noteLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(width: MappingRowLayout.noteColumnWidth, alignment: .leading)

                Picker("", selection: $mapping.kind) {
                    Text("Note").tag(MIDIMessageKind.noteOn)
                    Text("CC").tag(MIDIMessageKind.controlChange)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: MappingRowLayout.typeColumnWidth, alignment: .leading)

                MIDIValueStepper(value: velocityBinding, range: 1...127)
                    .frame(width: MappingRowLayout.valueColumnWidth, alignment: .leading)

                Spacer(minLength: 0)

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
            }
            .frame(height: MappingRowLayout.controlHeight)
        }
        .padding(.vertical, 4)
        .overlay {
            if isLearning {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.accentColor, lineWidth: 2)
            }
        }
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

private enum MappingRowLayout {
    static let noteColumnWidth: CGFloat = 148
    static let typeColumnWidth: CGFloat = 120
    static let valueColumnWidth: CGFloat = 84
    static let controlHeight: CGFloat = 24
    static let columnSpacing: CGFloat = 12
}

private extension Text {
    func mappingColumnLabel() -> some View {
        font(.caption)
            .foregroundStyle(.secondary)
            .frame(height: 14, alignment: .leading)
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
