import Foundation

struct AppSettings: Codable, Equatable {
    var defaultColorMode: ColorMode
    var jpegQuality: Int
    var vaultEnabled: Bool

    static let `default` = AppSettings(defaultColorMode: .color, jpegQuality: 90, vaultEnabled: false)
}

final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    @Published private(set) var settings: AppSettings = .default

    private let ioQueue = DispatchQueue(label: "SettingsStore.io", qos: .utility)
    private let fileManager = FileManager.default

    private var settingsURL: URL {
        let base = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("settings.json")
    }

    private init() {
        load()
    }

    func load() {
        ioQueue.async {
            guard let data = try? Data(contentsOf: self.settingsURL) else { return }
            let decoder = JSONDecoder()
            if let decoded = try? decoder.decode(AppSettings.self, from: data) {
                DispatchQueue.main.async {
                    self.settings = decoded
                }
            }
        }
    }

    func update(_ transform: (inout AppSettings) -> Void) {
        var next = settings
        transform(&next)
        apply(next)
    }

    private func apply(_ newSettings: AppSettings) {
        DispatchQueue.main.async {
            self.settings = newSettings
        }
        persist(newSettings)
    }

    private func persist(_ settings: AppSettings) {
        ioQueue.async {
            let encoder = JSONEncoder()
            guard let data = try? encoder.encode(settings) else { return }
            try? data.write(to: self.settingsURL, options: .atomic)
        }
    }
}

