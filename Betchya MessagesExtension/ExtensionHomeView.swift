import SwiftUI

struct ExtensionHomeView: View {
    let groupId: String
    let nickname: String
    let userId: String

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Betchya!")
                        .font(.title2.weight(.bold))
                    Spacer()
                    Text(nickname)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Text("Bones markets come next. You’re in.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 6) {
                    labeled("Group", String(groupId.prefix(8)) + "…")
                    labeled("You", String(userId.prefix(8)) + "…")
                }
                .font(.caption.monospaced())
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))

                Spacer(minLength: 0)
            }
            .padding(16)
        }
    }

    private func labeled(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
    }
}

#Preview {
    ExtensionHomeView(
        groupId: "75631DBE-AAAA-BBBB-CCCC-DDDDEEEEFFFF",
        nickname: "aryang",
        userId: "BA78E77D-1111-2222-3333-444455556666"
    )
}
