import Foundation

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

    func suggestions(conversationText: String?, imageJPEG: Data?, draft: String?) async throws -> [String] {
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

        let body: [String: Any] = [
            "model": settings.model,
            "stream": false,
            "format": "json",
            "keep_alive": "30m",
            "options": ["temperature": 0.9],
            "messages": [
                ["role": "system", "content": Prompt.system(settings)],
                userMessage
            ]
        ]

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 120
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
        let replies = Self.parseReplies(content)
        if replies.isEmpty { throw RizzError.empty }
        return replies
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

    /// Accepts {"replies":[...]}, a bare JSON array, or numbered lines as a fallback.
    static func parseReplies(_ raw: String) -> [String] {
        let content = raw.replacingOccurrences(of: "```json", with: "")
                         .replacingOccurrences(of: "```", with: "")

        if let start = content.firstIndex(of: "{"), let end = content.lastIndex(of: "}"), start < end,
           let data = String(content[start...end]).data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            var arr: [Any] = []
            if let r = obj["replies"] as? [Any] {
                arr = r
            } else {
                for value in obj.values {
                    if let r = value as? [Any] { arr = r; break }
                }
            }
            let strings = arr.compactMap { item -> String? in
                if let s = item as? String { return s }
                if let d = item as? [String: Any] { return (d["text"] ?? d["reply"]) as? String }
                return nil
            }
            let cleaned = clean(strings)
            if !cleaned.isEmpty { return cleaned }
        }

        if let start = content.firstIndex(of: "["), let end = content.lastIndex(of: "]"), start < end,
           let data = String(content[start...end]).data(using: .utf8),
           let arr = try? JSONSerialization.jsonObject(with: data) as? [String] {
            let cleaned = clean(arr)
            if !cleaned.isEmpty { return cleaned }
        }

        let lines = content.components(separatedBy: .newlines).map { line -> String in
            var l = line.trimmingCharacters(in: .whitespaces)
            while let f = l.first, "0123456789.)-*• ".contains(f) { l.removeFirst() }
            return l
        }
        return clean(lines)
    }

    private static func clean(_ items: [String]) -> [String] {
        let quotes = CharacterSet(charactersIn: "\"“”")
        return items
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: quotes) }
            .filter { !$0.isEmpty }
            .prefix(5)
            .map { $0 }
    }
}
