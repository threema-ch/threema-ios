//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022 Threema GmbH
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
import ThreemaFramework
import UIKit

class TextPreviewViewController: UIViewController, UITextViewDelegate {
    var previewText: String?
    var selectedText: NSRange?
    var selectedConversations: [Conversation]?
    var bottomLayoutConstraint: NSLayoutConstraint?
    
    init(previewText: String?, selectedText: NSRange? = nil, selectedConversations: [Conversation]? = nil) {
        self.previewText = previewText
        self.selectedText = selectedText
        self.selectedConversations = selectedConversations

        super.init(nibName: nil, bundle: nil)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = Colors.backgroundViewController
        
        overrideUserInterfaceStyle = UserSettings.shared().darkTheme ? .dark : .light
        
        configureLayout()
        
        textPreviewView.becomeFirstResponder()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateLayoutForKeyboard),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateLayoutForKeyboard),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateLayoutForKeyboard),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
    }
    
    var conversationDescriptionHeightConstraint: NSLayoutConstraint?
    var textPreviewHeightConstraint: NSLayoutConstraint?
    
    override func viewDidLayoutSubviews() {
        var conversationDescriptionViewHeight = conversationDescriptionView?.frame.height ?? 0
        if conversationDescriptionView?.frame.height ?? 0.0 >= view.frame.height / 6 {
            conversationDescriptionViewHeight = view.frame.height / 6
            conversationDescriptionHeightConstraint = conversationDescriptionView?.heightAnchor
                .constraint(equalToConstant: conversationDescriptionViewHeight)
            conversationDescriptionHeightConstraint?.isActive = true
            conversationDescriptionView?.isScrollEnabled = true
            conversationDescriptionView?.flashScrollIndicators()
        }
        else {
            conversationDescriptionView?.isScrollEnabled = false
            conversationDescriptionHeightConstraint?.isActive = false
        }

        print("\(textPreviewView.contentSize.height)")
        if textPreviewView.intrinsicContentSize.height >= (view.frame.height - conversationDescriptionViewHeight) {
            textPreviewHeightConstraint = textPreviewView.heightAnchor
                .constraint(equalToConstant: view.frame.height - conversationDescriptionViewHeight)
            textPreviewHeightConstraint?.isActive = true
            textPreviewView.isScrollEnabled = true
            textPreviewView.flashScrollIndicators()
        }
        else {
            textPreviewView.isScrollEnabled = false
            textPreviewHeightConstraint?.isActive = false
        }
    }
    
    private lazy var textPreviewView: UITextView = {
        let textView = UITextView()
        if let fontSize = UserSettings.shared()?.chatFontSize {
            textView.font = UIFont.systemFont(ofSize: CGFloat(fontSize))
        }
        
        textView.text = previewText

        if selectedText != nil {
            textView.selectedRange = selectedText!
        }
        
        textView.delegate = self
        textView.backgroundColor = Colors.backgroundViewController
        textView.textContainerInset = UIEdgeInsets(top: 6.5, left: 13, bottom: 0, right: 13)
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.isScrollEnabled = false
        
        return textView
    }()
    
    private lazy var conversationDescriptionView: UITextView? = {
        
        guard let selectedConversations = selectedConversations else {
            return nil
        }

        guard !selectedConversations.isEmpty else {
            return nil
        }
        
        let textView = UITextView()
        textView.attributedText = ShareExtensionHelpers.getDescription(for: selectedConversations)
        
        textView.backgroundColor = .clear
        textView.font = UIFont.preferredFont(forTextStyle: .subheadline)
        textView.isScrollEnabled = false
        textView.translatesAutoresizingMaskIntoConstraints = false
        
        return textView
    }()
    
    private lazy var hairlineView: UIView = {
        let view = UIView()
        
        NSLayoutConstraint.activate([
            view.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale),
        ])
        
        view.backgroundColor = Colors.separator
        
        view.setContentCompressionResistancePriority(.required, for: .vertical)
            
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var contentStackView: UIStackView = {
        let contentStackView = UIStackView()
        contentStackView.alignment = .center
        contentStackView.axis = .vertical
        contentStackView.distribution = .fill
        
        contentStackView.spacing = 6.5
        
        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        
        textPreviewView.setContentHuggingPriority(.defaultLow, for: .vertical)
        textPreviewView.setContentCompressionResistancePriority(.defaultHigh, for: .vertical)
        
        conversationDescriptionView?.setContentHuggingPriority(.required, for: .vertical)
        conversationDescriptionView?.setContentCompressionResistancePriority(.defaultHigh, for: .vertical)
        
        if let conversationDescriptionView = conversationDescriptionView {
            contentStackView.addArrangedSubview(conversationDescriptionView)
            contentStackView.addArrangedSubview(hairlineView)
        }
        
        contentStackView.addArrangedSubview(textPreviewView)
        
        return contentStackView
    }()
    
    func configureLayout() {
        view.addSubview(contentStackView)
        NSLayoutConstraint.activate([
            contentStackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 6.5),
            contentStackView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            contentStackView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
        ])
        
        NSLayoutConstraint.activate([
            contentStackView.leadingAnchor.constraint(equalTo: textPreviewView.leadingAnchor),
            contentStackView.trailingAnchor.constraint(equalTo: textPreviewView.trailingAnchor),
        ])
        
        if let conversationDescriptionView = conversationDescriptionView {
            NSLayoutConstraint.activate([
                contentStackView.leadingAnchor.constraint(
                    equalTo: conversationDescriptionView.leadingAnchor,
                    constant: -13.0
                ),
                contentStackView.trailingAnchor.constraint(
                    equalTo: conversationDescriptionView.trailingAnchor,
                    constant: 13.0
                ),
                contentStackView.leadingAnchor.constraint(equalTo: hairlineView.leadingAnchor, constant: 0),
                contentStackView.trailingAnchor.constraint(equalTo: hairlineView.trailingAnchor, constant: 0),
            ])
        }
        
        bottomLayoutConstraint = contentStackView.bottomAnchor
            .constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        bottomLayoutConstraint?.isActive = true
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        NotificationCenter.default.removeObserver(self)
    }
    
    func textViewDidChange(_ textView: UITextView) {
        previewText = textPreviewView.text
    }
    
    @objc func updateLayoutForKeyboard(notification: NSNotification) {
        _ = bottomLayoutConstraint?.constant
        if let userInfo = notification.userInfo {
            let endFrame = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
            let endFrameY = endFrame?.origin.y ?? 0
            let duration: TimeInterval = (userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?
                .doubleValue ?? 0
            let animationCurveRawNSN = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber
            let animationCurveRaw = animationCurveRawNSN?.uintValue ?? UIView.AnimationOptions.curveEaseInOut.rawValue
            let animationCurve = UIView.AnimationOptions(rawValue: animationCurveRaw)
            if endFrameY >= UIScreen.main.bounds.size.height {
                bottomLayoutConstraint?.constant = 0.0
            }
            else {
                if let endFrame = endFrame {
                    let safeInset: CGFloat = view.safeAreaInsets.bottom
                    let convertedEndframe = view.convert(endFrame, from: UIScreen.main.coordinateSpace)
                    let intersection = view.frame.intersection(convertedEndframe).height
                    bottomLayoutConstraint?.constant = -max(intersection - safeInset, 0)
                }
                else {
                    bottomLayoutConstraint?.constant = 0.0
                }
            }
            
            UIView.animate(
                withDuration: duration,
                delay: TimeInterval(0),
                options: animationCurve,
                animations: {
                    self.view.layoutIfNeeded()
                },
                completion: nil
            )
        }
    }
}
