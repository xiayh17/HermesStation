import Foundation

struct MemoryCatalogEntry: Identifiable, Hashable {
    let id: String
    let source: String
    let title: String
    let preview: String
    let body: String
    let fileURL: URL
    let modifiedAt: Date?
}

struct SkillCatalogEntry: Identifiable, Hashable {
    let id: String
    let identifier: String
    let name: String
    let description: String
    let version: String?
    let author: String?
    let homepage: String?
    let license: String?
    let categoryPath: String
    let relativePath: String
    let folderURL: URL
    let fileURL: URL
    let platforms: [String]
    let tags: [String]
    let prerequisites: [String]
    let body: String
    let isEnabled: Bool
    let hash: String?
}

enum HermesKnowledgeCatalog {
    static func loadMemoryEntries(from hermesHome: URL) -> [MemoryCatalogEntry] {
        let directoryURL = hermesHome.appending(path: "memories", directoryHint: .isDirectory)
        guard FileManager.default.fileExists(atPath: directoryURL.path) else {
            return []
        }

        let files = (try? FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        let markdownFiles = files
            .filter { $0.pathExtension.lowercased() == "md" }
            .filter { !$0.lastPathComponent.hasSuffix(".lock") }
            .sorted { lhs, rhs in
                let lhsDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let rhsDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                if lhsDate != rhsDate {
                    return lhsDate > rhsDate
                }
                return lhs.lastPathComponent < rhs.lastPathComponent
            }

        var entries: [MemoryCatalogEntry] = []

        for fileURL in markdownFiles {
            guard let contents = try? String(contentsOf: fileURL, encoding: .utf8) else {
                continue
            }

            let chunks = splitMemoryChunks(contents)
            let source = fileURL.deletingPathExtension().lastPathComponent.uppercased()
            let modifiedAt = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate

            for (index, chunk) in chunks.enumerated() {
                let preview = singleLinePreview(chunk, limit: 180)
                let title = memoryTitle(for: chunk, fallback: "\(source) \(index + 1)")
                entries.append(
                    MemoryCatalogEntry(
                        id: "\(source)-\(index)",
                        source: source,
                        title: title,
                        preview: preview,
                        body: chunk,
                        fileURL: fileURL,
                        modifiedAt: modifiedAt ?? nil
                    )
                )
            }
        }

        return entries
    }

    static func loadSkills(from hermesHome: URL) -> [SkillCatalogEntry] {
        let skillsRoot = hermesHome.appending(path: "skills", directoryHint: .isDirectory)
        guard FileManager.default.fileExists(atPath: skillsRoot.path) else {
            return []
        }

        let manifest = loadBundledManifest(from: skillsRoot)
        guard let enumerator = FileManager.default.enumerator(
            at: skillsRoot,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var skills: [SkillCatalogEntry] = []

        for case let fileURL as URL in enumerator {
            guard fileURL.lastPathComponent == "SKILL.md" else { continue }
            guard let skill = parseSkill(at: fileURL, skillsRoot: skillsRoot, manifest: manifest) else {
                continue
            }
            skills.append(skill)
        }

        return skills.sorted { lhs, rhs in
            if lhs.isEnabled != rhs.isEnabled {
                return lhs.isEnabled && !rhs.isEnabled
            }
            if lhs.categoryPath != rhs.categoryPath {
                return lhs.categoryPath < rhs.categoryPath
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private static func splitMemoryChunks(_ contents: String) -> [String] {
        var chunks: [String] = []
        var current: [String] = []

        for rawLine in contents.replacingOccurrences(of: "\r\n", with: "\n").split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            if line.trimmingCharacters(in: .whitespacesAndNewlines) == "§" {
                let chunk = current.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                if !chunk.isEmpty {
                    chunks.append(chunk)
                }
                current.removeAll(keepingCapacity: true)
                continue
            }
            current.append(line)
        }

        let tail = current.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty {
            chunks.append(tail)
        }

        return chunks
    }

    private static func memoryTitle(for chunk: String, fallback: String) -> String {
        let firstLine = chunk
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }

        guard let firstLine else { return fallback }
        return truncate(firstLine, limit: 90)
    }

    private static func loadBundledManifest(from skillsRoot: URL) -> [String: String] {
        let manifestURL = skillsRoot.appending(path: ".bundled_manifest")
        guard let contents = try? String(contentsOf: manifestURL, encoding: .utf8) else {
            return [:]
        }

        var manifest: [String: String] = [:]
        for rawLine in contents.replacingOccurrences(of: "\r\n", with: "\n").split(separator: "\n") {
            let line = String(rawLine).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }
            let pieces = line.split(separator: ":", maxSplits: 1).map(String.init)
            guard pieces.count == 2 else { continue }
            manifest[pieces[0]] = pieces[1]
        }
        return manifest
    }

    private static func parseSkill(at fileURL: URL, skillsRoot: URL, manifest: [String: String]) -> SkillCatalogEntry? {
        guard let contents = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return nil
        }

        let document = FrontmatterDocument(document: contents)
        let folderURL = fileURL.deletingLastPathComponent()
        let identifier = folderURL.lastPathComponent
        let relativePath = relativePath(from: skillsRoot, to: folderURL)
        let categoryPath = categoryPath(for: relativePath)
        let name = document.topLevelScalar("name") ?? identifier
        let description = document.topLevelScalar("description") ?? firstMeaningfulLine(in: document.body) ?? "No description."
        let platforms = document.list(for: "platforms", topLevelOnly: true)
        let fallbackPlatforms = platforms.isEmpty ? document.jsonList(for: "os") : []
        let tags = document.list(for: "tags")
        let prerequisites = document.list(for: "commands")
        let enabledHash = manifest[identifier] ?? manifest[name]

        return SkillCatalogEntry(
            id: identifier,
            identifier: identifier,
            name: name,
            description: description,
            version: document.topLevelScalar("version"),
            author: document.topLevelScalar("author"),
            homepage: document.topLevelScalar("homepage"),
            license: document.topLevelScalar("license"),
            categoryPath: categoryPath,
            relativePath: relativePath,
            folderURL: folderURL,
            fileURL: fileURL,
            platforms: uniqueValues(platforms + fallbackPlatforms),
            tags: uniqueValues(tags),
            prerequisites: uniqueValues(prerequisites),
            body: document.body.trimmingCharacters(in: .whitespacesAndNewlines),
            isEnabled: enabledHash != nil,
            hash: enabledHash
        )
    }

    private static func relativePath(from root: URL, to target: URL) -> String {
        let rootPath = root.standardizedFileURL.path
        let targetPath = target.standardizedFileURL.path
        guard targetPath.hasPrefix(rootPath) else { return target.lastPathComponent }

        let offset = targetPath.index(targetPath.startIndex, offsetBy: rootPath.count)
        let suffix = String(targetPath[offset...]).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return suffix.isEmpty ? target.lastPathComponent : suffix
    }

    private static func categoryPath(for relativePath: String) -> String {
        let components = relativePath.split(separator: "/").map(String.init)
        guard components.count > 1 else { return "Uncategorized" }
        return components.dropLast().map(humanizePathComponent).joined(separator: " / ")
    }

    private static func humanizePathComponent(_ component: String) -> String {
        component
            .split(separator: "-")
            .map { fragment in
                guard let first = fragment.first else { return "" }
                return String(first).uppercased() + fragment.dropFirst()
            }
            .joined(separator: " ")
    }

    private static func singleLinePreview(_ text: String, limit: Int) -> String {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return truncate(normalized, limit: limit)
    }

    private static func truncate(_ text: String, limit: Int) -> String {
        guard text.count > limit else { return text }
        let index = text.index(text.startIndex, offsetBy: limit)
        return text[..<index].trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }

    private static func firstMeaningfulLine(in body: String) -> String? {
        body
            .replacingOccurrences(of: "\r\n", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { line in
                !line.isEmpty && !line.hasPrefix("#")
            }
    }

    private static func uniqueValues(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        var result: [String] = []

        for value in values {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = trimmed.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(trimmed)
        }

        return result
    }
}

private struct FrontmatterDocument {
    let frontmatter: String
    let body: String
    private let lines: [String]

    init(document: String) {
        let normalized = document.replacingOccurrences(of: "\r\n", with: "\n")
        let separated = normalized.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        guard separated.first == "---" else {
            self.frontmatter = ""
            self.body = normalized.trimmingCharacters(in: .whitespacesAndNewlines)
            self.lines = []
            return
        }

        var closingIndex: Int?
        for index in separated.indices.dropFirst() where separated[index] == "---" {
            closingIndex = index
            break
        }

        guard let closingIndex else {
            self.frontmatter = ""
            self.body = normalized.trimmingCharacters(in: .whitespacesAndNewlines)
            self.lines = []
            return
        }

        self.frontmatter = separated[1..<closingIndex].joined(separator: "\n")
        self.body = separated.dropFirst(closingIndex + 1).joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.lines = self.frontmatter.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    }

    func topLevelScalar(_ key: String) -> String? {
        for line in lines {
            guard indentation(of: line) == 0 else { continue }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("\(key):") else { continue }
            let value = String(trimmed.dropFirst(key.count + 1)).trimmingCharacters(in: .whitespaces)
            return sanitizeScalar(value)
        }
        return nil
    }

    func list(for key: String, topLevelOnly: Bool = false) -> [String] {
        if let inline = inlineList(for: key, topLevelOnly: topLevelOnly), !inline.isEmpty {
            return inline
        }
        if let block = blockList(for: key, topLevelOnly: topLevelOnly), !block.isEmpty {
            return block
        }
        return jsonList(for: key)
    }

    func jsonList(for key: String) -> [String] {
        let pattern = #""\#(key)"\s*:\s*\[(.*?)\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]),
              let match = regex.firstMatch(in: frontmatter, range: NSRange(frontmatter.startIndex..., in: frontmatter)),
              let range = Range(match.range(at: 1), in: frontmatter) else {
            return []
        }

        let raw = String(frontmatter[range])
        return parseInlineList(raw)
    }

    private func inlineList(for key: String, topLevelOnly: Bool) -> [String]? {
        for line in lines {
            if topLevelOnly && indentation(of: line) != 0 {
                continue
            }

            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("\(key):") else { continue }

            let value = String(trimmed.dropFirst(key.count + 1)).trimmingCharacters(in: .whitespaces)
            guard value.hasPrefix("[") && value.hasSuffix("]") else { continue }
            return parseInlineList(String(value.dropFirst().dropLast()))
        }
        return nil
    }

    private func blockList(for key: String, topLevelOnly: Bool) -> [String]? {
        for index in lines.indices {
            let line = lines[index]
            let currentIndent = indentation(of: line)
            if topLevelOnly && currentIndent != 0 {
                continue
            }

            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed == "\(key):" else { continue }

            var result: [String] = []
            var cursor = index + 1

            while cursor < lines.count {
                let nextLine = lines[cursor]
                let nextTrimmed = nextLine.trimmingCharacters(in: .whitespaces)

                if nextTrimmed.isEmpty {
                    cursor += 1
                    continue
                }

                let nextIndent = indentation(of: nextLine)
                if nextIndent <= currentIndent {
                    break
                }

                if nextTrimmed.hasPrefix("- ") {
                    result.append(sanitizeScalar(String(nextTrimmed.dropFirst(2))))
                }

                cursor += 1
            }

            return result
        }
        return nil
    }

    private func parseInlineList(_ raw: String) -> [String] {
        raw.split(separator: ",")
            .map { sanitizeScalar(String($0)) }
            .filter { !$0.isEmpty }
    }

    private func sanitizeScalar(_ raw: String) -> String {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("\""), value.hasSuffix("\""), value.count >= 2 {
            value = String(value.dropFirst().dropLast())
        } else if value.hasPrefix("'"), value.hasSuffix("'"), value.count >= 2 {
            value = String(value.dropFirst().dropLast())
        }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func indentation(of line: String) -> Int {
        var count = 0
        for character in line {
            if character == " " {
                count += 1
            } else if character == "\t" {
                count += 4
            } else {
                break
            }
        }
        return count
    }
}
