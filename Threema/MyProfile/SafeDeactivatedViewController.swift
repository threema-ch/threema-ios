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

class SafeDeactivatedViewController: ThemedViewController {

    @IBOutlet var introImage: UIImageView!
    @IBOutlet var descriptionLabel: UILabel!
    @IBOutlet var introCircle: UIView!
    @IBOutlet var explainButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        descriptionLabel.text = #localize("safe_enable_explain_short")
        introCircle.layer.cornerRadius = introCircle.frame.height / 2
        
        setupColors()
        updateColors()
    }
    
    @objc override func refresh() {
        updateColors()
    }
    
    private func setupColors() {
        descriptionLabel.textColor = .label
    }
    
    override func updateColors() {
        super.updateColors()
        
        view.backgroundColor = Colors.backgroundGroupedViewController
        
        introCircle.backgroundColor = UIColor(red: 235.0 / 255.0, green: 235.0 / 255.0, blue: 235.0 / 255.0, alpha: 1.0)
        let explainImage = explainButton.imageView?.image!.withTint(.primary)
        explainButton.setImage(explainImage, for: .normal)
    }
}

extension SafeDeactivatedViewController {
    @IBAction func touchDownExplainButton(_ sender: UIButton, forEvent event: UIEvent) {
        UIAlertTemplate.showAlert(
            owner: self,
            title: "Threema Safe",
            message: #localize("safe_enable_explain")
        )
    }
}
