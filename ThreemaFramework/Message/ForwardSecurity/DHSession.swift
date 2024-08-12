//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2023 Threema GmbH
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
import ThreemaProtocols

public struct DHVersions: CustomStringConvertible, Equatable {
    /// Version for local/outgoing 4DH messages
    public var local: CspE2eFs_Version
    /// Version for remote/incoming 4DH messages
    public var remote: CspE2eFs_Version
    
    init(local: CspE2eFs_Version, remote: CspE2eFs_Version) {
        self.local = local
        self.remote = remote
    }
    
    /// Restore the 4DH versions from a database
    ///
    /// Only used for tests
    public static func restored(local: CspE2eFs_Version?, remote: CspE2eFs_Version?) -> DHVersions? {
        guard let local, let remote else {
            return nil
        }
        
        return DHVersions(local: local, remote: remote)
    }
    
    /// Bootstrap the initial 4DH versions from the negotiated version of the Init/Accept flow
    public static func negotiated(version: CspE2eFs_Version) -> DHVersions {
        DHVersions(local: version, remote: version)
    }
    
    /// 4DH versions to be updated from older versions after successful processing of an encapsulated message
    public static func updated(local: CspE2eFs_Version, remote: CspE2eFs_Version) -> DHVersions {
        DHVersions(local: local, remote: remote)
    }
    
    public var description: String {
        "local=\(local), remote=\(remote)"
    }
}

public class ProcessedVersions: CustomStringConvertible {
    // In Android `offeredVersion` is an Int, in Swift its not as inconvenient to use the real type
    /// The effective offered version of the associated message
    public var offeredVersion: CspE2eFs_Version
    /// The effective applied version of the associated message
    public var appliedVersion: CspE2eFs_Version
    /// The resulting versions to be committed when the message has been processed
    public var pending4DHVersion: DHVersions?
    
    init(offeredVersion: CspE2eFs_Version, appliedVersion: CspE2eFs_Version, pending4DHVersion: DHVersions?) {
        self.offeredVersion = offeredVersion
        self.appliedVersion = appliedVersion
        self.pending4DHVersion = pending4DHVersion
    }
    
    public var description: String {
        "offered=\(offeredVersion), applied=\(appliedVersion), pending=\(pending4DHVersion?.description ?? "nil")"
    }
}

public class UpdatedVersionsSnapshot {
    /// Versions before the update
    public var before: DHVersions
    /// Versions after the update
    public var after: DHVersions
    
    var description: String {
        "from (\(before)), to (\(after))"
    }
    
    init(before: DHVersions, after: DHVersions) {
        self.before = before
        self.after = after
    }
}

// MARK: - DHSession.DHSessionNegotiatedVersionUpdate

extension DHSession {
    enum DHSessionNegotiatedVersionUpdate {
        case none
        case updatedFrom(CspE2eFs_Version)
    }
}

// MARK: - DHSession.State

extension DHSession {
    public enum State: CustomStringConvertible {
        /// Locally initiated, out 2DH, in none
        case L20
        /// Remotely or locally initiated, out 4DH, in 4DH
        case RL44
        /// Remotely initiated, in 2DH, out none
        case R20
        /// Remotely initiated, in 2DH, out 4DH
        case R24
        
        enum StateError: Error {
            case invalidStateError(String)
        }
        
        public var description: String {
            switch self {
            case .L20:
                "L20"
            case .RL44:
                "RL44"
            case .R20:
                "R20"
            case .R24:
                "R24"
            }
        }
    }
}

enum BadMessageError: Error {
    case invalidFSVersion
    case invalidFSVersionRange
    case unsupportedMinimumFSVersion
    case unableToNegotiateFSSession
    case unexpectedGroupMessageEncapsulated
    case noGroupIdentity
}

enum RejectMessageError: Error {
    /// **Warning**: We have catch filters for this one case, if you add another, refactor the filters.
    /// Indicates that an encapsulated message cannot be processed. The FS session should be terminated and the
    /// associated message should be `Reject`ed.
    case rejectMessageError(description: String)
}

enum DHSessionError: Error {
    case missingEphemeralPrivateKey
    case invalidPublicKeyLength
}

public class DHSession: CustomStringConvertible, Equatable {
    static let keSalt2DHPrefix = "ke-2dh-"
    static let keSalt4DHPrefix = "ke-4dh-"
    static let kdfPersonal = "3ma-e2e"
    
