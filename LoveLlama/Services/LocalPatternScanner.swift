import Foundation

// MARK: - Scan Result

struct LocalScanResult {
    var flaggedPatterns: [FlaggedPattern]
    var riskLevel: RiskLevel
    var weightedScore: Double          // 0.0 - 1.0
    var conversationStage: String?
    var summary: String
    var recommendation: String
    var nextMovePrediction: String?

    struct FlaggedPattern: Identifiable {
        let id = UUID()
        let patternType: ScamPatternType
        let matchedPhrases: [String]
        let matchCount: Int
        let confidence: Double         // 0.0 - 1.0
        let explanation: String
    }
}

// MARK: - Pattern Definition

private struct PatternDef {
    let type: ScamPatternType
    let phrases: [String]
    let explanation: String
}

// MARK: - Compiled Pattern (pre-compiled regex for performance + security)

private struct CompiledPattern {
    let type: ScamPatternType
    let regexes: [(pattern: String, regex: NSRegularExpression)]
    let explanation: String
}

// MARK: - Scanner

struct LocalPatternScanner {

    // Pre-compiled regexes — built once at init, not on every scan
    private let compiledPatterns: [CompiledPattern]
    private let compiledStagePatterns: [(stage: String, regexes: [NSRegularExpression])]

    init() {
        // Pre-compile all scam pattern regexes
        compiledPatterns = Self.patterns.map { def in
            let regexes: [(String, NSRegularExpression)] = def.phrases.compactMap { phrase in
                guard let regex = try? NSRegularExpression(pattern: phrase, options: .caseInsensitive) else {
                    return nil
                }
                return (phrase, regex)
            }
            return CompiledPattern(type: def.type, regexes: regexes, explanation: def.explanation)
        }

        // Pre-compile stage detection regexes
        compiledStagePatterns = Self.stagePatterns.map { (stage, phrases) in
            let regexes = phrases.compactMap { try? NSRegularExpression(pattern: $0, options: .caseInsensitive) }
            return (stage, regexes)
        }
    }

    // MARK: - Pattern Database

