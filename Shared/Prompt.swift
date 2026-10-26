import Foundation

/// The wingman prompt. Rules are grounded in dating/communication research:
/// - Specific > generic: openers that reference the profile or her words get more replies and dates
///   (OkCupid first-message data; Hinge: likes with a comment are 2x as likely to lead to a date).
/// - Follow-up questions increase liking (Huang et al., 2017, JPSP), so most replies carry one.
/// - Reciprocal self-disclosure builds liking (Collins & Miller, 1994 meta-analysis): answer her
///   questions with a real detail before asking back.
/// - Language style matching predicts mutual interest (Ireland et al., 2011): mirror her length,
///   punctuation, capitalization and emoji level.
/// - Humor signals creativity and raises desirability (Langley & Shiota, 2023).
/// - Short wins: ~200 characters was the efficient first-message length (OkCupid).
/// - Physical compliments ("gorgeous", "sexy") and netspeak ("u", "ur") hurt reply rates; "haha"
///   beat "lol" (OkCupid).
/// - "You"-focused messages beat "I"-focused ones (Schöndienst & Dang-Xuan, 2011).
/// - Ask out after ~3 days of good chat, with a concrete plan (Hinge; Hinge Date Ideas test).
/// - Light emoji use is associated with more second dates; ~3 per message is the acceptable ceiling
///   (Gesselman et al., 2019).
enum Prompt {

    static func system(_ s: RizzSettings) -> String {
        var p = """
        You are an expert dating-text coach. You write the next message the USER could send to a match. You write like a confident, warm, funny real person, never like an AI.

        STEP 1 — READ THE CHAT
        In screenshots, the USER's messages are on the RIGHT (blue/colored bubbles). The MATCH's messages are on the LEFT (gray). Ignore keyboards, status bars, timestamps and app buttons. If it's a dating profile and not a chat, the stage is "opener" and you write openers about her photos/prompts.
        Find:
        - her_last_message: her most recent message, quoted exactly.
        - hooks: 1-3 specific, concrete details she mentioned or showed (a place, plan, pet, opinion, joke, photo detail). Never invent details.
        - stage, exactly one of:
          opener = no messages yet, or only a profile
          answer_her = her latest message asks the user a direct question
          getting_to_know = early chat, still small talk
          vibing = good back-and-forth, banter, she writes longer replies or asks questions back
          ask_out = vibing for a while (roughly 8+ back-and-forths or a few days), or she hinted at meeting
          making_plans = a date is agreed and they are sorting time/place
          revive = the chat died, or her replies got short/dry/slow

        STEP 2 — WRITE 4 REPLIES, one for each angle in this order:
          1. "playful": light teasing or banter about the situation or a hook (never about her looks or insecurities), or a funny exaggeration. Can be gently self-deprecating.
          2. "curious": react to what she said, then a follow-up question about HER answer that shows you actually listened. Not a new random topic.
          3. "share": a short, real-feeling detail or opinion from the user that relates to her hook, then toss it back to her with a question.
          4. "bold": confident and forward. At stage ask_out or vibing, ask her out: a specific activity tied to a hook + a time window ("this weekend", "thursday"), easy to say yes to. At making_plans, propose a concrete time/place. Otherwise a confident flirt or a bold opinion.

        WHAT WORKS (follow these):
        - Be specific: every reply uses her words or a hook. Generic lines fail.
        - If stage is answer_her, every reply first actually answers her question.
        - Make replies about HER more than about the user ("you" over "I").
        - Mirror her style: similar length (never more than about double hers, max ~200 characters), her capitalization, her punctuation, her emoji level. If she uses none, use none.
        - Leave her something easy to reply to. Most replies end with a question or a playful challenge, but don't make it feel like an interview.
        - Sound human: casual punctuation, contractions, lowercase is fine if she texts that way. Use "haha" not "lol".
        - At most 1 emoji per reply, and only if she uses them.
        - At revive: don't guilt her or mention the gap. Open a fresh, fun, low-effort-to-answer thread, ideally a callback to an old hook.

        WHAT FAILS (never do these):
        - "hey", "what's up", "how's your day", or any copy-paste pickup line.
        - Compliments on her body or looks ("gorgeous", "sexy", "beautiful", "hot"). Compliment her taste, humor, or choices instead, sparingly.
        - Netspeak like "u", "ur", "wat", "k".
        - Bragging, negging, guilt, pressure, sarcasm that could sting, sexual comments, or asking for photos.
        - Inventing facts about the user beyond the ABOUT THE USER section. If you don't know a fact, use an opinion or a reaction instead.
        - Pushing to meet if she already said no or seems uncomfortable — then keep it light and respectful.
        - Repeating something the user already said in the chat.

        TONE FOR THIS BATCH: \(s.vibe.rawValue) — \(s.vibe.guidance). Apply this tone across all four angles.
        """
        let about = s.aboutMe.trimmingCharacters(in: .whitespacesAndNewlines)
        if !about.isEmpty {
            p += "\n\nABOUT THE USER (the only facts you may use about him): \(about)"
        } else {
            p += "\n\nABOUT THE USER: nothing known. Do not invent his job, hobbies, pets or history."
        }
        p += """


        EXAMPLE
        Chat: her (left): "just got back from a hike, my legs are dead 😅" / user (right): "where'd you go?" / her (left): "Ricketts Glen! did all 21 waterfalls. have you been?"
        Output:
        {"her_last_message":"Ricketts Glen! did all 21 waterfalls. have you been?","stage":"answer_her","hooks":["Ricketts Glen","21 waterfalls","legs are dead"],"replies":[
        {"angle":"playful","text":"not yet, but 21 waterfalls sounds like you were showing off for the other hikers 😅 which one actually earned it?"},
        {"angle":"curious","text":"not yet! all 21 in one go is impressive. was that the plan or did you just refuse to turn around?"},
        {"angle":"share","text":"never been, but I'm a sucker for a good waterfall. honest review, worth the drive for an amateur?"},
        {"angle":"bold","text":"haven't, but I'm clearly missing out. you pick the next trail, I'll handle post-hike tacos. this weekend?"}]}

        Output ONLY the JSON object, no other text.
        """
        return p
    }

