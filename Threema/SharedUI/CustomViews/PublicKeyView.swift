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

import UIKit

final class PublicKeyView: UIView {
    // MARK: - Private properties
    
    private var contact: ContactEntity?
    private var identity: String?
    private var publicKey: Data?

    // MARK: Subviews
    
    private lazy var backgroundView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var containerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = 15.0
        view.layer.cornerCurve = .continuous
        view.clipsToBounds = true
        return view
    }()
    
    // StackView
    private lazy var verticalStackView: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [
            identityTextView,
            publicKeyLabel,
            hairline,
            okButton,
        ])

        stack.axis = .vertical
        stack.distribution = .fill
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        stack.spacing = 30
        stack.setCustomSpacing(0, after: hairline)
        return stack
    }()
    
    // Identity text view
    private lazy var identityTextView: UITextView = {
        let textView = UITextView(frame: .zero)
        textView.isScrollEnabled = false
        textView.font = UIFont.preferredFont(forTextStyle: .headline)
        textView.textAlignment = .center
        textView.isEditable = false
        textView.isSelectable = false
        textView.isUserInteractionEnabled = false
        textView.textContainerInset = UIEdgeInsets(top: 0.0, left: 20.0, bottom: 0.0, right: 20.0)
        textView.adjustsFontForContentSizeCategory = true
        
        return textView
    }()
    
    // Public key label
    private lazy var publicKeyLabel: CopyLabel = {
        let label = CopyLabel()
        let preferredFont = UIFont.preferredFont(forTextStyle: .title3)
        label.font = UIFont.monospacedSystemFont(ofSize: preferredFont.pointSize, weight: .regular)
        
        label.numberOfLines = 0
        label.textAlignment = .center
        label.adjustsFontForContentSizeCategory = true
        
        return label
    }()
    
    // Hairline View
    private lazy var hairline = UIView()
    
    // Close button
    private lazy var okButton: UIButton = {
        let button = UIButton()
        button.addTarget(self, action: #selector(close), for: .touchUpInside)
        button.addTarget(self, action: #selector(touchButtonDown), for: .touchDown)
        button.addTarget(self, action: #selector(touchCancel), for: .touchUpOutside)
        button.setTitle(BundleUtil.localizedString(forKey: "ok"), for: .normal)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.titleLabel?.font = UIFont.preferredFont(forTextStyle: .body)
        
        return button
    }()
       
    // MARK: - Initialization
    
    @objc init(for contact: ContactEntity) {
        super.init(frame: UIScreen.main.bounds)
        
        self.contact = contact
        
        configureView()
    }
    
    @objc init(identity: String, publicKey: Data) {
        super.init(frame: UIScreen.main.bounds)
        
        self.identity = identity
        self.publicKey = publicKey
        
        configureView()
    }
            
    @available(*, unavailable, message: "Use init(for:)")
    override init(frame: CGRect) {
        fatalError("Use init(for: Conversation)")
    }
    
    @available(*, unavailable, message: "Use init(for:)")
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Configuration
    
    private func configureView() {
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
                
        containerView.addSubview(verticalStackView)
        addSubview(backgroundView)
        addSubview(containerView)
        
        NSLayoutConstraint.activate([
            // Set constraints for the background
            backgroundView.topAnchor.constraint(equalTo: topAnchor),
            backgroundView.rightAnchor.constraint(equalTo: rightAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),
            backgroundView.leftAnchor.constraint(equalTo: leftAnchor),
            
            verticalStackView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 20.0),
            verticalStackView.rightAnchor.constraint(equalTo: containerView.rightAnchor),
            verticalStackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            verticalStackView.leftAnchor.constraint(equalTo: containerView.leftAnchor),
            
            containerView.centerXAnchor.constraint(equalTo: centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            containerView.leftAnchor.constraint(greaterThanOrEqualTo: leftAnchor, constant: 30.0),
            rightAnchor.constraint(greaterThanOrEqualTo: containerView.rightAnchor, constant: 30.0),
            
            hairline.leftAnchor.constraint(equalTo: containerView.leftAnchor),
            hairline.rightAnchor.constraint(equalTo: containerView.rightAnchor),
            hairline.heightAnchor.constraint(equalToConstant: 0.5),
            
            okButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44.0),
        ])
        
        if let contact = contact {
            // Configure identity label
            identityTextView.text = String.localizedStringWithFormat(
                BundleUtil.localizedString(forKey: "public_key_of"),
                contact.identity
            )
            formatAndSetPublicKey(publicKey: contact.publicKey.hexEncodedString())
        }
        else if let identity = identity,
                let publicKey = publicKey {
            identityTextView.text = String.localizedStringWithFormat(
                BundleUtil.localizedString(forKey: "public_key_of"),
                identity
            )
            formatAndSetPublicKey(publicKey: publicKey.hexEncodedString())
        }
        
        updateColors()
    }
    
    // MARK: - Public functions

    @objc public func show() {
        alpha = 0.0
        reloadConstraints()
        AppDelegate.shared().window.addSubview(self)
        UIView.animate(withDuration: 0.2) {
            self.alpha = 1.0
        }
    }
        
    @objc public func updateColors() {
        backgroundView.backgroundColor = .black
        backgroundView.alpha = 0.6
        
        containerView.backgroundColor = Colors.backgroundAlertView

        identityTextView.textColor = Colors.text
        identityTextView.backgroundColor = .clear

        publicKeyLabel.textColor = Colors.text

        hairline.backgroundColor = Colors.hairLine
        
        okButton.tintColor = .primary
        okButton.setTitleColor(.primary, for: .normal)
        okButton.backgroundColor = Colors.backgroundAlertView
    }
        
    // MARK: - Update functions
       
    private func formatAndSetPublicKey(publicKey: String) {
        var formattedPublicKey = ""
        for (index, char) in publicKey.enumerated() {
            if index % 8 == 0, !formattedPublicKey.isEmpty {
                formattedPublicKey.append("\n")
            }
            formattedPublicKey.append(char)
        }
        
        publicKeyLabel.text = formattedPublicKey
        publicKeyLabel.textForCopying = publicKey
        publicKeyLabel.addPublicKeyFormat()
    }
    
    private func reloadConstraints() {
        frame = UIScreen.main.bounds
        updateConstraints()
    }
    
    // MARK: - Actions
       
    @objc public func close() {
        okButton.backgroundColor = Colors.backgroundAlertView
        
        if superview != nil {
            UIView.animate(withDuration: 0.2) {
                self.alpha = 0.0
            } completion: { _ in
                self.removeFromSuperview()
            }
        }
    }
    
    @objc func touchButtonDown() {
        okButton.backgroundColor = Colors.backgroundTableViewCellSelected
    }
    
    @objc func touchCancel() {
        okButton.backgroundColor = Colors.backgroundAlertView
    }
}

extension UILabel {
    func addPublicKeyFormat(kernValue: Double = 6) {
        guard let labelText = text, !labelText.isEmpty else {
            return
        }
        
        let attributedString = NSMutableAttributedString(string: labelText)
        let range = NSRange(location: 0, length: attributedString.length)
        
        let preferredFont = UIFont.preferredFont(forTextStyle: .title3)
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4
        paragraphStyle.alignment = .center
        attributedString.addAttribute(NSAttributedString.Key.paragraphStyle, value: paragraphStyle, range: range)
        
        attributedString.addAttribute(NSAttributedString.Key.kern, value: kernValue, range: range)
        attributedString.addAttribute(
            NSAttributedString.Key.font,
            value: UIFont.monospacedSystemFont(ofSize: preferredFont.pointSize, weight: .regular),
            range: range
        )
        attributedText = attributedString
    }
}