    let id: DHSessionID
    let myIdentity: String
    let peerIdentity: String
    private(set) var myEphemeralPrivateKey: Data?
    private(set) var myEphemeralPublicKey: Data!
    
    var myRatchet2DH: KDFRatchet?
    var myRatchet4DH: KDFRatchet?
    var peerRatchet2DH: KDFRatchet?
    var peerRatchet4DH: KDFRatchet?
    
    /// Was a new session I initiated committed?
    ///
    /// The initial commit of an new initiated session should not happen before an `Init` and the message triggering it
    /// are sent. However, on iOS we need to store the session immediately as with two separate queues for incoming and
    /// outgoing messages we might have a race condition where an incoming `Accept` is processed before the message
    /// after the `Init` is sent.
    var newSessionCommitted: Bool {
        didSet {
            if newSessionCommitted == false, oldValue == true {
                DDLogWarn("[ForwardSecurity] New session committed should never be reset to false")
                assertionFailure()
            }
        }
    }
    
    /// Time of last message sent in this session
    var lastMessageSent: Date?
    
    /// Version used for local (outgoing) / remote (incoming) 4DH messages.
    /// `nil` in case the 4DH message version has not been negotiated yet.
    ///  Warning: Only exported for storing the session, don't use it anywhere else!
    private(set) var current4DHVersions: DHVersions?
    
    static func supportedVersionWithin(majorVersion: CspE2eFs_Version) throws -> CspE2eFs_Version {
        switch majorVersion.rawValue & 0xFF00 {
        case CspE2eFs_Version.v10.rawValue:
            return ThreemaEnvironment.fsMaxVersion
        default:
            throw DHSession.State.StateError.invalidStateError("Unknown major version: \(majorVersion)")
        }
    }
    
    // TODO: (IOS-3949) Todo needed aswell?
    // TODO(ANDR-2452): We don't save the remote `Init` version range at the moment and simply
    // assume it to be 1.0 if not provided. This is a horrible hack and prevents us from
    // bumping the minimum version.
    //
    // Note: It does not matter whether we pick the local or the remote version to determine
    // the maximum supported minor version as both should always use the same major version.
    #if DEBUG
        // This only exists for unit tests
        var outgoingOfferedVersionOverride: CspE2eFs_Version?
        var outgoingOfferedVersion: CspE2eFs_Version {
            guard let outgoingOfferedVersionOverride else {
                let tempState = try! state
                switch tempState {
                case .L20, .R20:
                    
                    // There should be no 4DH versions in this state
                    if let current4DHVersions {
                        DDLogError(
                            "[ForwardSecurity] outgoingOfferedVersion: Unexpected current4DHVersions=\(current4DHVersions) in L20 state"
                        )
                    }

                    // TODO(ANDR-2452): We don't save the remote `Init` version range at the moment and simply
                    // assume it to be 1.0 if not provided. This is a horrible hack and prevents us from
                    // bumping the minimum version.
                    return .v10

                // R24, L44 or R44
                case .RL44, .R24:
                    
                    // We expect 4DH versions to be available in these states
                    guard let current4DHVersions else {
                        DDLogError(
                            "[ForwardSecurity] outgoingOfferedVersion: Missing current4DHVersions in state=\(tempState)"
                        )
                        return .v10
                    }

                    // Note: It does not matter whether we pick the local or the remote version to determine
                    // the maximum supported minor version as both should always use the same major version.
                    return try! DHSession.supportedVersionWithin(majorVersion: current4DHVersions.local)
                }
            }
        
            return outgoingOfferedVersionOverride
        }
    #else
        var outgoingOfferedVersion: CspE2eFs_Version {
            let tempState = try! state
            switch tempState {
            case .L20, .R20:
                
                // There should be no 4DH versions in this state
                if let current4DHVersions {
                    DDLogError(
                        "[ForwardSecurity] outgoingOfferedVersion: Unexpected current4DHVersions=\(current4DHVersions) in L20 state"
                    )
                }

                // TODO(ANDR-2452): We don't save the remote `Init` version range at the moment and simply
                // assume it to be 1.0 if not provided. This is a horrible hack and prevents us from
                // bumping the minimum version.
                return .v10

            // R24, L44 or R44
            case .RL44, .R24:
                
                // We expect 4DH versions to be available in these states
                guard let current4DHVersions else {
                    DDLogError(
                        "[ForwardSecurity] outgoingOfferedVersion: Missing current4DHVersions in state=\(tempState)"
                    )
                    return .v10
                }

                // Note: It does not matter whether we pick the local or the remote version to determine
                // the maximum supported minor version as both should always use the same major version.
                return try! DHSession.supportedVersionWithin(majorVersion: current4DHVersions.local)
            }
        }
    #endif
    
