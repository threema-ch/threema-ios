//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024 Threema GmbH
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

/// Obj-C wrapper for `ForwardSecuritySessionTerminator`
@available(*, deprecated, renamed: "ForwardSecuritySessionTerminator", message: "Only use from Objective-C")
class ForwardSecuritySessionTerminatorObjC: NSObject {
    
    /// Terminate all sessions with contact with the reason "disabled by remote"
    ///
    /// - Note: You are responsible that this is called on the correct queue for `contact` and that you save `contact`
    ///         afterwards.
    ///
    /// - Parameters:
    ///   - identity: Identity to terminate sessions for
    ///   - completion: Called on successful termination. Returns `true` if any session was terminated
    ///   - error: Called if termination fails
    @objc static func terminateAllSessionsWithDisabledByRemote(
        for contact: ContactEntity,
        completion: (Bool) -> Void,
        error: (Error) -> Void
    ) {
        do {
            let forwardSecuritySessionTerminator = try ForwardSecuritySessionTerminator()
            
            let result = try forwardSecuritySessionTerminator.terminateAllSessions(
                with: contact,
                cause: .disabledByRemote
            )
            
            completion(result)
        }
        catch let caughtError {
            error(caughtError)
        }
    }
}
