import Foundation
import SwiftData

@Model
class Conversation {
    var id: UUID = UUID()
    var contactName: String?
    var platform: String?
    var inputText: String = ""
    var source: AnalysisSource = AnalysisSource.paste
    var createdAt: Date = Date()
    var analysisResultData: Data?

    var analysisResult: AnalysisResult? {
        get {
            guard let data = analysisResultData else { return nil }
            return try? JSONDecoder().decode(AnalysisResult.self, from: data)
        }
        set {
            analysisResultData = try? JSONEncoder().encode(newValue)
        }
    }

    init(inputText: String, source: AnalysisSource, contactName: String? = nil, platform: String? = nil) {
        self.id = UUID()
        self.inputText = inputText
        self.source = source
        self.contactName = contactName
        self.platform = platform
        self.createdAt = Date()
    }
}
