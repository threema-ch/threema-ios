import Foundation
import libthreemaSwift
import ThreemaEssentials

extension ContactEntity {
    func update(
        with contact: LibthreemaContact,
        sortOrderFirstName: Bool
    ) throws {
        guard let importStatus = ImportStatus(contact.syncState) else {
            throw MappingError.syncState
        }

        guard let readReceipt = ReadReceipt(contact.readReceiptPolicyOverride) else {
            throw MappingError.readReceipt
        }

        guard let contactState = ContactState(contact.activityState) else {
            throw MappingError.activityState
        }

        guard let typingIndicator = TypingIndicator(contact.typingIndicatorPolicyOverride) else {
            throw MappingError.typingIndicatorPolicyOverride
        }

        guard let contactVerificationLevel = VerificationLevel(contact.verificationLevel) else {
            throw MappingError.verificationLevel
        }

        createdAt = contact.createdAt.date
        featureMask = NSNumber(value: contact.featureMask)
        setFirstName(
            to: contact.firstName.isEmpty ? nil : contact.firstName,
            sortOrderFirstName: sortOrderFirstName
        )
        forwardSecurityState = NSNumber(value: UInt32(ForwardSecurityState.off.rawValue))
        isHidden = HiddenContact(contact.acquaintanceLevel)
        setIdentity(to: contact.identity, sortOrderFirstName: sortOrderFirstName)
        contactImportStatus = importStatus
        setLastName(
            to: contact.lastName.isEmpty ? nil : contact.lastName,
            sortOrderFirstName: sortOrderFirstName
        )
        publicKey = contact.publicKey
        let nickname = contact.nickname.isEmpty ? nil : contact.nickname
        publicNickname = nickname
        self.readReceipt = readReceipt
        self.contactState = contactState
        self.typingIndicator = typingIndicator
        self.contactVerificationLevel = contactVerificationLevel
        workContact = NSNumber(booleanLiteral: WorkContact(contact.workVerificationLevel))
    }

    func update(
        with contact: LibthreemaContactUpdate,
        sortOrderFirstName: Bool
    ) throws {
        if let value = contact.featureMask {
            featureMask = NSNumber(value: value)
        }

        if let value = contact.firstName {
            setFirstName(to: value.isEmpty ? nil : value, sortOrderFirstName: sortOrderFirstName)
        }

        if let value = contact.acquaintanceLevel {
            isHidden = HiddenContact(value)
        }
        setIdentity(to: contact.identity, sortOrderFirstName: sortOrderFirstName)
        if let value = contact.syncState {
            guard let importStatus = ImportStatus(value) else {
                throw MappingError.syncState
            }

            contactImportStatus = importStatus
        }

        if let value = contact.lastName {
            setLastName(to: value.isEmpty ? nil : value, sortOrderFirstName: sortOrderFirstName)
        }

        if let value = contact.nickname {
            publicNickname = value.isEmpty ? nil : value
        }

        switch contact.readReceiptPolicyOverride {
        case .remove:
            readReceipt = .default
        case .unchanged:
            break
        case let .update(value):
            guard let readReceipt = ReadReceipt(value) else {
                throw MappingError.readReceipt
            }

            self.readReceipt = readReceipt
        }

        if let value = contact.activityState {
            guard let contactState = ContactState(value) else {
                throw MappingError.activityState
            }

            self.contactState = contactState
        }

        switch contact.typingIndicatorPolicyOverride {
        case .remove:
            typingIndicator = .default
        case .unchanged:
            break
        case let .update(value):
            guard let typingIndicator = TypingIndicator(value) else {
                throw MappingError.typingIndicatorPolicyOverride
            }

            self.typingIndicator = typingIndicator
        }

        if let value = contact.verificationLevel {
            guard let contactVerificationLevel = VerificationLevel(value) else {
                throw MappingError.verificationLevel
            }

            self.contactVerificationLevel = contactVerificationLevel
        }

        if let value = contact.workVerificationLevel {
            workContact = NSNumber(booleanLiteral: WorkContact(value))
        }
    }
}
