//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2022 Threema GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License, version 3,
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import CocoaLumberjackSwift
import Contacts
import ContactsUI
import Foundation

/// Managing the linking between a Threema contact and a system contact (`CNContact`)
///
/// This class has four main functionalities. All of them handle also access rights to system contacts.
/// 1. Observe linked contact changes
/// 2. Manage linked contact. Choose a new one when none is linked or change it if there is an existing link. (`linkContact(in:of:)`)
/// 3. Get display text for the button managing the linking. (`linkedContactTitle` & `linkedContactDescription`)
/// 4. Open the edit screen. The system contact edit screen when a linked contact exists, the provided screen otherwise.
///     (`editContact(in:provider:)`)
class LinkedContactManger: NSObject {
    
    // MARK: - Private properties
    
    private let contact: Contact
    private var cnContactIDObserver: NSKeyValueObservation?
    
    private lazy var cnContactStore = CNContactStore()
    private lazy var contactStore = ContactStore.shared()
    
    /// Is the contact linked to any `CNContact`?
    private var contactIsLinked: Bool {
        contact.cnContactID != nil
    }
    
    /// Current linked `CNContact`
    private lazy var cnContact = currentCNContact() {
        didSet {
            linkedContactDidChange()
        }
    }
    
    private var observers = [UUID: (LinkedContactManger) -> Void]()

    /// Keep track of the view controller we presented on if we need custom dismissal
    private var lastViewControllerPresentedOn: UIViewController?
    
    private let openSettingsClosure: (UIAlertAction) -> Void = { _ in
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        
        UIApplication.shared.open(settingsURL)
    }
    
    // MARK: - Lifecycle
    
    init(for contact: Contact) {
        self.contact = contact
        
        super.init()
        
        configureObservers()
    }
    
    deinit {
        DDLogDebug("\(#function)")
    }
    
    // MARK: - Configure
    
    private func configureObservers() {
        // Subscribe to changed to `CNContacts`
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(contactStoreDidChange),
            name: .CNContactStoreDidChange,
            object: nil
        )
        
        // Get a notification when the linking of this contact changes
        cnContactIDObserver = contact.observe(\.cnContactID) { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.updateCNContact()
            }
        }
    }
    
    // MARK: - Update
    
    private func updateCNContact() {
        cnContact = currentCNContact()
    }
    
    // MARK: - Notification
    
    // Notifications ensure that we always have the most recent `CNContact`
    @objc private func contactStoreDidChange() {
        updateCNContact()
    }
    
    // MARK: - Helper
    
    private func currentCNContact() -> CNContact? {
        // Only fetch contact if we have access to them
        guard CNContactStore.authorizationStatus(for: .contacts) == .authorized else {
            return nil
        }
        
        guard let linkedID = contact.cnContactID else {
            return nil
        }
        
        // This could be written in one line with `try?`, but we would be unable to log errors.
        
        do {
            let foundContact = try cnContactStore.unifiedContact(
                withIdentifier: linkedID,
                keysToFetch: Constants.cnContactKeys
            )
            
            return foundContact
        }
        catch {
            DDLogNotice("Unable to get CNContact from CNContactStore: \(error.localizedDescription)")
        }
        
        return nil
    }
}

// MARK: - Observe

// Light weight observable implementation using closures
//
// Register a closure to observe changes. The closure is only retained as long as the return token
// is retained or `cancel()` on the token is called.
//
// Based on:
// - https://www.swiftbysundell.com/articles/observers-in-swift-part-2/#the-best-of-both-worlds
// - https://www.swiftbysundell.com/articles/published-properties-in-swift/#just-a-backport-away

extension LinkedContactManger {
    
    /// Token handed out when registering an observing closure
    class ObservationToken {
        private var closure: (() -> Void)?
        
        init(closure: @escaping () -> Void) {
            self.closure = closure
        }
        
        deinit {
            cancel()
        }
        
        /// Remove registered closure. (Automatically called when token is deallocated.)
        func cancel() {
            closure?()
            closure = nil
        }
    }
    