    private static let patterns: [PatternDef] = [

        // ── Financial Request (CRITICAL) ──────────────────────────
        PatternDef(
            type: .financialRequest,
            phrases: [
                "send money", "send me money", "wire transfer", "wire me",
                "gift card", "itunes card", "google play card", "steam card", "amazon card",
                "bitcoin", "crypto", "cryptocurrency", "btc", "usdt", "ethereum",
                "western union", "moneygram", "cash app", "zelle", "venmo", "paypal",
                "bank account", "routing number", "account number",
                "need money", "need \\$", "need financial", "financial help",
                "loan me", "lend me", "borrow money",
                "send \\$", "\\$\\d{2,}", "pay for", "cover the cost",
                "urgent payment", "transfer funds", "money transfer",
                "reimburse", "repay you", "pay you back", "i'll return",
                "help me financially", "just this once", "small amount",
                "fees", "customs fee", "processing fee", "release fee",
                "clearance fee", "tax payment", "medical bill",
                "hospital bill", "repair fee", "travel ticket",
                "plane ticket", "visa fee", "legal fee"
            ],
            explanation: "Direct or indirect requests for money are the hallmark of romance scams. Scammers fabricate emergencies, fees, or crises to extract money — often through untraceable methods like gift cards, crypto, or wire transfers."
        ),

        // ── Love Bombing ──────────────────────────────────────────
        PatternDef(
            type: .loveBombing,
            phrases: [
                "i love you", "i'm in love with you", "falling in love",
                "soul ?mate", "you're the one", "the one for me",
                "never felt this way", "love at first", "meant to be",
                "my everything", "can't live without you", "perfect match",
                "falling for you", "deeply in love", "head over heels",
                "you complete me", "you're my world", "my heart belongs",
                "when you know you know", "i knew from the moment",
                "feel like i've known you forever", "known you my whole life",
                "you make me feel alive", "best part of my day",
                "wake up next to you", "thinking about you all day",
                "dreaming about you", "count the minutes", "miss you so much",
                "you're so beautiful", "you're so gorgeous", "most beautiful",
                "you're perfect", "my queen", "my king", "my princess",
                "my angel", "my treasure", "my sunshine",
                "good morning beautiful", "good morning handsome",
                "good night my love", "sweet dreams my love"
            ],
            explanation: "Love bombing is an overwhelming display of affection very early in a relationship. Scammers use it to create a false sense of deep connection before the target has had time to verify their identity. Genuine feelings develop gradually."
        ),

        // ── Emotional Manipulation (NEW) ──────────────────────────
        PatternDef(
            type: .emotionalManipulation,
            phrases: [
                "i guess i was wrong about you", "i thought you loved me",
                "if you really loved me", "don't you trust me",
                "you don't believe me", "i can't believe you don't trust",
                "maybe we don't have a future", "maybe this was a mistake",
                "you're breaking my heart", "you're hurting me",
                "i'm so disappointed", "after everything i've told you",
                "i've never asked anyone for help", "i hate asking",
                "i would never ask if", "this is so embarrassing",
                "i'm too proud to ask", "swallow my pride",
                "i thought we had something special",
                "i thought you were different", "you're just like everyone",
                "nobody cares about me", "you're the only one who can help",
                "if you can't help me now", "i'll understand if you leave",
                "i wouldn't blame you", "guilt", "you owe me",
                "after all i've done", "prove your love",
                "do this for us", "for our future"
            ],
            explanation: "Emotional manipulation uses guilt, shame, or threats of ending the relationship to pressure you into compliance. This is a major red flag — someone who genuinely cares would never guilt you into sending money."
        ),

        // ── Tragic Backstory (NEW) ─────────────────────────────────
        PatternDef(
            type: .tragicBackstory,
            phrases: [
                "wife passed away", "husband passed away", "spouse passed",
                "wife died", "husband died", "lost my wife", "lost my husband",
                "widow", "widower", "widowed",
                "single parent", "single father", "single mother", "single dad", "single mom",
                "raising.*alone", "raise.*by myself",
                "daughter needs", "son needs", "my child is sick",
                "passed away.*years ago", "died.*years ago",
                "car accident", "cancer took", "tragic accident",
                "lost everything", "lost my family",
                "orphan", "grew up alone", "no family left",
                "parents died", "parents passed",
                "been through so much", "had a hard life",
                "you're all i have", "you're my only"
            ],
            explanation: "Scammers craft sympathetic backstories — a dead spouse, sick child, or tragic past — to generate empathy and lower your defenses. These stories make you feel special for 'saving' them, making it harder to say no when they later ask for money."
        ),

        // ── Future Promises (NEW) ──────────────────────────────────
        PatternDef(
            type: .futurePromises,
            phrases: [
                "start our life together", "when i get back",
                "once i'm home", "when we meet", "when i return",
                "our future together", "build a life",
                "get married", "marry you", "want to marry",
                "move in together", "come live with",
                "told my.*about you", "told my daughter", "told my son",
                "told my family", "told my mother", "told my father",
                "you're my future", "plan our wedding",
                "retire together", "grow old together",
                "i'll take care of everything", "never worry about money",
                "once this is over", "after this contract",
                "when the contract clears", "after the project",
                "once i get paid", "when i get my salary"
            ],
            explanation: "Scammers make grand promises about a shared future — marriage, meeting family, starting a life together — before ever meeting in person. These promises are designed to make you emotionally invested so you'll help with their fabricated 'obstacles' to reaching you."
        ),

        // ── Urgency & Pressure ────────────────────────────────────
        PatternDef(
            type: .urgencyPressure,
            phrases: [
                "right now", "immediately", "emergency", "urgent",
                "can't wait", "time sensitive", "don't tell anyone",
                "act fast", "limited time", "hurry", "asap",
                "running out of time", "deadline", "today only",
                "before it's too late", "i need this today",
                "they're going to", "they'll arrest me", "they'll deport me",
                "i'll be stuck here", "trapped here", "can't leave",
                "life or death", "medical emergency", "surgery",
                "something terrible happened", "equipment malfunctioned",
                "being detained", "locked up", "frozen.*account",
                "account.*frozen", "bank.*frozen"
            ],
            explanation: "Scammers create false urgency to prevent you from thinking critically. They claim emergencies, frozen accounts, or life-threatening situations that conveniently require your immediate financial help."
        ),

        // ── Military / Overseas Contractor ─────────────────────────
        PatternDef(
            type: .militaryDeploymentStory,
            phrases: [
                "deployed", "deployment", "military base",
                "army", "navy", "marines", "air force",
                "stationed overseas", "stationed abroad",
                "peacekeeping", "peace keeping", "special forces", "special ops",
                "oil rig", "oil platform", "offshore platform",
                "working overseas", "working abroad", "contractor overseas",
                "united nations", "un mission", "humanitarian mission",
                "cannot video call", "restricted communication",
                "base camp", "forward operating base",
                "combat zone", "war zone", "conflict area",
                "merchant marine", "cargo ship", "at sea",
                "engineering project", "construction project.*overseas",
                "working on a platform", "remote location"
            ],
            explanation: "Military deployment, oil rigs, and overseas contracting are among the most common cover stories in romance scams. They conveniently explain why the scammer can't meet in person, can't video call, and why they need money sent internationally."
        ),

        // ── Moving Off Platform ───────────────────────────────────
        PatternDef(
            type: .moveOffPlatform,
            phrases: [
                "whatsapp", "telegram", "hangouts", "google chat",
                "signal", "line app", "viber", "wechat", "kakaotalk",
                "text me at", "call me at", "here's my number",
                "my number is", "reach me at",
                "move to", "switch to", "talk on another app",
                "personal email", "let's chat on",
                "this app is bad", "this app is slow",
                "i prefer to talk on", "more private",
                "add me on", "find me on",
                "get off this app", "don't like this app",
                "chat off here"
            ],
            explanation: "Scammers quickly move conversations off dating platforms to avoid detection and moderation. Once on private messaging apps, there's no platform safety team monitoring for scam behavior."
        ),

        // ── Refusing Video Calls ──────────────────────────────────
        PatternDef(
            type: .refusingVideoCall,
            phrases: [
                "camera broken", "camera doesn't work", "camera is broken",
                "can't video", "no video call", "can't do video",
                "bad connection", "internet too slow", "poor connection",
                "bandwidth.*low", "connection.*unstable",
                "shy on camera", "not comfortable with video",
                "don't have a camera", "webcam.*broken",
                "video.*restricted", "not allowed to video",
                "security.*prevents.*video", "classified.*can't video",
                "i'll call you when i get back", "when i leave here",
                "next time", "soon", "once i have better internet"
            ],
            explanation: "A person who claims to be deeply in love but consistently avoids video calls is a major red flag. Video calls are the simplest way to verify someone is who they claim to be. Scammers will always have excuses to avoid them."
        ),

        // ── Isolation Tactics ─────────────────────────────────────
        PatternDef(
            type: .isolationTactics,
            phrases: [
                "don't tell", "keep this between us", "our secret",
                "your friends don't understand", "your family won't understand",
                "they're jealous", "they're trying to break us up",
                "nobody understands", "only trust me", "only i understand",
                "your friends are wrong", "don't listen to them",
                "they don't want you to be happy",
                "promise me you're not talking to other",
                "not talking to other men", "not talking to other women",
                "are you seeing someone else", "are you talking to others",
                "i want something serious", "be exclusive",
                "delete your profile", "get off the dating app",
                "block other people", "only talk to me"
            ],
            explanation: "Scammers try to isolate you from friends and family who might recognize the scam. They push for exclusivity, discourage you from seeking outside opinions, and make you feel guilty for talking to others."
        ),

        // ── Too Good to Be True ───────────────────────────────────
        PatternDef(
            type: .tooGoodToBeTrue,
            phrases: [
                "successful business", "my yacht", "my mansion",
                "i'll take care of you", "buy you anything",
                "wealthy", "millionaire", "very rich",
                "i own.*compan", "my company", "CEO",
                "i make.*per year", "six figures", "seven figures",
                "lavish lifestyle", "first class", "private jet",
                "came across your profile", "drawn to your smile",
                "drawn to your photo", "your profile caught my eye",
                "you seem like.*genuine", "you seem like.*kind",
                "you seem.*different", "not like other"
            ],
            explanation: "Scammers present themselves as highly successful, wealthy, and instantly captivated by you. Real connections don't start with someone claiming to be a millionaire CEO who was 'drawn to your smile.'"
        ),

        // ── Pig Butchering ────────────────────────────────────────
        PatternDef(
            type: .pigButchering,
            phrases: [
                "investment opportunity", "guaranteed returns",
                "trading platform", "trading app",
                "forex", "forex trading", "binary options",
                "cryptocurrency platform", "crypto exchange",
                "double your money", "triple your money",
                "passive income", "financial freedom", "my broker",
                "secret platform", "insider", "100% profit",
                "let me show you", "i can teach you",
                "my uncle.*invest", "my friend.*platform",
                "look at my returns", "look at my profits",
                "easy money", "risk free", "no risk",
                "guaranteed profit", "never lose",
                "withdrawal.*fee", "you need to deposit more"
            ],
            explanation: "Pig butchering scams combine romance with fake investment platforms. The scammer gains your trust, then introduces a 'guaranteed' investment opportunity. Initial small withdrawals work to build trust, then larger deposits are requested — and the money disappears."
        ),

        // ── Sextortion Setup ──────────────────────────────────────
        PatternDef(
            type: .sextortionSetup,
            phrases: [
                "send me a photo", "send me a pic", "show me",
                "private photo", "private pic", "intimate photo",
                "just between us", "nobody will see",
                "naughty", "turn on your camera", "take off",
                "undress", "naked", "nude", "sexy photo",
                "i'll send you mine first", "let's exchange",
                "video call.*clothes", "i want to see you",
                "boudoir", "lingerie pic"
            ],
            explanation: "Sextortion scammers coax intimate photos or videos from victims, then threaten to share them publicly unless money is paid. Never share intimate content with someone you haven't met in person."
        ),

        // ── Scripted / Grammar Patterns ───────────────────────────
        PatternDef(
            type: .grammarScriptedResponses,
            phrases: [
                "\\bdear\\b", "my beloved", "my darling", "\\bkindly\\b",
                "am a honest", "am an honest", "i am a god ?fearing",
                "do the needful", "revert back",
                "good day to you", "how was your night",
                "how is your day going over there",
                "i hope this message finds you",
                "i got your contact", "from your profile",
                "permit me to", "i wish to",
                "my name is.*i am from", "i hail from",
                "i am.*by profession", "by name i am"
            ],
            explanation: "Many scam messages follow scripted templates with telltale phrases and unusual grammar patterns. Phrases like 'dear', 'kindly', and overly formal greetings often indicate a scripted operation rather than genuine conversation."
        ),

        // ── AI-Generated Text Detection ─────────────────────────────
        PatternDef(
            type: .aiGeneratedText,
            phrases: [
                // ChatGPT signature phrases and filler
                "i completely understand", "i totally understand",
                "that being said", "that said", "having said that",
                "i appreciate you sharing", "thank you for sharing",
                "it's important to", "it's worth noting",
                "i want you to know that", "i want to assure you",
                "absolutely", "i hear you",
                "at the end of the day", "when all is said and done",
                "it means the world to me", "means so much to me",
                "i value our connection", "i cherish what we have",
                "navigate this together", "navigate.*journey",
                "on this journey", "our journey together",
                "moving forward", "going forward",
                "in this moment", "in this regard",
                "with that in mind", "all things considered",
                "if i'm being honest", "if i'm being completely honest",
                "i can only imagine", "i can't even imagine",
                "it's not about the money", "it's about us",

                // Overly polished emotional language
                "your presence in my life", "you light up my world",
                "every fiber of my being", "the depths of my heart",
                "the very essence of", "a profound sense of",
                "deeply resonates with me", "resonates deeply",
                "my heart swells", "fills my heart with",
                "a beacon of hope", "a ray of sunshine",
                "the tapestry of our", "the fabric of our",
                "unwavering support", "unwavering love",
                "unconditional love", "unconditionally",
                "wholeheartedly", "with all my heart",
                "a testament to", "speaks volumes about",

                // Structured/formulaic responses
                "firstly.*secondly", "on one hand.*on the other",
                "not only.*but also", "while i understand.*i also",
                "i respect your.*but", "let me be clear",
                "here's the thing", "here's what i think",
                "i believe that.*and i also believe",
                "the truth is.*and the reality is",

                // Filler hedging language
                "i completely respect", "i totally respect",
                "i would never want to", "the last thing i want",
                "i hope you know", "i hope you understand",
                "please know that", "please understand that",
                "rest assured", "you have my word",
                "i give you my word", "i promise you",
                "from the bottom of my heart",
                "with every ounce of my being",

                // Overly self-aware / therapeutic language
                "emotional connection", "emotional bond",
                "emotional intimacy", "vulnerable with you",
                "safe space", "open up to you",
                "authentic connection", "genuine connection",
                "healthy relationship", "healthy communication",
                "set boundaries", "respect your boundaries",
                "emotional availability", "emotionally available",
                "growth mindset", "personal growth",

                // Unnaturally perfect paragraph structure
                "moreover", "furthermore", "nevertheless",
                "consequently", "subsequently",
                "in addition to that", "building on that",
                "to elaborate", "to clarify", "to be more specific",
                "delve into", "delve deeper"
            ],
            explanation: "This conversation shows signs of AI-generated text (ChatGPT, etc.). Scammers increasingly use AI to craft emotionally sophisticated messages at scale. AI text tends to be overly polished, uses therapeutic language, and has unnaturally perfect structure — real people text messily."
        ),

        // ── Inconsistent Details ──────────────────────────────────
        PatternDef(
            type: .inconsistentDetails,
            phrases: [],
            explanation: "Inconsistencies in stories, details, or timelines are a sign the person may not be who they claim. This is best detected by AI analysis — add an API key in Settings for deeper analysis."
        )
    ]

