import Foundation

enum TalkingDuration: String, Codable, CaseIterable {
    case lessThanWeek = "< 1 week"
    case oneToFourWeeks = "1-4 weeks"
    case oneToThreeMonths = "1-3 months"
    case threeMonthsPlus = "3+ months"
}

struct ConversationContext: Codable {
    var talkingDuration: TalkingDuration?
    var hasVideoCalledPerson: Bool?
    var hasMetInPerson: Bool?
    var hasBeenAskedForMoney: Bool?
    var hasDiscussedInvestments: Bool?

    var hasAnyData: Bool {
        talkingDuration != nil ||
        hasVideoCalledPerson != nil ||
        hasMetInPerson != nil ||
        hasBeenAskedForMoney != nil ||
        hasDiscussedInvestments != nil
    }
}
