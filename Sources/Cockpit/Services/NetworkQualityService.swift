import Foundation

struct NetworkQualityResult: Equatable {
    var uplinkMbps: Double?
    var downlinkMbps: Double?
    var responsiveness: String?
    var responsivenessMilliseconds: Double?
    var responsivenessRPM: Int?
    var idleLatencyMilliseconds: Double?
    var idleLatencyRPM: Int?
    var interfaceName: String?
    var testEndpoint: String?
    var startTime: String?
    var endTime: String?
    var rawSummary: String

    var hasMeasuredCapacity: Bool {
        uplinkMbps != nil || downlinkMbps != nil
    }
}

enum NetworkQualityParser {
    static func parse(_ output: String) -> NetworkQualityResult {
        var result = NetworkQualityResult(rawSummary: output.trimmingCharacters(in: .whitespacesAndNewlines))
        let lines = output.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("Uplink capacity:") {
                result.uplinkMbps = parseFirstDouble(in: trimmed)
            } else if trimmed.hasPrefix("Downlink capacity:") {
                result.downlinkMbps = parseFirstDouble(in: trimmed)
            } else if trimmed.hasPrefix("Idle Latency:") {
                result.idleLatencyMilliseconds = parseMilliseconds(in: trimmed)
                result.idleLatencyRPM = parseRPM(in: trimmed)
            } else if trimmed.hasPrefix("Responsiveness:") {
                result.responsiveness = parseResponsivenessLabel(in: trimmed)
                result.responsivenessMilliseconds = parseMilliseconds(in: trimmed)
                result.responsivenessRPM = parseRPM(in: trimmed)
            } else if trimmed.hasPrefix("Interface:") {
                result.interfaceName = String(trimmed.dropFirst("Interface:".count)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("Test Endpoint:") {
                result.testEndpoint = String(trimmed.dropFirst("Test Endpoint:".count)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("Start:") {
                result.startTime = String(trimmed.dropFirst("Start:".count)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("End:") {
                result.endTime = String(trimmed.dropFirst("End:".count)).trimmingCharacters(in: .whitespaces)
            }
        }

        return result
    }

    private static func parseResponsivenessLabel(in line: String) -> String? {
        guard let value = line.components(separatedBy: ":").dropFirst().first else { return nil }
        let label = value.components(separatedBy: "(").first?.trimmingCharacters(in: .whitespacesAndNewlines)
        return label?.isEmpty == false ? label : nil
    }

    private static func parseFirstDouble(in line: String) -> Double? {
        let pattern = #"([0-9]+(?:\.[0-9]+)?)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let range = Range(match.range(at: 1), in: line) else {
            return nil
        }
        return Double(line[range])
    }

    private static func parseMilliseconds(in line: String) -> Double? {
        let pattern = #"([0-9]+(?:\.[0-9]+)?)\s+milliseconds"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let range = Range(match.range(at: 1), in: line) else {
            return nil
        }
        return Double(line[range])
    }

    private static func parseRPM(in line: String) -> Int? {
        let pattern = #"([0-9]+)\s+RPM"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let range = Range(match.range(at: 1), in: line) else {
            return nil
        }
        return Int(line[range])
    }
}

enum NetworkQualityService {
    static func run() async throws -> NetworkQualityResult {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/networkQuality")
            process.arguments = ["-v"]

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            process.terminationHandler = { process in
                let output = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let error = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let outputText = String(data: output, encoding: .utf8) ?? ""
                let errorText = String(data: error, encoding: .utf8) ?? ""
                let combined = [outputText, errorText]
                    .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                    .joined(separator: "\n")

                guard process.terminationStatus == 0 else {
                    continuation.resume(throwing: NetworkQualityError.failed(status: process.terminationStatus, output: combined))
                    return
                }

                continuation.resume(returning: NetworkQualityParser.parse(combined))
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

enum NetworkQualityError: Error, LocalizedError, Equatable {
    case failed(status: Int32, output: String)

    var errorDescription: String? {
        switch self {
        case let .failed(status, output):
            return "networkQuality exited with status \(status): \(output)"
        }
    }
}
