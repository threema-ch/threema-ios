import Foundation
import libthreemaSwift
import ThreemaEssentials

final class UserProfileProvider: libthreemaSwift.UserProfileProvider {
    private let userIdentity: ThreemaIdentity
    private nonisolated(unsafe) let profileStore: any ProfileStoreProtocol

    public init(
        userIdentity: ThreemaIdentity,
        profileStore: any ProfileStoreProtocol
    ) {
        self.userIdentity = userIdentity
        self.profileStore = profileStore
    }

    func get() throws -> libthreemaSwift.UserProfile {
        libthreemaSwift.UserProfile(profile: profileStore.profile)
    }
    
    func set(userProfile: libthreemaSwift.UserProfile) throws {
        profileStore.save(
            ProfileStore.Profile(profile: userProfile, myIdentity: userIdentity)
        )
    }
}

extension libthreemaSwift.UserProfile {
    fileprivate init(profile: ProfileStore.Profile) {
        let sharePolicy: ProfilePictureSharePolicy =
            switch profile.sendProfilePicture {
            case SendProfilePictureNone:
                .nobody
            case SendProfilePictureAll:
                .everyone
            case SendProfilePictureContacts:
                .allowList(profile.profilePictureContactList)
            default:
                // Fallback for undefined or missing policy. Default to the most restrictive option.
                .nobody
            }

        let linkedPhoneNumber: IdentityLinkPhoneNumber? =
            if let value = profile.mobilePhoneNo, !value.isEmpty {
                value == String.unknownLinkedPhoneNumber ? .unknown : .phoneNumber(value)
            }
            else {
                nil
            }

        let linkedEmailAddress: IdentityLinkEmailAddress? =
            if let value = profile.email, !value.isEmpty {
                value == String.unknownLinkedEmailAddress ? .unknown : .emailAddress(value)
            }
            else {
                nil
            }

        let workAvailabilityStatus: libthreemaSwift.WorkAvailabilityStatus =
            if let status = profile.workAvailabilityStatus {
                switch status.category {
                case .none:
                    .none
                case .unavailable:
                    .unavailable(status.text ?? String.empty)
                case .busy:
                    .busy(status.text ?? String.empty)
                }
            }
            else {
                .none
            }

        self.init(
            nickname: profile.nickname ?? String.empty,
            profilePicture: profile.profileImage.map {
                libthreemaSwift.ProfilePicture(mediaType: .jpeg, data: $0)
            },
            profilePictureSharePolicy: sharePolicy,
            linkedPhoneNumber: linkedPhoneNumber,
            linkedEmailAddress: linkedEmailAddress,
            workAvailabilityStatus: workAvailabilityStatus
        )
    }
}

extension ProfileStore.Profile {
    fileprivate init(profile: libthreemaSwift.UserProfile, myIdentity: ThreemaIdentity) {
        let sendProfilePicture: SendProfilePicture =
            switch profile.profilePictureSharePolicy {
            case .nobody:
                SendProfilePictureNone
            case .everyone:
                SendProfilePictureAll
            case .allowList:
                SendProfilePictureContacts
            }

        let profilePictureContactList: [String] =
            if case let .allowList(contacts) = profile.profilePictureSharePolicy {
                contacts
            }
            else {
                []
            }

        let mobilePhoneNo: String? =
            if case let .phoneNumber(number) = profile.linkedPhoneNumber, !number.isEmpty {
                number
            }
            else if case .unknown = profile.linkedPhoneNumber {
                String.unknownLinkedPhoneNumber
            }
            else {
                nil
            }

        let email: String? =
            if case let .emailAddress(address) = profile.linkedEmailAddress, !address.isEmpty {
                address
            }
            else if case .unknown = profile.linkedEmailAddress {
                String.unknownLinkedEmailAddress
            }
            else {
                nil
            }

        // Note: Some values have a fallback default when restoring a data backup.

        self.init(
            myIdentity: myIdentity,
            nickname: profile.nickname.isEmpty ? nil : profile.nickname,
            profileImage: profile.profilePicture?.data,
            sendProfilePicture: sendProfilePicture,
            profilePictureContactList: profilePictureContactList,
            mobilePhoneNo: mobilePhoneNo,
            isLinkMobileNoPending: false,
            email: email,
            isLinkEmailPending: false,
            workAvailabilityStatus: nil
        )
    }
}

extension String {
    fileprivate static var unknownLinkedPhoneNumber: Self { "***" }
    fileprivate static var unknownLinkedEmailAddress: Self { "***@***" }
}