    /// Register closure for observation
    ///
    /// The closure is removed if `cancel()` is called on the token or when the token is deallocated.
    ///
    /// - Parameters:
    ///     - closure: Closure to be called on `LinkedContactManger` changes and during registration
    ///     - callOnCreation: Should the closure be called when the observer is created?
    /// - Returns: Token to invalidate registration (either by calling `cancel()` or deallocating the token)
    func observe(
        with closure: @escaping (LinkedContactManger) -> Void,
        callOnCreation: Bool = true
    ) -> ObservationToken {
        if callOnCreation {
            closure(self)
        }
        
        let uuid = UUID()
        observers[uuid] = closure
        
        return ObservationToken { [weak self] in
            self?.observers.removeValue(forKey: uuid)
        }
    }
    
    /// Call when observers should be informed about changes invoked by this class
    private func linkedContactDidChange() {
        for closure in observers.values {
            closure(self)
        }
    }
}

// MARK: - Shared

private extension LinkedContactManger {
    private func requestAccess(authorized: @escaping () -> Void, denied: (() -> Void)? = nil) {
        cnContactStore.requestAccess(for: .contacts) { granted, error in
            if granted {
                DispatchQueue.main.async {
                    self.updateCNContact()
                    authorized()
                }
            }
            else {
                DispatchQueue.main.async {
                    self.linkedContactDidChange()
                    denied?()
                }
            }
            
            if let error = error {
                DDLogError("Error asking for CNContacts access: \(error.localizedDescription)")
            }
        }
    }
}

private extension CNContactViewController {
    // Some custom settings are needed to make `CNContactViewController` appear as expected.
    func applyWorkarounds() {
        // Enforce appearance to match app tint color
        view.tintColor = Colors.primary
        
        // Because `CNContactViewController` comes with a custom "header view" that runs behind
        // the navigation bar we hide the navigation bar.
        let transparentAppearance = UINavigationBarAppearance()
        transparentAppearance.configureWithTransparentBackground()
        navigationItem.standardAppearance = transparentAppearance
    }
}

// MARK: - Link contact

// This is the implemented flow for managing contact linking:
//
//                                         ┌───────────────────┐
//                                         │ Current contacts  │
//               ┌─────not determined──────┤   access status   ├───────┐
//               ▼                         └─┬───┬─────────┬───┘       │
//   ┌───────────────────────┐               │   │         │       restricted
//   │  Ask for permission   │               │   │         │           │        ┌───────────────────────┐
//   └───────────┬───────────┘               │   │         │           └───────▶│ Has a linked contact? │
//               │                   authorized  │         │                    └──┬─────────────────┬──┘
//               │                    │          │         │                       │No              Yes
//              granted               │          │         └─denied──┐             ▼                 ▼
//                    │               │   future unknown             │      *─────────────┐ *────────────────────┐
//                    │               │       states                 │      │ Inform that │ │ Inform that access │
//                    ▼               ▼          │                   │      │  access is  │ │   is restricted    │
//             ┌─────────────────────────────┐   │                   │      │ restricted  │ │  and allow unlink  │
//             │    Has a linked contact?    │◀──┘                   │      └─────────────┘ └────────────────────┘
//             └──────┬─────────────────────┬┘                       │
//                ┌Yes┘                     │                        ▼
//                ▼                         No           ┌───────────────────────┐
//     ┌─────────────────────┐              │            │ Has a linked contact? │
//     │ Can find CNContact? │              │            └───┬───────────────┬───┘
//     └───────┬───────────┬─┘              │                │No            Yes
//             │           │No              │                ▼               ▼
//             │           ▼                │        *──────────────┐*──────────────────┐
//            Yes    *───────────────────┐  │        │Ask for access││Ask for access in │
//             │     │1. Unlink contact  │  └─┐      │ in Settings  ││     Settings     │
//             │     │2. Link new contact│    │      └──────────────┘│ and allow unlink │
//             │     └──────────┬────────┘    │                      └──────────────────┘
//             ▼                │             │
//   *───────────────────┐      │             │
//   │1. Unlink contact  │      │             │
//   │2. Link new contact│─────Link new       │
//   │3. Show contact    │     contact        │
//   └───────────────────┘           │        │
//                                   │        │
//                                   ▼        ▼
//                               *────────────────┐
//                               │                │
//                               │  Show contact  │
//                               │     picker     │
//                               │                │
//                               └────────────────┘
//
//    * = Alert or sheet

