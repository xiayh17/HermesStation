import Foundation

struct RuntimePlatformState: Decodable {
    let state: String?
    let errorCode: String?
    let errorMessage: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case state
        case errorCode = "error_code"
        case errorMessage = "error_message"
        case updatedAt = "updated_at"
    }
}

struct RuntimeSessionInfo: Decodable {
    let sessionKey: String?
    let model: String?

    enum CodingKeys: String, CodingKey {
        case sessionKey = "session_key"
        case model
    }
}

struct RuntimeModelOverrideInfo: Decodable {
    let sessionKey: String?
    let overrideModel: String?

    enum CodingKeys: String, CodingKey {
        case sessionKey = "session_key"
        case overrideModel = "override_model"
    }
}

struct RuntimeStatus: Decodable {
    let gatewayState: String?
    let exitReason: String?
    let restartRequested: Bool?
    let activeAgents: Int?
    let updatedAt: String?
    let pid: Int?
    let platforms: [String: RuntimePlatformState]
    let activeSessions: [String: [RuntimeSessionInfo]]?
    let modelOverrides: [String: [RuntimeModelOverrideInfo]]?

    enum CodingKeys: String, CodingKey {
        case gatewayState = "gateway_state"
        case exitReason = "exit_reason"
        case restartRequested = "restart_requested"
        case activeAgents = "active_agents"
        case updatedAt = "updated_at"
        case pid
        case platforms
        case activeSessions = "active_sessions"
        case modelOverrides = "model_overrides"
    }
}

enum ServiceStatus: String {
    case running
    case stopped
    case degraded
    case unknown

    var symbol: String {
        switch self {
        case .running: return "bolt.circle.fill"
        case .stopped: return "bolt.slash.circle"
        case .degraded: return "exclamationmark.triangle.fill"
        case .unknown: return "questionmark.circle"
        }
    }
}

struct GatewaySnapshot {
    var serviceInstalled: Bool
    var serviceLoaded: Bool
    var serviceStatus: ServiceStatus
    var runtime: RuntimeStatus?
    var sessions: SessionSummary
    var agentSessions: AgentSessionSummary
    var usage: ModelUsageSummary
    var lastCommandOutput: String?

    static let empty = GatewaySnapshot(
        serviceInstalled: false,
        serviceLoaded: false,
        serviceStatus: .unknown,
        runtime: nil,
        sessions: SessionSummary(totalCount: 0, recent: []),
        agentSessions: .empty,
        usage: .empty,
        lastCommandOutput: nil
    )

    var menuBarSymbol: String {
        serviceStatus.symbol
    }
}
