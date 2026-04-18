import Foundation

struct SessionBindingOrigin: Decodable, Hashable {
    let platform: String?
    let chatID: String?
    let chatName: String?
    let chatType: String?
    let userID: String?
    let userName: String?
    let threadID: String?
    let chatTopic: String?
    let userIDAlt: String?

    enum CodingKeys: String, CodingKey {
        case platform
        case chatID = "chat_id"
        case chatName = "chat_name"
        case chatType = "chat_type"
        case userID = "user_id"
        case userName = "user_name"
        case threadID = "thread_id"
        case chatTopic = "chat_topic"
        case userIDAlt = "user_id_alt"
    }
}

struct SessionBindingEntry: Identifiable, Decodable, Hashable {
    let sessionKey: String
    let sessionID: String
    let createdAt: String?
    let updatedAt: String?
    let displayName: String?
    let platform: String?
    let chatType: String?
    let memoryFlushed: Bool?
    let suspended: Bool?
    let origin: SessionBindingOrigin?

    enum CodingKeys: String, CodingKey {
        case sessionKey = "session_key"
        case sessionID = "session_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case displayName = "display_name"
        case platform
        case chatType = "chat_type"
        case memoryFlushed = "memory_flushed"
        case suspended
        case origin
    }

    var id: String { sessionKey }

    var resolvedPlatformID: String {
        if let platform = platform?.trimmingCharacters(in: .whitespacesAndNewlines), !platform.isEmpty {
            return platform
        }
        if let platform = origin?.platform?.trimmingCharacters(in: .whitespacesAndNewlines), !platform.isEmpty {
            return platform
        }
        return SessionBindingStore.platformID(from: sessionKey)
    }

    var updatedAtDate: Date? {
        SessionBindingStore.parseDate(updatedAt)
    }

    var createdAtDate: Date? {
        SessionBindingStore.parseDate(createdAt)
    }

    var displayLabel: String {
        firstNonEmpty(
            displayName,
            origin?.chatName,
            origin?.userName,
            origin?.chatID,
            origin?.userIDAlt,
            origin?.userID
        ) ?? sessionID
    }

    var displaySubtitle: String {
        let pieces = [
            origin?.chatType ?? chatType,
            origin?.chatTopic,
            origin?.threadID
        ]
        .compactMap { value in
            let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return trimmed.isEmpty ? nil : trimmed
        }

        return pieces.joined(separator: " · ")
    }

    private func firstNonEmpty(_ values: String?...) -> String? {
        values.first { value in
            guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) else { return false }
            return !trimmed.isEmpty
        } ?? nil
    }
}

enum SessionBindingStore {
    static func load(from url: URL) -> [SessionBindingEntry] {
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else {
            return []
        }

        guard let decoded = try? JSONDecoder().decode([String: SessionBindingEntry].self, from: data) else {
            return []
        }

        return decoded.values.sorted { lhs, rhs in
            let lhsDate = lhs.updatedAtDate ?? lhs.createdAtDate ?? .distantPast
            let rhsDate = rhs.updatedAtDate ?? rhs.createdAtDate ?? .distantPast
            if lhsDate != rhsDate {
                return lhsDate > rhsDate
            }
            return lhs.sessionID > rhs.sessionID
        }
    }

    static func platformID(from sessionKey: String) -> String {
        let pieces = sessionKey.split(separator: ":").map(String.init)
        if pieces.count >= 3, pieces[0] == "agent", pieces[1] == "main" {
            return pieces[2]
        }
        return pieces.first ?? "unknown"
    }

    static func parseDate(_ value: String?) -> Date? {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: value)
    }
}