    // The current negotiated major and minor version that is expected to be the bottom line for remote/incoming
    // messages.
    var outgoingAppliedVersion: CspE2eFs_Version {
        
        let tempState = try! state
        switch tempState {
            
        case .L20, .R20:
            
            // There should be no 4DH versions in this state
            if let current4DHVersions {
                DDLogError(
                    "[ForwardSecurity] outgoingAppliedVersion: Unexpected current4DHVersions=\(current4DHVersions) in state=\(tempState)"
                )
            }

            // TODO(ANDR-2452): We don't save the remote `Init` version range at the moment and simply
            // assume it to be 1.0 if not provided. This is a horrible hack and prevents us from
            // bumping the minimum version.
            return .v10
            
        // R24, L44 or R44
        case .RL44, .R24:
            
            // We expect 4DH versions to be available in these states
            guard let current4DHVersions else {
                DDLogError("[ForwardSecurity] outgoingAppliedVersion: Missing current4DHVersions in state=\(tempState)")
                return .v10
            }
            return current4DHVersions.local
        }
    }
    
    // The current negotiated major and minor version that is expected to be the bottom line for
    // remote/incoming messages.
    //
    // IMPORTANT: This is always the bottom line version for use in case a message without FS has
    // been received. To validate an encapsulated message's versions, use
    // processIncomingMessageVersion instead.
    var minimumIncomingAppliedVersion: CspE2eFs_Version {
        
        let tempState = try! state
        switch tempState {
            
        case .L20, .R20:
            // There should be no 4DH versions in this state
            if let current4DHVersions {
                DDLogError(
                    "[ForwardSecurity] minimumIncomingAppliedVersion: Unexpected current4DHVersions=\(current4DHVersions) in L20 state"
                )
            }

            // TODO(ANDR-2452): We don't save the remote `Init` version range at the moment and simply
            // assume it to be 1.0 if not provided. This is a horrible hack and prevents us from
            // bumping the minimum version.
            return .v10

        case .R24:
            // Special case for this state where we can receive 2DH or 4DH messages, so the
            // bottom line is what has been offered in the remote's `Init`.

            // TODO(ANDR-2452): We don't save the remote `Init` version range at the moment and simply
            // assume it to be 1.0 if not provided. This is a horrible hack and prevents us from
            // bumping the minimum version.
            return .v10
            
        // L44 or R44
        case .RL44:
            // We expect 4DH versions to be available in these states
            guard let current4DHVersions else {
                DDLogError(
                    "[ForwardSecurity] minimumIncomingAppliedVersion: Missing current4DHVersions in state=\(tempState)"
                )
                return .v10
            }
            return current4DHVersions.remote
        }
    }
    
    /// Get the state of the DH session. Note that this state depends on the availability of the ratchets, which needs
    /// great care when adding and remove the ratchets.
    var state: State {
        get throws {
            if myRatchet2DH == nil,
               myRatchet4DH != nil,
               peerRatchet2DH == nil,
               peerRatchet4DH != nil {
                return .RL44
            }
            else if myRatchet2DH == nil,
                    myRatchet4DH != nil,
                    peerRatchet2DH != nil,
                    peerRatchet4DH != nil {
                return .R24
            }
            else if myRatchet2DH != nil,
                    myRatchet4DH == nil,
                    peerRatchet2DH == nil,
                    peerRatchet4DH == nil {
                return .L20
            }
            else if myRatchet2DH == nil,
                    myRatchet4DH == nil,
                    peerRatchet2DH != nil,
                    peerRatchet4DH == nil {
                return .R20
            }
            
            let description =
                "Illegal DH session state: myRatchet2DH=\(myRatchet2DH != nil), myRatchet4DH=\(myRatchet4DH != nil), peerRatchet2DH=\(peerRatchet2DH != nil), peerRatchet4DH=\(peerRatchet4DH != nil)"
            DDLogError("[ForwardSecurity] \(description)")
            throw DHSession.State.StateError.invalidStateError(description)
        }
    }
    
    // MARK: - Private Properties
    
    // TODO: (IOS-4251) Can this be removed?
    private let localSupportedVersionRange: CspE2eFs_VersionRange
    
