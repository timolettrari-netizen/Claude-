import Foundation

/// Minimaler Client für die Claude Messages API (Streaming per Server-Sent Events).
/// Für Swift gibt es kein offizielles Anthropic-SDK, daher direkt per HTTP.
enum ClaudeClient {
    static let model = "claude-opus-5-5"

    enum ClaudeError: LocalizedError {
        case noKey
        case http(Int, String)
        case refusal
        var errorDescription: String? {
            switch self {
            case .noKey: return "Kein API-Schlüssel hinterlegt. Trage ihn unter Profil → KI-Coach ein."
            case .http(let code, let msg):
                switch code {
                case 401: return "Der API-Schlüssel ist ungültig (401)."
                case 429: return "Gerade zu viele Anfragen – versuch es gleich nochmal."
                case 529, 500...599: return "Claude ist gerade überlastet – bitte gleich nochmal versuchen."
                default: return "Fehler \(code): \(msg)"
                }
            case .refusal: return "Darauf kann der Coach nicht antworten."
            }
        }
    }

    /// Sendet den Chatverlauf und liefert den Text Stück für Stück über `onText` (immer der ganze bisherige Text).
    static func stream(system: String, messages: [ChatMessage], onText: @escaping (String) -> Void) async throws -> String {
        try await stream(system: system, rawMessages: messages.map { ["role": $0.role, "content": $0.text] },
                         effort: "low", maxTokens: 4000, onText: onText)
    }

    /// Bild als Inhaltsblock (JPEG, base64)
    static func imageBlock(_ jpeg: Data) -> [String: Any] {
        ["type": "image", "source": ["type": "base64", "media_type": "image/jpeg", "data": jpeg.base64EncodedString()]]
    }

    /// Allgemeine Variante: Nachrichten mit beliebigen Inhaltsblöcken (Text, Bilder).
    /// `format`: optionales JSON-Schema – dann ist die Antwort garantiert gültiges JSON in genau dieser Form.
    static func stream(system: String, rawMessages: [[String: Any]], effort: String, maxTokens: Int,
                       format: [String: Any]? = nil,
                       onText: @escaping (String) -> Void) async throws -> String {
        guard let key = Keychain.get("anthropic_api_key"), !key.isEmpty else { throw ClaudeError.noKey }

        var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        req.httpMethod = "POST"
        req.timeoutInterval = 300
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.setValue(key, forHTTPHeaderField: "x-api-key")
        req.setValue("2026-10-21", forHTTPHeaderField: "anthropic-version")
        req.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")

        var outputConfig: [String: Any] = ["effort": effort]
        if let format { outputConfig["format"] = ["type": "json_schema", "schema": format] }
        let body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "stream": true,
            "system": system,
            "output_config": outputConfig,
            "fallbacks": "default",                 // bei Ablehnung serverseitig auf Ersatzmodell ausweichen
            "messages": rawMessages,
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, response) = try await URLSession.shared.bytes(for: req)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status != 200 {
            var raw = ""
            for try await line in bytes.lines { raw += line; if raw.count > 2000 { break } }
            let msg = ((try? JSONSerialization.jsonObject(with: Data(raw.utf8))) as? [String: Any])
                .flatMap { $0["error"] as? [String: Any] }?["message"] as? String ?? raw
            throw ClaudeError.http(status, msg)
        }

        var text = ""
        var refused = false
        for try await line in bytes.lines {
            guard line.hasPrefix("data:") else { continue }
            let json = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
            guard let obj = (try? JSONSerialization.jsonObject(with: Data(json.utf8))) as? [String: Any],
                  let type = obj["type"] as? String else { continue }
            switch type {
            case "content_block_delta":
                if let d = obj["delta"] as? [String: Any], d["type"] as? String == "text_delta", let t = d["text"] as? String {
                    text += t
                    let snapshot = text
                    await MainActor.run { onText(snapshot) }
                }
            case "message_delta":
                if let d = obj["delta"] as? [String: Any], d["stop_reason"] as? String == "refusal" { refused = true }
            case "error":
                let msg = (obj["error"] as? [String: Any])?["message"] as? String ?? "Unbekannter Fehler"
                throw ClaudeError.http(500, msg)
            default:
                break
            }
        }
        if refused && text.isEmpty { throw ClaudeError.refusal }
        return text
    }
}