    // MARK: - Conversation Stage Detection

    private static let stagePatterns: [(stage: String, phrases: [String])] = [
        ("initial_contact", [
            "came across your profile", "hope you don't mind",
            "thought i'd say hello", "nice to meet", "first time",
            "how are you", "tell me about yourself", "where are you from"
        ]),
        ("emotional_bonding", [
            "i love you", "falling for you", "soul ?mate", "meant to be",
            "you're the one", "feel like i've known you", "my everything",
            "best part of my day", "wake up next to you",
            "good morning beautiful", "miss you"
        ]),
        ("exclusivity_isolation", [
            "promise me", "not talking to other", "something serious",
            "told my.*about you", "don't tell", "our secret",
            "your friends don't understand", "be exclusive", "my future"
        ]),
        ("crisis_money_request", [
            "send money", "need money", "wire transfer", "gift card",
            "emergency", "urgent", "hospital", "accident", "fee",
            "frozen.*account", "can't access", "help me financially",
            "reimburse", "repair fee", "customs fee"
        ]),
        ("guilt_pressure", [
            "i thought you loved me", "if you really loved me",
            "maybe we don't have a future", "i was wrong about you",
            "prove your love", "you don't trust me",
            "after everything"
        ])
    ]

    // MARK: - Main Scan