    /// Create a new DHSession as an initiator, using a new random session ID and
    /// a new random private key.
    init(
        peerIdentity: String,
        peerPublicKey: Data,
        identityStore: MyIdentityStoreProtocol,
        localVersion: CspE2eFs_VersionRange = ThreemaEnvironment.fsVersion
    ) {
        self.id = DHSessionID()
        self.myIdentity = identityStore.identity
        self.peerIdentity = peerIdentity
        self.localSupportedVersionRange = localVersion
        
        self.newSessionCommitted = false
        self.lastMessageSent = nil
        
        var newPublicKey: NSData?
        var newPrivateKey: NSData?
        NaClCrypto.shared().generateKeyPairPublicKey(&newPublicKey, secretKey: &newPrivateKey)
        
        self.myEphemeralPublicKey = newPublicKey! as Data
        self.myEphemeralPrivateKey = newPrivateKey! as Data
        
        let dhStaticStatic = identityStore.sharedSecret(withPublicKey: peerPublicKey)!
        let dhStaticEphemeral = NaClCrypto.shared()
            .sharedSecret(forPublicKey: peerPublicKey, secretKey: myEphemeralPrivateKey)!
        
        initKDF2DH(dhStaticStatic: dhStaticStatic, dhStaticEphemeral: dhStaticEphemeral, peer: false)
        DDLogNotice(
            "[ForwardSecurity] New initiator DHSession initialized for peer=\(peerIdentity), localVersion=\(localVersion)"
        )
    }
    
    /// Create a new DHSession as a responder.
    init(
        id: DHSessionID,
        peerEphemeralPublicKey: Data,
        peerIdentity: String,
        peerPublicKey: Data,
        version: CspE2eFs_VersionRange,
        identityStore: MyIdentityStoreProtocol,
        localVersion: CspE2eFs_VersionRange = ThreemaEnvironment.fsVersion
    ) throws {
        if peerEphemeralPublicKey.count != kNaClCryptoPubKeySize {
            throw DHSessionError.invalidPublicKeyLength
        }
        
        self.id = id
        self.myIdentity = identityStore.identity
        self.peerIdentity = peerIdentity
        self.localSupportedVersionRange = localVersion
        
        self.newSessionCommitted = true
        self.lastMessageSent = nil
        
        self.myEphemeralPublicKey = completeKeyExchange(
            peerEphemeralPublicKey: peerEphemeralPublicKey,
            peerPublicKey: peerPublicKey,
            identityStore: identityStore
        )
        
        let negotiatedVersion = try negotiateMajorAndMinorVersion(from: localVersion, and: version)
        self.current4DHVersions = DHVersions.negotiated(version: negotiatedVersion)
        DDLogNotice(
            "[ForwardSecurity] New responder DHSession initialized for peer=\(peerIdentity), version=\(version), localVersion=\(localVersion)"
        )
    }
    
    /// Create a DHSession with existing data, e.g. read from a persistent store.
    init(
        id: DHSessionID,
        myIdentity: String,
        peerIdentity: String,
        myEphemeralPrivateKey: Data?,
        myEphemeralPublicKey: Data,
        myRatchet2DH: KDFRatchet?,
        myRatchet4DH: KDFRatchet?,
        peerRatchet2DH: KDFRatchet?,
        peerRatchet4DH: KDFRatchet?,
        current4DHVersions: DHVersions?,
        newSessionCommitted: Bool,
        lastMessageSent: Date?,
        localVersion: CspE2eFs_VersionRange = ThreemaEnvironment.fsVersion
    ) throws {
        
        self.id = id
        self.myIdentity = myIdentity
        self.peerIdentity = peerIdentity
        self.myEphemeralPrivateKey = myEphemeralPrivateKey
        self.myEphemeralPublicKey = myEphemeralPublicKey
        self.myRatchet2DH = myRatchet2DH
        self.myRatchet4DH = myRatchet4DH
        self.peerRatchet2DH = peerRatchet2DH
        self.peerRatchet4DH = peerRatchet4DH
        self.current4DHVersions = current4DHVersions
        self.newSessionCommitted = newSessionCommitted
        self.lastMessageSent = lastMessageSent
        self.localSupportedVersionRange = localVersion
        
        // The database may restore 4DH versions when there are none because the DB migration adds
        // a `DEFAULT` clause. We need to override it to `null` in L20 and R20 state.
        switch try state {
        case .L20, .R20:
            self.current4DHVersions = nil
        case .R24, .RL44:
            break
        }
        
        DDLogDebug(
            "[ForwardSecurity] Existing DHSession loaded for peer=\(peerIdentity), version=\(current4DHVersions?.description ?? "nil"), localVersion=\(localVersion)"
        )
    }
    
