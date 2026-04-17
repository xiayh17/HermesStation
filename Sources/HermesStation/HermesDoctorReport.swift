import Foundation

enum HermesDoctorReportStatus: String, Equatable {
    case clean
    case fixed
    case needsAttention
    case failed
    case unknown
}

enum HermesDoctorCheckState: String, Equatable {
    case ok
    case warning
    case failure
    case info
    case fixed
}

struct HermesDoctorCheck: Identifiable, Equatable {
    let id: String
    let section: String
    let title: String
    let detail: String?
    let state: HermesDoctorCheckState
}

struct HermesDoctorReport: Equatable {
    let ranAt: Date
    let profileName: String
    let exitStatus: Int32
    let summary: String
    let fixedCount: Int
    let issueCount: Int
    let checks: [HermesDoctorCheck]
    let rawOutput: String

    var status: HermesDoctorReportStatus {
        if exitStatus != 0 {
            return .failed
        }
        if issueCount > 0 || checks.contains(where: { $0.state == .failure }) {
            return .needsAttention
        }
        if fixedCount > 0 || checks.contains(where: { $0.state == .fixed }) {
            return .fixed
        }
        if checks.isEmpty {
            return .unknown
        }
        return .clean
    }

    var keyChecks: [HermesDoctorCheck] {
        let highlighted = checks.filter { check in
            switch check.state {
            case .ok:
                return false
            case .info:
                return check.title.localizedCaseInsensitiveContains("run ")
                    || check.title.localizedCaseInsensitiveContains("created")
                    || check.title.localizedCaseInsensitiveContains("not created")
            case .warning, .failure, .fixed:
                return true
            }
        }
        return highlighted.isEmpty ? Array(checks.prefix(6)) : highlighted
    }

    static func parse(
        output: String,
        exitStatus: Int32,
        profileName: String,
        ranAt: Date = Date()
    ) -> HermesDoctorReport {
        let cleaned = stripANSI(output)
        var section = "General"
        var checks: [HermesDoctorCheck] = []
        var summaryLines: [String] = []
        var fixedCount = 0
        var issueCount = 0

        for rawLine in cleaned.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }

            if line.hasPrefix(sectionMarker) {
                section = line
                    .replacingOccurrences(of: sectionMarker, with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                continue
            }

            if line.localizedCaseInsensitiveContains("all checks passed") {
                summaryLines = [line]
            } else if line.localizedCaseInsensitiveContains("found ")
                        && line.localizedCaseInsensitiveContains("issue") {
                summaryLines.append(line)
                issueCount = max(issueCount, firstInteger(in: line) ?? 0)
            } else if line.localizedCaseInsensitiveContains("fixed ")
                        && line.localizedCaseInsensitiveContains("issue") {
                summaryLines.append(line)
                fixedCount = max(fixedCount, firstInteger(in: line) ?? 0)
                if let manualCount = firstInteger(matching: #"(\d+)\s+issue\(s\)\s+require"#, in: line) {
                    issueCount = max(issueCount, manualCount)
                }
            } else if line.range(of: #"^\d+\.\s+"#, options: .regularExpression) != nil {
                summaryLines.append(line)
            }

            guard let check = parseCheckLine(line, section: section) else {
                continue
            }
            checks.append(check)
        }

        let summary = summaryLines.isEmpty
            ? (cleaned.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Doctor produced no output." : "Doctor completed.")
            : summaryLines.joined(separator: "\n")

        return HermesDoctorReport(
            ranAt: ranAt,
            profileName: profileName,
            exitStatus: exitStatus,
            summary: summary,
            fixedCount: fixedCount,
            issueCount: issueCount,
            checks: uniquedChecks(checks),
            rawOutput: cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private static func parseCheckLine(_ line: String, section: String) -> HermesDoctorCheck? {
        guard let marker = line.first else { return nil }
        let state: HermesDoctorCheckState
        switch String(marker) {
        case okMarker:
            state = okState(for: line)
        case warningMarker:
            state = .warning
        case failureMarker:
            state = .failure
        case infoMarker:
            state = .info
        default:
            return nil
        }

        let body = line.dropFirst().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return nil }
        let (title, detail) = splitDetail(body)
        return HermesDoctorCheck(
            id: "\(section)|\(state.rawValue)|\(title)|\(detail ?? "")",
            section: section,
            title: title,
            detail: detail,
            state: state
        )
    }

    private static func okState(for line: String) -> HermesDoctorCheckState {
        let lower = line.lowercased()
        if lower.contains("created ")
            || lower.contains("migrated ")
            || lower.contains("checkpoint performed")
            || lower.contains("fixed ") {
            return .fixed
        }
        return .ok
    }

    private static func splitDetail(_ body: String) -> (String, String?) {
        guard body.hasSuffix(")"),
              let open = body.lastIndex(of: "("),
              open > body.startIndex else {
            return (body, nil)
        }
        let title = body[..<open].trimmingCharacters(in: .whitespacesAndNewlines)
        let detail = body[open...].trimmingCharacters(in: .whitespacesAndNewlines)
        return (title.isEmpty ? body : title, detail)
    }

    private static func stripANSI(_ input: String) -> String {
        let pattern = "\u{001B}\\[[0-?]*[ -/]*[@-~]"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return input
        }
        let range = NSRange(input.startIndex..., in: input)
        return regex.stringByReplacingMatches(in: input, options: [], range: range, withTemplate: "")
    }

    private static func firstInteger(in line: String) -> Int? {
        firstInteger(matching: #"(\d+)"#, in: line)
    }

    private static func firstInteger(matching pattern: String, in line: String) -> Int? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: line) else {
            return nil
        }
        return Int(line[range])
    }

    private static func uniquedChecks(_ checks: [HermesDoctorCheck]) -> [HermesDoctorCheck] {
        var seen = Set<String>()
        return checks.filter { check in
            if seen.contains(check.id) {
                return false
            }
            seen.insert(check.id)
            return true
        }
    }

    private static let sectionMarker = "\u{25C6}"
    private static let okMarker = "\u{2713}"
    private static let warningMarker = "\u{26A0}"
    private static let failureMarker = "\u{2717}"
    private static let infoMarker = "\u{2192}"
}
