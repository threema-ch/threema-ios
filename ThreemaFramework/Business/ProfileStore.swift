//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2023 Threema GmbH
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
import Foundation
import PromiseKit
import ThreemaProtocols

@objc public class ProfileStore: NSObject {

    public struct Profile {
        public var nickname: String?
        public var profileImage: Data?
        public var sendProfilePicture: SendProfilePicture
        public var profilePictureContactList: [String]
        public var mobilePhoneNo: String?
        public var isLinkMobileNoPending: Bool
        public var email: String?
        public var isLinkEmailPending: Bool
    }
    
    private let serverConnector: ServerConnectorProtocol
    private let myIdentityStore: MyIdentityStoreProtocol
    private let contactStore: ContactStoreProtocol
    private let userSettings: UserSettingsProtocol
    private let taskManager: TaskManagerProtocol?
    
    init(
        serverConnector: ServerConnectorProtocol,
        myIdentityStore: MyIdentityStoreProtocol,
        contactStore: ContactStoreProtocol,
        userSettings: UserSettingsProtocol,
        taskManager: TaskManagerProtocol?
    ) {
        self.serverConnector = serverConnector
        self.myIdentityStore = myIdentityStore
        self.contactStore = contactStore
        self.userSettings = userSettings
        self.taskManager = taskManager
    }
    
    @objc override public convenience init() {
        self.init(
            serverConnector: ServerConnector.shared(),
            myIdentityStore: MyIdentityStore.shared(),
            contactStore: ContactStore.shared(),
            userSettings: UserSettings.shared(),
            taskManager: TaskManager()
        )
    }
    
    public func profile() -> Profile {
        let profileImage: Data? = myIdentityStore.profilePicture?["ProfilePicture"] as? Data
        
        return Profile(
            nickname: myIdentityStore.pushFromName,
            profileImage: profileImage,
            sendProfilePicture: userSettings.sendProfilePicture,
            profilePictureContactList: userSettings.profilePictureContactList as? [String] ?? [String](),
            mobilePhoneNo: myIdentityStore.linkedMobileNo,
            isLinkMobileNoPending: myIdentityStore.linkMobileNoPending,
            email: myIdentityStore.linkedEmail,
            isLinkEmailPending: myIdentityStore.linkEmailPending
        )
    }

    /// Sync changes of user profile and save if multi device activated otherwise just save
    /// - Parameter profile: User profile data
    public func syncAndSave(_ profile: Profile) -> Promise<Void> {
        Promise { seal in
            if userSettings.enableMultiDevice,
               let taskManager {
                var syncUserProfile = Sync_UserProfile()

                if myIdentityStore.profilePicture?["ProfilePicture"] as? Data != profile.profileImage {
                    if profile.profileImage != nil {
                        syncUserProfile.profilePicture.updated = Common_Image()
                    }
                    else {
                        syncUserProfile.profilePicture.removed = Common_Unit()
                    }
                }

                let actualProfilePictureContactList = userSettings.profilePictureContactList as? [String] ?? [String]()

                if userSettings.sendProfilePicture != profile.sendProfilePicture
                    || actualProfilePictureContactList != profile.profilePictureContactList {
                    syncUserProfile.profilePictureShareWith.policy = profilePictureShareWithPolicy(
                        for: profile.sendProfilePicture,
                        identities: profile.profilePictureContactList
                    )
                }

                if myIdentityStore.pushFromName ?? "" != profile.nickname {
                    syncUserProfile.nickname = profile.nickname ?? ""
                }

                // TODO: (IOS-3874) Test if we should set `syncUserProfile.identityLinks.links` to an empty array so it is explicitly set when linked mobile number & linked email are removed or pending.
                
                if myIdentityStore.linkedMobileNo != profile.mobilePhoneNo, !profile.isLinkMobileNoPending {
                    var link = Sync_UserProfile.IdentityLinks.IdentityLink()
                    link.phoneNumber = profile.mobilePhoneNo ?? ""
                    syncUserProfile.identityLinks.links.append(link)
                }

                if myIdentityStore.linkedEmail != profile.email, !profile.isLinkEmailPending {
                    var link = Sync_UserProfile.IdentityLinks.IdentityLink()
                    link.email = profile.email ?? ""
                    syncUserProfile.identityLinks.links.append(link)
                }

                let task = TaskDefinitionProfileSync(
                    syncUserProfile: syncUserProfile,
                    profileImage: profile.profileImage,
                    linkMobileNoPending: profile.isLinkMobileNoPending,
                    linkEmailPending: profile.isLinkEmailPending
                )

                taskManager.add(taskDefinition: task) { _, error in
                    if let error {
                        seal.reject(error)
                        return
                    }
                    seal.fulfill_()
                }
            }
            else {
                save(profile)
                seal.fulfill_()
            }
        }
    }

    /// Sync and save email to link if multi device activated otherwise only save
    /// - Parameter email: Email address to link
    @objc func syncAndSave(email: String?) -> AnyPromise {
        AnyPromise(
            syncAndSave(
                Profile(
                    nickname: myIdentityStore.pushFromName,
                    profileImage: myIdentityStore.profilePicture?["ProfilePicture"] as? Data,
                    sendProfilePicture: userSettings.sendProfilePicture,
                    profilePictureContactList: userSettings.profilePictureContactList as? [String] ?? [String](),
                    mobilePhoneNo: myIdentityStore.linkedMobileNo,
                    isLinkMobileNoPending: myIdentityStore.linkMobileNoPending,
                    email: email,
                    isLinkEmailPending: myIdentityStore.linkEmailPending
                )
            )
        )
    }

