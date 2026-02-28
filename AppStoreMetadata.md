# Love Llama - App Store Submission Metadata

## App Name
Love Llama

## Subtitle (30 chars max)
Romance Scam Detection AI

## Category
Primary: Utilities
Secondary: Lifestyle

## Age Rating
Recommended: 12+ (Infrequent/Mild Mature/Suggestive Themes)

## Price
Free

---

## App Store Description (4000 chars max)

Don't let love make you blind.

Love Llama is your personal AI-powered romance scam detector. Whether you're chatting on dating apps, social media, or messaging platforms, Love Llama helps you spot the red flags before your heart — and wallet — get scammed.

ANALYZE CONVERSATIONS
Paste suspicious messages or scan screenshots, and Love Llama's AI engine instantly detects manipulation tactics like love bombing, urgency pressure, financial requests, isolation tactics, and more. Get a clear risk score with detailed explanations of every red flag found.

VERIFY PROFILE PHOTOS
Wonder if that profile pic is a real person or an AI-generated catfish? Upload any photo and Love Llama runs dual analysis — on-device AI detection plus Reality Defender's deepfake technology — and shows both results side by side. No API key required for photo checks.

SPOT RED FLAGS WITH THE CHECKLIST
Not sure if something feels off? Walk through our interactive red flag checklist covering financial, emotional, communication, and identity warning signs. Get an instant risk assessment based on your selections.

FEATURES AT A GLANCE
- AI-powered chat analysis with 300+ scam pattern detections
- Built-in AI photo verification — no API key needed
- Interactive red flag checklist with weighted scoring
- Local pattern scanning works without internet
- Analysis history to track and review past checks
- All data encrypted and stored locally on your device
- No tracking, no ads, no data sharing

POWERED BY ADVANCED AI
Love Llama combines on-device pattern matching (300+ romance scam indicators) with optional cloud AI analysis via Anthropic's Claude for deeper insights. Photo verification includes built-in Reality Defender deepfake detection — no setup required. Chat analysis uses your own Anthropic API key, stored securely in the iOS Keychain.

YOUR PRIVACY MATTERS
- All data stored locally with iOS encryption
- API keys secured in the iOS Keychain
- No analytics or tracking of any kind
- Delete all your data anytime from Settings
- Full transparency about what data goes where

Romance scams cost victims billions of dollars every year. Love Llama puts AI in your corner so you can date with confidence.

---

## Keywords (100 chars max, comma-separated)
romance,scam,detector,dating,safety,catfish,AI,fraud,love,protect,verify,photo,fake,red flags,check

## Promotional Text (170 chars max, can be updated without new build)
Protect yourself from romance scams with AI-powered chat analysis, fake photo detection, and an interactive red flag checklist. Date smarter.

## Support URL
https://YOUR-GITHUB-USERNAME.github.io/lovellama-privacy/support.html

## Privacy Policy URL
https://YOUR-GITHUB-USERNAME.github.io/lovellama-privacy/

## Copyright
2026 Love Llama

---

## What's New in This Version

**v1.5.1**
Improved chat analysis — Love Llama now detects suspicious emoji-only and emoji-heavy short messages, a common "shotgun" tactic where scammers send flirty emojis to random numbers hoping someone engages. Previously these slipped through as safe — now flagged as low risk with a clear explanation.

**v1.5**
Photo verification just got a major upgrade. Every user now gets dual analysis — on-device AI detection plus Reality Defender's deepfake technology — with results shown side by side. No API key needed for photo checks anymore. You can still add your own Reality Defender key in Settings to use your own credits.

