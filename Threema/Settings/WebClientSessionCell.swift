//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2024 Threema GmbH
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

import Foundation
import ThreemaMacros

class WebClientSessionCell: UITableViewCell {
    @IBOutlet var browserIcon: UIImageView!
    @IBOutlet var loadingIndicator: UIActivityIndicatorView!
    @IBOutlet var browserLabel: UILabel!
    @IBOutlet var infoLabel: UILabel!
        
    var webClientSession: WebClientSessionEntity!
    var viewController: ThreemaWebViewController!
    
    func setupCell() {
        loadingIndicator.isHidden = true
        loadingIndicator.stopAnimating()
        loadingIndicator.style = Colors.activityIndicatorViewStyle
        
        if webClientSession.name != nil {
            browserLabel.text = webClientSession.name
        }
        else {
            browserLabel.text = #localize("webClientSession_unnamed")
        }
        
        let info: String
        let localizedSavedString = webClientSession.permanent.boolValue ? BundleUtil
            .localizedString(forKey: "webClientSession_saved") : BundleUtil
            .localizedString(forKey: "webClientSession_notSaved")
        if let lastConnenction = webClientSession.lastConnection {
            info = """
                \(#localize("webClientSession_lastUse")): \(DateFormatter
                .shortStyleDateTime(lastConnenction))
                \(localizedSavedString)
                """
        }
        else {
            info = "\n\(localizedSavedString)"
        }
        infoLabel.text = info

        switch webClientSession.browserName {
        case "chrome":
            browserIcon.image = UIImage(named: "Chrome")
        case "safari":
            browserIcon.image = UIImage(named: "Safari")
        case "firefox":
            browserIcon.image = UIImage(named: "FireFox")
        case "edge":
            browserIcon.image = UIImage(named: "Edge")
        case "opera":
            browserIcon.image = UIImage(named: "Opera")
        case "macosThreemaDesktop", "win32ThreemaDesktop", "linuxThreemaDesktop":
            browserIcon.image = UIImage(systemName: "desktopcomputer")
        default:
            if webClientSession.isConnecting {
                browserIcon.image = nil
                loadingIndicator.startAnimating()
                loadingIndicator.isHidden = false
            }
            else {
                let config = UIImage.SymbolConfiguration(paletteColors: [Colors.white, Colors.red])
                browserIcon.image = UIImage(systemName: "exclamationmark.circle.fill")?.withConfiguration(config)
            }
        }
        
        var cellAccessibility: String! = browserLabel.text
        var cellAccessibilityActions = [UIAccessibilityCustomAction]()
        cellAccessibility.append(". ")
        cellAccessibility.append(info)
        
        if (webClientSession.active?.boolValue)! {
            accessoryType = .none
            accessoryView = UIImageView(
                image: UIImage(systemName: "antenna.radiowaves.left.and.right.circle.fill")?
                    .applying(textStyle: .title2, symbolScale: .large)
            )
            accessoryView?.tintColor = .primary
            cellAccessibility.append(". ")
            cellAccessibility.append(#localize("status_loggedIn"))
            cellAccessibilityActions.append(UIAccessibilityCustomAction(
                name: #localize("webClientSession_actionSheet_stopSession"),
                target: self,
                selector: #selector(handleStopSession)
            ))
        }
        else {
            accessoryView = nil
            accessoryType = UIAccessibility.isVoiceOverRunning ? .none : .disclosureIndicator
        }
        accessibilityLabel = cellAccessibility
        
        cellAccessibilityActions.append(UIAccessibilityCustomAction(
            name: #localize("webClientSession_actionSheet_renameSession"),
            target: self,
            selector: #selector(handleRenameSession)
        ))
        accessibilityCustomActions = cellAccessibilityActions
    }
    
    @objc private func handleStopSession() {
        ValidationLogger.shared().logString("[Threema Web] Disconnect webclient userStoppedSession")
        WCSessionManager.shared.stopSession(webClientSession)
    }
    
    @objc private func handleRenameSession() {
        let renameAlert = UIAlertController(
            title: #localize("webClientSession_sessionName"),
            message: nil,
            preferredStyle: .alert
        )
        renameAlert.addTextField { textfield in
            if let sessionName = self.webClientSession.name {
                textfield.text = sessionName
            }
            else {
                textfield.placeholder = #localize("webClientSession_unnamed")
            }
        }
        let saveAction = UIAlertAction(title: #localize("save"), style: .default) { _ in
            let textField = renameAlert.textFields![0]
            WebClientSessionStore.shared.updateWebClientSession(
                session: self.webClientSession,
                sessionName: textField.text
            )
        }
        renameAlert.addAction(saveAction)
        
        let cancelAction = UIAlertAction(title: #localize("cancel"), style: .cancel)
        renameAlert.addAction(cancelAction)
        
        viewController.present(renameAlert, animated: true)
    }
    
    @objc private func handleDeleteSession() {
        WCSessionManager.shared.stopAndDeleteSession(webClientSession)
        
        if viewController.fetchedResultsController!.fetchedObjects!.isEmpty {
            UserSettings.shared().threemaWeb = false
        }
    }
}
