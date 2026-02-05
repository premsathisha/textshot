import AppKit
import Foundation
import Vision

enum ExitCode: Int32 {
    case success = 0
    case noText = 10
    case badArgs = 20
    case runtimeFailure = 30
    case unreadableInput = 40
}

struct Config {
    let inputPath: String
    let level: VNRequestTextRecognitionLevel
    let languageCorrection: Bool
    let json: Bool
}

func parseArgs() -> Config? {
    let args = CommandLine.arguments
    var inputPath: String?
    var level: VNRequestTextRecognitionLevel = .accurate
    var correction = true
    var json = false

    var index = 1
    while index < args.count {
        let arg = args[index]
        switch arg {
        case "--input":
            guard index + 1 < args.count else { return nil }
            inputPath = args[index + 1]
            index += 2
        case "--level":
            guard index + 1 < args.count else { return nil }
            level = args[index + 1] == "fast" ? .fast : .accurate
            index += 2
        case "--language-correction":
            guard index + 1 < args.count else { return nil }
            correction = args[index + 1] != "off"
            index += 2
        case "--json":
            json = true
            index += 1
        default:
            return nil
        }
    }

    guard let inputPath else { return nil }
    return Config(inputPath: inputPath, level: level, languageCorrection: correction, json: json)
}

func loadCGImage(path: String) -> CGImage? {
    guard let nsImage = NSImage(contentsOfFile: path) else { return nil }
    var rect = NSRect(origin: .zero, size: nsImage.size)
    return nsImage.cgImage(forProposedRect: &rect, context: nil, hints: nil)
}

func runOCR(image: CGImage, level: VNRequestTextRecognitionLevel, correction: Bool) throws -> [String] {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = level
    request.usesLanguageCorrection = correction

    let handler = VNImageRequestHandler(cgImage: image, options: [:])
    try handler.perform([request])

    let observations = request.results as? [VNRecognizedTextObservation] ?? []
    var lines: [String] = []

    for observation in observations {
        if let top = observation.topCandidates(1).first?.string {
            let line = top.trimmingCharacters(in: .whitespacesAndNewlines)
            if !line.isEmpty {
                lines.append(line)
            }
        }
    }

    return lines
}

func printJSON(text: String, level: String) {
    let payload: [String: Any] = [
        "text": text,
        "lines": text.split(separator: "\n").map(String.init),
        "level": level
    ]

    if let data = try? JSONSerialization.data(withJSONObject: payload, options: []),
       let output = String(data: data, encoding: .utf8) {
        print(output)
    } else {
        print("{\"text\":\"\",\"lines\":[],\"level\":\"\(level)\"}")
    }
}

guard let config = parseArgs() else {
    fputs("Usage: ocr-helper --input <path> [--level accurate|fast] [--language-correction on|off] [--json]\n", stderr)
    exit(ExitCode.badArgs.rawValue)
}

guard let image = loadCGImage(path: config.inputPath) else {
    fputs("Unable to read image at path: \(config.inputPath)\n", stderr)
    exit(ExitCode.unreadableInput.rawValue)
}

do {
    let lines = try runOCR(image: image, level: config.level, correction: config.languageCorrection)
    if lines.isEmpty {
        exit(ExitCode.noText.rawValue)
    }

    let text = lines.joined(separator: "\n")
    if config.json {
        printJSON(text: text, level: config.level == .fast ? "fast" : "accurate")
    } else {
        print(text)
    }
    exit(ExitCode.success.rawValue)
} catch {
    fputs("OCR error: \(error.localizedDescription)\n", stderr)
    exit(ExitCode.runtimeFailure.rawValue)
}