    /// Process a DH accept received from the peer.
    func processAccept(
        peerEphemeralPublicKey: Data,
        peerPublicKey: Data,
        peerSupportedVersionRange: CspE2eFs_VersionRange,
        identityStore: MyIdentityStoreProtocol
    ) throws {
        guard let myEphemeralPrivateKey else {
            throw DHSessionError.missingEphemeralPrivateKey
        }
        
        // Derive 4DH root key
        let dhStaticStatic = identityStore.sharedSecret(withPublicKey: peerPublicKey)!
        let dhStaticEphemeral = NaClCrypto.shared()
            .sharedSecret(forPublicKey: peerPublicKey, secretKey: myEphemeralPrivateKey)!
        let dhEphemeralStatic = identityStore.sharedSecret(withPublicKey: peerEphemeralPublicKey)!
        let dhEphemeralEphemeral = NaClCrypto.shared()
            .sharedSecret(forPublicKey: peerEphemeralPublicKey, secretKey: myEphemeralPrivateKey)!
        initKDF4DH(
            dhStaticStatic: dhStaticStatic,
            dhStaticEphemeral: dhStaticEphemeral,
            dhEphemeralStatic: dhEphemeralStatic,
            dhEphemeralEphemeral: dhEphemeralEphemeral
        )
        
        let negotiatedVersion = try negotiateMajorAndMinorVersion(
            from: ThreemaEnvironment.fsVersion,
            and: peerSupportedVersionRange
        )
        
        // myEphemeralPrivateKey is not needed anymore at this point
        self.myEphemeralPrivateKey = nil
        current4DHVersions = DHVersions.negotiated(version: negotiatedVersion)

        // My 2DH ratchet is not needed anymore at this point, but the peer 2DH ratchet is still
        // needed until we receive the first 4DH message, as there may be some 2DH messages still
        // in flight.
        // Note that this is also needed to be able to correctly determine the current session state.
        myRatchet2DH = nil
        
        DDLogNotice("[ForwardSecurity] Processed accept for \(description)")
    }
    
    /// Discard the 2DH peer ratchet associated with this session (because a 4DH message has been received).
    public func discardPeerRatchet2DH() {
        peerRatchet2DH = nil
    }
    
    func negotiateMajorAndMinorVersion(
        from localVersion: CspE2eFs_VersionRange,
        and remoteVersion: CspE2eFs_VersionRange
    ) throws -> CspE2eFs_Version {
        let remoteVersion = DHSession.actualRemoteVersion(from: remoteVersion)
        
        guard localVersion.isInitialized else {
            throw BadMessageError.invalidFSVersion
        }
        
        guard remoteVersion.isInitialized else {
            throw BadMessageError.invalidFSVersion
        }
        
        // Validate version range
        guard remoteVersion.min <= remoteVersion.max else {
            throw BadMessageError.invalidFSVersion
        }
        
        // Ensure the version range is supported
        guard !(remoteVersion.min > localVersion.max || localVersion.min > remoteVersion.max) else {
            throw BadMessageError.unableToNegotiateFSSession
        }
        
        let rawNegotiatedVersion = min(localVersion.max, remoteVersion.max)
        guard let newNegotiatedVersion = CspE2eFs_Version(rawValue: Int(rawNegotiatedVersion)) else {
            throw BadMessageError.unsupportedMinimumFSVersion
        }
        
        if case .UNRECOGNIZED = newNegotiatedVersion {
            throw BadMessageError.unableToNegotiateFSSession
        }
        
        return newNegotiatedVersion
    }
    
