# LoveLlama — Architecture Document

**Version**: 1.7.0  
**Platform**: iOS / iPadOS (SwiftUI)  
**Bundle ID**: `com.lovellama.app`  
**Minimum Target**: iOS 15+

---

## 1. Overview

LoveLlama is a romance scam detection app that uses a layered analysis approach — combining offline pattern scanning, on-device image forensics, and optional cloud-based AI services. The app is designed privacy-first: all core features work offline, and cloud APIs are only invoked with explicit user consent.

### Core Capabilities

| Feature | Local | Cloud |
|---------|-------|-------|
| Chat Analysis | 300+ regex patterns, 17 scam categories | Claude API (conversation analysis) |
| Photo Verification | 9 forensic image checks | Reality Defender + Scam.ai (parallel) |
| Video Detection | — | Reality Defender + Scam.ai (parallel) |
| Audio Detection | — | Reality Defender |
| Red Flag Checklist | 80+ weighted items, combo scoring | — |
| History | SwiftData persistence | — |

---

## 2. Project Structure

```
LoveLlama/
├── App/
│   ├── LoveLlamaApp.swift          # Entry point, SwiftData init, consent & force update
│   └── ContentView.swift            # 6-tab TabView, deep linking (lovellama://)
├── Models/
│   ├── Enums.swift                  # RiskLevel, ScamPatternType, AnalysisSource, MediaType
│   ├── Conversation.swift           # @Model — chat analysis history
│   ├── AnalysisResult.swift         # Codable — score, patterns, recommendation
│   ├── ConversationContext.swift     # Codable — talking duration, met in person, etc.
│   ├── PhotoCheck.swift             # @Model — image/video/audio analysis history
│   ├── ChecklistSession.swift       # @Model — checklist assessment history
│   └── ChecklistItem.swift          # Codable — loaded from ChecklistData.json
├── Services/
│   ├── ClaudeAPIClient.swift        # Anthropic Claude API integration
│   ├── RealityDefenderClient.swift  # Reality Defender deepfake detection
│   ├── ScamAIClient.swift           # Scam.ai AI image/video detection
│   ├── LocalPatternScanner.swift    # Regex-based scam pattern detection (offline)
│   ├── LocalImageAnalyzer.swift     # On-device forensic image analysis (offline)
│   ├── AIImageDetector.swift        # Photo analysis orchestrator (local + cloud)
│   ├── MediaDetector.swift          # Video/audio analysis orchestrator
│   ├── ScamAnalysisEngine.swift     # Chat analysis state machine
│   ├── ChecklistScorer.swift        # Weighted risk scoring
│   ├── APIKeyManager.swift          # Keychain storage for Claude API key
│   ├── EmbeddedKeyProvider.swift    # XOR-obfuscated embedded API keys
│   ├── ConsentManager.swift         # User consent tracking (UserDefaults)
│   ├── ForceUpdateChecker.swift     # Remote version check via GitHub Gist
│   └── OCRService.swift             # Vision framework text recognition
├── ViewModels/
│   ├── ChatAnalysisViewModel.swift
│   ├── PhotoVerificationViewModel.swift
│   ├── MediaVerificationViewModel.swift
│   ├── ChecklistViewModel.swift
│   └── SettingsViewModel.swift
├── Views/
│   ├── Dashboard/                   # Home overview
│   ├── ChatAnalysis/                # Text input, OCR, results
│   ├── PhotoVerification/           # Photo/video/audio UI, recorders, results
│   ├── Checklist/                   # Interactive checklist, results
│   ├── History/                     # Past analyses list & detail
│   ├── Settings/                    # API keys, consent, privacy policy
│   └── Components/                  # RiskGaugeView, PatternCardView, etc.
├── Utilities/
│   ├── Constants.swift              # API URLs, Keychain keys, model name
│   └── Extensions.swift             # Color, Date, Double helpers
└── Resources/
    ├── ChecklistData.json           # 80+ checklist items
    └── Assets.xcassets
```

---

## 3. Architecture Pattern — MVVM + Service Layer

