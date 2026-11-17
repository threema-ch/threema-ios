import CocoaLumberjackSwift
import ThreemaFramework
import ThreemaMacros
import UIKit

final class NewMessageToaster {

    private let previewSetting: InAppPreviewSetting
    private let bannerPresenter: NotificationBannerPresenting
    private let pushSettingManager: any PushSettingManagerProtocol
    private let entityManager: EntityManager
    private let notificationCenter: NotificationCenter

    private var queue: [NSManagedObjectID] = []

    init(
        previewSetting: any InAppPreviewSetting,
        bannerPresenter: any NotificationBannerPresenting,
        pushSettingManager: any PushSettingManagerProtocol,
        entityManager: EntityManager,
        notificationCenter: NotificationCenter
    ) {
        self.previewSetting = previewSetting
        self.bannerPresenter = bannerPresenter
        self.pushSettingManager = pushSettingManager
        self.entityManager = entityManager
        self.notificationCenter = notificationCenter
        registerObservers()
    }

    deinit {
        notificationCenter.removeObserver(self)
    }

    private func registerObservers() {
        notificationCenter.addObserver(
            self,
            selector: #selector(newMessageReceived),
            name: Notification.Name(IncomingMessageManager.inAppNotificationNewMessage),
            object: nil
        )
        notificationCenter.addObserver(
            self,
            selector: #selector(newReactionReceived),
            name: Notification.Name(IncomingMessageManager.inAppNotificationNewReaction),
            object: nil
        )
        notificationCenter.addObserver(
            self,
            selector: #selector(conversationOpened),
            name: Notification.Name(rawValue: kNotificationOpenedConversation),
            object: nil
        )
        notificationCenter.addObserver(
            self,
            selector: #selector(didBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    // MARK: - Notification handlers

    @objc private func newMessageReceived(_ notification: Notification) {
        DDLogVerbose("newMessageReceived: \(notification)")

        guard let messageObjectID = notification.object as? NSManagedObjectID else {
            return
        }
        
        handle(messageObjectID: messageObjectID)
    }

    private func handle(messageObjectID: NSManagedObjectID) {
        guard previewSetting.inAppPreview else {
            return
        }

        guard SharedAppProvider.isAppActive else {
            queue.append(messageObjectID)
            return
        }

        let entityManager = entityManager
        entityManager.perform {
            guard
                let message = entityManager.entityFetcher.existingObject(
                    with: messageObjectID
                ) as? BaseMessageEntity,
                !(message is SystemMessageEntity),
                self.pushSettingManager.canSendPush(for: message)
            else {
                return
            }

            Task { @MainActor in
                // The app can be active while the passcode lock screen is up; don't reveal a preview then.
                guard !SharedAppProvider.isAppLocked else {
                    return
                }

                SharedAppProvider.execute { coordinator in
                    guard coordinator.canDisplayNotificationToast(for: message) else {
                        return
                    }

                    if UIAccessibility.isVoiceOverRunning,
                       let text = self.accessibilityText(for: message) {
                        UIAccessibility.post(notification: .announcement, argument: text)
                        return
                    }

                    guard let tabBarController = SharedAppProvider.tabBarController else {
                        return
                    }

                    self.bannerPresenter.newBanner(on: tabBarController, baseMessage: message)
                }
            }
        }
    }

    @objc private func newReactionReceived(_ notification: Notification) {
        DDLogVerbose("newReactionReceived: \(notification)")

        guard let messageObjectID = notification.object as? NSManagedObjectID,
              let body = notification.userInfo?[IncomingMessageManager.inAppNotificationReactionBodyKey] as? String
        else {
            return
        }

        guard previewSetting.inAppPreview, SharedAppProvider.isAppActive else {
            return
        }

        let entityManager = entityManager
        entityManager.perform {
            guard let message = entityManager.entityFetcher.existingObject(
                with: messageObjectID
            ) as? BaseMessageEntity else {
                return
            }

            // A private chat only tells that a reaction came in, never who reacted or to what
            let accessibilityText = message.conversation.conversationCategory == .private
                ? #localize("private_reaction_label")
                : "\(message.conversation.displayName): \(body)"

            Task { @MainActor in
                // The app can be active while the passcode lock screen is up; don't reveal a preview then.
                guard !SharedAppProvider.isAppLocked else {
                    return
                }

                SharedAppProvider.execute { coordinator in
                    guard coordinator.canDisplayNotificationToast(for: message) else {
                        return
                    }

                    if UIAccessibility.isVoiceOverRunning {
                        UIAccessibility.post(notification: .announcement, argument: accessibilityText)
                        return
                    }

                    guard let tabBarController = SharedAppProvider.tabBarController else {
                        return
                    }

                    self.bannerPresenter.newReactionBanner(
                        on: tabBarController,
                        reactedMessage: message,
                        body: body
                    )
                }
            }
        }
    }

    @objc private func conversationOpened(_ notification: Notification) {
        guard let identifier = notification.object as? String else {
            return
        }

        Task { @MainActor in
            self.bannerPresenter.dismissAllNotifications(for: identifier)
        }
    }

    @objc private func didBecomeActive(_ notification: Notification) {
        guard SharedAppProvider.isAppActive else {
            return
        }

        let drained = queue
        queue.removeAll()
        for objectID in drained {
            handle(messageObjectID: objectID)
        }
    }

    // MARK: - Accessibility

    private func accessibilityText(for message: BaseMessageEntity) -> String? {
        guard let previewableMessage = message as? PreviewableMessage else {
            return nil
        }
        var text = #localize("new_message_accessibility")

        let entityManager = entityManager
        let from: String? = entityManager.performAndWait {
            guard let conversation = entityManager.entityFetcher.conversationEntity(
                with: previewableMessage.conversation.objectID
            ) else {
                return nil
            }

            if conversation.isGroup {
                return String.localizedStringWithFormat(
                    #localize("new_message_accessibility_group"),
                    conversation.displayName,
                    message.accessibilityMessageSender ?? #localize("unknown")
                )
            }
            else {
                return "\(#localize("from")) \(conversation.displayName). "
            }
        }

        if let from {
            text += from
        }

        text += previewableMessage.previewText
        return text
    }
}