    // Process the provided versions of an incoming message.
    // Returns the processed versions to be committed once the message has been processed.
    func processIncomingMessageVersion(message: ForwardSecurityDataMessage) throws -> ProcessedVersions {
        DDLogVerbose(
            "[ForwardSecurity] Process version for incoming message \(description). Message \(message.type) with offeredVersion=\(message.offeredVersion), appliedVersion=\(message.appliedVersion)"
        )
        
        // Determine offered and applied version from the message
        var offeredVersion = message.offeredVersion
        var rawAppliedVersion = message.appliedVersion
        
        if offeredVersion == .unspecified {
            offeredVersion = .v10
        }
        if rawAppliedVersion == .unspecified {
            rawAppliedVersion = offeredVersion
        }
        
        // TODO(ANDR-2452): Clamp hack. Clamping 2DH messages to 1.0 works around an issue where 2DH
        // messages would be claim to apply with 1.1 from older beta versions. This is a horrible hack
        // and prevents us from bumping the minimum version.
        if message.type == .twodh {
            offeredVersion = .v10
            rawAppliedVersion = .v10
        }
        
        // The applied version cannot be greater than offered version
        if rawAppliedVersion.rawValue > offeredVersion.rawValue {
            throw RejectMessageError
                .rejectMessageError(
                    description: "Invalid FS versions in message: offered=\(offeredVersion), applied=\(rawAppliedVersion)"
                )
        }
        
        // Handle according to the DH type
        // TODO: (IOS-3949) Do/catch or guard state?
        let state = try! state
        var appliedVersion: CspE2eFs_Version?
        var pendingDHVersions: DHVersions?
        
        if message.type == .twodh {
            // A 2DH message is only valid in R20 and R24 state
            if state != .R20, state != .R24 {
                throw RejectMessageError.rejectMessageError(description: "Unexpected 2DH message in state=\(state)")
            }
            
            // TODO(ANDR-2452): We don't save the remote `Init` version range at the moment and simply
            // assume it to be 1.0. This is a horrible hack and prevents us from bumping the minimum
            // version.
            let initVersionMin: CspE2eFs_Version = .v10
            
            // For 2DH messages, the versions must match exactly the minimum version that were
            // offered in the remote `Init`.
            if offeredVersion != initVersionMin {
                throw RejectMessageError
                    .rejectMessageError(
                        description: "Invalid offered FS version in 2DH message: offered=\(offeredVersion), init-version-min=\(initVersionMin)"
                    )
            }
            if rawAppliedVersion != initVersionMin {
                throw RejectMessageError
                    .rejectMessageError(
                        description: "Invalid applied FS version in 2DH message: applied=\(rawAppliedVersion), init-version-min=\(initVersionMin)"
                    )
            }
            
            // There are no versions to be committed
            appliedVersion = initVersionMin
            pendingDHVersions = nil
        }
        else {
            // A 4DH message is only valid in R24, L44 or R44 state
            if state != .R24 && state != .RL44 {
                throw RejectMessageError.rejectMessageError(description: "Unexpected 4DH message in state=\(state)")
            }
            
            guard let current4DHVersions else {
                throw RejectMessageError.rejectMessageError(description: "Internal FS state mismatch")
            }
            
            // Major versions must match, the minor version must be ≥ the respective version
            guard !(
                (offeredVersion.rawValue & 0xFF00) != (current4DHVersions.local.rawValue & 0xFF00) ||
                    (offeredVersion.rawValue & 0x00FF) < (current4DHVersions.local.rawValue & 0x00FF)
            ) else {
                throw RejectMessageError
                    .rejectMessageError(
                        description: "Invalid offered FS version in message: offered=\(offeredVersion), local-4dhv=\(current4DHVersions.local)"
                    )
            }
            
            guard !(
                (rawAppliedVersion.rawValue & 0xFF00) != (current4DHVersions.remote.rawValue & 0xFF00) ||
                    (rawAppliedVersion.rawValue & 0x00FF) < (current4DHVersions.remote.rawValue & 0x00FF)
            ) else {
                throw RejectMessageError
                    .rejectMessageError(
                        description: "Invalid applied FS version in message: applied=\(rawAppliedVersion), remote-4dhv=\(current4DHVersions.remote)"
                    )
            }
            
            // The offered version is allowed to be greater than what we support, so calculate the
            // maximum commonly supported offered version.
            //
            // Note: There should be no gaps, so the resulting version should exist.
            let newLocalVersion: CspE2eFs_Version? = try CspE2eFs_Version(
                rawValue: min(
                    offeredVersion.rawValue,
                    DHSession.supportedVersionWithin(majorVersion: offeredVersion).rawValue
                )
            )
            guard let newLocalVersion else {
                throw RejectMessageError.rejectMessageError(
                    description: "Unknown maximum commonly supported offered FS version in message: offered=\(offeredVersion), supported=\((try? DHSession.supportedVersionWithin(majorVersion: offeredVersion).rawValue) ?? nil), unsupported-common=\(newLocalVersion)"
                )
            }
            
            // The applied version is not allowed to be greater than what we support (as it depends
            // on what we have offered in a previous message).
            appliedVersion = rawAppliedVersion
            let supportedVersionWithin = try DHSession.supportedVersionWithin(majorVersion: offeredVersion).rawValue
            
            if appliedVersion == nil || rawAppliedVersion.rawValue > supportedVersionWithin {
                throw RejectMessageError
                    .rejectMessageError(
                        description: "Unsupported applied FS version in message: applied=\(rawAppliedVersion), supported=\(supportedVersionWithin)"
                    )
            }
            // Determine versions to be committed as the new bottom line for incoming and outgoing
            // FS encapsulated messages.
            pendingDHVersions = DHVersions.updated(local: newLocalVersion, remote: appliedVersion!)
        }
        
        return ProcessedVersions(
            offeredVersion: offeredVersion,
            appliedVersion: appliedVersion!,
            pending4DHVersion: pendingDHVersions
        )
    }
    