extension LinkedContactManger {
    
    /// Manage linking of contact to a `CNContact`
    ///
    /// Complete flow to link new `CNContact` or  manage existing linking. This includes asking for permission if there's no access
    /// to contacts.
    ///
    /// (See implementation for flow documentation.)
    ///
    /// - Parameter view: Origin view of action (used as anchor point for popups)
    /// - Parameter viewController: View Controller to present sheets and alerts on
    func linkContact(in view: UIView, of viewController: UIViewController) {
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .notDetermined:
            accessNotDetermined(in: view, of: viewController)
        case .authorized:
            accessAuthorized(in: view, of: viewController)
        case .denied:
            accessDenied(in: viewController)
        case .restricted:
            accessRestricted(in: viewController)
        @unknown default:
            // New unknown state. Let's try if we can use it like `.authorized`...
            accessAuthorized(in: view, of: viewController)
        }
    }
    
    private func accessNotDetermined(in view: UIView, of viewController: UIViewController) {
        requestAccess {
            self.accessAuthorized(in: view, of: viewController)
        }
    }
    
    private func accessAuthorized(in view: UIView, of viewController: UIViewController) {
        if contactIsLinked {
            showLinkedContactActions(in: view, of: viewController)
        }
        else {
            presentCNContactPicker(with: viewController)
        }
    }
    
    private func accessDenied(in viewController: UIViewController) {

        let localizedOpenSettingsTitle = BundleUtil.localizedString(forKey: "go_to_settings")
        
        if contactIsLinked {
            let localizedAlertTitle = BundleUtil.localizedString(forKey: "no_linked_contact_access_title")
            let localizedAlertMessage = BundleUtil.localizedString(forKey: "no_linked_contact_access_message")
                        
            let localizedUnlinkTitle = BundleUtil.localizedString(forKey: "unlink_contact")
            let unlinkAction = UIAlertAction(title: localizedUnlinkTitle, style: .destructive) { _ in
                ContactStore.shared().unlink(self.contact)
            }
            
            let openSettingsAction = UIAlertAction(
                title: localizedOpenSettingsTitle,
                style: .default,
                handler: openSettingsClosure
            )
    
            UIAlertTemplate.showAlert(
                owner: viewController,
                title: localizedAlertTitle,
                message: localizedAlertMessage,
                action1: unlinkAction,
                action2: openSettingsAction
            )
        }
        else {
            let localizedAlertTitle = BundleUtil.localizedString(forKey: "no_contacts_access_title")
            let localizedAlertMessage = BundleUtil.localizedString(forKey: "no_contacts_access_message")
            
            UIAlertTemplate.showAlert(
                owner: viewController,
                title: localizedAlertTitle,
                message: localizedAlertMessage,
                titleOk: localizedOpenSettingsTitle,
                actionOk: openSettingsClosure
            )
        }
    }
    
    private func accessRestricted(in viewController: UIViewController) {
        if contactIsLinked {
            let localizedAlertTile = BundleUtil.localizedString(forKey: "restricted_contacts_access_title")
            let localizedAlertMessage = String.localizedStringWithFormat(
                BundleUtil.localizedString(forKey: "restricted_linked_contact_access_message"),
                ThreemaApp.currentName
            )
            let localizedUnlinkTitle = BundleUtil.localizedString(forKey: "unlink_contact")
            
            UIAlertTemplate.showDestructiveAlert(
                owner: viewController,
                title: localizedAlertTile,
                message: localizedAlertMessage,
                titleDestructive: localizedUnlinkTitle,
                actionDestructive: { _ in
                    ContactStore.shared().unlink(self.contact)
                }
            )
        }
        else {
            let localizedAlertTile = BundleUtil.localizedString(forKey: "restricted_contacts_access_title")
            let localizedAlertMessage = BundleUtil.localizedString(forKey: "restricted_contacts_access_message")
            
            UIAlertTemplate.showAlert(
                owner: viewController,
                title: localizedAlertTile,
                message: localizedAlertMessage
            )
        }
    }
    
    private func showLinkedContactActions(in view: UIView, of viewController: UIViewController) {
        
        var actions = [UIAlertAction]()
        
        let localizedUnlinkTitle = BundleUtil.localizedString(forKey: "unlink_contact")
        let unlinkAction = UIAlertAction(title: localizedUnlinkTitle, style: .destructive) { _ in
            ContactStore.shared().unlink(self.contact)
        }
        actions.append(unlinkAction)
        
        let localizedLinkNewTitle = BundleUtil.localizedString(forKey: "link_new_contact")
        let linkNewAction = UIAlertAction(title: localizedLinkNewTitle, style: .default) { _ in
            self.presentCNContactPicker(with: viewController)
        }
        actions.append(linkNewAction)
        
        // Only show "Show Contact" action if we found the contact
        if cnContact != nil {
            let localizedShowContactTitle = BundleUtil.localizedString(forKey: "show_linked_contact")
            let showContactAction = UIAlertAction(title: localizedShowContactTitle, style: .default) { _ in
                self.presentCurrentCNContact(with: viewController)
            }
            actions.append(showContactAction)
        }
        
        UIAlertTemplate.showSheet(owner: viewController, popOverSource: view, actions: actions)
    }
    
    private func presentCNContactPicker(with viewController: UIViewController) {
        let picker = CNContactPickerViewController()
        picker.delegate = self
        picker.modalPresentationStyle = .formSheet
        picker.view.tintColor = Colors.primary // Ensure everything gets the correct tint color
        
        viewController.present(picker, animated: true)
    }
    
    private func presentCurrentCNContact(with viewController: UIViewController) {
        guard let cnContact = cnContact else {
            DDLogError("CNContact not found")
            return
        }
        
        let contactViewController = CNContactViewController(for: cnContact)
        contactViewController.applyWorkarounds()

        // This is only for checking the details of the linked contact
        contactViewController.allowsEditing = false
        
        // `CNContactViewController` only adds an "Edit" button if editing is enabled, thus we
        // add a custom "Done" button to dismiss the view. To keep track of the view controller
        // we need to dismiss it on we store the view controller in a property.
        let doneButton = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(dismissPresentedViewController)
        )
        contactViewController.navigationItem.rightBarButtonItem = doneButton
        lastViewControllerPresentedOn = viewController
        
        // The app crashes if we present `CNContactViewController` and don't show it on the current
        // navigation controller. Thus we create a custom navigation controller.
        let customNavigationController = ThemedNavigationController(rootViewController: contactViewController)
        customNavigationController.modalPresentationStyle = .formSheet
        
        viewController.present(customNavigationController, animated: true)
    }
    
    /// Custom dismissal of last presented view controller on `lastViewControllerPresentedOn`
    @objc private func dismissPresentedViewController() {
        guard let lastVC = lastViewControllerPresentedOn else {
            return
        }
        
        lastVC.dismiss(animated: true)
        
        // Prevent double dismissal
        lastViewControllerPresentedOn = nil
    }
}

