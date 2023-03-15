//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2023 Threema GmbH
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

class ChatSettingsViewController: ThemedTableViewController {
    
    @IBOutlet var wallpaperImageView: UIImageView!
    @IBOutlet var resetWallpaper: UILabel!
    
    @IBOutlet var biggerEmojiLabel: UILabel!
    @IBOutlet var biggerEmojiSwitch: UISwitch!
    
    private let businessInjector = BusinessInjector()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureCells()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateView()
    }
    
    // MARK: - Configuration
    
    private func configureCells() {
        // Loads wallpaper
        businessInjector.userSettings.checkWallpaper()
        
        resetWallpaper.text = BundleUtil.localizedString(forKey: "reset_wallpaper")
        resetWallpaper.textColor = .primary
        biggerEmojiLabel.text = BundleUtil.localizedString(forKey: "bigger_single_emojis")
        
        let deviceRatio = UIScreen.main.bounds.width / UIScreen.main.bounds.height
        wallpaperImageView.widthAnchor.constraint(equalTo: wallpaperImageView.heightAnchor, multiplier: deviceRatio)
            .isActive = true
        
        wallpaperImageView.contentMode = .scaleAspectFill
        wallpaperImageView.layer.borderColor = Colors.hairLine.cgColor
        wallpaperImageView.layer.borderWidth = 2.0
        wallpaperImageView.layer.cornerRadius = 20
        wallpaperImageView.layer.cornerCurve = .continuous
        
        biggerEmojiSwitch.isOn = !businessInjector.userSettings.disableBigEmojis
    }
    
    // MARK: - Update
    
    private func updateView() {
        
        guard businessInjector.userSettings.wallpaper != nil else {
            wallpaperImageView.image = nil
            wallpaperImageView.backgroundColor = nil
            if ThreemaApp.current == .threema || ThreemaApp.current == .red {
                var chatBackground = BundleUtil.imageNamed("ChatBackground")
                chatBackground = chatBackground?.withTint(Colors.backgroundChatLines)
                if let chatBack = chatBackground {
                    wallpaperImageView.backgroundColor = UIColor(patternImage: chatBack)
                }
            }
            return
        }
        wallpaperImageView.image = businessInjector.userSettings.wallpaper
    }
    
    // MARK: - Helper functions
    
    @IBAction func biggerEmojiChanged(_ sender: Any) {
        businessInjector.userSettings.disableBigEmojis = !biggerEmojiSwitch.isOn
    }
}

// MARK: - UITableViewDelegate

extension ChatSettingsViewController {
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 0, indexPath.row == 0 {
            return 300
        }
        return UITableView.automaticDimension
    }
    
    override func tableView(
        _ tableView: UITableView,
        willDisplay cell: UITableViewCell,
        forRowAt indexPath: IndexPath
    ) {
        // Workaround to have a full width separator line between wallpaper and reset button
        guard indexPath.section == 0, indexPath.row == 0 else {
            return
        }

        cell.preservesSuperviewLayoutMargins = false
        cell.separatorInset = .zero
        cell.layoutMargins = .zero
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 0 {
            if indexPath.row == 0 {
                let rect = tableView.rectForRow(at: indexPath)
                let picker = UIImagePickerController()
                picker.delegate = self
                ModalPresenter.present(picker, on: self, from: rect, in: view)
                picker.presentationController?.delegate = self
            }
            else if indexPath.row == 1 {
                businessInjector.userSettings.wallpaper = nil
                updateView()
                tableView.deselectRow(at: indexPath, animated: true)
            }
        }
    }
}

// MARK: - UIImagePickerControllerDelegate, UINavigationControllerDelegate

extension ChatSettingsViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
        if let image = info[.originalImage] as? UIImage {
            businessInjector.settingsStore.wallpaper = image
            updateView()
        }
        
        handlePickerFinished()
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        handlePickerFinished()
    }
    
    private func handlePickerFinished() {
        let indexPath = IndexPath(row: 0, section: 0)
        tableView.deselectRow(at: indexPath, animated: true)
        ModalPresenter.dismissPresentedController(on: self, animated: true)
    }
}

// MARK: - UIAdaptivePresentationControllerDelegate

extension ChatSettingsViewController: UIAdaptivePresentationControllerDelegate {
    func presentationControllerWillDismiss(_ presentationController: UIPresentationController) {
        let indexPath = IndexPath(row: 0, section: 0)
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
