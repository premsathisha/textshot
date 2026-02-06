import Foundation

struct PersistedSettings: Codable, Equatable {
    var hotkey: String
    var showConfirmation: Bool
    var launchAtLogin: Bool
    var debugMode: Bool
    var autoPaste: Bool
    var lastPermissionPromptAt: Int
    var lastAccessibilityPromptAt: Int

    static let defaults = PersistedSettings(
        hotkey: "CommandOrControl+Shift+2",
        showConfirmation: true,
        launchAtLogin: false,
        debugMode: false,
        autoPaste: false,
        lastPermissionPromptAt: 0,
        lastAccessibilityPromptAt: 0
    )

    var editable: EditableSettings {
        EditableSettings(
            hotkey: hotkey,
            showConfirmation: showConfirmation,
            launchAtLogin: launchAtLogin,
            debugMode: debugMode,
            autoPaste: autoPaste
        )
    }

    mutating func apply(_ editable: EditableSettings) {
        hotkey = editable.hotkey
        showConfirmation = editable.showConfirmation
        launchAtLogin = editable.launchAtLogin
        debugMode = editable.debugMode
        autoPaste = editable.autoPaste
    }
}

struct EditableSettings: Equatable {
    var hotkey: String
    var showConfirmation: Bool
    var launchAtLogin: Bool
    var debugMode: Bool
    var autoPaste: Bool
}

final class SettingsFileStore {
    private let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    func load() throws -> PersistedSettings {
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        return try decoder.decode(PersistedSettings.self, from: data)
    }

    @discardableResult
    func save(editable: EditableSettings, preserving previous: PersistedSettings) throws -> PersistedSettings {
        var next = previous
        next.apply(editable)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(next)

        // Data.write(..., .atomic) writes through a temp file + rename.
        try data.write(to: fileURL, options: .atomic)
        return next
    }
}

enum SettingsArguments {
    static func settingsFileURL(from args: [String]) throws -> URL {
        guard let flagIndex = args.firstIndex(of: "--settings-file"), args.indices.contains(flagIndex + 1) else {
            throw SettingsArgumentError.missingSettingsFile
        }

        let path = args[flagIndex + 1]
        guard !path.isEmpty else {
            throw SettingsArgumentError.emptySettingsFilePath
        }

        return URL(fileURLWithPath: path)
    }
}

enum SettingsArgumentError: LocalizedError {
    case missingSettingsFile
    case emptySettingsFilePath

    var errorDescription: String? {
        switch self {
        case .missingSettingsFile:
            return "Missing required argument: --settings-file <absolute_path_to_settings.json>"
        case .emptySettingsFilePath:
            return "--settings-file value cannot be empty"
        }
    }
}