// MARK: - LinkedContactManger + CNContactPickerDelegate

extension LinkedContactManger: CNContactPickerDelegate {
    
    // No need to dismiss the picker in our code (also when canceled). This is done automatically by the system.
    
    func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
        ContactStore.shared().link(self.contact, toCnContactID: contact.identifier)
    }
}

// MARK: - Link contact text

// How the output is determined:
//
//                                           ┌──────────────────────┐
//                                           │ Has linked contact?  │
//                                           └───┬──────────────┬───┘
//                                              Yes             │
//                                               ▼              └────No─────┐
//                                ┌───────────────────┐                     │
//                                │  Contact access?  │                     │
//                                └───┬───────────┬───┘                     ▼
//                     ┌─────Yes──────┘           │                ┌── ─── ─── ─── ─┐
//                     ▼                          │                  Link Contact   │
//          ┌─────────────────────┐               └───No───┐       │
//          │ Can find CNContact? │                        │       └─ ─── ─── ─── ──┘
//          └────┬───────────┬────┘                        │
//              Yes          │No                           ▼
//               ▼           ▼                       ┌──────────┐
//   ┌── ─── ─── ─── ─┐ ┌── ─── ─── ─── ─┐           │ Why not? │
//     Linked Contact │   Linked Contact │           └─┬──────┬─┘
//   │ <Name>           │ (unknown)           denied / not   restricted
//   └─ ─── ─── ─── ──┘ └─ ─── ─── ─── ──┘     determined           │
//                                               ▼                  ▼
//                                      ┌── ─── ─── ─── ─┐ ┌── ─── ─── ─── ─┐
//                                        Linked Contact │   Linked Contact │
//                                      │ (no access)      │ (restricted)
//                                      └─ ─── ─── ─── ──┘ └─ ─── ─── ─── ──┘

