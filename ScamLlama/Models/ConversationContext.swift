import Foundation

enum ContactDuration: String, Codable, CaseIterable {
    case lessThanWeek = "< 1 week"
    case oneToFourWeeks = "1-4 weeks"
    case oneToThreeMonths = "1-3 months"
    case threeMonthsPlus = "3+ months"
}

struct ConversationContext: Codable {
    var contactDuration: ContactDuration?
    var hasBeenAskedForMoney: Bool?
    var hasSharedPersonalInfo: Bool?
    var hasClickedLinks: Bool?
    var hasMadePayments: Bool?
    var contactedYouFirst: Bool?

    var hasAnyData: Bool {
        contactDuration != nil ||
        hasBeenAskedForMoney != nil ||
        hasSharedPersonalInfo != nil ||
        hasClickedLinks != nil ||
        hasMadePayments != nil ||
        contactedYouFirst != nil
    }
}
