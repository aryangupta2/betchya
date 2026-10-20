import SwiftUI

private enum ExtensionRoute: Hashable {
    case createMarket
    case market(String)
}

struct ExtensionHomeView: View {
    let groupId: String
    let nickname: String
    let userId: String
    let initialMarketId: String?
    let onRequestExpand: () -> Void
    let onRequestCompact: () -> Void
    let onInsertMarket: (MarketDTO) -> Void

    @State private var markets: [MarketDTO] = []
    @State private var members: [GroupMemberDTO] = []
    @State private var balance: Int?
    @State private var path = NavigationPath()
    @State private var statusText: String?
    @State private var isLoading = false
    @State private var didOpenInitialMarket = false

    var body: some View {
        NavigationStack(path: $path) {
            homeContent
                .navigationDestination(for: ExtensionRoute.self) { route in
                    switch route {
                    case .createMarket:
                        CreateMarketView(
                            groupId: groupId,
                            userId: userId,
                            nickname: nickname,
                            members: members,
                            onCreated: { market in
                                upsert(market)
                                statusText = "Posted to chat"
                                path = NavigationPath()
                                onInsertMarket(market)
                            }
                        )
                    case .market(let marketId):
                        MarketDetailView(
                            userId: userId,
                            nickname: nickname,
                            groupId: groupId,
                            marketId: marketId,
                            initialMarket: markets.first { $0.id == marketId },
                            onMarketUpdated: { updated in
                                upsert(updated)
                                onInsertMarket(updated)
                            }
                        )
                    }
                }
        }
        .onChange(of: path.count) { oldCount, newCount in
            if oldCount > 0, newCount == 0 {
                onRequestCompact()
            }
        }
        .task {
            await refresh()
            openInitialMarketIfNeeded()
        }
    }

    private var homeContent: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Betchya!")
                        .font(.title2.weight(.bold))
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(nickname)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(balance.map { "\($0) bones" } ?? "— bones")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }

                Button {
                    onRequestExpand()
                    path.append(ExtensionRoute.createMarket)
                } label: {
                    Text("New market")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)

                if let statusText {
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text("Open")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                if isLoading && markets.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else if openMarkets.isEmpty {
                    Text("No open markets yet. Create one and it’ll drop into the chat.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    List(openMarkets) { market in
                        Button {
                            onRequestExpand()
                            path.append(ExtensionRoute.market(market.id))
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(market.question)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text("Pot \(market.pot) · Yes \(market.yesTotal) / No \(market.noTotal)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .listStyle(.plain)
                }

                Spacer(minLength: 0)
            }
            .padding(16)
        }
    }

    private var openMarkets: [MarketDTO] {
        markets.filter { $0.status == .open }
    }

    private func upsert(_ market: MarketDTO) {
        if let idx = markets.firstIndex(where: { $0.id == market.id }) {
            markets[idx] = market
        } else {
            markets.insert(market, at: 0)
        }
        markets = markets.filter { $0.status == .open }
    }

    private func openInitialMarketIfNeeded() {
        guard !didOpenInitialMarket, let initialMarketId else { return }
        didOpenInitialMarket = true
        onRequestExpand()
        path.append(ExtensionRoute.market(initialMarketId))
    }

    private func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await APIClient.bootstrap(userId: userId)
            try await APIClient.ensureGroup(groupId: groupId, userId: userId, nickname: nickname)
            async let remoteMarkets = APIClient.listMarkets(groupId: groupId, userId: userId)
            async let people = APIClient.listMembers(groupId: groupId, userId: userId)
            markets = try await remoteMarkets.filter { $0.status == .open }
            members = try await people
            balance = members.first { $0.userId == userId }?.balance
            statusText = nil
        } catch {
            markets = []
            members = []
            balance = nil
            statusText = error.localizedDescription
        }
    }
}