extension LinkedContactManger {
    
    /// Title for linkend contact presentation in UI
    var linkedContactTitle: String {
        if contactIsLinked {
            return BundleUtil.localizedString(forKey: "linked_contact")
        }
        
        return BundleUtil.localizedString(forKey: "link_contact")
    }
    
    /// Description for linked contact presentation in UI
    ///
    /// If `nil` just show `linkedContactTitle`.
    var linkedContactDescription: String? {
        guard contactIsLinked else {
            return nil
        }
        
        let authorizationStatus = CNContactStore.authorizationStatus(for: .contacts)
        guard authorizationStatus == .authorized else {
            if authorizationStatus == .denied || authorizationStatus == .notDetermined {
                return BundleUtil.localizedString(forKey: "[no access]")
            }
            else if authorizationStatus == .restricted {
                return BundleUtil.localizedString(forKey: "[restricted]")
            }
            
            assertionFailure("unknown contact access status")
            return "[unknown status]" // This should never be reached
        }
        
        guard let contactDescription = contactDescription else {
            return BundleUtil.localizedString(forKey: "[not found]")
        }
        
        return contactDescription
    }
    
    private var contactDescription: String? {
        guard let cnContact = cnContact else {
            return nil
        }
        
        // Return one of these names. Use the first where some data is available.
        // (This is based on how these contacts are shown in Contacts.app.)
        // 1. Full name
        // 2. First email address
        // 3. First phone number
        // 4. Nothing
        
        var name: String?
        
        if let fullName = CNContactFormatter.string(from: cnContact, style: .fullName), !fullName.isEmpty {
            name = fullName
        }
        else if let firstEmail = cnContact.emailAddresses.first?.value {
            name = firstEmail as String
        }
        else if let firstPhone = cnContact.phoneNumbers.first?.value {
            name = firstPhone.stringValue
        }
        
        return name
    }
}

// MARK: - Edit contact

