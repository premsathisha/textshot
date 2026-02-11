import Foundation

final class CaptureTempStore {
    static let shared = CaptureTempStore()

    private let fm = FileManager.default
    private let queue = DispatchQueue(label: "com.textshot.capture-temp-store")
    private let rootDirectory: URL

    private var trackedPaths = Set<String>()
    private var didInstallExitHook = false

    private init() {
        rootDirectory = fm.temporaryDirectory
            .appendingPathComponent("com.textshot.capture-temp", isDirectory: true)
    }

    func prepareForLaunch(staleAgeLimit: TimeInterval = 60 * 60) {
        queue.sync {
            ensureDirectoryExists()
            installExitHookIfNeeded()
            purgeStaleFilesIfNeeded(staleAgeLimit: staleAgeLimit)
        }
    }

    func makeCaptureFileURL() -> URL {
        queue.sync {
            ensureDirectoryExists()
            let filename = "capture-\(Date().timeIntervalSince1970)-\(UUID().uuidString).png"
            let fileURL = rootDirectory.appendingPathComponent(filename)
            trackedPaths.insert(fileURL.path)
            return fileURL
        }
    }

    func removeCaptureFile(atPath path: String) {
        _ = queue.sync {
            trackedPaths.remove(path)
        }
        try? fm.removeItem(atPath: path)
    }

    func cleanupTrackedFiles() {
        let paths = queue.sync {
            let snapshot = Array(trackedPaths)
            trackedPaths.removeAll()
            return snapshot
        }

        for path in paths {
            try? fm.removeItem(atPath: path)
        }
    }

    private func ensureDirectoryExists() {
        try? fm.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
    }

    private func installExitHookIfNeeded() {
        guard !didInstallExitHook else {
            return
        }

        didInstallExitHook = true
        atexit {
            CaptureTempStore.shared.cleanupTrackedFiles()
        }
    }

    private func purgeStaleFilesIfNeeded(staleAgeLimit: TimeInterval) {
        let cutoffDate = Date().addingTimeInterval(-staleAgeLimit)

        guard let contents = try? fm.contentsOfDirectory(
            at: rootDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey, .creationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        for item in contents {
            guard let values = try? item.resourceValues(forKeys: [.contentModificationDateKey, .creationDateKey, .isRegularFileKey]) else {
                continue
            }

            if values.isRegularFile != true {
                continue
            }

            let timestamp = values.contentModificationDate ?? values.creationDate ?? .distantPast
            if timestamp < cutoffDate {
                try? fm.removeItem(at: item)
            }
        }
    }
}
