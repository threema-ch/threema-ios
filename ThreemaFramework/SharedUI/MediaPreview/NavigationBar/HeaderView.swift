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

import CocoaLumberjackSwift
import Foundation

class HeaderView: UIView {
    private lazy var touchAnimator = UIViewPropertyAnimator.barButtonHighlightAnimator(for: self)
    private var tapAction: (() -> Void?)?
    
    private var titleLabel: UILabel
    private var optionsLabel: UILabel?
    private var viewButton: UIButton
    private var stackView: UIStackView
    
    init(for mediaPreviewItems: [MediaPreviewItem], frame: CGRect, tapAction: (() -> Void?)? = nil) {
        self.titleLabel = UILabel()
        self.viewButton = UIButton(frame: frame)
        self.stackView = UIStackView(frame: frame)
        
        super.init(frame: frame)
        
        self.tapAction = tapAction
        configureView(titleViewSize: frame)
        updateTitleLabel(mediaPreviewItems: mediaPreviewItems)
        rotate(landscape: UIDevice.current.orientation.isLandscape, newWidth: frame.width)
        
        stackView.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
        stackView.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
        stackView.backgroundColor = .clear
        self.backgroundColor = .clear
    }
    
    deinit {
        touchAnimator.stopAnimation(true)
    }
    
    func rotate(landscape: Bool, newWidth: CGFloat) {
        let isLandcape = UIDevice.current.userInterfaceIdiom == .pad ? false : landscape

        stackView.axis = isLandcape ? .horizontal : .vertical
        stackView.distribution = isLandcape ? .fillEqually : .equalCentering
        stackView.alignment = isLandcape ? .center : .leading
        stackView.spacing = isLandcape ? 10.0 : 4.0
        
        if stackView.arrangedSubviews.count == 1, let optionsLabel = stackView.arrangedSubviews.first as? UILabel {
            optionsLabel.textAlignment = isLandcape ? .center : .left
        }
        
        titleLabel.sizeToFit()
        optionsLabel?.sizeToFit()
        titleLabel.textAlignment = isLandcape ? .right : .left
        
        stackView.frame = CGRect(
            x: stackView.frame.minX,
            y: stackView.frame.minY,
            width: newWidth,
            height: stackView.frame.height
        )
    }
    
    @available(*, deprecated, message: "Use init(for mediaPreviewItems : [MediaPreviewItem], frame : CGRect)")
    required init?(coder: NSCoder) {
        DDLogError("Use init(for: Conversation)")
        fatalError("init(coder:) has not been implemented")
    }
    
    func configureView(titleViewSize: CGRect) {
        stackView.axis = .vertical
        stackView.distribution = .equalCentering
        stackView.alignment = .leading
        
        titleLabel.text = BundleUtil.localizedString(forKey: "preview")
        titleLabel.isAccessibilityElement = false
        titleLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        titleLabel.textAlignment = .center
        titleLabel.textColor = Colors.text
        titleLabel.sizeToFit()
        stackView.addArrangedSubview(titleLabel)
        
        let titleHeight = titleLabel.font.lineHeight
        let titleConstraint = titleLabel.heightAnchor.constraint(equalToConstant: titleHeight)
        titleConstraint.isActive = true
        
        stackView.frame = CGRect(
            x: stackView.frame.minX,
            y: stackView.frame.minY,
            width: stackView.frame.width,
            height: titleLabel.frame.height
        )
        
        if tapAction != nil {
            optionsLabel = UILabel()
            guard let optionsLabel = optionsLabel else {
                DDLogError("OptionsLabel was nil")
                return
            }
            let maxFontSize = min(UIFont.preferredFont(forTextStyle: .footnote).pointSize, 32.0)
            optionsLabel.font = UIFont.preferredFont(forTextStyle: .footnote).withSize(maxFontSize)
            optionsLabel.textAlignment = .left
            
            optionsLabel.isAccessibilityElement = false
            
            let titleString = BundleUtil.localizedString(forKey: "mediapreview_options").appending(" ")
            let attributedTitleString = NSMutableAttributedString(string: titleString)
            let range = (titleString as NSString).range(of: titleString)
            
            attributedTitleString.addAttribute(
                NSAttributedString.Key.foregroundColor,
                value: Colors.primary,
                range: range
            )
            
            let arrowAttach = NSTextAttachment()
            arrowAttach.image = BundleUtil.imageNamed("ArrowNext")?.withTint(Colors.primary)
            
            let widthConst = optionsLabel.font.capHeight
            
            arrowAttach.bounds = CGRect(x: 0, y: 0, width: widthConst, height: widthConst)
            let arrowAttachString = NSAttributedString(attachment: arrowAttach)
            attributedTitleString.append(arrowAttachString)
            
            optionsLabel.attributedText = attributedTitleString
            
            let height = optionsLabel.font.lineHeight
            let constraint = optionsLabel.heightAnchor.constraint(equalToConstant: height)
            constraint.isActive = true
            
            optionsLabel.sizeToFit()
            
            stackView.frame = CGRect(
                x: stackView.frame.minX,
                y: stackView.frame.minY,
                width: stackView.frame.width,
                height: stackView.frame.height + optionsLabel.frame.height
            )
                        
            stackView.addArrangedSubview(optionsLabel)
            
            viewButton.addTarget(self, action: #selector(viewTapped), for: .touchUpInside)
            viewButton.addTarget(self, action: #selector(touchDown), for: .touchDown)
            viewButton.addTarget(self, action: #selector(touchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
            addSubview(viewButton)
        }
        
        // To deal with very large font sizes, we remove the item description from the header view
        // It is more important to show the functionality in a readable font size than to have an illegible
        // description.
        if stackView.frame.height > frame.height {
            stackView.frame = CGRect(
                x: stackView.frame.minX,
                y: stackView.frame.minY,
                width: stackView.frame.width,
                height: frame.height
            )
            titleLabel.removeFromSuperview()
        }
        addSubview(stackView)
        sendSubviewToBack(stackView)
    }
    
    @objc private func viewTapped() {
        if let tapAction = tapAction {
            tapAction()
        }
    }
    
    @objc private func touchDown() {
        touchAnimator.pauseAnimation()
        touchAnimator.isReversed = false
        touchAnimator.startAnimation()
    }
    
    @objc private func touchUp() {
        touchAnimator.pauseAnimation()
        touchAnimator.isReversed = true
        touchAnimator.startAnimation()
    }
    
    public func updateTitleLabel(mediaPreviewItems: [MediaPreviewItem]) {
        var tmpTitle: String?
        
        if mediaPreviewItems.count > 1 {
            tmpTitle = String.localizedStringWithFormat(
                BundleUtil.localizedString(forKey: "multiple_media_items"),
                mediaPreviewItems.count
            )
        }
        else {
            tmpTitle = BundleUtil.localizedString(forKey: "media_item")
        }
        
        guard let title = tmpTitle else {
            DDLogError("Title was nil when it should not have been.")
            return
        }
        
        titleLabel.text = title
        viewButton.accessibilityLabel = title
        viewButton.accessibilityValue = BundleUtil.localizedString(forKey: "mediapreview_options")
    }
}