// The implemented flow for edit contact:
//
//                              ┌─────────────────────────────┐
//                              │    Has a linked contact?    │─────No──────────────┐
//                              └────────┬────────────────────┘                     │
//                                      Yes                                         │
//                                       ▼                                          │
//                     ┌──────────────────────────────────┐                         │
//              ┌──────│  Current contacts access status  │                         │
//              │      └─────────┬───────────────┬────┬───┘                         │
//        authorized /     not determined        │    └──restricted──┐              │
//       future unknown          │               │                   ▼              │
//              │                ▼               │      *─────────────────────────┐ │
//              │     ┌─────────────────────┐    │      │ Unlink and edit contact │ │
//              │     │ Ask for permission  │    │      └────────────┬────────────┘ │
//              │     └───┬──────────┬──────┘    │                   │              │
//              │         │          │         denied                │              │
//              │    granted         │           │                   │              │
//              │      │             │           │                   │              │
//              ▼      ▼          denied         │                   │              │
//   ┌─────────────────────┐         │           │                   └─────────┐    │
//   │ Can find CNContact? │         │           │                             │    │
//   └────┬───────────┬────┘         ▼           ▼                             │    │
//        │           │         *──────────────────────┐                       │    │
//        │           │         │1. Change in Settings │                       │    │
//        │           │         │2. Unlink and edit    │─────────┐             │    │
//       Yes          │No       └──────────────────────┘         │             ▼    ▼
//        │           │                                          │         *────────────────┐
//        │           │        *─────────────────────────┐       │         │                │
//        │           └───────▶│ Unlink and edit contact │───────┴────────▶│ Show our edit  │
//        ▼                    └─────────────────────────┘                 │ contact screen │
//   *──────────────────┐                                                  │                │
//   │                  │                                                  └────────────────┘
//   │ Show system edit │
//   │  contact screen  │
//   │                  │
//   └──────────────────┘
//
//    * = Alert or screen

extension LinkedContactManger {
    
    /// Allow lazy loading of app edit contact screen
    /// - Parameter contact: Contact to edit
    /// - Returns: Edit screen ready to be presented modally
    typealias EditContactViewControllerProvider = (_ contact: Contact) -> UIViewController
    
    /// Edit contact managed by this contact
    ///
    /// Complete flow to edit a contact. For accessible linked contacts the system contact edit sheet is shown. If not accessible an
    /// alert is presented depending on the access settings. If no contact is linked the provided edit screen is presented.
    ///
    /// - Parameters:
    ///   - viewController: View Controller to present screens and alerts on
    ///   - provider: Lazy provider of app contact edit screen
    func editContact(in viewController: UIViewController, provider: @escaping EditContactViewControllerProvider) {
        if contactIsLinked {
            editLinkedContact(in: viewController, provider: provider)
        }
        else {
            presentProvidedEditContactViewController(in: viewController, provider: provider)
        }
    }
    
