import UIKit
import Messages
import SwiftUI

class MessagesViewController: MSMessagesAppViewController {
    private var hostingController: UIHostingController<AnyView>?

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func willBecomeActive(with conversation: MSConversation) {
        super.willBecomeActive(with: conversation)
        presentRoot(for: conversation)
    }

    override func didTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        super.didTransition(to: presentationStyle)
        if let conversation = activeConversation {
            presentRoot(for: conversation)
        }
    }

    private func presentRoot(for conversation: MSConversation) {
        _ = UserIdentity.currentUserId()
        let groupId = resolveGroupId(in: conversation)
        UserIdentity.setGroupId(groupId)

        let root: AnyView
        if let nickname = UserIdentity.nickname(forGroup: groupId) {
            root = AnyView(
                ExtensionHomeView(
                    groupId: groupId,
                    nickname: nickname,
                    userId: UserIdentity.currentUserId()
                )
            )
        } else {
            root = AnyView(
                NicknameGateView(groupId: groupId) { [weak self] _ in
                    guard let self, let conversation = self.activeConversation else { return }
                    self.presentRoot(for: conversation)
                }
            )
        }

        if let hostingController {
            hostingController.rootView = root
        } else {
            let host = UIHostingController(rootView: root)
            addChild(host)
            host.view.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(host.view)
            NSLayoutConstraint.activate([
                host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                host.view.topAnchor.constraint(equalTo: view.topAnchor),
                host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
            host.didMove(toParent: self)
            hostingController = host
        }
    }

    /// Prefer group id embedded in a selected Betchya message URL; otherwise local ensured id.
    private func resolveGroupId(in conversation: MSConversation) -> String {
        if let url = conversation.selectedMessage?.url,
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let group = components.queryItems?.first(where: { $0.name == "g" })?.value,
           !group.isEmpty {
            return group
        }
        return UserIdentity.ensureGroupId()
    }
}
