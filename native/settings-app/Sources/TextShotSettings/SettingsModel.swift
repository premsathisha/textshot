import Foundation

struct AppSettingsV2: Codable, Equatable {
    var schemaVersion: Int
    var hotkey: String
    var showConfirmation: Bool
    var launchAtLogin: Bool
    var autoPaste: Bool
    var lastPermissionPromptAt: Int
    var lastAccessibilityPromptAt: Int

    static let schemaVersionValue = 2

    static let defaults = AppSettingsV2(
        schemaVersion: schemaVersionValue,
        hotkey: "CommandOrControl+Shift+2",
        showConfirmation: true,
        launchAtLogin: false,
        autoPaste: false,
        lastPermissionPromptAt: 0,
        lastAccessibilityPromptAt: 0
    )
}

struct EditableSettings: Equatable {
    var hotkey: String
    var showConfirmation: Bool
    var launchAtLogin: Bool
    var autoPaste: Bool
}

extension AppSettingsV2 {
    var editable: EditableSettings {
        EditableSettings(
            hotkey: hotkey,
            showConfirmation: showConfirmation,
            launchAtLogin: launchAtLogin,
            autoPaste: autoPaste
        )
    }

    mutating func apply(_ editable: EditableSettings) {
        hotkey = editable.hotkey
        showConfirmation = editable.showConfirmation
        launchAtLogin = editable.launchAtLogin
        autoPaste = editable.autoPaste
    }
}

final class SettingsStoreV2 {
    private let fileURL: URL
    private let fm: FileManager

    init(fileURL: URL, fileManager: FileManager = .default) {
        self.fileURL = fileURL
        self.fm = fileManager
    }

    var settingsURL: URL { fileURL }

    func load() -> AppSettingsV2 {
        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try JSONDecoder().decode(AppSettingsV2.self, from: data)
            return normalized(decoded)
        } catch {
            return .defaults
        }
    }

    @discardableResult
    func save(_ settings: AppSettingsV2) throws -> AppSettingsV2 {
        let next = normalized(settings)
        try ensureParentDirectory()

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(next)
        try data.write(to: fileURL, options: .atomic)
        return next
    }

    @discardableResult
    func update(_ updateBlock: (inout AppSettingsV2) -> Void) throws -> AppSettingsV2 {
        var current = load()
        updateBlock(&current)
        return try save(current)
    }

    private func ensureParentDirectory() throws {
        try fm.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    }

    private func normalized(_ settings: AppSettingsV2) -> AppSettingsV2 {
        var copy = settings
        copy.schemaVersion = AppSettingsV2.schemaVersionValue
        if copy.hotkey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            copy.hotkey = AppSettingsV2.defaults.hotkey
        }
        return copy
    }
}

struct SettingsMigrator {
    private let fm: FileManager
    private let appSupportURLOverride: URL?

    init(fileManager: FileManager = .default, appSupportURLOverride: URL? = nil) {
        self.fm = fileManager
        self.appSupportURLOverride = appSupportURLOverride
    }

    func prepareStore() throws -> SettingsStoreV2 {
        let appSupport = try appSupportDirectory()
        let settingsDirectory = appSupport.appendingPathComponent("Text Shot", isDirectory: true)
        let targetURL = settingsDirectory.appendingPathComponent("settings-v2.json")
        let markerURL = settingsDirectory.appendingPathComponent(".migration-v2-done")

        try fm.createDirectory(at: settingsDirectory, withIntermediateDirectories: true)

        if !fm.fileExists(atPath: targetURL.path) {
            let migrated = migrateLegacySettingsIfAvailable() ?? .defaults
            let store = SettingsStoreV2(fileURL: targetURL, fileManager: fm)
            _ = try store.save(migrated)
        }

        if !fm.fileExists(atPath: markerURL.path) {
            fm.createFile(atPath: markerURL.path, contents: Data())
        }

        return SettingsStoreV2(fileURL: targetURL, fileManager: fm)
    }

    private func appSupportDirectory() throws -> URL {
        if let appSupportURLOverride {
            return appSupportURLOverride
        }

        guard let url = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw NSError(domain: "TextShot", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Application Support directory unavailable"])
        }
        return url
    }

    private func migrateLegacySettingsIfAvailable() -> AppSettingsV2? {
        let candidates = legacySettingsCandidates()
        for url in candidates where fm.fileExists(atPath: url.path) {
            guard
                let data = try? Data(contentsOf: url),
                let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else {
                continue
            }

            return AppSettingsV2(
                schemaVersion: AppSettingsV2.schemaVersionValue,
                hotkey: readString(payload, "hotkey") ?? AppSettingsV2.defaults.hotkey,
                showConfirmation: readBool(payload, "showConfirmation") ?? AppSettingsV2.defaults.showConfirmation,
                launchAtLogin: readBool(payload, "launchAtLogin") ?? AppSettingsV2.defaults.launchAtLogin,
                autoPaste: readBool(payload, "autoPaste") ?? AppSettingsV2.defaults.autoPaste,
                lastPermissionPromptAt: readInt(payload, "lastPermissionPromptAt") ?? 0,
                lastAccessibilityPromptAt: readInt(payload, "lastAccessibilityPromptAt") ?? 0
            )
        }

        return nil
    }

    private func legacySettingsCandidates() -> [URL] {
        guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return []
        }

        return [
            appSupport.appendingPathComponent("Text Shot/settings.json"),
            appSupport.appendingPathComponent("text-shot/settings.json")
        ]
    }

    private func readString(_ payload: [String: Any], _ key: String) -> String? {
        (payload[key] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func readBool(_ payload: [String: Any], _ key: String) -> Bool? {
        payload[key] as? Bool
    }

    private func readInt(_ payload: [String: Any], _ key: String) -> Int? {
        if let intValue = payload[key] as? Int {
            return intValue
        }

        if let number = payload[key] as? NSNumber {
            return number.intValue
        }

        return nil
    }
}
