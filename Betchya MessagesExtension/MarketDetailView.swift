import SwiftUI

struct MarketDetailView: View {
    let userId: String
    let nickname: String
    let groupId: String
    let marketId: String
    let initialMarket: MarketDTO?
    let onMarketUpdated: (MarketDTO) -> Void

    @State private var market: MarketDTO?
    @State private var side: MarketSide = .yes
    @State private var stakeText = "50"
    @State private var balance: Int?
    @State private var errorText: String?
    @State private var statusText: String?
    @State private var isLoading = false
    @State private var isSubmitting = false

    private var stake: Int { Int(stakeText) ?? 0 }
    private var alreadyBet: Bool { market?.hasBet(from: userId) ?? false }
    private var isResolver: Bool {
        guard let market else { return false }
        return userId == (market.subjectId ?? market.creatorId)
    }

    var body: some View {
        Group {
            if let market {
                form(for: market)
            } else if isLoading {
                ProgressView("Loading market…")
            } else {
                ContentUnavailableView(
                    "Market unavailable",
                    systemImage: "questionmark.circle",
                    description: Text(errorText ?? "Couldn’t load this market.")
                )
            }
        }
        .navigationTitle("Market")
        .navigationBarTitleDisplayMode(.inline)
        .task { await reload() }
    }

    private func form(for market: MarketDTO) -> some View {
        Form {
            Section {
                Text(market.question)
                    .font(.headline)
                Text(oddsLine(market))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Closes \(market.deadline.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Your bones") {
                Text(balance.map(String.init) ?? "—")
                    .font(.title3.monospacedDigit().weight(.semibold))
            }

            if market.status == .open, !isResolver, !alreadyBet {
                Section("Place bet (locked after confirm)") {
                    Picker("Side", selection: $side) {
                        Text("YES").tag(MarketSide.yes)
                        Text("NO").tag(MarketSide.no)
                    }
                    .pickerStyle(.segmented)

                    TextField("Stake", text: $stakeText)
                        .keyboardType(.numberPad)

                    Button {
                        Task { await submit() }
                    } label: {
                        Text(isSubmitting ? "Placing…" : "Confirm bet")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(isSubmitting || stake < 10 || (balance.map { stake > $0 } ?? true))
                }
            } else if isResolver {
                Section {
                    Text("You’re the resolver — you can’t bet on this market.")
                        .foregroundStyle(.secondary)
                }
            } else if alreadyBet {
                Section {
                    Text("Your bet is locked.")
                        .foregroundStyle(.secondary)
                }
            }

            if let statusText {
                Section { Text(statusText).font(.footnote).foregroundStyle(.secondary) }
            }
            if let errorText, self.market != nil {
                Section { Text(errorText).font(.footnote).foregroundStyle(.orange) }
            }
        }
    }

    private func oddsLine(_ market: MarketDTO) -> String {
        let pot = market.pot
        if pot == 0 { return "Yes 0 · No 0 · Pot 0" }
        let yesPct = Int((Double(market.yesTotal) / Double(pot) * 100).rounded())
        return "Yes \(yesPct)% · Pot \(pot) bones"
    }

    private func reload() async {
        if market == nil {
            market = initialMarket
        }
        isLoading = market == nil
        errorText = nil
        defer { isLoading = false }

        do {
            let nick = UserIdentity.nickname(forGroup: groupId) ?? nickname
            try await APIClient.bootstrap(userId: userId)
            try await APIClient.ensureGroup(groupId: groupId, userId: userId, nickname: nick)
            let remote = try await APIClient.getMarket(marketId: marketId, userId: userId)
            market = remote
            let members = try await APIClient.listMembers(groupId: groupId, userId: userId)
            balance = members.first { $0.userId == userId }?.balance
        } catch {
            if market == nil {
                errorText = error.localizedDescription
            }
        }
    }

    private func submit() async {
        errorText = nil
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let updated = try await APIClient.placeBet(
                marketId: marketId,
                userId: userId,
                side: side,
                stake: stake
            )
            market = updated
            statusText = "Bet locked"
            let members = try await APIClient.listMembers(groupId: groupId, userId: userId)
            balance = members.first { $0.userId == userId }?.balance
            onMarketUpdated(updated)
        } catch {
            errorText = error.localizedDescription
        }
    }
}