    private func editLinkedContact(
        in viewController: UIViewController,
        provider: @escaping EditContactViewControllerProvider
    ) {
        // Check for current access status
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .notDetermined:
            editAccessNotDetermined(in: viewController, provider: provider)
        case .authorized:
            editAccessAuthorized(in: viewController, provider: provider)
        case .denied:
            editAccessDenied(in: viewController, provider: provider)
        case .restricted:
            editAccessRestricted(in: viewController, provider: provider)
        @unknown default:
            // New unknown state. Let's try if we can use it like `.authorized`...
            editAccessAuthorized(in: viewController, provider: provider)
        }
    }
    
    private func editAccessNotDetermined(
        in viewController: UIViewController,
        provider: @escaping EditContactViewControllerProvider
    ) {
        requestAccess(
            authorized: {
                self.editAccessAuthorized(in: viewController, provider: provider)
            }, denied: {
                self.editAccessDenied(in: viewController, provider: provider)
            }
        )
    }
    
    private func editAccessAuthorized(
        in viewController: UIViewController,
        provider: @escaping EditContactViewControllerProvider
    ) {
        // Can we find the contact?
        guard cnContact != nil else {
            // If not show error and option to unlink
            let localizedNotFoundTitle = BundleUtil.localizedString(forKey: "linked_contact_not_found_title")
            let localizedNotFoundMessage = BundleUtil.localizedString(forKey: "linked_contact_not_found_message")
            
            showUnlinkAndEditActionSheet(
                title: localizedNotFoundTitle,
                message: localizedNotFoundMessage,
                in: viewController,
                provider: provider
            )
            
            return
        }
        
        presentEditCNContact(with: viewController)
    }
    
    private func editAccessDenied(
        in viewController: UIViewController,
        provider: @escaping EditContactViewControllerProvider
    ) {
        let localizedDeniedTitle = BundleUtil.localizedString(forKey: "no_linked_contact_access_title")
        let localizedDeniedMessage = BundleUtil.localizedString(forKey: "no_linked_contact_access_edit_message")
        
        let localizedUnlinkAndEditActionTitle = BundleUtil.localizedString(forKey: "unlink_and_edit_contact")
        let unlinkAndEditAction = UIAlertAction(
            title: localizedUnlinkAndEditActionTitle,
            style: .destructive,
            handler: unlinkAndEditClosure(in: viewController, provider: provider)
        )
        
        let localizedOpenSettingsTitle = BundleUtil.localizedString(forKey: "go_to_settings")
        let openSettingsAction = UIAlertAction(
            title: localizedOpenSettingsTitle,
            style: .default,
            handler: openSettingsClosure
        )

        UIAlertTemplate.showAlert(
            owner: viewController,
            title: localizedDeniedTitle,
            message: localizedDeniedMessage,
            action1: unlinkAndEditAction,
            action2: openSettingsAction
        )
    }
    
    private func editAccessRestricted(
        in viewController: UIViewController,
        provider: @escaping EditContactViewControllerProvider
    ) {
        
        let localizedRestrictedTitle = BundleUtil.localizedString(forKey: "restricted_contacts_access_title")
        let localizedRestrictedMessage = String.localizedStringWithFormat(
            BundleUtil.localizedString(forKey: "restricted_linked_contact_access_edit_message"),
            ThreemaApp.currentName
        )
        
        showUnlinkAndEditActionSheet(
            title: localizedRestrictedTitle,
            message: localizedRestrictedMessage,
            in: viewController,
            provider: provider
        )
    }
    
    private func showUnlinkAndEditActionSheet(
        title: String,
        message: String,
        in viewController: UIViewController,
        provider: @escaping EditContactViewControllerProvider
    ) {
        let localizedUnlinkAndEditActionTitle = BundleUtil.localizedString(forKey: "unlink_and_edit_contact")
        let unlinkAndEditAction = unlinkAndEditClosure(in: viewController, provider: provider)
        
        UIAlertTemplate.showDestructiveAlert(
            owner: viewController,
            title: title,
            message: message,
            titleDestructive: localizedUnlinkAndEditActionTitle,
            actionDestructive: unlinkAndEditAction
        )
    }
    
    private func unlinkAndEditClosure(
        in viewController: UIViewController,
        provider: @escaping EditContactViewControllerProvider
    ) -> (UIAlertAction) -> Void {
        { _ in
            ContactStore.shared().unlink(self.contact)
            self.presentProvidedEditContactViewController(in: viewController, provider: provider)
        }
    }

    private func presentEditCNContact(with viewController: UIViewController) {
        guard let cnContact = cnContact else {
            DDLogError("CNContact not found")
            return
        }
        
        // Workaround to directly open in edit mode
        let contactViewController = CNContactViewController(forNewContact: cnContact)
        contactViewController.applyWorkarounds()
        
        // Hide "New Contact" title as this is not correct ;)
        contactViewController.title = nil
        
        // Needed to dismiss modal view controller when finished editing
        contactViewController.delegate = self

        let customNavigationController = ThemedNavigationController(rootViewController: contactViewController)
        customNavigationController.modalPresentationStyle = .formSheet
        
        viewController.present(customNavigationController, animated: true)
    }
    
    private func presentProvidedEditContactViewController(
        in viewController: UIViewController,
        provider: EditContactViewControllerProvider
    ) {
        let editContactViewController = provider(contact)
        editContactViewController.modalPresentationStyle = .formSheet
        
        viewController.present(editContactViewController, animated: true)
    }
}

// MARK: - LinkedContactManger + CNContactViewControllerDelegate

extension LinkedContactManger: CNContactViewControllerDelegate {
    func contactViewController(_ viewController: CNContactViewController, didCompleteWith contact: CNContact?) {
        // Hide view controller when editing of CNContact is completed ("Done" or "Cancel")
        viewController.dismiss(animated: true)
        // We need force relink the contact in order to import the changes from the address book again
        if let contact = contact {
            ContactStore().link(self.contact, toCnContactID: contact.identifier)
        }
    }
}
