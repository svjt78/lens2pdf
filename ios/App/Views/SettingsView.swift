import SwiftUI

struct SettingsView: View {
    @ObservedObject private var store = SettingsStore.shared

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Capture")) {
                    Picker("Color mode", selection: Binding(
                        get: { store.settings.defaultColorMode },
                        set: { mode in store.update { $0.defaultColorMode = mode } }
                    )) {
                        ForEach(ColorMode.allCases) { mode in
                            Text(modeLabel(mode))
                                .tag(mode)
                        }
                    }

                    HStack {
                        Text("JPEG quality")
                        Spacer()
                        Text("\(store.settings.jpegQuality)")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: Binding(
                        get: { Double(store.settings.jpegQuality) },
                        set: { newValue in
                            let clamped = Int(newValue.rounded())
                            store.update { $0.jpegQuality = min(max(clamped, 60), 95) }
                        }
                    ), in: 60...95, step: 1)
                }

                Section(header: Text("Vault"), footer: Text("Vault enforcement arrives in a later iteration; toggle persists now for configurability.")) {
                    Toggle(isOn: Binding(
                        get: { store.settings.vaultEnabled },
                        set: { newValue in store.update { $0.vaultEnabled = newValue } }
                    )) {
                        Text("Enable Vault by default")
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }

    private func modeLabel(_ mode: ColorMode) -> String {
        switch mode {
        case .color: return "Color"
        case .grayscale: return "Grayscale"
        case .monochrome: return "Monochrome"
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}

