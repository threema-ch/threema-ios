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

import ThreemaFramework
import UIKit

class TextPreviewViewController: UIViewController, UITextViewDelegate {
    
    @IBOutlet var textView: UITextView!
    @IBOutlet var bottomLayoutConstraint: NSLayoutConstraint!
    
    var previewText: String?
    var selectedText: NSRange?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let fontSize = UserSettings.shared()?.chatFontSize {
            textView.font = UIFont.systemFont(ofSize: CGFloat(fontSize))
        }
        
        textView.text = previewText
        if selectedText != nil {
            textView.selectedRange = selectedText!
        }
        
        textView.textContainerInset = UIEdgeInsets(top: 13, left: 13, bottom: 0, right: 13)
        
        textView.becomeFirstResponder()
        textView.delegate = self
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateLayoutForKeyboard(notification:)),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
        
        view.backgroundColor = Colors.backgroundViewController
        textView.backgroundColor = Colors.backgroundViewController
        
        overrideUserInterfaceStyle = UserSettings.shared().darkTheme ? .dark : .light
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        NotificationCenter.default.removeObserver(self)
    }
    
    func textViewDidChange(_ textView: UITextView) {
        previewText = self.textView.text
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
