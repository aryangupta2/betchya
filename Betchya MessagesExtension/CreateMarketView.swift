import SwiftUI

struct CreateMarketView: View {
    let groupId: String
    let userId: String
    let nickname: String
    let members: [GroupMemberDTO]
    let onCreated: (MarketDTO) -> Void

    @State private var question = ""
    @State private var deadline = Date().addingTimeInterval(60 * 60 * 24)
    @State private var showAmounts = false
    @State private var subjectId: String?
    @State private var isSubmitting = false
    @State private var errorText: String?

    var body: some View {
        Form {
            Section("Question") {
                TextField("Will … ?", text: $question, axis: .vertical)
                    .lineLimit(3...5)
            }

            Section("Closes") {
                DatePicker(
                    "Bet deadline",
                    selection: $deadline,
                    in: Date()...,
                    displayedComponents: [.date, .hourAndMinute]
                )
            }

            Section("Subject (optional)") {
                Picker("Resolves", selection: $subjectId) {
                    Text("Creator resolves").tag(String?.none)
                    ForEach(members.filter { $0.userId != userId }) { member in
                        Text(member.nickname).tag(Optional(member.userId))
                    }
                }
            }

            Section {
                Toggle("Show amounts", isOn: $showAmounts)
            } footer: {
                Text("Off = sides visible, stakes hidden until resolve.")
            }

            if let errorText {
                Section {
                    Text(errorText)
                        .foregroundStyle(.orange)
                        .font(.footnote)
                }
            }
        }
        .navigationTitle("New market")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Post") { Task { await submit() } }
                    .disabled(question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
            }
        }
    }

    private func submit() async {
        isSubmitting = true
        errorText = nil
        defer { isSubmitting = false }
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try await APIClient.bootstrap(userId: userId)
            try await APIClient.ensureGroup(groupId: groupId, userId: userId, nickname: nickname)
            let market = try await APIClient.createMarket(
                groupId: groupId,
                userId: userId,
                question: trimmed,
                deadline: deadline,
                subjectId: subjectId,
                showAmounts: showAmounts
            )
            onCreated(market)
        } catch {
            errorText = error.localizedDescription
        }
    }
}
