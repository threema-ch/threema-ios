import Foundation
import libthreemaSwift
import Testing
import ThreemaEssentials
@testable import ThreemaFramework

@MainActor
struct UserProfileProviderTests {

    // MARK: - userProfile()

    @Test func userProfileNicknameTakenFromProfileStoreIsNil() throws {
        let sut = makeSUT(profileStore: .mock)

        #expect(try sut.get().nickname.isEmpty)
    }

    @Test func userProfileNicknameTakenFromProfileStore() throws {
        let profileStore = ProfileStoreMock()
        let sut = makeSUT(profileStore: profileStore)

        profileStore.profile.nickname = "Bob"
        #expect(try sut.get().nickname == "Bob")

        profileStore.profile.profileImage = nil
        #expect(try sut.get().profilePicture == nil)
    }

    @Test func userProfileProfilePicture() throws {
        let profileStore = ProfileStoreMock()
        let sut = makeSUT(profileStore: profileStore)

        profileStore.profile.profileImage = nil
        #expect(try sut.get().profilePicture == nil)

        let imageData = Data([0xFF, 0xD8, 0xFF, 0xE0])
        profileStore.profile.profileImage = imageData
        #expect(
            try sut.get().profilePicture == libthreemaSwift.ProfilePicture(mediaType: .jpeg, data: imageData)
        )
    }

    @Test func userProfileShareProfilePolicy() throws {
        let profileStore = ProfileStoreMock()
        let sut = makeSUT(profileStore: profileStore)

        profileStore.profile.sendProfilePicture = SendProfilePictureNone
        #expect(try sut.get().profilePictureSharePolicy == .nobody)

        profileStore.profile.sendProfilePicture = SendProfilePictureAll
        #expect(try sut.get().profilePictureSharePolicy == .everyone)

        profileStore.profile.sendProfilePicture = SendProfilePictureContacts
        profileStore.profile.profilePictureContactList = ["AAAAAAAA", "BBBBBBBB"]
        #expect(try sut.get().profilePictureSharePolicy == .allowList(["AAAAAAAA", "BBBBBBBB"]))

        profileStore.profile.sendProfilePicture = .init(99)
        #expect(try sut.get().profilePictureSharePolicy == .nobody)
    }

    @Test func userProfileLinkedPhoneNumber() throws {
        let profileStore = ProfileStoreMock()
        let sut = makeSUT(profileStore: profileStore)

        profileStore.profile.mobilePhoneNo = nil
        #expect(try sut.get().linkedPhoneNumber == nil)

        profileStore.profile.mobilePhoneNo = ""
        #expect(try sut.get().linkedPhoneNumber == nil)

        profileStore.profile.mobilePhoneNo = "***"
        #expect(try sut.get().linkedPhoneNumber == .unknown)

        profileStore.profile.mobilePhoneNo = "41791234567"
        #expect(try sut.get().linkedPhoneNumber == .phoneNumber("41791234567"))
    }

    @Test func userProfileLinkedEmailAddress() throws {
        let profileStore = ProfileStoreMock()
        let sut = makeSUT(profileStore: profileStore)

        profileStore.profile.email = nil
        #expect(try sut.get().linkedEmailAddress == nil)

        profileStore.profile.email = ""
        #expect(try sut.get().linkedEmailAddress == nil)

        profileStore.profile.email = "***@***"
        #expect(try sut.get().linkedEmailAddress == .unknown)

        profileStore.profile.email = "bob@example.com"
        #expect(try sut.get().linkedEmailAddress == .emailAddress("bob@example.com"))
    }

    @Test func userProfileWorkAvailabilityStatus() throws {
        typealias ProfileStatus = ThreemaFramework.WorkAvailabilityStatus
        typealias UserStatus = libthreemaSwift.WorkAvailabilityStatus

        let profileStore = ProfileStoreMock()
        let sut = makeSUT(profileStore: profileStore)

        profileStore.profile.workAvailabilityStatus = nil
        #expect(try sut.get().workAvailabilityStatus == libthreemaSwift.WorkAvailabilityStatus.none)

        profileStore.profile.workAvailabilityStatus = ProfileStatus(category: .none, text: nil)
        #expect(try sut.get().workAvailabilityStatus == UserStatus.none)

        profileStore.profile.workAvailabilityStatus = ProfileStatus(category: .unavailable, text: nil)
        #expect(try sut.get().workAvailabilityStatus == UserStatus.unavailable(""))

        profileStore.profile.workAvailabilityStatus = ProfileStatus(category: .unavailable, text: "Message")
        #expect(try sut.get().workAvailabilityStatus == UserStatus.unavailable("Message"))

        profileStore.profile.workAvailabilityStatus = ProfileStatus(category: .busy, text: nil)
        #expect(try sut.get().workAvailabilityStatus == UserStatus.busy(""))

        profileStore.profile.workAvailabilityStatus = ProfileStatus(category: .busy, text: "Message")
        #expect(try sut.get().workAvailabilityStatus == UserStatus.busy("Message"))
    }

    // MARK: - setUserProfile(userProfile:)

    @Test func setUserProfileSavesNicknameFromUserProfileIsEmpty() throws {
        let profileStore = ProfileStoreMock()
        let sut = makeSUT(profileStore: profileStore)

        try sut.set(userProfile: .testProfile())

        #expect(profileStore.savedProfile?.nickname == nil)
    }

    @Test func setUserProfileSavesNicknameFromUserProfile() throws {
        let profileStore = ProfileStoreMock()
        let sut = makeSUT(profileStore: profileStore)

        try sut.set(userProfile: .testProfile(nickname: "Bob"))

        #expect(profileStore.savedProfile?.nickname == "Bob")
    }

    @Test func setUserProfileSavesProfileImageDataWhenProfilePictureSet() throws {
        let profileStore = ProfileStoreMock()
        let sut = makeSUT(profileStore: profileStore)

        let imageData = Data([0xFF, 0xD8, 0xFF, 0xE0])
        try sut.set(userProfile: .testProfile(
            profilePicture: libthreemaSwift.ProfilePicture(mediaType: .jpeg, data: imageData)
        ))

        #expect(profileStore.savedProfile?.profileImage == imageData)
    }

    @Test func setUserProfileSavesNilProfileImageWhenProfilePictureNil() throws {
        let profileStore = ProfileStoreMock()
        let sut = makeSUT(profileStore: profileStore)

        try sut.set(userProfile: .testProfile(profilePicture: nil))

        #expect(profileStore.savedProfile?.profileImage == nil)
    }

    @Test func setUserProfileMapsShareNobodyToSendProfilePicture() throws {
        let profileStore = ProfileStoreMock()
        let sut = makeSUT(profileStore: profileStore)

        try sut.set(userProfile: .testProfile(profilePictureSharePolicy: .nobody))

        #expect(profileStore.savedProfile?.sendProfilePicture == SendProfilePictureNone)
    }

    @Test func setUserProfileMapsShareEveryoneToSendProfilePictureAll() throws {
        let profileStore = ProfileStoreMock()
        let sut = makeSUT(profileStore: profileStore)

        try sut.set(userProfile: .testProfile(profilePictureSharePolicy: .everyone))

        #expect(profileStore.savedProfile?.sendProfilePicture == SendProfilePictureAll)
    }

    @Test func setUserProfileMapsShareAllowListToSendProfilePictureContacts() throws {
        let profileStore = ProfileStoreMock()
        let sut = makeSUT(profileStore: profileStore)

        try sut.set(userProfile: .testProfile(profilePictureSharePolicy: .allowList(["AAAAAAAA"])))

        #expect(profileStore.savedProfile?.sendProfilePicture == SendProfilePictureContacts)
    }

    @Test func setUserProfileSavesContactListWhenShareAllowList() throws {
        let profileStore = ProfileStoreMock()
        let sut = makeSUT(profileStore: profileStore)

        try sut.set(userProfile: .testProfile(
            profilePictureSharePolicy: .allowList(["AAAAAAAA", "BBBBBBBB"])
        ))

        #expect(profileStore.savedProfile?.profilePictureContactList == ["AAAAAAAA", "BBBBBBBB"])
    }

    @Test func setUserProfileSavesEmptyContactListWhenShareNotAllowList() throws {
        let profileStore = ProfileStoreMock()
        let sut = makeSUT(profileStore: profileStore)

        try sut.set(userProfile: .testProfile(profilePictureSharePolicy: .everyone))

        #expect(profileStore.savedProfile?.profilePictureContactList == [])
    }

    @Test func setUserProfileSavesPhoneNumber() throws {
        let profileStore = ProfileStoreMock()
        let sut = makeSUT(profileStore: profileStore)

        try sut.set(userProfile: .testProfile(linkedPhoneNumber: nil))
        #expect(profileStore.savedProfile?.mobilePhoneNo == nil)

        try sut.set(userProfile: .testProfile(linkedPhoneNumber: .phoneNumber("")))
        #expect(profileStore.savedProfile?.mobilePhoneNo == nil)

        try sut.set(userProfile: .testProfile(linkedPhoneNumber: .unknown))
        #expect(profileStore.savedProfile?.mobilePhoneNo == "***")

        try sut.set(userProfile: .testProfile(linkedPhoneNumber: .phoneNumber("41791234567")))
        #expect(profileStore.savedProfile?.mobilePhoneNo == "41791234567")
    }

    @Test func setUserProfileSavesEmailAddress() throws {
        let profileStore = ProfileStoreMock()
        let sut = makeSUT(profileStore: profileStore)

        try sut.set(userProfile: .testProfile(linkedEmailAddress: .unknown))
        #expect(profileStore.savedProfile?.email == "***@***")

        try sut.set(userProfile: .testProfile(linkedEmailAddress: .emailAddress("")))
        #expect(profileStore.savedProfile?.email == nil)

        try sut.set(userProfile: .testProfile(linkedEmailAddress: .emailAddress("bob@example.com")))
        #expect(profileStore.savedProfile?.email == "bob@example.com")
    }

    @Test func setUserProfileAlwaysSetsIsLinkMobileNoPendingFalse() throws {
        let profileStore = ProfileStoreMock()
        let sut = makeSUT(profileStore: profileStore)

        try sut.set(userProfile: .testProfile())

        #expect(profileStore.savedProfile?.isLinkMobileNoPending == false)
    }

    @Test func setUserProfileAlwaysSetsIsLinkEmailPendingFalse() throws {
        let profileStore = ProfileStoreMock()
        let sut = makeSUT(profileStore: profileStore)

        try sut.set(userProfile: .testProfile())

        #expect(profileStore.savedProfile?.isLinkEmailPending == false)
    }

    @Test func setUserProfileAlwaysSetsWorkAvailabilityStatusNil() throws {
        let profileStore = ProfileStoreMock()
        let sut = makeSUT(profileStore: profileStore)

        try sut.set(userProfile: .testProfile())

        #expect(profileStore.savedProfile?.workAvailabilityStatus == nil)
    }

    // MARK: - Private methods

    private func makeSUT(
        userIdentity: ThreemaIdentity = ThreemaIdentity("AAAAAAAA"),
        profileStore: any ProfileStoreProtocol = ProfileStoreMock()
    ) -> ThreemaFramework.UserProfileProvider {
        ThreemaFramework.UserProfileProvider(userIdentity: userIdentity, profileStore: profileStore)
    }
}

extension libthreemaSwift.UserProfile {
    fileprivate static func testProfile(
        nickname: String = String.empty,
        profilePicture: libthreemaSwift.ProfilePicture? = nil,
        profilePictureSharePolicy: ProfilePictureSharePolicy = .nobody,
        linkedPhoneNumber: IdentityLinkPhoneNumber? = nil,
        linkedEmailAddress: IdentityLinkEmailAddress? = nil,
        workAvailabilityStatus: libthreemaSwift.WorkAvailabilityStatus? = nil,
    ) -> libthreemaSwift.UserProfile {
        libthreemaSwift.UserProfile(
            nickname: nickname,
            profilePicture: profilePicture,
            profilePictureSharePolicy: profilePictureSharePolicy,
            linkedPhoneNumber: linkedPhoneNumber,
            linkedEmailAddress: linkedEmailAddress,
            workAvailabilityStatus: workAvailabilityStatus
        )
    }
}
