import Foundation

protocol CaptureServing {
    func captureRegion() async -> CaptureResult
}

enum CaptureFailureReason: Equatable {
    case permissionDenied
    case toolFailed(message: String)
    case unexpected(message: String)
}

extension CaptureService: CaptureServing {}

struct CaptureResult: Equatable {
    let canceled: Bool
    let path: String?
    let error: String?
    let failureReason: CaptureFailureReason?
}

final class CaptureService {
    func captureRegion() async -> CaptureResult {
        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent("text-shot-capture-\(Date().timeIntervalSince1970)-\(UUID().uuidString).png")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-i", "-x", output.path]

        let stderrPipe = Pipe()
        process.standardError = stderrPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return CaptureResult(
                canceled: false,
                path: nil,
                error: error.localizedDescription,
                failureReason: .unexpected(message: error.localizedDescription)
            )
        }

        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        let stderr = String(data: stderrData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if process.terminationStatus == 0 && FileManager.default.fileExists(atPath: output.path) {
            return CaptureResult(canceled: false, path: output.path, error: nil, failureReason: nil)
        }

        try? FileManager.default.removeItem(at: output)

        return resultForFailure(terminationStatus: process.terminationStatus, stderr: stderr)
    }

    func resultForFailure(terminationStatus: Int32, stderr: String) -> CaptureResult {
        if terminationStatus == 1 {
            return CaptureResult(canceled: true, path: nil, error: nil, failureReason: nil)
        }

        let reason = Self.classifyFailure(terminationStatus: terminationStatus, stderr: stderr)
        let message: String
        switch reason {
        case .permissionDenied:
            message = "Screen Recording permission denied."
        case .toolFailed(let detail):
            message = detail
        case .unexpected(let detail):
            message = detail
        }

        return CaptureResult(canceled: false, path: nil, error: message, failureReason: reason)
    }

    static func classifyFailure(terminationStatus: Int32, stderr: String) -> CaptureFailureReason {
        if isPermissionDenied(stderr: stderr) {
            return .permissionDenied
        }

        if !stderr.isEmpty {
            return .toolFailed(message: stderr)
        }

        return .unexpected(message: "screencapture failed with exit code \(terminationStatus)")
    }

    private static func isPermissionDenied(stderr: String) -> Bool {
        let normalized = stderr.lowercased()
        let markers = [
            "screen recording",
            "not authorized",
            "not permitted",
            "permission denied",
            "denied by tcc"
        ]
        return markers.contains(where: { normalized.contains($0) })
    }
}
