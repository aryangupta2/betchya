import SwiftUI

struct NicknameGateView: View {
    let groupId: String
    let onSaved: (String) -> Void

    @State private var nickname = ""
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Text("Betchya!")
                    .font(.title.weight(.bold))

                Text("Pick your nickname for this chat.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                TextField("Nickname", text: $nickname)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .padding(12)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                    .focused($focused)

                Button {
                    let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    UserIdentity.setNickname(trimmed, forGroup: groupId)
                    onSaved(trimmed)
                } label: {
                    Text("Continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .disabled(nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(20)
        }
        .onAppear { focused = true }
    }
}

#Preview {
    NicknameGateView(groupId: "preview-group") { _ in }
}
