import Foundation
import UIKit
import SwiftData
import Observation

@Observable
class ChatAnalysisViewModel {
    enum InputMode: String, CaseIterable {
        case paste = "Paste Text"
        case screenshot = "Screenshot"
    }

    var inputMode: InputMode = .paste
    var inputText: String = ""
    var contactName: String = ""
    var platform: String = ""
    var engine = ScamAnalysisEngine()
    var showingResult = false

    // Situation context fields
    var contextSectionExpanded: Bool = false
    var talkingDuration: TalkingDuration?
    var hasVideoCalledPerson: Bool = false
    var hasMetInPerson: Bool = false
    var hasBeenAskedForMoney: Bool = false
    var hasDiscussedInvestments: Bool = false

    var conversationContext: ConversationContext? {
        // Only return context if user actually opened the context section
        guard contextSectionExpanded else { return nil }
        return ConversationContext(
            talkingDuration: talkingDuration,
            hasVideoCalledPerson: hasVideoCalledPerson,
            hasMetInPerson: hasMetInPerson,
            hasBeenAskedForMoney: hasBeenAskedForMoney,
            hasDiscussedInvestments: hasDiscussedInvestments
        )
    }

    // OCR state
    var selectedImage: UIImage?
    var isExtractingText = false
    var ocrError: String?

    private let ocrService = OCRService()

    static let maxInputLength = 50_000 // ~50KB of text

    var canAnalyze: Bool {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= 20 && trimmed.count <= Self.maxInputLength
    }

    var inputTooLong: Bool {
        inputText.count > Self.maxInputLength
    }

    var isLoading: Bool {
        engine.state == .scanning || engine.state == .analyzing
    }

    var analysisResult: AnalysisResult? {
        if case .complete(let result) = engine.state {
            return result
        }
        return nil
    }

    var errorMessage: String? {
        if case .error(let msg) = engine.state {
            return msg
        }
        return nil
    }

    var analysisSource: AnalysisSource {
        inputMode == .paste ? .paste : .screenshot
    }

    func extractText(from image: UIImage) async {
        selectedImage = image
        isExtractingText = true
        ocrError = nil

        do {
            let text = try await ocrService.recognizeText(from: image)
            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                ocrError = "No text found in the image. Try a clearer screenshot."
            } else {
                inputText = text
            }
        } catch {
            ocrError = error.localizedDescription
        }

        isExtractingText = false
    }

    func analyze() async {
        await engine.analyze(text: inputText, context: conversationContext)
        if analysisResult != nil {
            showingResult = true
        }
    }

    func saveConversation(modelContext: ModelContext) {
        guard let result = analysisResult else { return }
        let conversation = Conversation(
            inputText: inputText,
            source: analysisSource,
            contactName: contactName.isEmpty ? nil : contactName,
            platform: platform.isEmpty ? nil : platform
        )
        conversation.analysisResult = result
        conversation.conversationContext = conversationContext
        modelContext.insert(conversation)
    }

    func reset() {
        inputText = ""
        contactName = ""
        platform = ""
        contextSectionExpanded = false
        talkingDuration = nil
        hasVideoCalledPerson = false
        hasMetInPerson = false
        hasBeenAskedForMoney = false
        hasDiscussedInvestments = false
        selectedImage = nil
        ocrError = nil
        engine.reset()
        showingResult = false
    }
}
