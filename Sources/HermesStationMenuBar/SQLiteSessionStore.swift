import Foundation
import SQLite3

struct SessionRow: Identifiable {
    let id: String
    let title: String
    let updatedAt: String
    let transcriptURL: URL
}

struct SessionSummary {
    let totalCount: Int
    let recent: [SessionRow]
}

struct AgentSessionRow: Identifiable, Equatable {
    let id: String
    let title: String
    let source: String
    let model: String
    let startedAt: Double
    let startedAtText: String
    let endedAtText: String
    let statusText: String
    let endReason: String
    let messageCount: Int
    let toolCallCount: Int
    let inputTokens: Int
    let outputTokens: Int
    let estimatedCostText: String
    let transcriptURL: URL
    let isActive: Bool
}

struct AgentSessionSummary {
    let totalCount: Int
    let activeCount: Int
    let rows: [AgentSessionRow]

    static let empty = AgentSessionSummary(totalCount: 0, activeCount: 0, rows: [])
}

struct UsageTotals: Equatable {
    let sessionCount: Int
    let inputTokens: Int
    let outputTokens: Int
    let toolCallCount: Int
    let totalCostUSD: Double

    static let empty = UsageTotals(sessionCount: 0, inputTokens: 0, outputTokens: 0, toolCallCount: 0, totalCostUSD: 0)

    var totalTokens: Int {
        inputTokens + outputTokens
    }
}

struct ModelUsageRow: Identifiable, Equatable {
    let id: String
    let model: String
    let provider: String
    let source: String
    let sessionCount: Int
    let inputTokens: Int
    let outputTokens: Int
    let toolCallCount: Int
    let totalCostUSD: Double
    let lastUsedAt: Double
    let lastUsedText: String

    var totalTokens: Int {
        inputTokens + outputTokens
    }
}

struct UsageTimeBucket: Identifiable, Equatable {
    let id: String
    let bucketStart: Double
    let sessionCount: Int
    let inputTokens: Int
    let outputTokens: Int
    let toolCallCount: Int
    let totalCostUSD: Double

    var totalTokens: Int {
        inputTokens + outputTokens
    }
}

struct ModelUsageSummary: Equatable {
    let last24Hours: UsageTotals
    let last7Days: UsageTotals
    let allTime: UsageTotals
    let last24HourRows: [ModelUsageRow]
    let last7DayRows: [ModelUsageRow]
    let allTimeRows: [ModelUsageRow]
    let last24HourBuckets: [UsageTimeBucket]
    let last7DayBuckets: [UsageTimeBucket]
    let allTimeBuckets: [UsageTimeBucket]

    static let empty = ModelUsageSummary(
        last24Hours: .empty,
        last7Days: .empty,
        allTime: .empty,
        last24HourRows: [],
        last7DayRows: [],
        allTimeRows: [],
        last24HourBuckets: [],
        last7DayBuckets: [],
        allTimeBuckets: []
    )
}

private enum UsageBucketGranularity {
    case hourly
    case daily
    case weekly

    var seconds: Double {
        switch self {
        case .hourly: return 3600
        case .daily: return 86400
        case .weekly: return 604800
        }
    }
}

enum SQLiteSessionStore {
    static func load(from dbURL: URL, paths: HermesPaths) -> SessionSummary {
        let agents = loadAgents(from: dbURL, paths: paths)
        let recent = agents.rows.prefix(5).map {
            SessionRow(id: $0.id, title: $0.title, updatedAt: $0.startedAtText, transcriptURL: $0.transcriptURL)
        }
        return SessionSummary(totalCount: agents.totalCount, recent: recent)
    }