```
┌─────────────────────────────────────────────────┐
│                     Views                        │
│  (SwiftUI — observe ViewModels via @Observable)  │
└────────────────────┬────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────┐
│                  ViewModels                      │
│  (@Observable — compose Services, manage state)  │
└────────────────────┬────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────┐
│                   Services                       │
│  ┌──────────────┐  ┌──────────────────────────┐ │
│  │ Orchestrators│  │ API Clients              │ │
│  │ (Engines)    │──│ Claude, RD, Scam.ai      │ │
│  └──────┬───────┘  └──────────────────────────┘ │
│         │          ┌──────────────────────────┐ │
│         │          │ Local Analyzers           │ │
│         └──────────│ PatternScanner, ImageAnalyzer│
│                    └──────────────────────────┘ │
│                    ┌──────────────────────────┐ │
│                    │ Managers                  │ │
│                    │ APIKey, Consent, Embedded │ │
│                    └──────────────────────────┘ │
└─────────────────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────┐
│                   Models                         │
│  SwiftData (@Model) + Codable structs            │
└─────────────────────────────────────────────────┘
```

**Key patterns:**

- **State Machines**: `ScamAnalysisEngine`, `AIImageDetector`, and `MediaDetector` use enum-based state (`.idle` → `.scanning` → `.analyzing` → `.complete` / `.error`) to drive UI reactivity.
- **Actor Isolation**: `APIKeyManager` and `RDKeyManager` are Swift actors for thread-safe Keychain access.
- **Composition**: ViewModels compose engine/detector objects; engines compose local analyzers + cloud clients.

---

## 4. Data Models

### SwiftData Entities (Persisted)

| Entity | Purpose | Key Fields |
|--------|---------|------------|
| `Conversation` | Chat analysis history | `contactName`, `platform`, `inputText`, `source`, `analysisResultData` (JSON), `contextData` (JSON) |
| `PhotoCheck` | Media analysis history | `imageData`, `detectionStatus`, `aiScore`, `mediaType`, `mediaDuration`, `isLocalOnly` |
| `ChecklistSession` | Checklist history | `contactName`, `checkedItemIDs`, `riskScore`, `riskLevel` |

### Value Types (In-Memory)

| Type | Purpose |
|------|---------|
| `AnalysisResult` | Score (0–1), risk level, detected patterns, summary, recommendation |
| `DetectedPattern` | Pattern type, confidence, evidence, explanation |
| `ConversationContext` | Duration, video calls, met in person, money requests, investments |
| `ChecklistItem` | Title, description, weight, category (loaded from JSON) |

### Enums

| Enum | Values |
|------|--------|
| `RiskLevel` | `.low`, `.medium`, `.high`, `.critical` — each with color, label, icon |
| `ScamPatternType` | 17 variants — love bombing, financial request, pig butchering, sextortion, etc. |
| `AnalysisSource` | `.paste`, `.screenshot` |
| `MediaType` | `.photo`, `.video`, `.audio` — each with `maxFileSize` |

---

## 5. Service Layer

### 5.1 Chat Analysis Pipeline

```
User Input (text or screenshot OCR)
    │
    ▼
ScamAnalysisEngine                      State Machine
    │
    ├─► LocalPatternScanner             Always runs (offline)
    │   ├─ 17 pattern categories        300+ compiled NSRegularExpressions
    │   ├─ Weighted scoring             Critical=5.0, High=3.5–4.0, Medium=2.5–3.0, Low=1.5–2.0
    │   ├─ Stage detection              early → building_trust → escalating → requesting
    │   └─ Returns LocalScanResult      flaggedPatterns, weightedScore, riskLevel
    │
    ├─► ConsentManager check            hasConsentedChatAPI?
    │
    └─► ClaudeAPIClient                 Only if consent + API key
        ├─ Model: claude-sonnet-4
        ├─ System prompt: scam expert
        ├─ Includes context (duration, video calls, money, investments)
        └─ Returns AnalysisResult       Enhanced AI-powered analysis
    │
    ▼
Conversation saved to SwiftData
```

### 5.2 Photo Analysis Pipeline

