import Foundation

struct ClaudeAPIClient {
    struct APIError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    private let apiURL = URL(string: Constants.anthropicAPIURL)!
    private let model = Constants.defaultModel

    func analyze(text: String, apiKey: String, context: ConversationContext? = nil) async throws -> AnalysisResult {
        var request = URLRequest(url: apiURL, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let systemPrompt = """
        You are a financial scam detection expert. Analyze the provided text (message, email, or conversation) for signs of financial scams, fraud, phishing, and social engineering.

        Respond ONLY with valid JSON matching this exact schema:
        {
          "overallScore": <number 0.0-1.0>,
          "riskLevel": "<low|medium|high|critical>",
          "detectedPatterns": [
            {
              "patternType": "<one of: financialRequest, urgencyPressure, upfrontPayment, unusualPaymentMethod, overpaymentRefund, fakeCryptoInvestment, guaranteedReturns, tradingPlatformScam, pigButcheringFinancial, bankImpersonation, governmentImpersonation, techSupportScam, utilityImpersonation, phishingAttempt, accountVerification, suspiciousLink, credentialHarvesting, fakeJobOffer, workFromHomeScam, reshippingMule, lotteryPrizeScam, inheritanceScam, sweepstakesScam, legalThreat, debtCollectionScam, blackmailExtortion, emotionalManipulation, charityScam, disasterReliefScam, rentalHousingScam, tooGoodToBeTrue, inconsistentDetails, grammarScriptedResponses, aiGeneratedText, packageDeliveryScam>",
              "confidence": <number 0.0-1.0>,
              "evidence": "<exact quote or paraphrase from text>",
              "explanation": "<why this is concerning>"
            }
          ],
          "summary": "<2-3 sentence assessment>",
          "recommendation": "<actionable advice>",
          "conversationStage": "<initial_contact|building_trust|setup|extraction|escalation>",
          "nextMovePrediction": "<what the scammer is likely to do next based on current stage>"
        }

        Score guidelines:
        - 0.0-0.24: Low risk — normal communication
        - 0.25-0.49: Medium risk — some concerning patterns
        - 0.50-0.74: High risk — multiple red flags
        - 0.75-1.0: Critical risk — strong scam indicators

        Be thorough but avoid false positives. Consider that legitimate businesses, banks, and government agencies do contact people — look for the specific tactics that distinguish scams from legitimate communication (urgency, unusual payment methods, threats, requests for personal info via insecure channels, too-good-to-be-true offers).
        """

        var userMessage = "Analyze this text for financial scam indicators:\n\n\(text)"

        if let context = context, context.hasAnyData {
            var contextLines: [String] = ["\n\nAdditional context provided by the user:"]
            if let duration = context.contactDuration {
                contextLines.append("- Contact duration: \(duration.rawValue)")
            }
            if let askedForMoney = context.hasBeenAskedForMoney {
                contextLines.append("- Asked for money: \(askedForMoney ? "Yes" : "No")")
            }
            if let sharedInfo = context.hasSharedPersonalInfo {
                contextLines.append("- Shared personal info (SSN, bank details, etc.): \(sharedInfo ? "Yes" : "No")")
            }
            if let clickedLinks = context.hasClickedLinks {
                contextLines.append("- Clicked links from sender: \(clickedLinks ? "Yes" : "No")")
            }
            if let madePayments = context.hasMadePayments {
                contextLines.append("- Already made payments: \(madePayments ? "Yes" : "No")")
            }
            if let contactedFirst = context.contactedYouFirst {
                contextLines.append("- They contacted the user first (unsolicited): \(contactedFirst ? "Yes" : "No")")
            }
            contextLines.append("\nFactor this context into your risk assessment. If the user has already made payments or shared personal info, emphasize immediate protective actions. Unsolicited contact is a significant red flag for most scam types.")
            userMessage += contextLines.joined(separator: "\n")
        }

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 2048,
            "system": systemPrompt,
            "messages": [
                ["role": "user", "content": userMessage]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError(message: "Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            if httpResponse.statusCode == 401 {
                throw APIError(message: "Invalid API key. Please check your key in Settings.")
            }
            throw APIError(message: "API error (\(httpResponse.statusCode)): \(errorBody)")
        }

        let claudeResponse = try JSONDecoder().decode(ClaudeResponse.self, from: data)
        guard let textContent = claudeResponse.content.first(where: { $0.type == "text" }),
              let responseText = textContent.text else {
            throw APIError(message: "No text content in response")
        }

        let jsonString = extractJSON(from: responseText)
        guard let cleanData = jsonString.data(using: .utf8) else {
            throw APIError(message: "Failed to parse response text")
        }

        do {
            return try JSONDecoder().decode(AnalysisResult.self, from: cleanData)
        } catch {
            throw APIError(message: "Failed to parse analysis result: \(error.localizedDescription)")
        }
    }

    private func extractJSON(from text: String) -> String {
        if let jsonStart = text.range(of: "```json"),
           let jsonEnd = text.range(of: "```", range: jsonStart.upperBound..<text.endIndex) {
            return String(text[jsonStart.upperBound..<jsonEnd.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let jsonStart = text.range(of: "```"),
           let jsonEnd = text.range(of: "```", range: jsonStart.upperBound..<text.endIndex) {
            return String(text[jsonStart.upperBound..<jsonEnd.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let start = text.firstIndex(of: "{"),
           let end = text.lastIndex(of: "}") {
            return String(text[start...end])
        }
        return text
    }
}

// MARK: - Claude API Response Models

private struct ClaudeResponse: Decodable {
    let content: [ContentBlock]

    struct ContentBlock: Decodable {
        let type: String
        let text: String?
    }
}