    // Update the versions with the processed versions returned from `processIncomingMessageVersion`.
    // Returns the updated versions snapshot containing before and after versions, if any have been updated.
    func commitVersion(processedVersions: ProcessedVersions) -> UpdatedVersionsSnapshot? {
        guard let pending4DHVersion = processedVersions.pending4DHVersion else {
            return nil
        }
        
        guard let current4DHVersions else {
            DDLogError(
                "[ForwardSecurity] Expected local/remote 4DH versions to exist, id=\(id), state=\(String(describing: try? state))"
            )
            return nil
        }
        
        // Check if we need to update the versions
        var needsUpdate = false
        if pending4DHVersion.local != current4DHVersions.local {
            DDLogVerbose(
                "[ForwardSecurity] Updated local/outgoing message version ({\(current4DHVersions.local)} -> {\(String(describing: processedVersions.pending4DHVersion?.local))}, id={\(id)})"
            )
            needsUpdate = true
        }
        if pending4DHVersion.remote != current4DHVersions.remote {
            DDLogVerbose(
                "[ForwardSecurity] Updated remote/incoming message version ({\(current4DHVersions.remote)} -> {\(String(describing: processedVersions.pending4DHVersion?.remote))}, id={\(id)})"
            )
            needsUpdate = true
        }
        
        guard needsUpdate else {
            DDLogVerbose("[ForwardSecurity] \(#function) Versions don't need update")
            return nil
        }
        
        DDLogNotice(
            "[ForwardSecurity] \(#function) Commit version update from \(self.current4DHVersions?.description ?? "nil") to \(pending4DHVersion.description)"
        )
        let updatedVersion = UpdatedVersionsSnapshot(before: current4DHVersions, after: pending4DHVersion)
        self.current4DHVersions = pending4DHVersion
        return updatedVersion
    }
    
    private func initKDF2DH(dhStaticStatic: Data, dhStaticEphemeral: Data, peer: Bool) {
        // We can feed the combined 64 bytes directly into BLAKE2b
        let kdf = ThreemaKDF(personal: DHSession.kdfPersonal)
        if peer {
            let peerK0 = kdf.deriveKey(
                salt: DHSession.keSalt2DHPrefix + peerIdentity,
                key: dhStaticStatic + dhStaticEphemeral
            )!
            peerRatchet2DH = KDFRatchet(counter: 1, initialChainKey: peerK0)
        }
        else {
            let myK0 = kdf.deriveKey(
                salt: DHSession.keSalt2DHPrefix + myIdentity,
                key: dhStaticStatic + dhStaticEphemeral
            )!
            myRatchet2DH = KDFRatchet(counter: 1, initialChainKey: myK0)
        }
    }
    
    private func initKDF4DH(
        dhStaticStatic: Data,
        dhStaticEphemeral: Data,
        dhEphemeralStatic: Data,
        dhEphemeralEphemeral: Data
    ) {
        // The combined 128 bytes need to be hashed with plain BLAKE2b (512 bit output) first
        let intermediateHash = ThreemaKDF
            .hash(
                input: dhStaticStatic + dhStaticEphemeral + dhEphemeralStatic + dhEphemeralEphemeral,
                outputLen: .b64
            )!
        
        let kdf = ThreemaKDF(personal: DHSession.kdfPersonal)
        let myK = kdf.deriveKey(salt: DHSession.keSalt4DHPrefix + myIdentity, key: intermediateHash)!
        let peerK = kdf.deriveKey(salt: DHSession.keSalt4DHPrefix + peerIdentity, key: intermediateHash)!
        
        myRatchet4DH = KDFRatchet(counter: 1, initialChainKey: myK)
        peerRatchet4DH = KDFRatchet(counter: 1, initialChainKey: peerK)
    }
    
