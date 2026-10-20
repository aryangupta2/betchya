import SwiftUI

private enum ExtensionRoute: Hashable {
    case createMarket
}

struct ExtensionHomeView: View {
    let groupId: String
    let nickname: String
    let userId: String
    let onRequestExpand: () -> Void
    let onRequestCompact: () -> Void
    let onInsertMarket: (MarketDTO) -> Void

    @State private var markets: [MarketDTO] = []
    @State private var members: [GroupMemberDTO] = []
    @State private var path = NavigationPath()
    @State private var statusText: String?
    @State private var isLoading = false

    var body: some View {
        NavigationStack(path: $path) {
            homeContent
                .navigationDestination(for: ExtensionRoute.self) { route in
                    switch route {
                    case .createMarket:
                        CreateMarketView(
                            groupId: groupId,
                            userId: userId,
                            members: members,
                            onCreated: { market, usedDraft in
                                LocalMarketStore.upsert(market)
                                markets = LocalMarketStore.load(groupId: groupId)
                                    .filter { $0.status == .open }
                                statusText = usedDraft ? "Saved locally (API offline)" : "Posted to chat"
                                path = NavigationPath()
                                onInsertMarket(market)
                            }
                        )
                    }
                }
        }
        .onChange(of: path.count) { oldCount, newCount in
            // Swipe/back from create → collapse Messages extension again.
            if oldCount > 0, newCount == 0 {
                onRequestCompact()
            }
        }
        .task { await refresh() }
    }

    private var homeContent: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Betchya!")
                        .font(.title2.weight(.bold))
                    Spacer()
                    Text(nickname)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
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
                        VStack(alignment: .leading, spacing: 4) {
                            Text(market.question)
                                .font(.subheadline.weight(.semibold))
                            Text("Pot \(market.pot) · Yes \(market.yesTotal) / No \(market.noTotal)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
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

    private func refresh() async {
        isLoading = true
        defer { isLoading = false }

        // Always show locally cached markets immediately (covers offline drafts).
        markets = LocalMarketStore.load(groupId: groupId).filter { $0.status == .open }

        do {
            try await APIClient.bootstrap(userId: userId)
            try await APIClient.ensureGroup(groupId: groupId, userId: userId, nickname: nickname)
            async let remoteMarkets = APIClient.listMarkets(groupId: groupId, userId: userId)
            async let people = APIClient.listMembers(groupId: groupId, userId: userId)
            let fetched = try await remoteMarkets
            members = try await people

            // Prefer server list; keep any local-only drafts not yet on the API.
            let remoteIds = Set(fetched.map(\.id))
            let localOnly = LocalMarketStore.load(groupId: groupId).filter { !remoteIds.contains($0.id) }
            let merged = (fetched + localOnly).filter { $0.status == .open }
            markets = merged
            LocalMarketStore.save(merged, groupId: groupId)
            statusText = localOnly.isEmpty ? nil : "Showing server + \(localOnly.count) local draft(s)"
        } catch {
            statusText = "Offline — showing \(markets.count) local market(s)"
            members = []
        }
    }
}
