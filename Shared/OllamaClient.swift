import Foundation

struct Reply: Hashable {
    let angle: String
    let text: String

    var angleLabel: String {
        switch angle.lowercased() {
        case "playful": return "😜 PLAYFUL"
        case "curious": return "🤔 CURIOUS"
        case "share": return "💬 SHARE"
        case "bold": return "🔥 BOLD"
        default: return angle.uppercased()
        }
    }
}

struct RizzResult {
    let stage: String
    let hooks: [String]
    let replies: [Reply]

    var summary: String {
        var s = Prompt.stageLabel(stage)
        if let h = hooks.first, !h.isEmpty { s += " · hook: \(h)" }
        return s
    }
}

enum RizzError: LocalizedError {
    case badURL
    case server(Int, String)
    case empty

    var errorDescription: String? {
        switch self {
        case .badURL: return "Server URL looks wrong. Example: http://192.168.1.50:11434"
        case .server(let code, let body): return "Ollama error \(code): \(body.prefix(160))"
        case .empty: return "The model didn't return any replies. Try again or switch models."
        }
    }
}

struct OllamaClient {
    let settings: RizzSettings

    private var baseURL: URL? {
        var s = settings.serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !s.lowercased().hasPrefix("http") { s = "http://" + s }
        while s.hasSuffix("/") { s.removeLast() }
        return URL(string: s)
    }

    func suggestions(conversationText: String?, imageJPEG: Data?, draft: String?) async throws -> RizzResult {
        do {
            return try await request(conversationText: conversationText, imageJPEG: imageJPEG, draft: draft, format: Prompt.schema)
        } catch RizzError.server(let code, _) where code == 400 || code == 500 {
            // Older Ollama versions don't accept a JSON schema in `format`; fall back to plain JSON mode.
            return try await request(conversationText: conversationText, imageJPEG: imageJPEG, draft: draft, format: "json")
        }
    }

    private func request(conversationText: String?, imageJPEG: Data?, draft: String?, format: Any) async throws -> RizzResult {
        guard let base = baseURL else { throw RizzError.badURL }
        let url = base.appendingPathComponent("api/chat")

        var userMessage: [String: Any] = [
            "role": "user",
            "content": Prompt.user(conversationText: conversationText,
                                   hasImage: imageJPEG != nil,
                                   draft: draft)
        ]
        if let img = imageJPEG {
            userMessage["images"] = [img.base64EncodedString()]
        }

        let options: [String: Any] = ["temperature": 0.85, "top_p": 0.92, "num_ctx": 8192]
        let messages: [[String: Any]] = [
            ["role": "system", "content": Prompt.system(settings)],
            userMessage
        ]
        let body: [String: Any] = [
            "model": settings.model,
            "stream": false,
            "format": format,
            "keep_alive": "30m",
            "options": options,
            "messages": messages
        ]

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 180
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard code == 200 else {
            throw RizzError.server(code, String(data: data, encoding: .utf8) ?? "")
        }

        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let message = obj["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw RizzError.empty
        }
        let result = Self.parse(content)
        if result.replies.isEmpty { throw RizzError.empty }
        return result
    }

    func listModels() async throws -> [String] {
        guard let base = baseURL else { throw RizzError.badURL }
        var req = URLRequest(url: base.appendingPathComponent("api/tags"))
        req.timeoutInterval = 10
        let (data, response) = try await URLSession.shared.data(for: req)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard code == 200 else { throw RizzError.server(code, String(data: data, encoding: .utf8) ?? "") }
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let models = obj?["models"] as? [[String: Any]] ?? []
        return models.compactMap { $0["name"] as? String }.sorted()
    }

    // MARK: Parsing

    static func parse(_ raw: String) -> RizzResult {
        let content = raw.replacingOccurrences(of: "```json", with: "")
                         .replacingOccurrences(of: "```", with: "")

        if let start = content.firstIndex(of: "{"), let end = content.lastIndex(of: "}"), start < end,
           let data = String(content[start...end]).data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {

            var items: [Any] = []
            if let r = obj["replies"] as? [Any] {
                items = r
            } else {
                for value in obj.values {
                    if let r = value as? [Any] { items = r; break }
                }
            }
            let angles = ["playful", "curious", "share", "bold"]
            var replies: [Reply] = []
            for (i, item) in items.enumerated() {
                let fallbackAngle = i < angles.count ? angles[i] : "idea"
                if let s = item as? String {
                    replies.append(Reply(angle: fallbackAngle, text: s))
                } else if let d = item as? [String: Any],
                          let t = (d["text"] ?? d["reply"] ?? d["message"]) as? String {
                    replies.append(Reply(angle: (d["angle"] as? String) ?? fallbackAngle, text: t))
                }
            }
            let stage = (obj["stage"] as? String) ?? ""
            let hooks = (obj["hooks"] as? [String]) ?? []
            let cleaned = polish(replies)
            if !cleaned.isEmpty { return RizzResult(stage: stage, hooks: hooks, replies: cleaned) }
        }

        // Last resort: numbered lines.
        let lines = content.components(separatedBy: .newlines).map { line -> String in
            var l = line.trimmingCharacters(in: .whitespaces)
            while let f = l.first, "0123456789.)-*• ".contains(f) { l.removeFirst() }
            return l
        }
        let replies = lines.filter { !$0.isEmpty }.map { Reply(angle: "idea", text: $0) }
        return RizzResult(stage: "", hooks: [], replies: polish(replies))
    }

    /// Cleans up model output and enforces the research-backed rules that small models sometimes miss.
    static func polish(_ replies: [Reply]) -> [Reply] {
        let quotes = CharacterSet(charactersIn: "\"“”")
        var seen = Set<String>()
        var out: [Reply] = []
        for r in replies {
            var t = r.text.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: quotes)
            t = fixNetspeak(t)
            t = limitEmoji(t, max: 1)
            t = t.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = t.lowercased()
            guard !t.isEmpty, !seen.contains(key), !containsBannedPhrase(t) else { continue }
            seen.insert(key)
            out.append(Reply(angle: r.angle, text: t))
        }
        return Array(out.prefix(4))
    }

    private static func containsBannedPhrase(_ text: String) -> Bool {
        let lower = " " + text.lowercased() + " "
        let banned = [" sexy", " gorgeous", " hottie", " send pics", " send a pic", " as an ai"]
        return banned.contains { lower.contains($0) }
    }

    /// "u" → "you", "ur" → "your", "lol" → "haha" (OkCupid reply-rate data).
    private static func fixNetspeak(_ text: String) -> String {
        let swaps: [(String, String)] = [("u", "you"), ("ur", "your"), ("lol", "haha"), ("wat", "what")]
        var words = text.components(separatedBy: " ")
        for i in words.indices {
            let w = words[i]
            let core = w.trimmingCharacters(in: .punctuationCharacters)
            guard !core.isEmpty else { continue }
            for (from, to) in swaps where core.lowercased() == from {
                let replacement = core.first?.isUppercase == true ? to.prefix(1).uppercased() + to.dropFirst() : to
                words[i] = w.replacingOccurrences(of: core, with: replacement)
            }
        }
        return words.joined(separator: " ")
    }

    private static func limitEmoji(_ text: String, max: Int) -> String {
        var count = 0
        var result = ""
        for ch in text {
            let isEmoji = ch.unicodeScalars.contains { $0.properties.isEmojiPresentation }
            if isEmoji {
                count += 1
                if count > max { continue }
            }
            result.append(ch)
        }
        return result.replacingOccurrences(of: "  ", with: " ")
    }
}