    func scan(_ text: String, context: ConversationContext? = nil) -> LocalScanResult {
        // Truncate excessively long input to prevent ReDoS
        let safeText = String(text.prefix(50_000))
        let lowered = safeText.lowercased()
        var flagged: [LocalScanResult.FlaggedPattern] = []

        // Scan all pattern categories using pre-compiled regexes
        for compiled in compiledPatterns {
            guard !compiled.regexes.isEmpty else { continue }
            var matched: [String] = []
            let range = NSRange(lowered.startIndex..., in: lowered)
            for (phrase, regex) in compiled.regexes {
                if regex.numberOfMatches(in: lowered, range: range) > 0 {
                    matched.append(phrase)
                }
            }
            if !matched.isEmpty {
                // Confidence scales with how many distinct phrases matched within this category
                let totalPhrases = compiled.regexes.count
                let matchRatio = Double(matched.count) / Double(totalPhrases)
                let confidence = min(0.95, 0.3 + matchRatio * 1.5)

                flagged.append(.init(
                    patternType: compiled.type,
                    matchedPhrases: matched,
                    matchCount: matched.count,
                    confidence: confidence,
                    explanation: compiled.explanation
                ))
            }
        }

        // Detect suspicious emoji-only/emoji-heavy short messages (common scam opener)
        if let emojiFlag = detectSuspiciousOpener(safeText) {
            flagged.append(emojiFlag)
        }

        // Generate synthetic flags from context
        if let context = context {
            flagged = applySyntheticFlags(flagged: flagged, context: context)
        }

        // Weighted score calculation
        var weightedScore = calculateWeightedScore(flagged)

        // Apply context-based scoring boosts
        if let context = context {
            weightedScore = applyContextBoosts(score: weightedScore, flagged: flagged, context: context)
        }

        let riskLevel = riskLevelFromScore(weightedScore)
        let stage = detectStage(lowered)
        let summary = buildSummary(flagged: flagged, riskLevel: riskLevel, stage: stage)
        let recommendation = buildRecommendation(flagged: flagged, riskLevel: riskLevel, stage: stage)
        let prediction = buildNextMovePrediction(stage: stage)

        return LocalScanResult(
            flaggedPatterns: flagged,
            riskLevel: riskLevel,
            weightedScore: weightedScore,
            conversationStage: stage,
            summary: summary,
            recommendation: recommendation,
            nextMovePrediction: prediction
        )
    }

