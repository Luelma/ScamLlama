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
        You are a romance scam detection expert. Analyze the provided conversation text for signs of romance scams.

        Respond ONLY with valid JSON matching this exact schema:
        {
          "overallScore": <number 0.0-1.0>,
          "riskLevel": "<low|medium|high|critical>",
          "detectedPatterns": [
            {
              "patternType": "<one of: loveBombing, urgencyPressure, financialRequest, isolationTactics, inconsistentDetails, refusingVideoCall, militaryDeploymentStory, moveOffPlatform, tooGoodToBeTrue, grammarScriptedResponses, pigButchering, sextortionSetup>",
              "confidence": <number 0.0-1.0>,
              "evidence": "<exact quote or paraphrase from text>",
              "explanation": "<why this is concerning>"
            }
          ],
          "summary": "<2-3 sentence assessment>",
          "recommendation": "<actionable advice>",
          "conversationStage": "<early|building_trust|escalating|requesting>",
          "nextMovePrediction": "<what the scammer is likely to do next based on current stage>"
        }

        Score guidelines:
        - 0.0-0.24: Low risk — normal conversation
        - 0.25-0.49: Medium risk — some concerning patterns
        - 0.50-0.74: High risk — multiple red flags
        - 0.75-1.0: Critical risk — strong scam indicators

        Be thorough but avoid false positives. Consider cultural context.
        """

        var userMessage = "Analyze this conversation for romance scam indicators:\n\n\(text)"

        if let context = context, context.hasAnyData {
            var contextLines: [String] = ["\n\nAdditional context provided by the user:"]
            if let duration = context.talkingDuration {
                contextLines.append("- Talking duration: \(duration.rawValue)")
            }
            if let videoCalled = context.hasVideoCalledPerson {
                contextLines.append("- Video called: \(videoCalled ? "Yes" : "No")")
            }
            if let metInPerson = context.hasMetInPerson {
                contextLines.append("- Met in person: \(metInPerson ? "Yes" : "No")")
            }
            if let askedForMoney = context.hasBeenAskedForMoney {
                contextLines.append("- Asked for money: \(askedForMoney ? "Yes" : "No")")
            }
            if let investments = context.hasDiscussedInvestments {
                contextLines.append("- Discussed investments: \(investments ? "Yes" : "No")")
            }
            contextLines.append("\nFactor this context into your risk assessment. A person who has been talking for months without video calling is a significant red flag. Money requests from someone never met in person should be weighted as critical risk.")
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

        // Parse Claude response
        let claudeResponse = try JSONDecoder().decode(ClaudeResponse.self, from: data)
        guard let textContent = claudeResponse.content.first(where: { $0.type == "text" }),
              let responseText = textContent.text else {
            throw APIError(message: "No text content in response")
        }

        // Try to extract JSON from response (Claude sometimes wraps it in markdown)
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
        // Try to find JSON block in markdown code fences
        if let jsonStart = text.range(of: "```json"),
           let jsonEnd = text.range(of: "```", range: jsonStart.upperBound..<text.endIndex) {
            return String(text[jsonStart.upperBound..<jsonEnd.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let jsonStart = text.range(of: "```"),
           let jsonEnd = text.range(of: "```", range: jsonStart.upperBound..<text.endIndex) {
            return String(text[jsonStart.upperBound..<jsonEnd.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        // If no code fences, try to find JSON object directly
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
