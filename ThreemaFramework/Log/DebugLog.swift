//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2025 Threema GmbH
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

public final class DebugLog: NSObject {

    @available(swift, obsoleted: 1.0, renamed: "logAppVersion", message: "Only use from Objective-C")
    @objc public static func logAppVersion() {
        logAppVersion()
    }

    public static func logAppVersion(
        file: StaticString = #file,
        function: StaticString = #function,
        line: UInt = #line
    ) {
        DDLogNotice(
            "[Config] App Version: \(ThreemaUtility.clientVersionWithMDM)",
            file: file,
            function: function,
            line: line
        )
    }

    @available(swift, obsoleted: 1.0, renamed: "logAppVersion", message: "Only use from Objective-C")
    @objc public static func logAppConfiguration() {
        logAppConfiguration()
    }

    public static func logAppConfiguration(
        file: StaticString = #file,
        function: StaticString = #function,
        line: UInt = #line
    ) {
        logRemoteSecretConfiguration(file: file, function: function, line: line)
        logMultiDeviceConfiguration(file: file, function: function, line: line)
    }

    @available(swift, obsoleted: 1.0, renamed: "logRemoteSecretConfiguration", message: "Only use from Objective-C")
    @objc public static func logRemoteSecretConfiguration() {
        logRemoteSecretConfiguration()
    }

    public static func logRemoteSecretConfiguration(
        file: StaticString = #file,
        function: StaticString = #function,
        line: UInt = #line
    ) {
        DDLogNotice(
            "[Config] Remote Secret: \(AppLaunchManager.isRemoteSecretEnabled)",
            file: file,
            function: function,
            line: line
        )
    }

    @available(swift, obsoleted: 1.0, renamed: "logMultiDeviceConfiguration", message: "Only use from Objective-C")
    @objc public static func logMultiDeviceConfiguration() {
        logMultiDeviceConfiguration()
    }

    public static func logMultiDeviceConfiguration(
        file: StaticString = #file,
        function: StaticString = #function,
        line: UInt = #line
    ) {
        DDLogNotice(
            "[Config] Multi-Device: \(UserSettings.shared().enableMultiDevice)",
            file: file,
            function: function,
            line: line
        )
    }

    @available(swift, obsoleted: 1.0, renamed: "logMessage", message: "Only use from Objective-C")
    @objc(logBoxedMessage:isIncoming:errorDescription:) static func log(
        _ boxedMessage: BoxedMessage,
        isIncoming: Bool,
        errorDescription: String?
    ) {
        log(boxedMessage, isIncoming: isIncoming, errorDescription: errorDescription)
    }

    static func log(
        _ boxedMessage: BoxedMessage,
        isIncoming: Bool,
        errorDescription: String?,
        file: StaticString = #file,
        function: StaticString = #function,
        line: UInt = #line
    ) {
        guard UserSettings.shared().validationLogging else {
            return
        }

        var message = "\(isIncoming ? "Incoming" : "Outgoing") boxed message \(boxedMessage.loggingDescription)"
        message += " from=\(boxedMessage.fromIdentity ?? "unknown") to=\(boxedMessage.toIdentity ?? "unknown")"
        message += " date=\(string(from: boxedMessage.date) ?? "unknown")"

        if let errorDescription {
            message += " error: \(errorDescription)"
        }

        DDLogNotice("[Messaging] \(message)", file: file, function: function, line: line)
    }

    @available(swift, obsoleted: 1.0, renamed: "logMessage", message: "Only use from Objective-C")
    @objc(logAbstractMessage:isIncoming:) static func log(_ abstractMessage: AbstractMessage, isIncoming: Bool) {
        log(abstractMessage, isIncoming: isIncoming)
    }

    @available(swift, obsoleted: 1.0, renamed: "logMessage", message: "Only use from Objective-C")
    @objc(logAbstractMessage:isIncoming:errorDescription:) static func log(
        _ abstractMessage: AbstractMessage,
        isIncoming: Bool,
        errorDescription: String
    ) {
        log(abstractMessage, isIncoming: isIncoming, errorDescription: errorDescription)
    }