    // MARK: - Suspicious Opener Detection

    /// Romantic/flirty emojis commonly used in scam openers
    private static let romanticEmojis: Set<Character> = [
        "\u{1F60D}", // 😍
        "\u{1F970}", // 🥰
        "\u{1F618}", // 😘
        "\u{1F617}", // 😗
        "\u{1F619}", // 😙
        "\u{1F61A}", // 😚
        "\u{2764}",  // ❤️
        "\u{1F495}", // 💕
        "\u{1F496}", // 💖
        "\u{1F497}", // 💗
        "\u{1F498}", // 💘
        "\u{1F49D}", // 💝
        "\u{1F49E}", // 💞
        "\u{1F49F}", // 💟
        "\u{1F48B}", // 💋
        "\u{1F339}", // 🌹
        "\u{1F48C}", // 💌
        "\u{1F60A}", // 😊
        "\u{1F609}", // 😉
        "\u{1F525}", // 🔥
        "\u{2728}",  // ✨
        "\u{1FA77}", // 🩷
    ]

    /// Detects short/emoji-only messages with romantic emojis — a common "shotgun" scam opener
    private func detectSuspiciousOpener(_ text: String) -> LocalScanResult.FlaggedPattern? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Strip all emoji to measure actual text content
        let nonEmoji = trimmed.unicodeScalars.filter { scalar in
            !scalar.properties.isEmoji || scalar.isASCII
        }
        let nonEmojiText = String(nonEmoji).trimmingCharacters(in: .whitespacesAndNewlines)

