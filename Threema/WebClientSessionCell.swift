//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2020 Threema GmbH
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

class WebClientSessionCell: UITableViewCell {
    @IBOutlet weak var browserIcon: UIImageView!
    @IBOutlet weak var loadingIndicator: UIActivityIndicatorView!
    @IBOutlet weak var browserLabel: UILabel!
    @IBOutlet weak var infoLabel: UILabel!
        
    var webClientSession: WebClientSession!
    var viewController: ThreemaWebViewController!
    
    func setupCell() {
        loadingIndicator.isHidden = true
        loadingIndicator.stopAnimating()
       
        switch Colors.getTheme() {
        case ColorThemeDark, ColorThemeDarkWork:
            loadingIndicator.style = .white
        case ColorThemeLight, ColorThemeLightWork, ColorThemeUndefined:
            loadingIndicator.style = .gray
        default:
            loadingIndicator.style = .gray
        }
        
        if webClientSession.name != nil {
            browserLabel.text = webClientSession.name
        } else {
            browserLabel.text = NSLocalizedString("webClientSession_unnamed", comment: "")
        }
        
        var info: String?
        if let lastConenction = webClientSession.lastConnection {
            info = String(format: "%@: %@\n%@", NSLocalizedString("webClientSession_lastUse", comment: ""), DateFormatter.shortStyleDateTime(lastConenction), (webClientSession.permanent?.boolValue)! ? NSLocalizedString("webClientSession_saved", comment: "") : NSLocalizedString("webClientSession_notSaved", comment: ""))
            
        } else {
            info = String(format: "\n%@", (webClientSession.permanent?.boolValue)! ? NSLocalizedString("webClientSession_saved", comment: "") : NSLocalizedString("webClientSession_notSaved", comment: ""))
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
        default:
            if webClientSession.isConnecting {
                browserIcon.image = nil
                loadingIndicator.startAnimating()
                loadingIndicator.isHidden = false
            } else {
                browserIcon.image = UIImage(named: "ExclamationMark")
            }
        }
        
        var cellAccessibility: String! = browserLabel.text
        var cellAccessibilityActions = [UIAccessibilityCustomAction]()
        if let sessionInfo = info {
            cellAccessibility.append(". ")
            cellAccessibility.append(sessionInfo)
        }
        
        if (webClientSession.active?.boolValue)! {
            accessoryType = .none
            accessoryView = UIImageView(image: UIImage(named: "WebClientConnection", in: Colors.main()))
            cellAccessibility.append(". ")
            cellAccessibility.append(NSLocalizedString("status_loggedin", comment: ""))
            cellAccessibilityActions.append(UIAccessibilityCustomAction(name: NSLocalizedString("webClientSession_actionSheet_stopSession", comment: ""), target: self, selector: #selector(handleStopSession)))
        } else {
            accessoryView = nil
            accessoryType = UIAccessibility.isVoiceOverRunning ? .none : .disclosureIndicator
        }
        self.accessibilityLabel = cellAccessibility
        
        cellAccessibilityActions.append(UIAccessibilityCustomAction(name: NSLocalizedString("webClientSession_actionSheet_renameSession", comment: ""), target: self, selector: #selector(handleRenameSession)))
        self.accessibilityCustomActions = cellAccessibilityActions
    }
    
    @objc private func handleStopSession() {
        ValidationLogger.shared().logString("Threema Web: Disconnect webclient userStoppedSession")
        WCSessionManager.shared.stopSession(webClientSession)
    }
    
    @objc private func handleRenameSession() {
        let renameAlert = UIAlertController(title: NSLocalizedString("webClientSession_sessionName", comment: ""), message: nil, preferredStyle: .alert)
        renameAlert.addTextField { textfield in
            if let sessionName = self.webClientSession.name {
                textfield.text = sessionName
            } else {
                textfield.placeholder = NSLocalizedString("webClientSession_unnamed", comment: "")
            }
        }
        let saveAction = UIAlertAction(title: NSLocalizedString("save", comment: ""), style: .default) { alertAction in
            let textField = renameAlert.textFields![0]
            WebClientSessionStore.shared.updateWebClientSession(session: self.webClientSession, sessionName: textField.text)
        }
        renameAlert.addAction(saveAction)
        
        let cancelAction = UIAlertAction(title: NSLocalizedString("cancel", comment: ""), style: .cancel)
        renameAlert.addAction(cancelAction)
        
        viewController.present(renameAlert, animated: true)
    }
    
    @objc private func handleDeleteSession() {
        WCSessionManager.shared.stopAndDeleteSession(webClientSession)
        
        if viewController.fetchedResultsController!.fetchedObjects!.count == 0 {
            UserSettings.shared().threemaWeb = false
        }
    }
}
