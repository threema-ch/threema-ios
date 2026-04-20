import Foundation

enum ForwardSecurityError: Error {
    case invalidSessionIDLength
    case invalidPublicKeyLength
    case invalidMessageIDLength
    case invalidMode
    case counterOutOfRange
    case noDHModeNegotiated
    case messageTypeNotSupported
    case missingGroupIdentity
    case existingSession
    case unknownEnvelope
}
