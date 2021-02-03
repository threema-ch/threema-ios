//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2021 Threema GmbH
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

import UIKit
import ThreemaFramework
import QuartzCore

class MeContactDetailsViewController: ThemedTableViewController {
    
    @IBOutlet weak var headerView: UIView!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var threemaTypeIcon: UIImageView!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
                
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        navigationController?.interactivePopGestureRecognizer?.delegate = nil
        
        NotificationCenter.default.addObserver(self, selector: #selector(colorThemeChanged(notification:)), name: NSNotification.Name(rawValue: kNotificationColorThemeChanged), object: nil)
        let tapRecognizer = UITapGestureRecognizer.init(target: self, action: #selector(tappedImage))
        imageView.addGestureRecognizer(tapRecognizer)
        
        threemaTypeIcon.image = Utils.threemaTypeIcon()
        
        setupColors()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        view.alpha = 1.0
        
        updateView()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if (navigationController?.isNavigationBarHidden)! {
            navigationController?.isNavigationBarHidden = false
        }
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        let fontDescriptor:UIFontDescriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .title3)
        let size = fontDescriptor.pointSize
        nameLabel.font = UIFont.boldSystemFont(ofSize: size)
    }
    
    func setupColors() {
        nameLabel.textColor = Colors.fontNormal()
        nameLabel.shadowColor = nil
    }
    
    func updateView() {
        var name = MyIdentityStore.shared().pushFromName
        if name == nil {
            name = MyIdentityStore.shared().identity
        }
        title = String.init(format:"@%@", BundleUtil.localizedString(forKey: "me"))
        nameLabel.text = name
        headerView.accessibilityLabel = name
        
        if let profilePicture = MyIdentityStore.shared().profilePicture,
            profilePicture["ProfilePicture"] != nil {
            imageView.image = UIImage.init(data: profilePicture["ProfilePicture"] as! Data)
            imageView.contentMode = .scaleAspectFill
            imageView.layer.masksToBounds = true
            imageView.layer.cornerRadius = imageView.bounds.size.width / 2
        } else {
            imageView.image = AvatarMaker.shared()?.unknownPersonImage()
        }
        imageView.accessibilityLabel = NSLocalizedString("my_profilepicture", comment: "")
        
        threemaTypeIcon.isHidden = !LicenseStore.requiresLicenseKey()
                
        tableView.reloadData()
    }
    
    
    // MARK: - Table view data source
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 3
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.row == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "IdentityCell", for: indexPath)
            let label = cell.viewWithTag(100) as! UILabel
            label.text = MyIdentityStore.shared().identity
            return cell
        }
        else if indexPath.row == 1 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "PublicNicknameCell", for: indexPath)
            let label = cell.viewWithTag(101) as! UILabel
            var name = MyIdentityStore.shared().pushFromName
            if name == nil {
                name = MyIdentityStore.shared().identity
            }
            label.text = name
            return cell
        }
        else {
            let cell:KeyFingerprintCell = tableView.dequeueReusableCell(withIdentifier: "KeyFingerprintCell", for: indexPath) as! KeyFingerprintCell
            cell.fingerprintValueLabel.text = CryptoUtils.fingerprint(forPublicKey: MyIdentityStore.shared().publicKey)
            return cell
        }
    }

    
    // MARK: - GestureRecognizer
    
    @objc func tappedImage() {
        
        if let profilePicture = MyIdentityStore.shared().profilePicture,
            profilePicture["ProfilePicture"] != nil {
            let image = UIImage.init(data: profilePicture["ProfilePicture"] as! Data)
            if image != nil {
                let imageController: FullscreenImageViewController = FullscreenImageViewController.init(for: image)
                if UIDevice.current.userInterfaceIdiom == .pad {
                    let nav: ModalNavigationController = ModalNavigationController.init(rootViewController: imageController)
                    nav.showDoneButton = true
                    nav.showFullScreenOnIPad = true
                    self.present(nav, animated: true, completion: nil)
                } else {
                    navigationController!.pushViewController(imageController, animated: true)
                }
            }
        }
    }

    
    // MARK: - Notifications
    
    @objc func colorThemeChanged(notification:NSNotification) {
        setupColors()
    }
    
    func showProfilePictureChanged(notification:NSNotification) {
        updateView()
    }
}