    private func completeKeyExchange(
        peerEphemeralPublicKey: Data,
        peerPublicKey: Data,
        identityStore: MyIdentityStoreProtocol
    ) -> Data {
        var myEphemeralPublicKeyLocal: NSData?
        var myEphemeralPrivateKeyLocal: NSData?
        NaClCrypto.shared().generateKeyPairPublicKey(&myEphemeralPublicKeyLocal, secretKey: &myEphemeralPrivateKeyLocal)
        
        // Derive 2DH root key
        let dhStaticStatic = identityStore.sharedSecret(withPublicKey: peerPublicKey)!
        let dhStaticEphemeral = identityStore.sharedSecret(withPublicKey: peerEphemeralPublicKey)!
        initKDF2DH(dhStaticStatic: dhStaticStatic, dhStaticEphemeral: dhStaticEphemeral, peer: true)
        
        // Derive 4DH root key
        let dhEphemeralStatic = NaClCrypto.shared()
            .sharedSecret(forPublicKey: peerPublicKey, secretKey: myEphemeralPrivateKeyLocal! as Data)!
        let dhEphemeralEphemeral = NaClCrypto.shared()
            .sharedSecret(forPublicKey: peerEphemeralPublicKey, secretKey: myEphemeralPrivateKeyLocal! as Data)!
        initKDF4DH(
            dhStaticStatic: dhStaticStatic,
            dhStaticEphemeral: dhStaticEphemeral,
            dhEphemeralStatic: dhEphemeralStatic,
            dhEphemeralEphemeral: dhEphemeralEphemeral
        )
        
        return myEphemeralPublicKeyLocal! as Data
    }
    
    /// Older clients may not provide a version range. Map min and max to V1.0 in that case.
    /// - Parameter remoteVersion: The remote version as sent by the peer
    /// - Returns: A filled in
    private static func actualRemoteVersion(from remoteVersion: CspE2eFs_VersionRange) -> CspE2eFs_VersionRange {
        // Older clients may not provide a version range. Map min and max to V1.0 in that case.
        if remoteVersion.min == 0, remoteVersion.max == 0 {
            var initializedVersion = CspE2eFs_VersionRange()
            initializedVersion.min = UInt32(CspE2eFs_Version.v10.rawValue)
            initializedVersion.max = UInt32(CspE2eFs_Version.v10.rawValue)
            
            return initializedVersion
        }
        else {
            return remoteVersion
        }
    }
    
    /// Are these two session identical? (Not only if they are the same session (this is would be given by `id`,
    /// `myIdentity` and `peerIdentity`)).
    public static func == (lhs: DHSession, rhs: DHSession) -> Bool {
        let directComparison = lhs.id == rhs.id &&
            lhs.myIdentity == rhs.myIdentity &&
            lhs.peerIdentity == rhs.peerIdentity &&
            lhs.myEphemeralPublicKey == rhs.myEphemeralPublicKey &&
            lhs.myRatchet2DH == rhs.myRatchet2DH &&
            lhs.myRatchet4DH == rhs.myRatchet4DH &&
            lhs.peerRatchet2DH == rhs.peerRatchet2DH &&
            lhs.peerRatchet4DH == rhs.peerRatchet4DH &&
            lhs.current4DHVersions == rhs.current4DHVersions &&
            lhs.newSessionCommitted == rhs.newSessionCommitted
        
        // As the stored date loses some precision we only compare it down to the second
        if let lhsLastMessageSent = lhs.lastMessageSent, let rhsLastMessageSent = rhs.lastMessageSent {
            if abs(lhsLastMessageSent.distance(to: rhsLastMessageSent)) < 1 {
                return directComparison
            }
            else {
                return false
            }
        }
        else if lhs.lastMessageSent == nil, rhs.lastMessageSent == nil {
            return directComparison
        }
        else {
            return false
        }
    }
    
    public var description: String {
        "DH session \(id) with \(peerIdentity) (\(myRatchet4DH != nil ? "4DH" : "2DH") (4dh-versions=\(current4DHVersions?.description ?? "nil"))"
    }
}