```
Selected Photo (UIImage)
    │
    ▼
AIImageDetector                         State Machine
    │
    ├─► LocalImageAnalyzer              Always runs (offline, 9 concurrent checks)
    │   ├─ Face symmetry                VNDetectFaceLandmarksRequest (weight 1.5)
    │   ├─ Background consistency       Sharp vs blurry region detection (weight 1.0)
    │   ├─ Color distribution           Histogram analysis (weight 1.0)
    │   ├─ Texture uniformity           Over-smoothing detection (weight 1.2)
    │   ├─ Sharpness patterns           Uniform focus detection (weight 0.8)
    │   ├─ Error Level Analysis         Compression artifact detection (weight 2.0)
    │   ├─ Noise consistency            Sensor noise mismatch (weight 1.5)
    │   ├─ Edge artifacts               Compositing detection (weight 1.8)
    │   └─ Lighting consistency         Light direction analysis (weight 1.3)
    │
    ├─► ConsentManager check            hasConsentedPhotoAPI?
    │
    └─► Parallel cloud analysis         Only if consent + keys available
        ├─ RealityDefenderClient        3-step: presign → S3 upload → poll results
        └─ ScamAIClient                 Multipart POST, instant response
    │
    ▼
PhotoCheck saved to SwiftData
Triple-result UI (Local + RD + Scam.ai)
```

**Risk thresholds (local):** low < 0.25, medium 0.25–0.50, high 0.50–0.75, critical ≥ 0.75  
**Label mapping:** Only "critical" → FAKE; "high" → SUSPICIOUS; others → AUTHENTIC

### 5.3 Video / Audio Analysis Pipeline

```
Selected Video or Audio file
    │
    ▼
MediaDetector                           State Machine
    │
    ├─► File validation                 Video ≤ 250MB, Audio ≤ 20MB
    │
    └─► Parallel cloud analysis
        ├─ RealityDefenderClient        Upload to S3, poll (video: 40× / audio: 30×)
        └─ ScamAIClient (video only)    Multipart POST to /video/detection
    │
    ▼
PhotoCheck saved to SwiftData (mediaType = .video/.audio)
```

### 5.4 Checklist Scoring

```
User checks items (80+ items, 4 categories)
    │
    ▼
ChecklistScorer.calculateScore()
    ├─ Base score:     sum(checked weights) / 15.0 ceiling
    ├─ Critical floor: single item ≥5.0 → min 0.45; ≥4.0 → min 0.30; ≥3.0 → min 0.20
    ├─ Count bonus:    +0.04 per checked item
    ├─ Category spread: +0.05 per additional category
    ├─ Combo bonus:    +0.15 if financial + (emotional or communication)
    └─ Risk mapping:   0–0.15 low, 0.15–0.40 medium, 0.40–0.65 high, ≥0.65 critical
    │
    ▼
ChecklistSession saved to SwiftData
```

---

## 6. External Integrations

### Anthropic Claude API
| | |
|---|---|
| **Endpoint** | `https://api.anthropic.com/v1/messages` |
| **Model** | `claude-sonnet-4-20250514` |
| **Auth** | `x-api-key` header (user-provided, Keychain-stored) |
| **Use** | Enhanced conversation scam analysis |

### Reality Defender API
| | |
|---|---|
| **Base URL** | `https://api.prd.realitydefender.xyz/api` |
| **Auth** | `X-API-KEY` header (user-provided or embedded) |
| **Flow** | `POST /files/aws-presigned` → `PUT` S3 → `GET /media/users/{requestId}` (poll) |
| **Media** | Photos (JPEG), Videos (MP4/MOV), Audio (MP3/WAV/M4A/OGG/FLAC) |
| **Polling** | 3s intervals — Photos: 20× (60s), Videos: 40× (120s), Audio: 30× (90s) |
| **Statuses** | AUTHENTIC, FAKE, SUSPICIOUS, NOT_APPLICABLE, UNABLE_TO_EVALUATE |

### Scam.ai API
| | |
|---|---|
| **Image Endpoint** | `POST https://api.scam.ai/api/defence/ai-image-detection/detect-file` |
| **Video Endpoint** | `POST https://api.scam.ai/api/defence/video/detection` |
| **Auth** | `x-api-key` header (embedded only) |
| **Format** | Multipart form-data |
| **Response** | `likely_ai_generated` (bool) + `confidence_score` (0–1) |

### Force Update Check
| | |
|---|---|
| **Source** | GitHub Gist (`dc598476815a301faeccde950194ece9`) |
| **Trigger** | App launch |
| **Action** | Full-screen blocker → App Store redirect if outdated |
| **Failure** | Silent (no block if offline) |

---

