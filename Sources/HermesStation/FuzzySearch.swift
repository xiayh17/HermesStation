import Foundation

enum FuzzySearch {
    static func ranked<Item>(_ items: [Item], query rawQuery: String, fields: (Item) -> [String]) -> [Item] {
        let query = normalize(rawQuery)
        guard !query.isEmpty else { return items }

        let rankedMatches: [RankedMatch<Item>] = items
            .enumerated()
            .compactMap { entry in
                let (offset, item) = entry
                guard let score = scoredBestMatch(query: query, fields: fields(item)) else { return nil }
                return RankedMatch(item: item, score: score, offset: offset)
            }

        return rankedMatches
            .sorted { lhs, rhs in
                if lhs.score != rhs.score {
                    return lhs.score > rhs.score
                }
                return lhs.offset < rhs.offset
            }
            .map(\.item)
    }

    static func bestScore(query rawQuery: String, fields: [String]) -> Int? {
        let query = normalize(rawQuery)
        guard !query.isEmpty else { return nil }
        return scoredBestMatch(query: query, fields: fields)
    }

    private static func scoredBestMatch(query: String, fields rawFields: [String]) -> Int? {
        let fields = rawFields
            .map(normalize)
            .filter { !$0.isEmpty }

        guard !fields.isEmpty else { return nil }

        var scores: [Int] = []
        for (index, field) in fields.enumerated() {
            guard let score = score(query: query, candidate: field) else { continue }
            let fieldPriorityBonus = max(0, (fields.count - index) * 12)
            scores.append(score + fieldPriorityBonus)
        }

        if fields.count > 1,
           let combinedScore = score(query: query, candidate: fields.joined(separator: " ")) {
            scores.append(combinedScore)
        }

        return scores.max()
    }

    private static func score(query: String, candidate: String) -> Int? {
        if candidate == query {
            return 4_000
        }

        if candidate.hasPrefix(query) {
            return 3_500 - min(candidate.count - query.count, 400)
        }

        if let range = candidate.range(of: query) {
            let distance = candidate.distance(from: candidate.startIndex, to: range.lowerBound)
            return 3_100 - min(distance, 500)
        }

        let tokens = query.split(separator: " ").map(String.init).filter { !$0.isEmpty }
        if tokens.count > 1 {
            var total = 0
            for token in tokens {
                guard let tokenScore = scoreSingleToken(token, in: candidate) else { return nil }
                total += tokenScore
            }
            return 2_300 + total / max(tokens.count, 1)
        }

        return subsequenceScore(query: query, candidate: candidate)
    }

    private static func scoreSingleToken(_ token: String, in candidate: String) -> Int? {
        if candidate == token {
            return 1_600
        }

        if candidate.hasPrefix(token) {
            return 1_400 - min(candidate.count - token.count, 200)
        }

        if let range = candidate.range(of: token) {
            let distance = candidate.distance(from: candidate.startIndex, to: range.lowerBound)
            return 1_200 - min(distance, 300)
        }

        return subsequenceScore(query: token, candidate: candidate).map { 700 + $0 }
    }

    private static func subsequenceScore(query: String, candidate: String) -> Int? {
        let compactQuery = query.replacingOccurrences(of: " ", with: "")
        let compactCandidate = candidate.replacingOccurrences(of: " ", with: "")

        guard !compactQuery.isEmpty, compactQuery.count <= compactCandidate.count else {
            return nil
        }

        var queryIndex = compactQuery.startIndex
        var candidateOffset = 0
        var startOffset: Int?
        var gapCount = 0
        var consecutiveMatches = 0
        var previousMatchOffset: Int?

        for character in compactCandidate {
            guard queryIndex < compactQuery.endIndex else { break }

            if character == compactQuery[queryIndex] {
                if startOffset == nil {
                    startOffset = candidateOffset
                }
                if let previousMatchOffset, candidateOffset == previousMatchOffset + 1 {
                    consecutiveMatches += 1
                }
                previousMatchOffset = candidateOffset
                queryIndex = compactQuery.index(after: queryIndex)
            } else if startOffset != nil {
                gapCount += 1
            }

            candidateOffset += 1
        }

        guard queryIndex == compactQuery.endIndex else { return nil }

        let startPenalty = min(startOffset ?? 0, 80)
        let compactnessBonus = consecutiveMatches * 18
        let gapPenalty = gapCount * 4
        let lengthBonus = compactQuery.count * 20

        return max(1, 900 + lengthBonus + compactnessBonus - gapPenalty - startPenalty)
    }

    private static func normalize(_ text: String) -> String {
        text
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }
}

private struct RankedMatch<Item> {
    let item: Item
    let score: Int
    let offset: Int
}