        // Count romantic emojis in the message
        let romanticCount = trimmed.filter { Self.romanticEmojis.contains($0) }.count

        // Flag if: message is very short on actual text AND contains romantic emojis
        // This catches: "😍", "hey 🥰", "hi 😘❤️", "💋💋💋", etc.
        guard nonEmojiText.count <= 15, romanticCount >= 1 else { return nil }

        // Scale confidence based on how emoji-heavy the message is
        let confidence: Double
        let matchedDescription: String
        if nonEmojiText.isEmpty {
            // Pure emoji message (e.g., "😍🥰" or "❤️")
            confidence = 0.55
            matchedDescription = "Emoji-only message with romantic emojis"
        } else if romanticCount >= 2 {
            // Short text + multiple romantic emojis
            confidence = 0.50
            matchedDescription = "Very short message heavy with romantic emojis"
        } else {
            // Short text + single romantic emoji (e.g., "hey 😍")
            confidence = 0.40
            matchedDescription = "Short message with romantic emoji"
        }

        return .init(
            patternType: .suspiciousOpener,
            matchedPhrases: [matchedDescription],
            matchCount: romanticCount,
            confidence: confidence,
            explanation: "Very short or emoji-only messages with romantic emojis from unknown contacts are a common 'shotgun' tactic — scammers send these to many numbers hoping someone engages. A real person who knows you would say more than just an emoji. Don't respond to unsolicited messages like this."
        )
    }

    // MARK: - Context Scoring Boosts

    private func applySyntheticFlags(flagged: [LocalScanResult.FlaggedPattern], context: ConversationContext) -> [LocalScanResult.FlaggedPattern] {
        var result = flagged
        let existingTypes = Set(flagged.map { $0.patternType })

        // No video call + 1+ months → synthetic refusingVideoCall
        if context.hasVideoCalledPerson == false,
           let duration = context.talkingDuration,
           (duration == .oneToThreeMonths || duration == .threeMonthsPlus),
           !existingTypes.contains(.refusingVideoCall) {
            result.append(.init(
                patternType: .refusingVideoCall,
                matchedPhrases: ["User reported: no video call after \(duration.rawValue)"],
                matchCount: 1,
                confidence: 0.70,
                explanation: "You've been talking for \(duration.rawValue) without a video call. This is a significant red flag — someone who is genuinely interested will make time for a video call."
            ))
        }

        // Asked for money = true → synthetic financialRequest
        if context.hasBeenAskedForMoney == true,
           !existingTypes.contains(.financialRequest) {
            result.append(.init(
                patternType: .financialRequest,
                matchedPhrases: ["User reported: has been asked for money"],
                matchCount: 1,
                confidence: 0.80,
                explanation: "You reported that this person has asked you for money. This is one of the strongest indicators of a romance scam, especially if you have never met in person."
            ))
        }

        // Discussed investments = true → synthetic pigButchering
        if context.hasDiscussedInvestments == true,
           !existingTypes.contains(.pigButchering) {
            result.append(.init(
                patternType: .pigButchering,
                matchedPhrases: ["User reported: investment discussions"],
                matchCount: 1,
                confidence: 0.75,
                explanation: "You reported that this person has discussed investments with you. Romance scammers frequently introduce fake investment platforms (pig butchering scam) after building trust."
            ))
        }

        return result
    }

    private func applyContextBoosts(score: Double, flagged: [LocalScanResult.FlaggedPattern], context: ConversationContext) -> Double {
        var boosted = score

        // No video call + 1+ months talking: +0.15
        if context.hasVideoCalledPerson == false,
           let duration = context.talkingDuration,
           (duration == .oneToThreeMonths || duration == .threeMonthsPlus) {
            boosted += 0.15
        }

        // No in-person meeting + 3+ months: +0.10
        if context.hasMetInPerson == false,
           context.talkingDuration == .threeMonthsPlus {
            boosted += 0.10
        }

        // Asked for money: +0.20
        if context.hasBeenAskedForMoney == true {
            boosted += 0.20
        }

        // Discussed investments: +0.15
        if context.hasDiscussedInvestments == true {
            boosted += 0.15
        }

        // Love bombing detected + < 1 week talking: +0.10
        let hasLoveBombing = flagged.contains { $0.patternType == .loveBombing }
        if hasLoveBombing, context.talkingDuration == .lessThanWeek {
            boosted += 0.10
        }

        return min(1.0, boosted)
    }

    // MARK: - Scoring

    private func calculateWeightedScore(_ flagged: [LocalScanResult.FlaggedPattern]) -> Double {
        guard !flagged.isEmpty else { return 0.0 }

        // Sum weighted scores: each pattern contributes weight * confidence
        let totalWeighted = flagged.reduce(0.0) { sum, pattern in
            sum + pattern.patternType.weight * pattern.confidence
        }

        // Scale based on realistic detection scenarios:
        // 1 low-weight pattern at min confidence (~0.45) = score ~0.07  → Low
        // 2 medium patterns (~3.0 weight, ~0.4 confidence) = ~2.4  → Medium
        // 3-4 patterns with moderate weight = ~5-8  → High
        // 5+ patterns or financial combo = 10+  → Critical
        let maxRealistic: Double = 15.0

        // Normalize to 0.0 - 1.0
        let normalized = min(1.0, totalWeighted / maxRealistic)

        // Boost when multiple distinct pattern types detected (compound risk)
        let patternCount = Double(flagged.count)
        let coOccurrenceBonus = min(0.20, patternCount * 0.04)

        // Financial request + emotional manipulation/love bombing = classic scam combo
        let hasFinancial = flagged.contains { $0.patternType == .financialRequest }
        let hasEmotionalManip = flagged.contains { $0.patternType == .emotionalManipulation }
        let hasLoveBombing = flagged.contains { $0.patternType == .loveBombing }
        let hasTragicBackstory = flagged.contains { $0.patternType == .tragicBackstory }
        let hasAIText = flagged.contains { $0.patternType == .aiGeneratedText }
        var comboBonus: Double = 0.0
        if hasFinancial && (hasEmotionalManip || hasLoveBombing) {
            comboBonus = 0.25
        } else if hasFinancial || (hasLoveBombing && hasTragicBackstory) {
            comboBonus = 0.10
        }
        // AI-generated text combined with any romance scam pattern = extra suspicion
        if hasAIText && (hasLoveBombing || hasEmotionalManip || hasTragicBackstory || hasFinancial) {
            comboBonus += 0.10
        }

        return min(1.0, normalized + coOccurrenceBonus + comboBonus)
    }

    private func riskLevelFromScore(_ score: Double) -> RiskLevel {
        switch score {
        case 0..<0.15: return .low
        case 0.15..<0.40: return .medium
        case 0.40..<0.65: return .high
        default: return .critical
        }
    }

    // MARK: - Stage Detection

    private func detectStage(_ text: String) -> String? {
        var bestStage: String?
        var bestCount = 0
        let range = NSRange(text.startIndex..., in: text)

        for (stage, regexes) in compiledStagePatterns {
            var count = 0
            for regex in regexes {
                if regex.firstMatch(in: text, range: range) != nil {
                    count += 1
                }
            }
            if count > bestCount {
                bestCount = count
                bestStage = stage
            }
        }

        // Only return stage if we have reasonable confidence
        return bestCount >= 2 ? bestStage : nil
    }

    // MARK: - Summary & Recommendation

    private func buildSummary(flagged: [LocalScanResult.FlaggedPattern], riskLevel: RiskLevel, stage: String?) -> String {
        if flagged.isEmpty {
            return "No scam patterns were detected in this conversation. The text appears normal, but always stay cautious with online relationships."
        }

        let patternNames = flagged.prefix(4).map { $0.patternType.displayName }
        let patternList = patternNames.joined(separator: ", ")

        let stageNote: String
        if let stage = stage {
            let stageDisplay = stage.replacingOccurrences(of: "_", with: " ").capitalized
            stageNote = " The conversation appears to be in the '\(stageDisplay)' stage of a typical romance scam."
        } else {
            stageNote = ""
        }

        switch riskLevel {
        case .low:
            return "Minor patterns detected (\(patternList)). These could be innocent, but stay alert.\(stageNote)"
        case .medium:
            return "Concerning patterns found: \(patternList). This conversation shows some characteristics common in romance scams.\(stageNote)"
        case .high:
            return "Multiple serious red flags detected: \(patternList). This conversation closely matches known romance scam patterns.\(stageNote)"
        case .critical:
            return "Critical warning: \(patternList). This conversation exhibits the classic hallmarks of a romance scam.\(stageNote)"
        }
    }

    private func buildNextMovePrediction(stage: String?) -> String? {
        guard let stage = stage else { return nil }
        switch stage {
        case "initial_contact":
            return "Expect escalating affection, compliments, and talk of destiny. They may push to move off the dating platform soon."
        case "emotional_bonding":
            return "Expect requests for exclusivity, talk of marriage or meeting family, and possibly a tragic backstory to generate sympathy."
        case "exclusivity_isolation":
            return "A crisis or financial request is likely coming soon. They may introduce an 'investment opportunity' or fabricate an emergency."
        case "crisis_money_request":
            return "If you send money, expect the requests to escalate. There will always be another emergency, another fee, another obstacle."
        case "guilt_pressure":
            return "This is the pressure phase. They will threaten to end the relationship or make you feel guilty for not helping. This is manipulation."
        default:
            return nil
        }
    }

    private func buildRecommendation(flagged: [LocalScanResult.FlaggedPattern], riskLevel: RiskLevel, stage: String?) -> String {
        let hasFinancial = flagged.contains { $0.patternType == .financialRequest }
        let hasPig = flagged.contains { $0.patternType == .pigButchering }

        if hasFinancial || hasPig {
            return "DO NOT send any money, gift cards, or cryptocurrency. No matter what reason is given, a person you've never met in person asking for money is almost certainly a scam. If you've already sent money, contact your bank immediately and report to the FTC at reportfraud.ftc.gov."
        }

        switch riskLevel {
        case .low:
            return "The conversation appears mostly normal. Continue getting to know this person, but insist on a video call before sharing personal information or deepening the relationship."
        case .medium:
            return "Proceed with caution. Request a live video call to verify their identity. Do not share financial information. If they consistently avoid video calls or push for moving off the platform, consider it a serious warning sign."
        case .high:
            return "This conversation shows multiple warning signs of a romance scam. Do not send money or share personal/financial information. Insist on a video call — if they refuse, strongly consider ending contact. Talk to a trusted friend or family member about the situation."
        case .critical:
            return "This conversation closely matches known romance scam patterns. Stop all financial transactions immediately. Do not send money, gift cards, or crypto under any circumstances. Report this person to the platform, and consider filing a report at reportfraud.ftc.gov."
        }
    }
}
