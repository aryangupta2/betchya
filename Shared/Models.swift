import Foundation

enum MarketSide: String, Codable, CaseIterable, Identifiable {
    case yes, no
    var id: String { rawValue }
    var title: String { rawValue.uppercased() }
}

enum MarketStatus: String, Codable {
    case open, locked, resolved, refunded
}

struct MarketDTO: Codable, Identifiable, Hashable {
    let id: String
    let groupId: String
    let question: String
    let deadline: Date
    let creatorId: String
    let subjectId: String?
    let showAmounts: Bool
    let status: MarketStatus
    let outcome: MarketSide?
    let yesTotal: Int
    let noTotal: Int
    let pot: Int
}

struct GroupMemberDTO: Codable, Identifiable, Hashable {
    var id: String { userId }
    let userId: String
    let nickname: String
    let balance: Int
    let lifetimeProfit: Int
}

struct MarketsResponse: Codable {
    let markets: [MarketDTO]
}

struct MembersResponse: Codable {
    let members: [GroupMemberDTO]
}
