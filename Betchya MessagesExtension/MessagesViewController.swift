import UIKit
import Messages
import SwiftUI

class MessagesViewController: MSMessagesAppViewController {
    private var hostingController: UIHostingController<AnyView>?
    private var lastGroupId: String?

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func willBecomeActive(with conversation: MSConversation) {
        super.willBecomeActive(with: conversation)
        presentRoot(for: conversation, force: true)
    }

    override func didSelect(_ message: MSMessage, conversation: MSConversation) {
        super.didSelect(message, conversation: conversation)
        presentRoot(for: conversation, force: true)
    }

    override func willTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        super.willTransition(to: presentationStyle)
        // Keep current SwiftUI navigation; do not rebuild root on expand/collapse.
    }

    override func didTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        super.didTransition(to: presentationStyle)
    }

    private func presentRoot(for conversation: MSConversation, force: Bool) {
        _ = UserIdentity.currentUserId()
        let groupId = resolveGroupId(in: conversation)
        UserIdentity.setGroupId(groupId)

        if !force, groupId == lastGroupId, hostingController != nil {
            return
        }
        lastGroupId = groupId

        let focusedMarketId = MarketMessageBuilder.parseIDs(from: conversation.selectedMessage?.url)?.marketId

        let root: AnyView
        if let nickname = UserIdentity.nickname(forGroup: groupId) {
            root = AnyView(
                ExtensionHomeView(
                    groupId: groupId,
                    nickname: nickname,
                    userId: UserIdentity.currentUserId(),
                    initialMarketId: focusedMarketId,
                    onRequestExpand: { [weak self] in
                        self?.requestPresentationStyle(.expanded)
                    },
                    onRequestCompact: { [weak self] in
                        self?.requestPresentationStyle(.compact)
                    },
                    onInsertMarket: { [weak self] market in
                        self?.insertMarketBubble(market, in: conversation)
                    }
                )
            )
        } else {
            root = AnyView(
                NicknameGateView(groupId: groupId) { [weak self] _ in
                    guard let self, let conversation = self.activeConversation else { return }
                    self.presentRoot(for: conversation, force: true)
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

    private func insertMarketBubble(_ market: MarketDTO, in conversation: MSConversation) {
        let session = conversation.selectedMessage?.session
        let message = MarketMessageBuilder.makeMessage(for: market, session: session)
        conversation.insert(message) { error in
            if let error {
                print("Betchya insert failed: \(error)")
            }
        }
        // After create, collapse; after bet updates, stay unless already compact.
        if presentationStyle == .expanded {
            requestPresentationStyle(.compact)
        }
        dismiss()
    }

    private func resolveGroupId(in conversation: MSConversation) -> String {
        if let ids = MarketMessageBuilder.parseIDs(from: conversation.selectedMessage?.url) {
            return ids.groupId
        }
        return UserIdentity.ensureGroupId()
    }
}
