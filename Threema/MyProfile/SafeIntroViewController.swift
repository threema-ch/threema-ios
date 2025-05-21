//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2025 Threema GmbH
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

import ThreemaMacros
import UIKit

class SafeIntroViewController: ThemedViewController {
    
    @IBOutlet var mainContent: UIStackView!
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var descriptionLabel: UILabel!
    @IBOutlet var introCircle: UIView!
    @IBOutlet var introImage: UIImageView!
    @IBOutlet var explainLabel: UILabel!
    @IBOutlet var okButton: SetupButton!
    @IBOutlet var cancelButton: SetupButton!

    // TODO: (IOS-3251) Remove
    weak var launchModalDelegate: LaunchModalManagerDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()

        titleLabel.text = String.localizedStringWithFormat(
            #localize("safe_intro_title"),
            TargetManager.localizedAppName
        )
        descriptionLabel.text = String.localizedStringWithFormat(
            #localize("safe_intro_description"),
            TargetManager.localizedAppName
        )
        introCircle.layer.cornerRadius = introCircle.frame.height / 2
        explainLabel.text = String.localizedStringWithFormat(
            #localize("safe_intro_explain"),
            TargetManager.localizedAppName,
            TargetManager.appName
        )
        cancelButton.setTitle(#localize("safe_intro_cancel"), for: .normal)
        okButton.setTitle(#localize("safe_intro_enable"), for: .normal)
        
        cancelButton.accentColor = .tintColor
        cancelButton.textColor = .label
        okButton.accentColor = .tintColor
        okButton.textColor = .white

        introCircle.backgroundColor = .tertiarySystemGroupedBackground

        isModalInPresentation = true
    }
    
    // TODO: (IOS-3251) Remove
    override func viewDidDisappear(_ animated: Bool) {
        launchModalDelegate?.didDismiss()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let navigationController = segue.destination as? UINavigationController else {
            return
        }
        
        if let safeSetupPasswordViewController = navigationController
            .topViewController as? SafeSetupPasswordViewController {
            safeSetupPasswordViewController.isOpenedFromIntro = true
        }
    }
}

extension SafeIntroViewController {
    @IBAction func touchDownButton(_ sender: UIButton, forEvent event: UIEvent) {
        UserSettings.shared().safeIntroShown = true
        dismiss(animated: true, completion: nil)
    }

    @IBAction func doneSafeIntroPassword(_ segue: UIStoryboardSegue) {
        guard segue.source is SafeSetupPasswordViewController else {
            return
        }
        
        // object: 0 -> 0s backup delay and force it
        NotificationCenter.default.post(name: NSNotification.Name(kSafeBackupTrigger), object: 0)
        
        dismiss(animated: true, completion: nil)
    }
}