    static func loadAgents(from dbURL: URL, paths: HermesPaths) -> AgentSessionSummary {
        guard FileManager.default.fileExists(atPath: dbURL.path) else {
            return .empty
        }

        var db: OpaquePointer?
        guard sqlite3_open_v2(dbURL.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let db else {
            return .empty
        }
        defer { sqlite3_close(db) }

        let rows = queryAgents(db, paths: paths)
        let activeCount = rows.filter(\.isActive).count
        return AgentSessionSummary(totalCount: rows.count, activeCount: activeCount, rows: rows)
    }

    static func loadUsage(from dbURL: URL) -> ModelUsageSummary {
        guard FileManager.default.fileExists(atPath: dbURL.path) else {
            return .empty
        }

        var db: OpaquePointer?
        guard sqlite3_open_v2(dbURL.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let db else {
            return .empty
        }
        defer { sqlite3_close(db) }

        let now = Date().timeIntervalSince1970
        let last24Cutoff = now - 24 * 60 * 60
        let last7Cutoff = now - 7 * 24 * 60 * 60
        let last24Hours = queryUsageTotals(db, cutoff: last24Cutoff)
        let last7Days = queryUsageTotals(db, cutoff: last7Cutoff)
        let allTime = queryUsageTotals(db, cutoff: nil)
        let last24HourRows = queryUsageRows(db, cutoff: last24Cutoff)
        let last7DayRows = queryUsageRows(db, cutoff: last7Cutoff)
        let allTimeRows = queryUsageRows(db, cutoff: nil)
        let last24HourBuckets = queryUsageBuckets(db, cutoff: last24Cutoff, granularity: .hourly)
        let last7DayBuckets = queryUsageBuckets(db, cutoff: last7Cutoff, granularity: .daily)
        let allTimeBuckets = queryUsageBuckets(db, cutoff: nil, granularity: .weekly)

        return ModelUsageSummary(
            last24Hours: last24Hours,
            last7Days: last7Days,
            allTime: allTime,
            last24HourRows: last24HourRows,
            last7DayRows: last7DayRows,
            allTimeRows: allTimeRows,
            last24HourBuckets: last24HourBuckets,
            last7DayBuckets: last7DayBuckets,
            allTimeBuckets: allTimeBuckets
        )
    }

    private static func queryAgents(_ db: OpaquePointer, paths: HermesPaths) -> [AgentSessionRow] {
        let sql = """
        SELECT
            id,
            COALESCE(NULLIF(title, ''), id),
            COALESCE(source, ''),
            COALESCE(model, ''),
            started_at,
            ended_at,
            COALESCE(end_reason, ''),
            COALESCE(message_count, 0),
            COALESCE(tool_call_count, 0),
            COALESCE(input_tokens, 0),
            COALESCE(output_tokens, 0),
            COALESCE(actual_cost_usd, estimated_cost_usd)
        FROM sessions
        ORDER BY started_at DESC
        LIMIT 200;
        """

        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            return []
        }

        var rows: [AgentSessionRow] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = stringColumn(stmt, index: 0)
            let title = stringColumn(stmt, index: 1)
            let source = stringColumn(stmt, index: 2)
            let model = stringColumn(stmt, index: 3)
            let startedAt = doubleColumn(stmt, index: 4)
            let endedAt = optionalDoubleColumn(stmt, index: 5)
            let endReason = stringColumn(stmt, index: 6)
            let messageCount = intColumn(stmt, index: 7)
            let toolCallCount = intColumn(stmt, index: 8)
            let inputTokens = intColumn(stmt, index: 9)
            let outputTokens = intColumn(stmt, index: 10)
            let costUSD = optionalDoubleColumn(stmt, index: 11)

            let isActive = endedAt == nil
            let endedAtText = endedAt.map(formatTimestamp) ?? "Running"
            let statusText: String
            if isActive {
                statusText = "Running"
            } else if !endReason.isEmpty {
                statusText = endReason
            } else {
                statusText = "Completed"
            }

            rows.append(
                AgentSessionRow(
                    id: id,
                    title: title,
                    source: source,
                    model: model,
                    startedAt: startedAt,
                    startedAtText: formatTimestamp(startedAt),
                    endedAtText: endedAtText,
                    statusText: statusText,
                    endReason: endReason,
                    messageCount: messageCount,
                    toolCallCount: toolCallCount,
                    inputTokens: inputTokens,
                    outputTokens: outputTokens,
                    estimatedCostText: formatCost(costUSD),
                    transcriptURL: paths.transcriptURL(for: id),
                    isActive: isActive
                )
            )
        }
        return rows
    }

    private static func queryUsageTotals(_ db: OpaquePointer, cutoff: Double?) -> UsageTotals {
        let sql = """
        SELECT
            COUNT(*),
            COALESCE(SUM(input_tokens), 0),
            COALESCE(SUM(output_tokens), 0),
            COALESCE(SUM(tool_call_count), 0),
            COALESCE(SUM(COALESCE(actual_cost_usd, estimated_cost_usd, 0)), 0)
        FROM sessions
        WHERE (?1 IS NULL OR started_at >= ?1);
        """

        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            return .empty
        }

        if let cutoff {
            sqlite3_bind_double(stmt, 1, cutoff)
        } else {
            sqlite3_bind_null(stmt, 1)
        }

        guard sqlite3_step(stmt) == SQLITE_ROW else {
            return .empty
        }

