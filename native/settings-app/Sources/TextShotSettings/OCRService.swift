import AppKit
import Foundation
import Vision

protocol OCRServing {
    func runOcrWithRetry(imagePath: String) throws -> String?
}

final class OCRService {
    enum RecognitionLevel {
        case accurate
        case fast
    }

    private let retryChain: [(RecognitionLevel, Bool)] = [
        (.accurate, true),
        (.accurate, false),
        (.fast, true)
    ]

    func runOcrWithRetry(imagePath: String) throws -> String? {
        guard let cgImage = loadCGImage(path: imagePath) else {
            throw NSError(domain: "TextShot", code: 2001, userInfo: [NSLocalizedDescriptionKey: "Unable to read captured image"])
        }

        for (level, correction) in retryChain {
            let text = try recognizeText(from: cgImage, level: level, correction: correction)
            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return cleanupOcrText(text)
            }
        }

        return nil
    }

    func cleanupOcrText(_ input: String) -> String {
        let normalized = input.replacingOccurrences(of: "\r\n", with: "\n")
        let lines = normalized
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.replacingOccurrences(of: "[ \t]+$", with: "", options: .regularExpression) }

        let filtered = lines.filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                return true
            }

            return trimmed.range(of: "^[|`~.,:;]+$", options: .regularExpression) == nil
        }

        let joined = filtered.joined(separator: "\n")
        let collapsed = joined.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
        return collapsed.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func loadCGImage(path: String) -> CGImage? {
        guard let image = NSImage(contentsOfFile: path) else {
            return nil
        }

        var rect = NSRect(origin: .zero, size: image.size)
        return image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }

    private func recognizeText(from image: CGImage, level: RecognitionLevel, correction: Bool) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = level == .fast ? .fast : .accurate
        request.usesLanguageCorrection = correction

        let handler = VNImageRequestHandler(cgImage: image)
        try handler.perform([request])

        let observations = request.results ?? []
        let lines = observations.compactMap { observation in
            observation.topCandidates(1).first?.string.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        .filter { !$0.isEmpty }

        return lines.joined(separator: "\n")
    }
}

extension OCRService: OCRServing {}
