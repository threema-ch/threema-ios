//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2021 Threema GmbH
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

class VerificationViewController: ThemedViewController {
    
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var descriptionText: SSLabel!
    
    @IBOutlet weak var workTitle: SSLabel!
    @IBOutlet weak var otherTitle: SSLabel!
    
    @IBOutlet weak var labelLevel0: SSLabel!
    @IBOutlet weak var labelLevel1: SSLabel!
    @IBOutlet weak var labelLevel2: SSLabel!
    @IBOutlet weak var labelLevel3: SSLabel!
    @IBOutlet weak var labelLevel4: SSLabel!
    
    @IBOutlet weak var imageLevel0: UIImageView!
    @IBOutlet weak var imageLevel1: UIImageView!
    @IBOutlet weak var imageLevel2: UIImageView!
    @IBOutlet weak var imageLevel3: UIImageView!
    @IBOutlet weak var imageLevel4: UIImageView!
    
    @IBOutlet weak var workConstraint: NSLayoutConstraint!
    @IBOutlet weak var threemaConstraint: NSLayoutConstraint!
    
    private var wasTabBarHidden = false
    override func viewDidLoad() {
        super.viewDidLoad()
                
        labelLevel0.verticalTextAlignment = SSLabelVerticalTextAlignmentTop
        labelLevel1.verticalTextAlignment = SSLabelVerticalTextAlignmentTop
        labelLevel2.verticalTextAlignment = SSLabelVerticalTextAlignmentTop
        labelLevel3.verticalTextAlignment = SSLabelVerticalTextAlignmentTop
        labelLevel4.verticalTextAlignment = SSLabelVerticalTextAlignmentTop
        
        labelLevel0.accessibilityLabel = accessibilityLabelForLevel(level: 0)
        labelLevel1.accessibilityLabel = accessibilityLabelForLevel(level: 1)
        labelLevel2.accessibilityLabel = accessibilityLabelForLevel(level: 2)
        labelLevel3.accessibilityLabel = accessibilityLabelForLevel(level: 3)
        labelLevel4.accessibilityLabel = accessibilityLabelForLevel(level: 4)
        
        imageLevel0.image = StyleKit.verificationSmall0
        imageLevel1.image = StyleKit.verificationSmall1
        imageLevel2.image = StyleKit.verificationSmall2
        imageLevel3.image = StyleKit.verificationSmall3
        imageLevel4.image = StyleKit.verificationSmall4
        
        if !LicenseStore.requiresLicenseKey() {
            imageLevel3.isHidden = true
            imageLevel4.isHidden = true
            labelLevel3.isHidden = true
            labelLevel4.isHidden = true
            workTitle.isHidden = true
            otherTitle.isHidden = true
            
            if workConstraint.priority != .defaultLow {
                workConstraint.priority = .defaultLow
            }
            if threemaConstraint.priority != .required {
                threemaConstraint.priority = .required
            }
        } else {
            if workConstraint.priority != .required {
                workConstraint.priority = .required
            }
            if threemaConstraint.priority != .defaultLow {
                threemaConstraint.priority = .defaultLow
            }
        }
        
        setupColors()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
            
        updateView()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if let tabBarController = tabBarController {
            tabBarController.tabBar.isHidden = wasTabBarHidden
        }
    }
            
    func setupColors() {
        view.backgroundColor = Colors.background()
        descriptionText.textColor = Colors.fontNormal()
        
        labelLevel0.textColor = Colors.fontNormal()
        labelLevel1.textColor = Colors.fontNormal()
        labelLevel2.textColor = Colors.fontNormal()
        labelLevel3.textColor = Colors.fontNormal()
        labelLevel4.textColor = Colors.fontNormal()
    }
    
    func updateView() {
        if let tabBarController = tabBarController {
            wasTabBarHidden = tabBarController.tabBar.isHidden
            tabBarController.tabBar.isHidden = true
        }
        
        descriptionText.text = BundleUtil.localizedString(forKey: "verification_level_text")
        
        workTitle.text = BundleUtil.localizedString(forKey: "verification_level_section_work")
        otherTitle.text = BundleUtil.localizedString(forKey: "verification_level_section_other")
        
        labelLevel0.text = BundleUtil.localizedString(forKey: "level0_explanation")
        labelLevel1.text = BundleUtil.localizedString(forKey: "level1_explanation")
        labelLevel2.text = BundleUtil.localizedString(forKey: "level2_explanation")
        labelLevel3.text = BundleUtil.localizedString(forKey: "level3_explanation")
        labelLevel4.text = BundleUtil.localizedString(forKey: "level4_explanation")
    }
    
    // MARK: - Private functions
    
    private func accessibilityLabelForLevel(level: Int) -> String {
        let title = BundleUtil.localizedString(forKey: String(format: "level%d_title", level))
        let description = BundleUtil.localizedString(forKey: String(format: "level%d_explanation", level))
        
        return "\(title!), \(description!)"
    }
}
