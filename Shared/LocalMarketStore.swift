import Foundation

enum LocalMarketStore {
    private static let keyPrefix = "betchya.localMarkets."

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: AppConstants.appGroupID) ?? .standard
    }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            let withFraction = ISO8601DateFormatter()
            withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = withFraction.date(from: value) { return date }
            let plain = ISO8601DateFormatter()
            plain.formatOptions = [.withInternetDateTime]
            if let date = plain.date(from: value) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Bad date \(value)")
        }
        return d
    }()

    static func load(groupId: String) -> [MarketDTO] {
        guard let data = defaults.data(forKey: keyPrefix + groupId) else { return [] }
        return (try? decoder.decode([MarketDTO].self, from: data)) ?? []
    }

    static func save(_ markets: [MarketDTO], groupId: String) {
        guard let data = try? encoder.encode(markets) else { return }
        defaults.set(data, forKey: keyPrefix + groupId)
    }

    static func upsert(_ market: MarketDTO) {
        var markets = load(groupId: market.groupId)
        if let index = markets.firstIndex(where: { $0.id == market.id }) {
            markets[index] = market
        } else {
            markets.insert(market, at: 0)
        }
        save(markets, groupId: market.groupId)
    }
}
