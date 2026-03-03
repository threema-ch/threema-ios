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

import Observation
import ThreemaEssentials
import ThreemaMacros

@MainActor
@Observable
final class QRCodeScannerViewModel {
    var title = ""
    var info = ""

    var alert: AlertData?
    var shouldResume = false

    // MARK: - Public

    enum QRCodeDecodeMode {
        case identity
        case identityBackup
        case multiDeviceLink
        case webSession
        case plainText
    }

    enum QRCodeResult {
        case identityContact(identity: ThreemaIdentity, publicKey: Data, expirationDate: Date?)
        case identityLink(url: URL)
        case multiDeviceLink(urlSafeBase64: String)
        case webSession(session: [String: Any], authToken: Data)
        case plainText(String)
    }

    struct AlertData: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    let audioSessionManager: AudioSessionManagerProtocol
    let systemFeedbackManager: SystemFeedbackManagerProtocol
    let systemPermissionsManager: SystemPermissionsManagerProtocol

    var onCompletion: ((QRCodeResult) -> Void)?
    var onCancel: (() -> Void)?
    var onDisappear: (() -> Void)?

    // MARK: - Private

    private let mode: QRCodeDecodeMode
    private let parser = QRCodeParser()
    private let appName = TargetManager.appName

    // MARK: - Lifecycle

    init(
        mode: QRCodeDecodeMode,
        audioSessionManager: AudioSessionManagerProtocol,
        systemFeedbackManager: SystemFeedbackManagerProtocol,
        systemPermissionsManager: SystemPermissionsManagerProtocol
    ) {
        self.mode = mode
        self.audioSessionManager = audioSessionManager
        self.systemFeedbackManager = systemFeedbackManager
        self.systemPermissionsManager = systemPermissionsManager
    }

    func onViewAppear() {
        updateTitleAndSubtitle()
    }

    func onViewDisappear() {
        onDisappear?()
    }

    func handleResult(_ result: String?) {
        guard let result, !result.isEmpty else {
            alertUnrecognizedQRCode()
            return
        }

        // For plain text and identity backup code no parsing is needed, return early
        if mode == .plainText || mode == .identityBackup {
            systemFeedbackManager.playSuccessSound()
            onCompletion?(.plainText(result))
            return
        }

        // Parse QR code for known codes
        guard let parserResult = parser.parse(result) else {
            alertUnrecognizedQRCode()
            return
        }

        let handled: Bool

        switch (mode, parserResult) {
        case let (.identity, .identityContact(id, key, date)):
            onCompletion?(.identityContact(identity: id, publicKey: key, expirationDate: date))
            handled = true

        case let (.identity, .identityLink(url)):
            systemFeedbackManager.playSuccessSound()
            onCompletion?(.identityLink(url: url))
            handled = true

        case let (.multiDeviceLink, .multiDeviceLink(url)):
            systemFeedbackManager.playSuccessSound()
            onCompletion?(.multiDeviceLink(urlSafeBase64: url))
            handled = true

        case let (.webSession, .webSession(session, authToken)):
            onCompletion?(.webSession(session: session, authToken: authToken))
            handled = true

        default:
            handled = false
        }

        if !handled {
            alertWrongQRCode(result: parserResult)
        }
    }

    func cancelButtonTapped() {
        onCancel?()
    }

    func alertOKButtonTapped() {
        alert = nil
        shouldResume = true
    }

    // MARK: - Helpers

    private func updateTitleAndSubtitle() {
        title = #localize("qr_code_scanner_title")

        switch mode {
        case .identity:
            info = #localize("qr_code_scanner_info_identity")

        case .identityBackup:
            info = #localize("qr_code_scanner_info_identity_backup")

        case .multiDeviceLink:
            info = .localizedStringWithFormat(#localize("qr_code_scanner_info_multi_device_join_link"), appName)

        case .webSession:
            info = #localize("qr_code_scanner_info_web_session")

        case .plainText:
            info = #localize("qr_code_scanner_info_plain_text")
        }
    }

    private func alertUnrecognizedQRCode() {
        showAlert(
            title: #localize("qr_code_scanner_unrecognized_code_error_title"),
            message: #localize("qr_code_scanner_unrecognized_code_error_message")
        )
    }

    private func alertWrongQRCode(result: QRCodeParserResult) {
        let message =
            switch result {
            case .identityContact:
                #localize("qr_code_scanner_wrong_identity_code_error_message")

            case .identityLink:
                #localize("qr_code_scanner_wrong_identity_link_code_error_message")

            case .multiDeviceLink:
                String.localizedStringWithFormat(
                    #localize("qr_code_scanner_wrong_multi_device_join_link_code_error_message"), appName
                )

            case .webSession:
                #localize("qr_code_scanner_wrong_web_client_code_error_message")
            }
        showAlert(title: #localize("qr_code_scanner_error_title"), message: message)
    }

    private func showAlert(title: String, message: String) {
        alert = AlertData(title: title, message: message)
    }
}
