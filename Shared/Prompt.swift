import Foundation

enum Prompt {
    static func system(_ s: RizzSettings) -> String {
        var p = """
        You are a dating-app texting wingman. You write reply options the USER could send next in a conversation with a match.

        How to read a screenshot: the user's own messages are on the RIGHT (usually blue or colored bubbles). The match's messages are on the LEFT (usually gray). Ignore keyboards, status bars and app chrome. If it's a dating profile instead of a chat, write opening lines based on her photos/prompts.

        Rules:
        - Reply to the most recent message from the match, using specific details from the conversation.
        - Sound like a real person texting: short (usually under 25 words), natural, casual punctuation is fine.
        - No generic pickup lines, no cringe, max one emoji per reply.
        - Each option takes a different angle (e.g. a tease, a callback, a question, a bold one).
        - If the vibe is going well, make one option move toward meeting up or getting a number.
        - Be respectful: never crude, sexual, pushy, negging or manipulative.
        - Vibe for this batch: \(s.vibe.rawValue) — \(s.vibe.guidance).
        """
        let about = s.aboutMe.trimmingCharacters(in: .whitespacesAndNewlines)
        if !about.isEmpty {
            p += "\n- About the user (use only if it fits naturally): \(about)"
        }
        p += """

        Output ONLY valid JSON, no extra text, in exactly this shape:
        {"replies": ["option 1", "option 2", "option 3", "option 4"]}
        """
        return p
    }

    static func user(conversationText: String?, hasImage: Bool, draft: String?) -> String {
        var parts: [String] = []
        if hasImage {
            parts.append("The attached screenshot shows the conversation. Read it carefully.")
        }
        if let t = conversationText?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty {
            parts.append("Copied conversation text (usually the match's latest message(s)):\n\"\"\"\n\(t)\n\"\"\"")
        }
        if let d = draft?.trimmingCharacters(in: .whitespacesAndNewlines), !d.isEmpty {
            parts.append("The user has started typing this draft — improve it or write better alternatives in the same spirit:\n\"\(d)\"")
        }
        if parts.isEmpty {
            parts.append("There is no conversation yet. Write 4 strong, specific-feeling opening lines.")
        }
        parts.append("Give 4 reply options as JSON.")
        return parts.joined(separator: "\n\n")
    }
}