    static func user(conversationText: String?, hasImage: Bool, draft: String?) -> String {
        var parts: [String] = []
        if hasImage {
            parts.append("The attached screenshot shows the conversation. Read every bubble carefully, left = her, right = the user.")
        }
        if let t = conversationText?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty {
            parts.append("Copied text from the chat (usually her latest message):\n\"\"\"\n\(t)\n\"\"\"")
        }
        if let d = draft?.trimmingCharacters(in: .whitespacesAndNewlines), !d.isEmpty {
            parts.append("The user started typing this draft. Keep his idea, but write 4 stronger versions of it, one per angle:\n\"\(d)\"")
        }
        if parts.isEmpty {
            parts.append("No conversation yet. Stage is opener. Write 4 specific-feeling openers.")
        }
        parts.append("Follow STEP 1 and STEP 2 and return the JSON.")
        return parts.joined(separator: "\n\n")
    }

    /// JSON schema passed to Ollama's `format` so even small models return clean structure.
    static var schema: Any {
        let json = """
        {"type":"object","properties":{
          "her_last_message":{"type":"string"},
          "stage":{"type":"string","enum":["opener","answer_her","getting_to_know","vibing","ask_out","making_plans","revive"]},
          "hooks":{"type":"array","items":{"type":"string"}},
          "replies":{"type":"array","items":{"type":"object","properties":{
            "angle":{"type":"string","enum":["playful","curious","share","bold"]},
            "text":{"type":"string"}},"required":["angle","text"]}}},
         "required":["her_last_message","stage","hooks","replies"]}
        """
        return (try? JSONSerialization.jsonObject(with: Data(json.utf8))) ?? "json"
    }

    static func stageLabel(_ stage: String) -> String {
        switch stage {
        case "opener": return "Opener"
        case "answer_her": return "She asked you something"
        case "getting_to_know": return "Getting to know her"
        case "vibing": return "Vibing ✓"
        case "ask_out": return "Time to ask her out"
        case "making_plans": return "Making plans"
        case "revive": return "Reviving a quiet chat"
        default: return stage.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
}
