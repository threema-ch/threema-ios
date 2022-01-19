//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2022 Threema GmbH
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

class SafeDeactivatedViewController: ThemedViewController {

    @IBOutlet weak var introImage: UIImageView!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var introCircle: UIView!
    @IBOutlet weak var explainButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.descriptionLabel.text = NSLocalizedString("safe_enable_explain_short", comment: "")
        self.introCircle.layer.cornerRadius = self.introCircle.frame.height / 2
        
        setupColors()
    }
    
    @objc override func refresh() {
        setupColors()
    }
    
    private func setupColors() {
        Colors.setTextColor(Colors.fontNormal(), in: self.view)
        
        self.view.backgroundColor = Colors.background()
        
        self.introCircle.backgroundColor = UIColor(red: 235.0/255.0, green: 235.0/255.0, blue: 235.0/255.0, alpha: 1.0)
        let explainImage = self.explainButton.imageView?.image!.withTint(Colors.main())
        self.explainButton.setImage(explainImage, for: .normal)
    }
}

extension SafeDeactivatedViewController {
    @IBAction func touchDownExplainButton(_ sender: UIButton, forEvent event: UIEvent) {
        UIAlertTemplate.showAlert(owner: self, title: "Threema Safe", message: NSLocalizedString("safe_enable_explain", comment: ""))
    }
}
