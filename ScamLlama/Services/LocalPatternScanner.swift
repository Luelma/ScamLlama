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
        compiledPatterns = Self.patterns.map { def in
            let regexes: [(String, NSRegularExpression)] = def.phrases.compactMap { phrase in
                guard let regex = try? NSRegularExpression(pattern: phrase, options: .caseInsensitive) else {
                    return nil
                }
                return (phrase, regex)
            }
            return CompiledPattern(type: def.type, regexes: regexes, explanation: def.explanation)
        }

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
                "western union", "moneygram", "cash app", "zelle", "venmo",
                "bank account", "routing number", "account number",
                "need money", "need \\$", "need financial", "financial help",
                "send \\$", "\\$\\d{2,}", "pay for", "cover the cost",
                "urgent payment", "transfer funds", "money transfer",
                "help me financially", "just this once", "small amount",
                "processing fee", "release fee", "clearance fee",
                "tax payment", "legal fee", "administration fee",
                "insurance fee", "handling charge", "activation fee",
                "deposit required", "security deposit", "refundable deposit",
                "pay.*upfront", "advance.*payment", "pay.*before"
            ],
            explanation: "Requests for money — especially via gift cards, wire transfers, or cryptocurrency — are the hallmark of financial scams. Legitimate businesses and government agencies never request payment through these methods."
        ),

        // ── Urgency & Pressure ───────────────────────────────────
        PatternDef(
            type: .urgencyPressure,
            phrases: [
                "act now", "act fast", "act immediately", "right away",
                "limited time", "expires today", "expires soon", "last chance",
                "urgent", "immediately", "right now", "don't delay",
                "within 24 hours", "within the hour", "time.sensitive",
                "only.*available.*today", "offer expires", "window.*closing",
                "must.*respond.*today", "cannot wait", "don't have much time",
                "today only", "final notice", "last warning",
                "account.*suspended", "account.*locked", "account.*closed",
                "will be.*terminated", "will be.*suspended", "will be.*deleted",
                "lose access", "immediate action required",
                "failure to respond", "if you don't act",
                "before it's too late", "running out of time",
                "deadline.*today", "must be.*resolved"
            ],
            explanation: "Scammers create artificial urgency to prevent you from thinking clearly or consulting others. Legitimate organizations give you time to make decisions and verify information through official channels."
        ),

        // ── Upfront Payment Required ─────────────────────────────
        PatternDef(
            type: .upfrontPayment,
            phrases: [
                "pay.*to receive", "fee.*to release", "pay.*to claim",
                "send.*to unlock", "deposit.*to access", "payment.*to process",
                "small fee.*to get", "pay.*before.*can.*release",
                "advance fee", "advance payment", "upfront cost",
                "one.time fee", "membership fee", "registration fee",
                "pay.*first", "send.*first.*then", "fee required.*before",
                "processing.*requires.*payment", "must pay.*to continue",
                "service charge.*before"
            ],
            explanation: "Legitimate prizes, jobs, loans, and services never require you to pay money upfront to receive them. Advance fee fraud is one of the most common scam tactics — once you pay, the scammer disappears or invents more fees."
        ),

        // ── Unusual Payment Method ───────────────────────────────
        PatternDef(
            type: .unusualPaymentMethod,
            phrases: [
                "gift card", "buy.*gift card", "scratch.*card",
                "itunes.*card", "google play.*card", "steam.*card",
                "send.*card number", "card.*code", "redemption code",
                "wire transfer only", "only.*accept.*crypto",
                "pay.*in bitcoin", "send.*btc", "crypto.*wallet",
                "money order", "cashier.?s check",
                "prepaid.*debit", "prepaid.*card",
                "pay with.*apple pay", "pay with.*venmo",
                "send.*through.*cash app", "zelle.*only",
                "payment.*app", "no credit card", "no bank transfer",
                "cannot.*accept.*regular payment"
            ],
            explanation: "Scammers insist on untraceable payment methods — gift cards, cryptocurrency, wire transfers, or payment apps — because these cannot be reversed. No legitimate business or government agency asks for payment via gift cards."
        ),

        // ── Overpayment / Refund Scam ────────────────────────────
        PatternDef(
            type: .overpaymentRefund,
            phrases: [
                "overpayment", "overpaid", "sent too much",
                "send.*difference", "refund.*the rest", "return.*the excess",
                "accidental.*payment", "accidentally.*sent",
                "refund.*due", "refund.*pending", "owed a refund",
                "excess.*amount", "please return", "send back",
                "refund.*process", "claim.*your.*refund",
                "subscription.*refund", "cancel.*refund",
                "too much.*was charged", "duplicate.*charge"
            ],
            explanation: "In overpayment scams, scammers send a fake check or 'accidentally' overpay you, then ask you to return the difference. The original payment bounces, and you lose the money you sent back. Refund scams trick you into giving remote access or sending money to 'process' a refund."
        ),

        // ── Fake Crypto / Investment ─────────────────────────────
        PatternDef(
            type: .fakeCryptoInvestment,
            phrases: [
                "invest.*crypto", "crypto.*opportunity", "crypto.*platform",
                "bitcoin.*investment", "trading.*platform", "forex.*trading",
                "guaranteed.*profit", "guaranteed.*return", "risk.free.*investment",
                "double your money", "triple your returns",
                "exclusive.*investment", "private.*investment.*group",
                "minimum.*investment", "initial.*deposit",
                "trading.*bot", "automated.*trading", "ai.*trading",
                "passive.*income", "financial.*freedom",
                "join.*my.*platform", "sign up.*platform",
                "crypto.*mining", "cloud.*mining",
                "nft.*opportunity", "token.*launch", "ico",
                "defi.*opportunity", "yield.*farming",
                "liquidity.*pool", "staking.*reward"
            ],
            explanation: "Fake investment and crypto scams promise unrealistic returns to lure victims into depositing money on fraudulent platforms. The platform may show fake profits, but you can never withdraw. This includes pig butchering scams where trust is built before introducing the investment."
        ),

        // ── Guaranteed Returns ───────────────────────────────────
        PatternDef(
            type: .guaranteedReturns,
            phrases: [
                "guaranteed.*return", "guaranteed.*profit", "no risk",
                "risk.free", "100%.*return", "500%.*return", "1000%.*return",
                "double.*your.*money", "triple.*your.*money",
                "\\d+%.*daily", "\\d+%.*weekly", "\\d+%.*monthly",
                "can't lose", "never lose", "always.*profit",
                "proven.*system", "proven.*strategy", "proven.*method",
                "everyone.*making money", "people.*getting rich",
                "secret.*method", "insider.*information", "insider.*tip",
                "make.*\\$\\d+.*per day", "earn.*\\$\\d+.*daily",
                "make money.*while you sleep", "passive.*\\$\\d+"
            ],
            explanation: "No legitimate investment guarantees returns. Any promise of guaranteed profits, risk-free investing, or unrealistic returns (especially percentages per day/week) is a hallmark of investment fraud. Real investments always carry risk."
        ),

        // ── Fake Trading Platform ────────────────────────────────
        PatternDef(
            type: .tradingPlatformScam,
            phrases: [
                "download.*app", "download.*platform",
                "create.*account.*on", "sign up.*on.*platform",
                "open.*trading.*account", "register.*on.*exchange",
                "deposit.*to start", "fund.*your.*account",
                "withdrawal.*fee", "can't.*withdraw",
                "pay.*tax.*before.*withdraw", "verify.*before.*withdraw",
                "account.*frozen.*pay", "need.*more.*deposit",
                "upgrade.*your.*account", "premium.*account.*required",
                "minimum.*balance.*required", "platform.*maintenance.*fee"
            ],
            explanation: "Fake trading platforms look professional but are designed to steal your money. They show fake profits to encourage larger deposits, then lock your account or demand fees when you try to withdraw. Always verify platforms through official financial regulators."
        ),

        // ── Pig Butchering (Financial Side) ──────────────────────
        PatternDef(
            type: .pigButcheringFinancial,
            phrases: [
                "my uncle.*invest", "my friend.*invest", "my mentor.*showed",
                "i made.*so much", "look at my profits", "look at my returns",
                "let me show you", "let me teach you", "i can help you invest",
                "just start.*small", "start with.*small amount",
                "i started with.*\\$", "try it.*small amount",
                "the platform is.*legit", "it's regulated", "it's licensed",
                "i use it myself", "i've been using",
                "you can withdraw.*anytime", "easy.*to.*withdraw",
                "my account manager", "my broker", "my financial advisor",
                "you should try it", "what do you have to lose"
            ],
            explanation: "Pig butchering scams involve someone building a relationship with you (online or in person), then gradually introducing a 'great investment opportunity.' They show fake screenshots of their own 'profits' and coach you to invest on a fraudulent platform."
        ),

        // ── Bank Impersonation ───────────────────────────────────
        PatternDef(
            type: .bankImpersonation,
            phrases: [
                "your bank", "bank.*security", "bank.*department",
                "fraud.*department", "fraud.*alert", "fraud.*detected",
                "suspicious.*activity", "unauthorized.*transaction",
                "verify.*your.*account", "confirm.*your.*identity",
                "update.*your.*information", "update.*banking",
                "card.*compromised", "account.*compromised",
                "temporary.*hold", "security.*freeze",
                "call.*this number", "call.*us.*immediately",
                "provide.*your.*pin", "confirm.*your.*ssn",
                "last four.*digits", "social security",
                "online.*banking.*login", "verify.*credentials"
            ],
            explanation: "Scammers impersonate banks to steal your login credentials, Social Security number, or PIN. Real banks never ask for your full password, PIN, or SSN via text, email, or unsolicited calls. Always call the number on the back of your card if you're concerned."
        ),

        // ── Government Impersonation ─────────────────────────────
        PatternDef(
            type: .governmentImpersonation,
            phrases: [
                "irs", "internal revenue", "tax.*refund", "tax.*owed",
                "social security.*administration", "ssa",
                "medicare", "medicaid",
                "department of", "federal.*agency", "government.*agency",
                "warrant.*for.*arrest", "arrest warrant",
                "legal.*action.*against", "lawsuit.*filed",
                "back taxes", "unpaid.*taxes", "tax.*lien",
                "stimulus.*check", "stimulus.*payment",
                "benefits.*suspended", "benefits.*expired",
                "immigration.*status", "visa.*expired",
                "court.*appearance", "court.*summons",
                "fbi", "dea", "dhs", "homeland security",
                "badge number", "case number", "file number"
            ],
            explanation: "Government agencies (IRS, SSA, FBI, etc.) do not contact people by text, email, or phone to demand immediate payment or threaten arrest. They send official mail first. Never pay a 'government official' with gift cards, wire transfers, or crypto."
        ),

        // ── Tech Support Scam ────────────────────────────────────
        PatternDef(
            type: .techSupportScam,
            phrases: [
                "your computer.*infected", "virus.*detected", "malware.*found",
                "security.*breach", "hacked", "been compromised",
                "microsoft.*support", "apple.*support", "windows.*support",
                "tech.*support", "technical.*support",
                "remote.*access", "teamviewer", "anydesk", "logmein",
                "let me.*connect", "remote.*session",
                "download.*this.*software", "install.*this.*program",
                "your.*ip.*address", "ip.*has been flagged",
                "subscription.*expired", "license.*expired",
                "renew.*subscription", "auto.*renewal.*\\$",
                "geek.*squad", "norton.*renewal", "mcafee.*renewal"
            ],
            explanation: "Tech support scammers claim your device is infected or your account is compromised to gain remote access or charge for fake repairs. Microsoft, Apple, and other companies never make unsolicited calls about your computer. Never give remote access to someone who contacts you first."
        ),

        // ── Utility Impersonation ────────────────────────────────
        PatternDef(
            type: .utilityImpersonation,
            phrases: [
                "power.*will be.*shut off", "electricity.*disconnected",
                "gas.*service.*terminated", "water.*shut off",
                "utility.*payment.*overdue", "past due.*utility",
                "final.*disconnect.*notice", "service.*interruption",
                "pay.*to avoid.*disconnection", "avoid.*shutoff",
                "energy.*company", "electric.*company",
                "pay.*immediately.*or.*service"
            ],
            explanation: "Utility impersonation scams threaten immediate service disconnection unless you pay right away via unusual methods. Real utility companies send multiple written notices before disconnection and accept standard payment methods."
        ),

        // ── Phishing Attempt ─────────────────────────────────────
        PatternDef(
            type: .phishingAttempt,
            phrases: [
                "click.*here", "click.*this.*link", "click.*below",
                "verify.*your.*email", "verify.*your.*account",
                "confirm.*your.*information", "update.*your.*details",
                "log.*in.*to.*verify", "sign.*in.*to.*confirm",
                "unusual.*sign.in", "unusual.*login",
                "unrecognized.*device", "new.*device.*detected",
                "security.*alert", "security.*notification",
                "password.*reset", "password.*expired",
                "action.*required", "attention.*required",
                "your.*package", "track.*your.*order",
                "delivery.*failed", "delivery.*attempt",
                "update.*payment.*method", "payment.*failed"
            ],
            explanation: "Phishing messages impersonate trusted companies to trick you into clicking malicious links or entering your credentials on fake websites. Always go directly to the official website by typing the URL yourself — never click links in suspicious messages."
        ),

        // ── Account Verification Scam ────────────────────────────
        PatternDef(
            type: .accountVerification,
            phrases: [
                "verify.*your.*identity", "identity.*verification",
                "send.*photo.*of.*id", "copy.*of.*your.*id",
                "driver.*license", "passport.*copy",
                "selfie.*with.*id", "selfie.*holding",
                "ssn", "social security number", "social.*security",
                "date of birth", "mother.*maiden name",
                "security.*question", "verification.*code",
                "one.time.*password", "otp", "2fa.*code",
                "send.*the code", "share.*the code",
                "text.*you.*a code", "code.*we.*sent"
            ],
            explanation: "Scammers pose as legitimate services to harvest your personal information, ID documents, or one-time verification codes. Sharing a 2FA code allows scammers to break into your accounts. No legitimate company asks you to share verification codes sent to your phone."
        ),

        // ── Suspicious Link ──────────────────────────────────────
        PatternDef(
            type: .suspiciousLink,
            phrases: [
                "bit\\.ly", "tinyurl", "t\\.co", "goo\\.gl", "ow\\.ly",
                "shortened.*link", "click.*link.*below",
                "http[^s].*\\.", "www\\..*\\.(xyz|tk|ml|ga|cf|top|buzz|click)",
                "download.*from.*this", "open.*this.*file",
                "view.*document", "view.*attachment",
                "sign.*in.*at", "log.*in.*at",
                "claim.*at", "redeem.*at", "collect.*at"
            ],
            explanation: "Shortened URLs and links to unfamiliar domains are commonly used in phishing and malware attacks. Legitimate companies use their official domains. Be especially wary of links in unsolicited messages asking you to sign in or claim something."
        ),

        // ── Credential Harvesting ────────────────────────────────
        PatternDef(
            type: .credentialHarvesting,
            phrases: [
                "enter.*your.*password", "type.*your.*password",
                "provide.*your.*login", "share.*your.*credentials",
                "username.*and.*password", "login.*details",
                "bank.*login", "email.*password",
                "send me.*your.*password", "what is.*your.*password",
                "give me.*access", "share.*access.*to",
                "log in.*on my behalf", "let me.*log in",
                "need.*your.*apple.*id", "need.*your.*google.*password"
            ],
            explanation: "No legitimate service, employee, or support agent will ever ask for your password directly. This is a direct attempt to steal your account credentials. Never share passwords, PINs, or security codes with anyone."
        ),

        // ── Fake Job Offer ───────────────────────────────────────
        PatternDef(
            type: .fakeJobOffer,
            phrases: [
                "job.*opportunity", "work.*from home", "work.*remotely",
                "earn.*\\$\\d+.*per hour", "earn.*\\$\\d+.*per week",
                "no experience.*needed", "no experience.*required",
                "hiring.*immediately", "start.*today", "start.*now",
                "easy money", "easy work", "simple tasks",
                "data entry.*job", "social media.*job",
                "package.*forwarding", "receive.*packages",
                "personal.*assistant", "virtual.*assistant.*job",
                "mystery.*shopper", "secret.*shopper",
                "buy.*gift cards.*for.*company",
                "training.*fee", "equipment.*fee", "background check.*fee",
                "pay.*for.*training", "invest.*in.*equipment"
            ],
            explanation: "Fake job scams promise easy, high-paying work then ask you to pay for training, equipment, or background checks upfront. Reshipping scams recruit you to forward stolen goods. Legitimate employers never charge you to start a job."
        ),

        // ── Work From Home Scam ──────────────────────────────────
        PatternDef(
            type: .workFromHomeScam,
            phrases: [
                "work from home", "work from anywhere",
                "be your own boss", "financial freedom",
                "unlimited earning", "unlimited income",
                "no.*selling.*required", "not.*mlm",
                "ground.*floor.*opportunity", "join.*my.*team",
                "direct.*sales", "network.*marketing",
                "residual.*income", "downline",
                "change.*your.*life", "quit.*your.*job",
                "fire.*your.*boss", "replace.*your.*income",
                "six.*figure", "five.*figure.*month"
            ],
            explanation: "Work-from-home scams promise unrealistic income for minimal work. MLM/pyramid schemes disguise themselves as business opportunities. Legitimate remote jobs have clear job descriptions, real companies, and never promise guaranteed income."
        ),

        // ── Reshipping / Money Mule ──────────────────────────────
        PatternDef(
            type: .reshippingMule,
            phrases: [
                "receive.*packages.*for us", "forward.*packages",
                "reship", "package.*forwarding.*job",
                "receive.*funds.*transfer", "transfer.*money.*for us",
                "payment.*processing.*job", "financial.*agent",
                "receive.*deposits", "forward.*funds",
                "use.*your.*bank account", "we'll.*deposit.*into.*your",
                "keep.*a.*percentage", "keep.*\\d+%", "commission.*for.*forwarding"
            ],
            explanation: "Reshipping and money mule scams use you to launder stolen goods or money. You receive packages (bought with stolen cards) and forward them, or receive stolen funds and wire them onwards. This makes you legally liable for the criminal activity."
        ),

        // ── Lottery / Prize Scam ─────────────────────────────────
        PatternDef(
            type: .lotteryPrizeScam,
            phrases: [
                "you've won", "you have won", "you are a winner",
                "congratulations.*winner", "selected.*as.*winner",
                "lottery.*winner", "prize.*winner",
                "claim.*your.*prize", "collect.*your.*winnings",
                "unclaimed.*funds", "unclaimed.*prize",
                "random.*selection", "randomly.*selected",
                "email.*lottery", "online.*lottery",
                "lucky.*winner", "lucky.*draw",
                "free.*prize", "won.*a.*free",
                "grand.*prize", "jackpot"
            ],
            explanation: "You cannot win a lottery or contest you never entered. Prize scams tell you that you've won but require you to pay taxes, fees, or shipping before receiving your 'prize.' The prize doesn't exist — they just want your payment."
        ),

        // ── Inheritance Scam ─────────────────────────────────────
        PatternDef(
            type: .inheritanceScam,
            phrases: [
                "inheritance", "beneficiary", "next of kin",
                "deceased.*client", "deceased.*relative",
                "unclaimed.*inheritance", "unclaimed.*estate",
                "million.*dollars", "\\$\\d+.*million",
                "barrister", "solicitor", "attorney.*representing",
                "estate.*of.*the late", "will.*and.*testament",
                "bank.*in.*africa", "bank.*in.*europe",
                "foreign.*account", "dormant.*account",
                "share.*the.*funds", "split.*the.*money",
                "diplomatic.*delivery", "diplomatic.*courier"
            ],
            explanation: "Inheritance scams claim a stranger or distant relative left you a fortune, but you need to pay fees to release it. These emails often come from 'lawyers' or 'bankers' in foreign countries. No legitimate inheritance requires upfront payments from the beneficiary."
        ),

        // ── Sweepstakes Scam ─────────────────────────────────────
        PatternDef(
            type: .sweepstakesScam,
            phrases: [
                "sweepstakes", "giveaway.*winner",
                "promotional.*draw", "promotional.*event",
                "your.*entry.*was selected", "your.*email.*was selected",
                "reward.*program", "loyalty.*reward",
                "exclusive.*offer.*for you", "special.*selection",
                "cash.*prize", "monetary.*award",
                "claim.*within.*\\d+.*hours", "expires.*if.*not.*claimed"
            ],
            explanation: "Sweepstakes and giveaway scams create excitement about fake winnings to extract fees or personal information. Legitimate sweepstakes never require payment to claim prizes and are governed by strict legal rules."
        ),

        // ── Legal Threat ─────────────────────────────────────────
        PatternDef(
            type: .legalThreat,
            phrases: [
                "legal action", "lawsuit", "sue you",
                "court.*order", "subpoena", "warrant",
                "press.*charges", "criminal.*charges",
                "arrest.*warrant", "come.*arrest",
                "law.*enforcement", "police.*report",
                "going to jail", "face.*prosecution",
                "settle.*out of court", "pay.*to.*avoid.*charges",
                "fine.*of.*\\$", "penalty.*of.*\\$",
                "unless.*you.*pay", "unless.*you.*settle",
                "lawyer.*will.*contact", "attorney.*will.*contact",
                "legal.*department", "compliance.*department"
            ],
            explanation: "Scammers use legal threats to create fear and pressure you into paying. Real legal proceedings are served formally through courts, not via text messages, emails, or phone calls demanding immediate payment."
        ),

        // ── Fake Debt Collection ─────────────────────────────────
        PatternDef(
            type: .debtCollectionScam,
            phrases: [
                "outstanding.*debt", "unpaid.*balance", "past due.*account",
                "collection.*agency", "debt.*collector",
                "settle.*your.*debt", "negotiate.*your.*debt",
                "pay.*what.*you.*owe", "debt.*resolution",
                "final.*attempt", "last.*notice.*before",
                "report.*to.*credit.*bureau", "damage.*your.*credit",
                "garnish.*wages", "seize.*assets",
                "payment.*plan.*available", "reduced.*settlement"
            ],
            explanation: "Fake debt collectors pressure you to pay debts you don't owe or debts that have already been paid. Real debt collectors must provide written validation of the debt and follow specific legal procedures. Never pay a debt you can't verify."
        ),

        // ── Blackmail / Extortion ────────────────────────────────
        PatternDef(
            type: .blackmailExtortion,
            phrases: [
                "i have your.*password", "i hacked.*your",
                "i recorded.*you", "i have.*footage",
                "compromising.*photos", "compromising.*video",
                "send.*to your contacts", "share.*with.*everyone",
                "expose.*you", "ruin.*your.*reputation",
                "pay.*or.*i will", "send.*bitcoin.*or",
                "\\d+.*hours.*to pay", "\\d+.*days.*to pay",
                "know what you did", "we know about",
                "remain anonymous", "this is automated",
                "browsing.*history", "webcam.*recording",
                "adult.*website", "explicit.*content"
            ],
            explanation: "Blackmail/extortion scams claim to have embarrassing information or recordings and demand payment (usually in crypto). These are almost always bluffs — they send the same mass email to millions. Do not pay, do not respond, and report to authorities."
        ),

        // ── Emotional Manipulation ───────────────────────────────
        PatternDef(
            type: .emotionalManipulation,
            phrases: [
                "you're my only hope", "you're the only one",
                "no one else can help", "i have no one",
                "i'll die.*without", "my children.*will suffer",
                "please.*i'm begging", "i'm desperate",
                "don't abandon me", "you promised",
                "after everything i", "if you really cared",
                "guilt", "how could you",
                "think of.*the children", "for the kids",
                "god.*will bless", "god.*will repay",
                "you'll be.*rewarded", "karma.*will"
            ],
            explanation: "Scammers use emotional manipulation — guilt, sympathy, religious appeals, or threats of self-harm — to pressure you into complying. Legitimate requests don't come with emotional coercion. Take a step back and consult someone you trust before acting."
        ),

        // ── Charity Scam ─────────────────────────────────────────
        PatternDef(
            type: .charityScam,
            phrases: [
                "donate.*now", "donation.*needed", "urgent.*donation",
                "help.*the children", "feed.*the hungry",
                "charity.*foundation", "nonprofit.*organization",
                "tax.*deductible.*donation", "100%.*goes.*to",
                "make a difference", "save.*lives",
                "matching.*donation", "double.*your.*donation",
                "donate.*via.*gift card", "donate.*via.*crypto"
            ],
            explanation: "Charity scams exploit your generosity by impersonating real charities or creating fake ones, especially after disasters. Always verify charities through give.org or charitynavigator.org before donating, and never donate via gift cards or wire transfers."
        ),

        // ── Disaster Relief Scam ─────────────────────────────────
        PatternDef(
            type: .disasterReliefScam,
            phrases: [
                "disaster.*relief", "hurricane.*fund", "earthquake.*fund",
                "flood.*relief", "wildfire.*fund",
                "emergency.*fund", "crisis.*fund",
                "victims.*need", "help.*victims",
                "rebuild", "recovery.*fund",
                "gofundme", "crowdfund.*for"
            ],
            explanation: "After disasters, scammers create fake relief funds or impersonate legitimate charities. Verify any disaster relief organization through official channels before donating. Be especially wary of social media solicitations and crowdfunding links from unknown sources."
        ),

        // ── Rental / Housing Scam ────────────────────────────────
        PatternDef(
            type: .rentalHousingScam,
            phrases: [
                "apartment.*for rent", "house.*for rent",
                "below.*market.*rent", "great.*deal.*on.*rent",
                "available.*immediately", "move in.*today",
                "first.*month.*deposit", "security.*deposit.*wire",
                "can't.*show.*the property", "out of.*town",
                "send.*deposit.*to hold", "won't.*last.*long",
                "application.*fee", "background.*check.*fee.*upfront",
                "keys.*upon.*payment", "sight.*unseen"
            ],
            explanation: "Rental scams list properties at below-market prices to attract victims, then demand deposits or fees before you can see the property. The scammer often claims to be out of town. Never send money for a rental you haven't visited in person."
        ),

        // ── Too Good to Be True ──────────────────────────────────
        PatternDef(
            type: .tooGoodToBeTrue,
            phrases: [
                "too good to be true", "unbelievable.*deal",
                "once in a lifetime", "amazing.*opportunity",
                "incredible.*offer", "special.*offer.*just for you",
                "exclusive.*access", "vip.*access",
                "free.*money", "free.*\\$\\d+",
                "congratulations.*selected", "chosen.*specially",
                "millionaire", "get rich", "make.*fortune",
                "secret.*to.*wealth", "wealth.*secret",
                "overnight.*success", "instant.*wealth",
                "free.*iphone", "free.*macbook", "free.*gift"
            ],
            explanation: "If an offer sounds too good to be true, it almost certainly is. Scammers lure victims with unrealistic promises — free money, exclusive deals, secret wealth methods. Legitimate opportunities don't need to be sold with extreme language."
        ),

        // ── Inconsistent Details ─────────────────────────────────
        PatternDef(
            type: .inconsistentDetails,
            phrases: [],
            explanation: "Inconsistencies in stories, names, companies, or details are a sign of fraud. This is best detected by AI analysis — add an API key in Settings for deeper analysis."
        ),

        // ── Scripted / Generic Responses ─────────────────────────
        PatternDef(
            type: .grammarScriptedResponses,
            phrases: [
                "dear sir", "dear madam", "dear customer",
                "dear valued", "dear beneficiary", "dear winner",
                "dear friend", "dear beloved",
                "kindly", "do the needful", "kindly revert",
                "humbly", "with due respect",
                "i am.*prince", "i am.*barrister", "i am.*diplomat",
                "writing to inform", "pleased to inform",
                "this is to notify", "be informed that",
                "hoping to hear.*from you.*soon",
                "remain blessed", "god bless"
            ],
            explanation: "Scam messages often use stilted, formal, or formulaic language — 'Dear Sir/Madam,' 'Kindly,' or excessively polite phrasing. These scripted templates are a hallmark of mass-distributed fraud emails and messages."
        ),

        // ── AI-Generated Text ────────────────────────────────────
        PatternDef(
            type: .aiGeneratedText,
            phrases: [],
            explanation: "AI-generated text can be unnaturally fluent and generic, lacking personal specifics. This is best detected by AI analysis — add an API key in Settings for deeper analysis."
        ),

        // ── Package Delivery Scam ────────────────────────────────
        PatternDef(
            type: .packageDeliveryScam,
            phrases: [
                "package.*delivery", "your.*package", "your.*parcel",
                "delivery.*attempt.*failed", "unable.*to.*deliver",
                "reschedule.*delivery", "update.*delivery.*address",
                "tracking.*number", "track.*your.*package",
                "customs.*fee.*required", "import.*duty",
                "pay.*to.*release.*package", "shipping.*fee",
                "usps", "ups", "fedex", "dhl",
                "postal.*service", "courier.*service",
                "confirm.*delivery.*details", "verify.*shipping.*address"
            ],
            explanation: "Package delivery scams send fake shipping notifications with links to phishing sites or demand fees to 'release' packages. If you're expecting a delivery, check the status directly on the carrier's official website — not through links in messages."
        )
    ]

    // MARK: - Conversation Stage Detection

    private static let stagePatterns: [(stage: String, phrases: [String])] = [
        ("initial_contact", [
            "congratulations", "you've been selected", "dear sir",
            "dear madam", "we are contacting you", "writing to inform",
            "i came across", "i found your", "is this still available"
        ]),
        ("building_trust", [
            "i can show you", "let me prove", "here are my results",
            "screenshot.*profits", "look at this", "trust me",
            "i'm a real person", "i'm legitimate", "you can verify",
            "check my.*website", "check my.*profile"
        ]),
        ("setup", [
            "all you need to do", "just follow these steps",
            "create.*account", "sign up.*here", "download.*this",
            "click.*this.*link", "visit.*this.*site",
            "small.*investment", "start.*with.*\\$", "minimum.*deposit"
        ]),
        ("extraction", [
            "send.*money", "wire.*transfer", "gift card",
            "pay.*fee", "processing.*fee", "release.*fee",
            "deposit.*required", "payment.*required",
            "send.*bitcoin", "send.*crypto"
        ]),
        ("escalation", [
            "more.*money", "additional.*fee", "another.*payment",
            "one more", "final.*payment", "last.*fee",
            "you'll lose.*everything", "can't.*withdraw.*until",
            "account.*locked", "must.*pay.*to.*unlock",
            "if you don't pay", "legal.*action"
        ])
    ]

    // MARK: - Main Scan

    func scan(_ text: String, context: ConversationContext? = nil) -> LocalScanResult {
        let safeText = String(text.prefix(50_000))
        let lowered = safeText.lowercased()
        var flagged: [LocalScanResult.FlaggedPattern] = []

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

    // MARK: - Context Scoring Boosts

    private func applySyntheticFlags(flagged: [LocalScanResult.FlaggedPattern], context: ConversationContext) -> [LocalScanResult.FlaggedPattern] {
        var result = flagged
        let existingTypes = Set(flagged.map { $0.patternType })

        // Already made payments = critical
        if context.hasMadePayments == true,
           !existingTypes.contains(.financialRequest) {
            result.append(.init(
                patternType: .financialRequest,
                matchedPhrases: ["User reported: has already made payments"],
                matchCount: 1,
                confidence: 0.85,
                explanation: "You reported that you have already sent money. If this was to someone you haven't verified through official channels, contact your bank immediately to attempt a reversal and report the fraud."
            ))
        }

        // Asked for money
        if context.hasBeenAskedForMoney == true,
           !existingTypes.contains(.financialRequest),
           context.hasMadePayments != true {
            result.append(.init(
                patternType: .financialRequest,
                matchedPhrases: ["User reported: has been asked for money"],
                matchCount: 1,
                confidence: 0.75,
                explanation: "You reported that you've been asked for money. Be extremely cautious — verify the identity and legitimacy of anyone requesting payment through official channels before sending anything."
            ))
        }

        // Shared personal info
        if context.hasSharedPersonalInfo == true,
           !existingTypes.contains(.credentialHarvesting) {
            result.append(.init(
                patternType: .credentialHarvesting,
                matchedPhrases: ["User reported: shared personal information"],
                matchCount: 1,
                confidence: 0.70,
                explanation: "You reported sharing personal information (SSN, bank details, etc.). If you shared this with an unverified contact, monitor your accounts closely, consider a credit freeze, and change any compromised passwords immediately."
            ))
        }

        // They contacted you first (unsolicited)
        if context.contactedYouFirst == true {
            let hasAnyScamPattern = !flagged.isEmpty
            if hasAnyScamPattern {
                // Unsolicited contact + scam patterns = boost confidence on all flags
                result = result.map { pattern in
                    .init(
                        patternType: pattern.patternType,
                        matchedPhrases: pattern.matchedPhrases,
                        matchCount: pattern.matchCount,
                        confidence: min(0.95, pattern.confidence + 0.10),
                        explanation: pattern.explanation
                    )
                }
            }
        }

        return result
    }

    private func applyContextBoosts(score: Double, flagged: [LocalScanResult.FlaggedPattern], context: ConversationContext) -> Double {
        var boosted = score

        // Already made payments: +0.25
        if context.hasMadePayments == true {
            boosted += 0.25
        }

        // Asked for money: +0.20
        if context.hasBeenAskedForMoney == true {
            boosted += 0.20
        }

        // Shared personal info: +0.15
        if context.hasSharedPersonalInfo == true {
            boosted += 0.15
        }

        // Clicked links: +0.10
        if context.hasClickedLinks == true {
            boosted += 0.10
        }

        // Unsolicited contact: +0.10
        if context.contactedYouFirst == true {
            boosted += 0.10
        }

        // Short contact + financial request = high risk
        let hasFinancial = flagged.contains { $0.patternType == .financialRequest }
        if hasFinancial, context.contactDuration == .lessThanWeek {
            boosted += 0.15
        }

        return min(1.0, boosted)
    }

    // MARK: - Scoring

    private func calculateWeightedScore(_ flagged: [LocalScanResult.FlaggedPattern]) -> Double {
        guard !flagged.isEmpty else { return 0.0 }

        let totalWeighted = flagged.reduce(0.0) { sum, pattern in
            sum + pattern.patternType.weight * pattern.confidence
        }

        let maxRealistic: Double = 15.0
        let normalized = min(1.0, totalWeighted / maxRealistic)

        let patternCount = Double(flagged.count)
        let coOccurrenceBonus = min(0.20, patternCount * 0.04)

        // Classic scam combos
        let hasFinancial = flagged.contains { $0.patternType == .financialRequest }
        let hasUrgency = flagged.contains { $0.patternType == .urgencyPressure }
        let hasImpersonation = flagged.contains {
            [.bankImpersonation, .governmentImpersonation, .techSupportScam, .utilityImpersonation].contains($0.patternType)
        }
        let hasUpfront = flagged.contains { $0.patternType == .upfrontPayment }
        let hasGuaranteed = flagged.contains { $0.patternType == .guaranteedReturns }
        let hasCrypto = flagged.contains { $0.patternType == .fakeCryptoInvestment }
        let hasAIText = flagged.contains { $0.patternType == .aiGeneratedText }

        var comboBonus: Double = 0.0

        // Urgency + financial request = classic scam combo
        if hasFinancial && hasUrgency {
            comboBonus = 0.25
        }
        // Impersonation + urgency = impersonation scam combo
        else if hasImpersonation && hasUrgency {
            comboBonus = 0.20
        }
        // Guaranteed returns + crypto = investment scam combo
        else if hasGuaranteed && hasCrypto {
            comboBonus = 0.25
        }
        // Upfront payment + any other flag
        else if hasUpfront && flagged.count > 1 {
            comboBonus = 0.15
        }

        if hasAIText && flagged.count > 1 {
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

        return bestCount >= 2 ? bestStage : nil
    }

    // MARK: - Summary & Recommendation

    private func buildSummary(flagged: [LocalScanResult.FlaggedPattern], riskLevel: RiskLevel, stage: String?) -> String {
        if flagged.isEmpty {
            return "No scam patterns were detected in this text. The message appears normal, but always verify unexpected requests through official channels."
        }

        let patternNames = flagged.prefix(4).map { $0.patternType.displayName }
        let patternList = patternNames.joined(separator: ", ")

        let stageNote: String
        if let stage = stage {
            let stageDisplay = stage.replacingOccurrences(of: "_", with: " ").capitalized
            stageNote = " This appears to be in the '\(stageDisplay)' stage of a typical scam."
        } else {
            stageNote = ""
        }

        switch riskLevel {
        case .low:
            return "Minor patterns detected (\(patternList)). These could be legitimate, but stay alert.\(stageNote)"
        case .medium:
            return "Concerning patterns found: \(patternList). This message shows characteristics common in financial scams.\(stageNote)"
        case .high:
            return "Multiple serious red flags detected: \(patternList). This closely matches known scam patterns.\(stageNote)"
        case .critical:
            return "Critical warning: \(patternList). This message exhibits the classic hallmarks of a financial scam.\(stageNote)"
        }
    }

    private func buildNextMovePrediction(stage: String?) -> String? {
        guard let stage = stage else { return nil }
        switch stage {
        case "initial_contact":
            return "Expect them to build credibility — sharing fake credentials, websites, or testimonials. They'll try to establish trust before making any financial request."
        case "building_trust":
            return "They're establishing credibility to lower your guard. Expect them to soon present an 'opportunity' or make a request that involves money, personal information, or account access."
        case "setup":
            return "They're guiding you toward taking action — creating accounts, clicking links, or making small initial payments. These are designed to commit you psychologically before larger requests."
        case "extraction":
            return "This is the money extraction phase. If you comply, expect escalating requests — additional fees, taxes, or 'problems' that require more payments to resolve."
        case "escalation":
            return "They're pressuring you for more money or threatening consequences. This is a sign they've already extracted what they can and are making a final push. Do not send more money."
        default:
            return nil
        }
    }

    private func buildRecommendation(flagged: [LocalScanResult.FlaggedPattern], riskLevel: RiskLevel, stage: String?) -> String {
        let hasFinancial = flagged.contains { $0.patternType == .financialRequest }
        let hasCrypto = flagged.contains { $0.patternType == .fakeCryptoInvestment }
        let hasPig = flagged.contains { $0.patternType == .pigButcheringFinancial }
        let hasImpersonation = flagged.contains {
            [.bankImpersonation, .governmentImpersonation, .techSupportScam].contains($0.patternType)
        }
        let hasCredential = flagged.contains {
            [.credentialHarvesting, .accountVerification, .phishingAttempt].contains($0.patternType)
        }

        if hasFinancial || hasCrypto || hasPig {
            return "DO NOT send any money, gift cards, or cryptocurrency. Verify any claims independently through official channels (call the company directly using a number you find yourself, not one they provide). If you've already sent money, contact your bank immediately and report to the FTC at reportfraud.ftc.gov."
        }

        if hasImpersonation {
            return "Do not trust caller ID, email addresses, or official-looking messages — these can all be spoofed. Hang up and contact the organization directly using a phone number from their official website or the back of your card. Never give personal information to someone who contacted you."
        }

        if hasCredential {
            return "Never share passwords, PINs, verification codes, or personal information with anyone who contacts you. Go directly to the official website by typing the URL yourself. If you've already shared credentials, change your passwords immediately and enable two-factor authentication."
        }

        switch riskLevel {
        case .low:
            return "The message appears mostly normal. Stay cautious with any unexpected requests and verify through official channels before taking action."
        case .medium:
            return "Proceed with caution. Do not click links or share personal information. Verify the sender's identity independently. If they claim to be from a company or agency, contact that organization directly."
        case .high:
            return "This message shows multiple warning signs of a scam. Do not respond, click links, or send money. Block the sender and report the message. If you've already engaged, stop all communication."
        case .critical:
            return "This is very likely a scam. Do not respond or send money under any circumstances. Block and report the sender. If you've already sent money or shared personal information, contact your bank immediately and file a report at reportfraud.ftc.gov."
        }
    }
}
