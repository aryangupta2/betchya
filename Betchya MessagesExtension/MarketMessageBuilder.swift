import Foundation
import Messages
import UIKit

enum MarketMessageBuilder {
    static func messageURL(groupId: String, marketId: String) -> URL {
        var components = URLComponents(url: AppConstants.messageURLBase, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "g", value: groupId),
            URLQueryItem(name: "m", value: marketId)
        ]
        return components.url!
    }

    static func parseIDs(from url: URL?) -> (groupId: String, marketId: String)? {
        guard
            let url,
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let items = components.queryItems,
            let groupId = items.first(where: { $0.name == "g" })?.value,
            let marketId = items.first(where: { $0.name == "m" })?.value,
            !groupId.isEmpty,
            !marketId.isEmpty
        else { return nil }
        return (groupId, marketId)
    }

    static func makeMessage(for market: MarketDTO, session: MSSession? = nil) -> MSMessage {
        let message = MSMessage(session: session ?? MSSession())
        message.url = messageURL(groupId: market.groupId, marketId: market.id)

        let layout = MSMessageTemplateLayout()
        layout.caption = market.question
        layout.subcaption = captionOdds(market)
        layout.trailingCaption = "Betchya!"
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        layout.trailingSubcaption = "Closes \(formatter.string(from: market.deadline))"
        message.layout = layout
        message.summaryText = "Betchya: \(market.question)"
        return message
    }

    private static func captionOdds(_ market: MarketDTO) -> String {
        let pot = market.pot
        if pot == 0 {
            return "Yes 0 · No 0 · Pot 0 bones"
        }
        let yesPct = Int((Double(market.yesTotal) / Double(pot) * 100).rounded())
        return "Yes \(yesPct)% · Pot \(pot) bones"
    }
}