**v1.4**
New situation context questionnaire in chat analysis — answer quick questions about your interactions (how long you've been talking, video call history, money requests) to boost detection accuracy. Results now include a Situation Assessment card highlighting key risk factors and a "What a Scammer Would Do Next" prediction based on the detected conversation stage.

**v1.3**
Further improved photo verification accuracy — removed metadata-based detection that caused false positives on photos shared via social media and messaging apps. Detection now relies entirely on visual analysis of image content.

**v1.2**
Improved photo verification accuracy — reduced false positives in AI image detection. Rebalanced detection thresholds and scoring to require stronger evidence before labeling a photo as AI-generated.

**v1.0**
Love Llama 1.0 — your AI-powered romance scam detector is here! Analyze chats, verify photos, and spot red flags to stay safe while dating.

---

## App Review Notes (for Apple reviewers)

This app uses API keys to access third-party AI services:

1. **Anthropic API Key** (for chat analysis): Users provide their own key from console.anthropic.com. Without a key, the app still performs local pattern scanning with 300+ romance scam indicators.

2. **Reality Defender** (for photo verification): A built-in API key provides deepfake detection for all users automatically. Users may optionally add their own key in Settings to use their own credits instead.

The red flag checklist feature works entirely offline without any API key.

Demo flow for testing:
1. Open app → Accept data consent
2. Go to "Analyze Chat" tab → Paste sample text → See local scan results
3. Go to "Red Flags" tab → Check items → See risk assessment
4. Go to Settings → See privacy policy, delete data option

---

## App Store Submission Checklist

- [x] App icon (1024x1024) in Assets.xcassets
- [x] NSPhotoLibraryUsageDescription set
- [x] PrivacyInfo.xcprivacy privacy manifest
- [x] Data consent modal on first launch
- [x] In-app privacy policy
- [x] Delete All Data feature in Settings
- [x] Contact/Support link in Settings
- [x] No hardcoded API keys or secrets
- [x] NSFileProtectionComplete entitlement
- [x] Request timeouts on all API calls
- [x] Input size limits
- [x] App Store screenshots (5 screens, captured)
- [x] Privacy policy HTML page (ready to host)
- [x] Support page HTML (ready to host)
- [x] Release build verified
- [x] URL scheme for deep linking (lovellama://)
- [ ] Host privacy policy (GitHub Pages — see instructions below)
- [ ] Apple Developer account ($99/year)
- [ ] App Store Connect setup
- [ ] Set signing team in Xcode
- [ ] Archive & upload via Xcode Organizer

---

## How to Host the Privacy Policy (GitHub Pages — Free)

1. Create a new GitHub repo called `lovellama-privacy`
2. Copy the `privacy-policy/` folder contents into the repo root
3. Go to repo Settings → Pages → Source: "Deploy from a branch" → Branch: main
4. Your URLs will be:
   - Privacy: `https://YOUR-USERNAME.github.io/lovellama-privacy/`
   - Support: `https://YOUR-USERNAME.github.io/lovellama-privacy/support.html`
5. Update the URLs in App Store Connect and in the in-app privacy policy

---

## How to Archive & Submit

1. Open `LoveLlama.xcodeproj` in Xcode
2. Select your Apple Developer signing team:
   - Project → Signing & Capabilities → Team → Select your team
3. Select "Any iOS Device (arm64)" as the build destination (not a simulator)
4. Product → Archive
5. When the archive completes, the Organizer window opens
6. Click "Distribute App" → "App Store Connect" → "Upload"
7. Follow the prompts to upload the build
8. Go to App Store Connect (appstoreconnect.apple.com):
   - Create a new app with bundle ID: `com.lovellama.app`
   - Fill in all metadata from this file
   - Upload the 5 screenshots from `AppStoreScreenshots/`
   - Set age rating: 12+
   - Add privacy policy and support URLs
   - Paste the App Review Notes above
   - Submit for review!

---

## Files Ready for Submission

```
LoveLlama/
├── AppStoreScreenshots/
│   ├── 01_Dashboard.png
│   ├── 02_AnalyzeChat.png
│   ├── 03_PhotoVerification.png
│   ├── 04_Checklist.png
│   └── 05_Settings.png
├── privacy-policy/
│   ├── index.html          (privacy policy page)
│   └── support.html        (support/FAQ page)
├── LoveLlama.xcodeproj/
└── LoveLlama/              (source code)
```