    /// Sync and save mobile number to link if multi device activated otherwise only save
    /// - Parameter mobileNo: Mobile number to link
    @objc func syncAndSave(mobileNo: String?) -> AnyPromise {
        AnyPromise(
            syncAndSave(
                Profile(
                    nickname: myIdentityStore.pushFromName,
                    profileImage: myIdentityStore.profilePicture?["ProfilePicture"] as? Data,
                    sendProfilePicture: userSettings.sendProfilePicture,
                    profilePictureContactList: userSettings.profilePictureContactList as? [String] ?? [String](),
                    mobilePhoneNo: mobileNo,
                    isLinkMobileNoPending: myIdentityStore.linkMobileNoPending,
                    email: myIdentityStore.linkedEmail,
                    isLinkEmailPending: myIdentityStore.linkEmailPending
                )
            )
        )
    }

    public func save(_ profile: Profile) {
        myIdentityStore.pushFromName = profile.nickname
        myIdentityStore.linkedEmail = profile.email
        myIdentityStore.linkedMobileNo = profile.mobilePhoneNo
        
        myIdentityStore.linkEmailPending = profile.isLinkEmailPending
        myIdentityStore.linkMobileNoPending = profile.isLinkMobileNoPending
        
        // TODO: Decouple AvatarMaker
        AvatarMaker.shared().clearCacheForProfilePicture()
        var profilePicture = myIdentityStore.profilePicture
        
        let avatar = profile.profileImage
        if avatar == nil {
            if myIdentityStore.profilePicture != nil {
                myIdentityStore.profilePicture = nil
                contactStore.removeProfilePictureFlagForAllContacts()
            }
        }
        else {
            if profilePicture == nil {
                profilePicture = [:]
            }
            
            if avatar != profilePicture!["ProfilePicture"] as? Data {
                profilePicture?.setValue(avatar, forKey: "ProfilePicture")
                profilePicture?.removeObject(forKey: "LastUpload")
                myIdentityStore.profilePicture = profilePicture
                contactStore.removeProfilePictureFlagForAllContacts()
            }
        }

        userSettings.sendProfilePicture = profile.sendProfilePicture
        userSettings.profilePictureContactList = profile.profilePictureContactList
    }

    /// Save only changed form synced profile
    /// - Parameters:
    ///   - syncUserProfile: Delta updates of user profile
    ///   - profileImage: Image of user profile
    ///   - isLinkMobileNoPending: Not synced by MD
    ///   - isLinkEmailPending: Not synced by MD
    func save(
        syncUserProfile: Sync_UserProfile,
        profileImage: Data?,
        isLinkMobileNoPending: Bool,
        isLinkEmailPending: Bool
    ) {
        if syncUserProfile.hasProfilePicture {
            switch syncUserProfile.profilePicture.image {
            case .removed:
                if myIdentityStore.profilePicture != nil {
                    AvatarMaker.shared().clearCacheForProfilePicture()

                    myIdentityStore.profilePicture = nil
                    contactStore.removeProfilePictureFlagForAllContacts()
                }
            case .updated:
                if let image = profileImage {
                    AvatarMaker.shared().clearCacheForProfilePicture()

                    var profilePicture = myIdentityStore.profilePicture
                    if profilePicture == nil {
                        profilePicture = [:]
                    }

                    profilePicture?.setValue(image, forKey: "ProfilePicture")
                    profilePicture?.removeObject(forKey: "LastUpload")
                    myIdentityStore.profilePicture = profilePicture
                    contactStore.removeProfilePictureFlagForAllContacts()
                }
            case .none:
                break
            }
        }

        if syncUserProfile.hasProfilePictureShareWith {
            switch syncUserProfile.profilePictureShareWith.policy {
            case .nobody:
                userSettings.sendProfilePicture = SendProfilePictureNone
            case let .allowList(contacts):
                userSettings.sendProfilePicture = SendProfilePictureContacts
                userSettings.profilePictureContactList = contacts.identities
            case .everyone:
                userSettings.sendProfilePicture = SendProfilePictureAll
            case .none:
                break
            }
        }

        if syncUserProfile.hasNickname {
            myIdentityStore.pushFromName = syncUserProfile.nicknameNullable
        }

        if syncUserProfile.hasIdentityLinks {
            myIdentityStore.linkedMobileNo = syncUserProfile.identityLinks.links
                .first(where: { $0.phoneNumberNullable != nil })?.phoneNumberNullable
            myIdentityStore.linkedEmail = syncUserProfile.identityLinks.links
                .first(where: { $0.emailNullable != nil })?.emailNullable
        }

        myIdentityStore.linkMobileNoPending = isLinkMobileNoPending
        myIdentityStore.linkEmailPending = isLinkEmailPending
    }

    private func profilePictureShareWithPolicy(
        for sendProfilePicture: SendProfilePicture,
        identities: [String]
    ) -> Sync_UserProfile.ProfilePictureShareWith.OneOf_Policy {
        switch sendProfilePicture {
        case SendProfilePictureNone:
            return .nobody(Common_Unit())
        case SendProfilePictureContacts:
            var allowList = Common_Identities()
            allowList.identities = identities
            return .allowList(allowList)
        case SendProfilePictureAll:
            return .everyone(Common_Unit())
        default:
            return .nobody(Common_Unit())
        }
    }
}