    static func log(
        _ abstractMessage: AbstractMessage,
        isIncoming: Bool,
        errorDescription: String? = nil,
        file: StaticString = #file,
        function: StaticString = #function,
        line: UInt = #line
    ) {
        guard UserSettings.shared().validationLogging, abstractMessage.type() != MSGTYPE_TYPING_INDICATOR else {
            return
        }

        let type: String
        var details = ""

        switch Int32(abstractMessage.type()) {
        case MSGTYPE_TEXT:
            type = "TEXT"
        case MSGTYPE_IMAGE:
            type = "IMAGE"
        case MSGTYPE_LOCATION:
            type = "LOCATION"
        case MSGTYPE_VIDEO:
            type = "VIDEO"
        case MSGTYPE_AUDIO:
            type = "AUDIO"
        case MSGTYPE_BALLOT_CREATE:
            type = "BALLOT_CREATE"
        case MSGTYPE_BALLOT_VOTE:
            type = "BALLOT_VOTE"
        case MSGTYPE_FILE:
            type = "FILE"
        case MSGTYPE_CONTACT_SET_PHOTO:
            type = "CONTACT_SET_PHOTO"
        case MSGTYPE_CONTACT_DELETE_PHOTO:
            type = "CONTACT_DELETE_PHOTO"
        case MSGTYPE_CONTACT_REQUEST_PHOTO:
            type = "CONTACT_REQUEST_PHOTO"
        case MSGTYPE_GROUP_TEXT:
            type = "GROUP_TEXT"
        case MSGTYPE_GROUP_LOCATION:
            type = "GROUP_LOCATION"
        case MSGTYPE_GROUP_IMAGE:
            type = "GROUP_IMAGE"
        case MSGTYPE_GROUP_VIDEO:
            type = "GROUP_VIDEO"
        case MSGTYPE_GROUP_AUDIO:
            type = "GROUP_AUDIO"
        case MSGTYPE_GROUP_FILE:
            type = "GROUP_FILE"
        case MSGTYPE_GROUP_CREATE:
            type = "GROUP_CREATE"
        case MSGTYPE_GROUP_RENAME:
            type = "GROUP_RENAME"
        case MSGTYPE_GROUP_LEAVE:
            type = "GROUP_LEAVE"
        case MSGTYPE_GROUP_SET_PHOTO:
            type = "GROUP_SET_PHOTO"
        case MSGTYPE_GROUP_REQUEST_SYNC:
            type = "GROUP_REQUEST_SYNC"
        case MSGTYPE_GROUP_BALLOT_CREATE:
            type = "GROUP_BALLOT_CREATE"
        case MSGTYPE_GROUP_BALLOT_VOTE:
            type = "GROUP_BALLOT_VOTE"
        case MSGTYPE_GROUP_DELETE_PHOTO:
            type = "GROUP_DELETE_PHOTO"
        case MSGTYPE_VOIP_CALL_OFFER:
            type = "CALL_OFFER"
            if let data = (abstractMessage as? BoxVoIPCallOfferMessage)?.jsonData,
               let json = try? JSONSerialization.jsonObject(with: data) {
                details = "json=\(json)"
            }
        case MSGTYPE_VOIP_CALL_ANSWER:
            type = "CALL_ANSWER"
            if let data = (abstractMessage as? BoxVoIPCallAnswerMessage)?.jsonData,
               let json = try? JSONSerialization.jsonObject(with: data) {
                details = "json=\(json)"
            }
        case MSGTYPE_VOIP_CALL_ICECANDIDATE:
            type = "CALL_ICECANDIDATE"
            if let data = (abstractMessage as? BoxVoIPCallIceCandidatesMessage)?.jsonData,
               let json = try? JSONSerialization.jsonObject(with: data) {
                details = "json=\(json)"
            }
        case MSGTYPE_VOIP_CALL_HANGUP:
            type = "CALL_HANGUP"
            if let data = (abstractMessage as? BoxVoIPCallHangupMessage)?.jsonData,
               let json = try? JSONSerialization.jsonObject(with: data) {
                details = "json=\(json)"
            }
        case MSGTYPE_VOIP_CALL_RINGING:
            type = "CALL_RINGING"
            if let data = (abstractMessage as? BoxVoIPCallRingingMessage)?.jsonData,
               let json = try? JSONSerialization.jsonObject(with: data) {
                details = "json=\(json)"
            }
        case MSGTYPE_DELIVERY_RECEIPT:
            type = "DELIVERY_RECEIPT"
            if let deliveryReceiptMessage = abstractMessage as? DeliveryReceiptMessage {
                details += "receiptType=\(deliveryReceiptMessage.receiptType)"

                if let receiptMessageIDs = deliveryReceiptMessage.receiptMessageIDs,
                   !receiptMessageIDs.isEmpty {
                    details +=
                        " receiptMessageIDs=\(receiptMessageIDs.compactMap { ($0 as? Data)?.hexString }.joined(separator: ","))"
                }
            }
        case MSGTYPE_GROUP_DELIVERY_RECEIPT:
            type = "GROUP_DELIVERY_RECEIPT"
            if let groupDeliveryReceiptMessage = abstractMessage as? GroupDeliveryReceiptMessage {
                details += "receiptType=\(groupDeliveryReceiptMessage.receiptType)"

                if let receiptMessageIDs = groupDeliveryReceiptMessage.receiptMessageIDs,
                   !receiptMessageIDs.isEmpty {
                    details +=
                        " receiptMessageIDs=\(receiptMessageIDs.compactMap { ($0 as? Data)?.hexString }.joined(separator: ","))"
                }
            }
        case MSGTYPE_REACTION:
            type = "REACTION"
        case MSGTYPE_GROUP_REACTION:
            type = "GROUP_REACTION"
        case MSGTYPE_TYPING_INDICATOR:
            type = "TYPING_INDICATOR"
        case MSGTYPE_EDIT:
            type = "EDIT"
        case MSGTYPE_DELETE:
            type = "DELETE"
        case MSGTYPE_GROUP_EDIT:
            type = "GROUP_EDIT"
        case MSGTYPE_GROUP_DELETE:
            type = "GROUP_DELETE"
        case MSGTYPE_FORWARD_SECURITY:
            type = "FORWARD_SECURITY"
        case MSGTYPE_AUTH_TOKEN:
            type = "AUTH_TOKEN"
        case MSGTYPE_GROUP_CALL_START:
            type = "GROUP_CALL_START"
        case MSGTYPE_EMPTY:
            type = "EMPTY"
        default:
            fatalError("\(#function): Unsupported message type \(abstractMessage.type())")
        }

        var message =
            "\(isIncoming ? "Incoming" : "Outgoing") abstract message \(type) \(abstractMessage.loggingDescription)"
        message += " from=\(abstractMessage.fromIdentity ?? "unknown") to=\(abstractMessage.toIdentity ?? "unknown")"
        message += " date=\(string(from: abstractMessage.date) ?? "unknown")"

        if !details.isEmpty {
            message += " \(details)"
        }

        if let errorDescription {
            message += " error: \(errorDescription)"
        }

        DDLogNotice("[Messaging] \(message)", file: file, function: function, line: line)
    }

    // MARK: - Private functions

    private static func string(from date: Date?) -> String? {
        guard let date else {
            return nil
        }

        let dateFormatter = Foundation.DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return dateFormatter.string(from: date)
    }
}
