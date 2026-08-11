import Foundation

struct HarperCorrection {
    let characterRange: Range<Int>
    let replacement: String
    let message: String
}

final class HarperCorrectionService {
    private struct Report: Decodable {
        let lints: [Lint]
    }

    private struct Lint: Decodable {
        struct Span: Decodable {
            let charStart: Int
            let charEnd: Int

            enum CodingKeys: String, CodingKey {
                case charStart = "char_start"
                case charEnd = "char_end"
            }
        }

        let kind: String
        let span: Span
        let message: String
        let suggestions: [String]
        let matchedText: String

        enum CodingKeys: String, CodingKey {
            case kind, span, message, suggestions
            case matchedText = "matched_text"
        }
    }

    var isAvailable: Bool { FileManager.default.isExecutableFile(atPath: executableURL.path) }

    private var executableURL: URL {
        if let resource = Bundle.main.resourceURL {
            return resource.appendingPathComponent("Helpers", isDirectory: true)
                .appendingPathComponent("harper-cli")
        }
        return URL(fileURLWithPath: "/missing-harper-cli")
    }

    private var dictionaryURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("Hello, Word", isDirectory: true)
            .appendingPathComponent("harper-dictionary.txt")
    }

    func check(_ text: String, completion: @escaping ([HarperCorrection]) -> Void) {
        guard isAvailable, text.count >= 3 else {
            completion([])
            return
        }

        let executable = executableURL
        let dictionary = dictionaryURL
        DispatchQueue.global(qos: .userInitiated).async {
            self.ensureDictionaryExists(at: dictionary)
            let process = Process()
            let output = Pipe()
            let errors = Pipe()
            process.executableURL = executable
            process.arguments = [
                "lint", "--format", "json", "--quiet",
                "--user-dict-path", dictionary.path,
                text
            ]
            process.standardOutput = output
            process.standardError = errors

            do {
                try process.run()
                process.waitUntilExit()
                let data = output.fileHandleForReading.readDataToEndOfFile()
                let reports = try JSONDecoder().decode([Report].self, from: data)
                let corrections = reports.flatMap(\.lints).compactMap(self.safeCorrection(from:))
                DispatchQueue.main.async { completion(corrections) }
            } catch {
                DispatchQueue.main.async { completion([]) }
            }
        }
    }

    private func ensureDictionaryExists(at url: URL) {
        guard !FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data().write(to: url, options: .atomic)
        } catch {
            NSLog("Hello, Word could not create the Harper dictionary: \(error.localizedDescription)")
        }
    }

    private func safeCorrection(from lint: Lint) -> HarperCorrection? {
        guard lint.suggestions.count == 1,
              let replacement = replacementText(from: lint.suggestions[0]),
              !replacement.isEmpty,
              replacement != lint.matchedText,
              replacement.count <= max(80, lint.matchedText.count * 3),
              lint.span.charStart >= 0,
              lint.span.charEnd > lint.span.charStart else {
            return nil
        }
        return HarperCorrection(
            characterRange: lint.span.charStart..<lint.span.charEnd,
            replacement: replacement,
            message: lint.message
        )
    }

    private func replacementText(from suggestion: String) -> String? {
        let prefixes = ["Replace with: “", "Replace with: \""]
        for prefix in prefixes where suggestion.hasPrefix(prefix) {
            let suffix: Character = prefix.hasSuffix("“") ? "”" : "\""
            guard suggestion.last == suffix else { continue }
            return String(suggestion.dropFirst(prefix.count).dropLast())
        }
        return nil
    }
}
