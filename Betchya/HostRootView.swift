import SwiftUI

struct HostRootView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.12, blue: 0.18),
                    Color(red: 0.12, green: 0.22, blue: 0.20)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("Betchya!")
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)

                Text("Friend-group prediction pools in iMessage. Play with bones — never real money.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 28)

                Text("Open Messages → Apps drawer → Betchya!")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(red: 0.55, green: 0.95, blue: 0.75))
                    .padding(.top, 8)
            }
            .padding()
        }
    }
}

#Preview {
    HostRootView()
}
