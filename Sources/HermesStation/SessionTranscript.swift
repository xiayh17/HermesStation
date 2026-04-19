import Foundation

struct SessionTranscript: Decodable {
    let sessionId: String
    let model: String?
    let systemPrompt: String?
    let messages: [TranscriptMessage]

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case model
        case systemPrompt = "system_prompt"
        case messages
    }
}

extension SessionTranscript {
    var searchableText: String {
        ([systemPrompt] + messages.map(\.searchableText))
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }
}

struct TranscriptMessage: Decodable, Identifiable {
    let id = UUID()
    let role: String
    let content: String?
    let reasoning: String?
    let toolCalls: [TranscriptToolCall]?
    let toolCallId: String?
    let finishReason: String?

    enum CodingKeys: String, CodingKey {
        case role
        case content
        case reasoning
        case toolCalls = "tool_calls"
        case toolCallId = "tool_call_id"
        case finishReason = "finish_reason"
    }
}

extension TranscriptMessage {
    var searchableText: String? {
        let parts = [
            content,
            reasoning,
            toolCalls?.map(\.searchableText).joined(separator: "\n"),
            toolCallId,
            finishReason,
        ]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: "\n")
    }
}

struct TranscriptToolCall: Decodable, Identifiable {
    let id: String
    let type: String?
    let function: TranscriptToolFunction?

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case function
    }
}

extension TranscriptToolCall {
    var searchableText: String {
        [function?.name, function?.arguments, type, id]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }
}

struct TranscriptToolFunction: Decodable {
    let name: String
    let arguments: String?
}

enum SessionTranscriptLoader {
    static func load(from url: URL) -> SessionTranscript? {
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? JSONDecoder().decode(SessionTranscript.self, from: data)
    }
}
