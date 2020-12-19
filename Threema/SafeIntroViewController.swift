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

import UIKit

class SafeIntroViewController: ThemedViewController {
    
    @IBOutlet weak var mainContent: UIStackView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var introCircle: UIView!
    @IBOutlet weak var introImage: UIImageView!
    @IBOutlet weak var explainLabel: UILabel!
    @IBOutlet weak var okButton: SetupButton!
    @IBOutlet weak var cancelButton: SetupButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        self.titleLabel.text = BundleUtil.localizedString(forKey: "safe_intro_title")
        self.descriptionLabel.text = BundleUtil.localizedString(forKey: "safe_intro_description")
        self.introCircle.layer.cornerRadius = self.introCircle.frame.height / 2
        self.introCircle.backgroundColor = UIColor(red: 235.0/255.0, green: 235.0/255.0, blue: 235.0/255.0, alpha: 1.0)
        self.explainLabel.text = BundleUtil.localizedString(forKey: "safe_intro_explain")
        self.cancelButton.setTitle(BundleUtil.localizedString(forKey: "safe_intro_cancel"), for: .normal)
        self.okButton.setTitle(BundleUtil.localizedString(forKey: "safe_intro_enable"), for: .normal)
        
        self.cancelButton.accentColor = Colors.main()
        self.cancelButton.textColor = Colors.fontNormal()
        self.okButton.accentColor = Colors.main()
        self.okButton.textColor = Colors.fontInverted()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let navigationController = segue.destination as? UINavigationController else {
            return
        }
        
        if let safeSetupPasswordViewController = navigationController.topViewController as? SafeSetupPasswordViewController {
            safeSetupPasswordViewController.isOpenedFromIntro = true
        }
    }
}

extension SafeIntroViewController {
    @IBAction func touchDownButton(_ sender: UIButton, forEvent event: UIEvent) {
        self.dismiss(animated: true, completion: nil)
    }

    @IBAction func doneSafeIntroPassword(_ segue: UIStoryboardSegue) {
        guard segue.source is SafeSetupPasswordViewController else {
            return
        }
        
        // object: 0 -> 0s backup delay and force it
        NotificationCenter.default.post(name: NSNotification.Name(kSafeBackupTrigger), object: 0)
        
        self.dismiss(animated: true, completion: nil)
    }
}
