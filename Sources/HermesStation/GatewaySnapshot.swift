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

struct HermesReleaseInfo {
    let currentVersion: String?
    let currentTag: String?
    let latestVersion: String?
    let latestTag: String?
    let releaseURL: URL?
    let publishedAt: String?
    let body: String?
    let isUpdateAvailable: Bool
    let globalHermesPath: String?
    let globalHermesTarget: String?
    let globalHermesVersion: String?
    let isGlobalHermesMatching: Bool
    let fetchError: String?
}

struct GitHubRelease: Decodable {
    let tagName: String
    let name: String?
    let htmlUrl: String?
    let publishedAt: String?
    let body: String?
    let prerelease: Bool
    let draft: Bool

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case htmlUrl = "html_url"
        case publishedAt = "published_at"
        case body
        case prerelease
        case draft
    }
}

struct EndpointSourceSnapshot {
    let label: String
    let value: String?
    let detail: String?
    let isMismatch: Bool
}

struct CredentialPoolEntrySnapshot: Identifiable {
    let id: String
    let label: String
    let source: String?
    let baseURL: String?
    let requestCount: Int?
}

struct LatestRequestDumpSnapshot {
    let fileURL: URL
    let timestamp: String?
    let reason: String?
    let method: String?
    let requestURL: String?
    let requestBaseURL: String?
    let model: String?
    let errorType: String?
    let errorMessage: String?
}

struct EndpointTransparencySnapshot {
    let provider: String
    let model: String
    let configBaseURL: String?
    let envBaseURLKey: String?
    let envBaseURL: String?
    let credentialPoolEntries: [CredentialPoolEntrySnapshot]
    let latestRequestDump: LatestRequestDumpSnapshot?
    let sourceRows: [EndpointSourceSnapshot]

    var hasMismatch: Bool {
        sourceRows.contains(where: \.isMismatch)
    }
}

struct GatewayProcessInfo: Identifiable {
    let id: Int
    let command: String
    let startTime: Date?
    let isLaunchdManaged: Bool
    let isAuthoritative: Bool
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
    var authoritativeGatewayPID: Int?
    var pidFilePID: Int?
    var runtimeIsStale: Bool
    var runtimeStaleReason: String?
    var duplicateGatewayPIDs: [Int]
    var gatewayProcesses: [GatewayProcessInfo]
    var endpointTransparency: EndpointTransparencySnapshot?
    var releaseInfo: HermesReleaseInfo?
    var sessions: SessionSummary
    var agentSessions: AgentSessionSummary
    var usage: ModelUsageSummary
    var lastCommandOutput: String?

    static let empty = GatewaySnapshot(
        serviceInstalled: false,
        serviceLoaded: false,
        serviceStatus: .unknown,
        runtime: nil,
        authoritativeGatewayPID: nil,
        pidFilePID: nil,
        runtimeIsStale: false,
        runtimeStaleReason: nil,
        duplicateGatewayPIDs: [],
        gatewayProcesses: [],
        endpointTransparency: nil,
        releaseInfo: nil,
        sessions: SessionSummary(totalCount: 0, recent: []),
        agentSessions: .empty,
        usage: .empty,
        lastCommandOutput: nil
    )

    var hasDuplicateGatewayProcesses: Bool {
        gatewayProcesses.count > 1
    }

    var trustedRuntime: RuntimeStatus? {
        runtimeIsStale ? nil : runtime
    }

    var displayPlatforms: [String: RuntimePlatformState]? {
        runtime?.platforms
    }

    var menuBarSymbol: String {
        serviceStatus.symbol
    }
}