## 7. Security & Key Management

### API Key Storage

| Key | Storage | Access |
|-----|---------|--------|
| Claude API | Keychain (`com.lovellama.anthropic-api-key`) | User-provided (BYOK) |
| Reality Defender | Keychain (`com.lovellama.realitydefender-api-key`) OR embedded | User-provided or XOR-obfuscated fallback |
| Scam.ai | Embedded only | XOR-obfuscated in `EmbeddedKeyProvider` |

- All Keychain items use `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` (no iCloud sync)
- `APIKeyManager` and `RDKeyManager` are Swift actors (thread-safe)
- `EmbeddedKeyProvider` XOR-decodes keys at runtime to avoid plaintext in binary
- Settings UI shows masked keys (`sk-ant-...••••`) — full key revealed only on explicit tap

### Consent Model

| Consent | Scope | Storage |
|---------|-------|---------|
| General | First-launch agreement | UserDefaults (`hasAcceptedDataConsent`) |
| Chat API | Send conversation text to Claude | UserDefaults (`hasConsentedChatAPI`) |
| Photo API | Upload media to RD / Scam.ai | UserDefaults (`hasConsentedPhotoAPI`) |

Cloud APIs are **never called without explicit consent**. Users can revoke consent and delete all local data from Settings.

---

## 8. Data Persistence

| Layer | Technology | Contents |
|-------|------------|----------|
| **SwiftData** | SQLite (via SwiftData framework) | Conversations, PhotoChecks, ChecklistSessions |
| **Keychain** | Security framework | API keys (device-only, encrypted) |
| **UserDefaults** | Standard defaults | Consent flags, consent dates |
| **Bundle** | Read-only resource | `ChecklistData.json` (80+ items) |

SwiftData is initialized in `LoveLlamaApp.swift` with a model container for all three entities. Views access it via `@Environment(\.modelContext)`.

---

## 9. Navigation & Deep Linking

**Tab Structure** (ContentView.swift):

| Tab | Index | View | Purpose |
|-----|-------|------|---------|
| Home | 0 | `DashboardView` | Overview, quick stats |
| Analyze | 1 | `ChatAnalysisView` | Conversation analysis |
| Media | 2 | `MediaVerificationView` | Photo/video/audio |
| Checklist | 3 | `ChecklistView` | Red flag checklist |
| History | 4 | `HistoryListView` | Past analyses |
| Settings | 5 | `SettingsView` | Keys, consent, privacy |

**URL Scheme**: `lovellama://` with host-based routing to specific tabs.

---

## 10. Concurrency Model

| Pattern | Where Used |
|---------|------------|
| `async/await` | All network calls, image analysis, OCR |
| `Task { }` groups | Parallel cloud API calls (RD + Scam.ai) |
| `Actor` | `APIKeyManager`, `RDKeyManager` (thread-safe Keychain) |
| `@Observable` | All ViewModels, `ConsentManager`, engines/detectors |
| Pre-compiled regex | `LocalPatternScanner` compiles 300+ patterns at init |
| Image downscaling | `LocalImageAnalyzer` resizes to 1024px max before processing |

---

## 11. Technology Stack

| Category | Technology |
|----------|------------|
| Language | Swift 5.9+ |
| UI | SwiftUI |
| Persistence | SwiftData |
| Image Analysis | Vision (face landmarks), CoreImage, CoreGraphics |
| Text Recognition | Vision (`VNRecognizeTextRequest`) |
| Media Capture | AVFoundation (video/audio recording) |
| Security | Security framework (Keychain) |
| Networking | URLSession (async) |
| Serialization | Codable (JSON) |

**No third-party dependencies** — the app uses only Apple frameworks.

---

## 12. Codebase Metrics

| Metric | Value |
|--------|-------|
| Total Swift lines | ~8,200 |
| Services | ~3,300 lines (40%) |
| Views | ~3,000 lines (37%) |
| ViewModels | ~620 lines (8%) |
| Models | ~300 lines (4%) |
| Scam pattern categories | 17 |
| Regex patterns | 300+ |
| Forensic image checks | 9 |
| Checklist items | 80+ across 4 categories |
| Max text input | 50,000 characters |
| Max photo size | 20 MB |
| Max video size | 250 MB |
| Max audio size | 20 MB |
