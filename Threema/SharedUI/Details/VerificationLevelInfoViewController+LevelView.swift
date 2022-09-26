//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2022 Threema GmbH
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

extension VerificationLevelInfoViewController {
    
    /// Custom view for each level with dots image and description text
    class LevelView: UIView {
        
        private enum Configuration {
            static var levelImageOffsetFromTop: CGFloat {
                UIFontMetrics(forTextStyle: .body).scaledValue(for: 5)
            }
            
            static var verticalSpacingBetweenImageAndLabel: CGFloat {
                UIFontMetrics(forTextStyle: .body).scaledValue(for: 16)
            }
        }
        
        private lazy var levelImage: UIImageView = {
            let imageView = UIImageView()
            
            imageView.contentMode = .scaleAspectFit
            
            return imageView
        }()
        
        private lazy var levelLabel: UILabel = {
            let label = UILabel()
            
            label.font = UIFont.preferredFont(forTextStyle: .body)
            label.adjustsFontForContentSizeCategory = true
            
            label.numberOfLines = 0
            
            label.isAccessibilityElement = false
            
            return label
        }()
        
        init(for level: Int) {
            super.init(frame: .zero)
            
            configureContent(for: level)
            configureLayout()
        }
        
        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        private func configureContent(for level: Int) {
            if traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
                levelImage.image = StyleKit.verificationImageBig(for: level)
            }
            else {
                levelImage.image = StyleKit.verificationImage(for: level)
            }
            
            let localizedTitle = BundleUtil.localizedString(forKey: "level\(level)_title")
            let localizedExplanation = BundleUtil.localizedString(forKey: "level\(level)_explanation")

            levelLabel.text = localizedExplanation
            
            accessibilityLabel = localizedTitle
            accessibilityValue = localizedExplanation
            isAccessibilityElement = true
        }
        
        private func configureLayout() {
            addSubview(levelImage)
            addSubview(levelLabel)
            
            levelImage.translatesAutoresizingMaskIntoConstraints = false
            levelLabel.translatesAutoresizingMaskIntoConstraints = false
            
            let sharedConstraints = [
                // Add constant for optical alignment with text labels
                levelImage.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 1),
                
                levelImage.topAnchor.constraint(equalTo: topAnchor, constant: Configuration.levelImageOffsetFromTop),
                
                levelLabel.bottomAnchor.constraint(equalTo: bottomAnchor),
                levelLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            ]
            
            let defaultConstraints = [
                levelLabel.topAnchor.constraint(equalTo: topAnchor),
                levelLabel.leadingAnchor.constraint(
                    equalTo: levelImage.trailingAnchor,
                    constant: Configuration.verticalSpacingBetweenImageAndLabel
                ),
            ] + sharedConstraints
            
            let accessibilityContentSizeConstraints = [
                levelLabel.topAnchor.constraint(
                    equalTo: levelImage.bottomAnchor,
                    constant: Configuration.verticalSpacingBetweenImageAndLabel
                ),
                levelLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            ] + sharedConstraints
            
            if traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
                NSLayoutConstraint.activate(accessibilityContentSizeConstraints)
            }
            else {
                NSLayoutConstraint.activate(defaultConstraints)
            }
        }
    }
}