        return UsageTotals(
            sessionCount: intColumn(stmt, index: 0),
            inputTokens: intColumn(stmt, index: 1),
            outputTokens: intColumn(stmt, index: 2),
            toolCallCount: intColumn(stmt, index: 3),
            totalCostUSD: doubleColumn(stmt, index: 4)
        )
    }

    private static func queryUsageRows(_ db: OpaquePointer, cutoff: Double?) -> [ModelUsageRow] {
        let sql = """
        SELECT
            COALESCE(NULLIF(model, ''), '(unknown)'),
            COALESCE(NULLIF(billing_provider, ''), '(unknown)'),
            COALESCE(NULLIF(source, ''), '(unknown)'),
            COUNT(*) AS session_count,
            COALESCE(SUM(input_tokens), 0),
            COALESCE(SUM(output_tokens), 0),
            COALESCE(SUM(tool_call_count), 0),
            COALESCE(SUM(COALESCE(actual_cost_usd, estimated_cost_usd, 0)), 0),
            COALESCE(MAX(started_at), 0)
        FROM sessions
        WHERE (?1 IS NULL OR started_at >= ?1)
        GROUP BY model, billing_provider, source
        ORDER BY COALESCE(SUM(COALESCE(actual_cost_usd, estimated_cost_usd, 0)), 0) DESC,
                 COUNT(*) DESC,
                 COALESCE(MAX(started_at), 0) DESC;
        """

        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            return []
        }

        if let cutoff {
            sqlite3_bind_double(stmt, 1, cutoff)
        } else {
            sqlite3_bind_null(stmt, 1)
        }

        var rows: [ModelUsageRow] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let model = stringColumn(stmt, index: 0)
            let provider = stringColumn(stmt, index: 1)
            let source = stringColumn(stmt, index: 2)
            let sessionCount = intColumn(stmt, index: 3)
            let inputTokens = intColumn(stmt, index: 4)
            let outputTokens = intColumn(stmt, index: 5)
            let toolCallCount = intColumn(stmt, index: 6)
            let totalCostUSD = doubleColumn(stmt, index: 7)
            let lastUsedAt = doubleColumn(stmt, index: 8)

            rows.append(
                ModelUsageRow(
                    id: "\(model)|\(provider)|\(source)",
                    model: model,
                    provider: provider,
                    source: source,
                    sessionCount: sessionCount,
                    inputTokens: inputTokens,
                    outputTokens: outputTokens,
                    toolCallCount: toolCallCount,
                    totalCostUSD: totalCostUSD,
                    lastUsedAt: lastUsedAt,
                    lastUsedText: formatTimestamp(lastUsedAt)
                )
            )
        }

        return rows
    }

    private static func queryUsageBuckets(_ db: OpaquePointer, cutoff: Double?, granularity: UsageBucketGranularity) -> [UsageTimeBucket] {
        let bucketSeconds = granularity.seconds
        let sql = """
        SELECT
            CAST(started_at / ?2 AS INTEGER) * ?2 AS bucket_start,
            COUNT(*),
            COALESCE(SUM(input_tokens), 0),
            COALESCE(SUM(output_tokens), 0),
            COALESCE(SUM(tool_call_count), 0),
            COALESCE(SUM(COALESCE(actual_cost_usd, estimated_cost_usd, 0)), 0)
        FROM sessions
        WHERE (?1 IS NULL OR started_at >= ?1)
        GROUP BY bucket_start
        ORDER BY bucket_start ASC;
        """

        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            return []
        }

        if let cutoff {
            sqlite3_bind_double(stmt, 1, cutoff)
        } else {
            sqlite3_bind_null(stmt, 1)
        }
        sqlite3_bind_double(stmt, 2, bucketSeconds)

        var rows: [UsageTimeBucket] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let bucketStart = doubleColumn(stmt, index: 0)
            rows.append(
                UsageTimeBucket(
                    id: "\(bucketStart)",
                    bucketStart: bucketStart,
                    sessionCount: intColumn(stmt, index: 1),
                    inputTokens: intColumn(stmt, index: 2),
                    outputTokens: intColumn(stmt, index: 3),
                    toolCallCount: intColumn(stmt, index: 4),
                    totalCostUSD: doubleColumn(stmt, index: 5)
                )
            )
        }

        return rows
    }

    private static func intColumn(_ stmt: OpaquePointer?, index: Int32) -> Int {
        Int(sqlite3_column_int(stmt, index))
    }

    private static func doubleColumn(_ stmt: OpaquePointer?, index: Int32) -> Double {
        sqlite3_column_double(stmt, index)
    }

    private static func optionalDoubleColumn(_ stmt: OpaquePointer?, index: Int32) -> Double? {
        guard sqlite3_column_type(stmt, index) != SQLITE_NULL else { return nil }
        return sqlite3_column_double(stmt, index)
    }

    private static func stringColumn(_ stmt: OpaquePointer?, index: Int32) -> String {
        guard let ptr = sqlite3_column_text(stmt, index) else { return "" }
        return String(cString: ptr)
    }

    private static func formatTimestamp(_ value: Double) -> String {
        guard value > 0 else { return "n/a" }
        return sessionDateFormatter.string(from: Date(timeIntervalSince1970: value))
    }

    private static func formatCost(_ value: Double?) -> String {
        guard let value else { return "n/a" }
        return String(format: "$%.4f", value)
    }

    private static let sessionDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
}
