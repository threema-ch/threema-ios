//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021 Threema GmbH
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
import ThreemaFramework

class TextPreviewViewController: UIViewController, UITextViewDelegate {
    
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var bottomLayoutConstraint: NSLayoutConstraint!
    
    var previewText : String?
    var selectedText : NSRange?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let fontSize = UserSettings.shared()?.chatFontSize {
            self.textView.font = UIFont.systemFont(ofSize: CGFloat(fontSize))
        }
        
        self.textView.text = previewText
        if self.selectedText != nil {
            self.textView.selectedRange = self.selectedText!
        }
        
        textView.textContainerInset = UIEdgeInsets(top: 13, left: 13, bottom: 0, right: 13)
        
        self.textView.becomeFirstResponder()
        self.textView.delegate = self
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.updateLayoutForKeyboard(notification:)),
                                               name: UIResponder.keyboardWillChangeFrameNotification,
                                               object: nil)
        
        self.view.backgroundColor = Colors.background()
        self.textView.backgroundColor = Colors.background()
        self.textView.textColor = Colors.fontNormal()
        self.textView.tintColor = Colors.main()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        NotificationCenter.default.removeObserver(self)
    }
    
    func textViewDidChange(_ textView: UITextView) {
        self.previewText = self.textView.text
    }
    
    @objc func updateLayoutForKeyboard(notification: NSNotification) {
        _ = self.bottomLayoutConstraint?.constant
        if let userInfo = notification.userInfo {
            let endFrame = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
            let endFrameY = endFrame?.origin.y ?? 0
            let duration: TimeInterval = (userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue ?? 0
            let animationCurveRawNSN = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber
            let animationCurveRaw = animationCurveRawNSN?.uintValue ?? UIView.AnimationOptions.curveEaseInOut.rawValue
            let animationCurve: UIView.AnimationOptions = UIView.AnimationOptions(rawValue: animationCurveRaw)
            if endFrameY >= UIScreen.main.bounds.size.height {
                self.bottomLayoutConstraint?.constant = 0.0
            } else {
                if let endFrame = endFrame {
                    let safeInset: CGFloat
                    if #available(iOS 11.0, *) {
                        safeInset = self.view.safeAreaInsets.bottom
                    } else {
                        safeInset = 0.0
                    }
                    let convertedEndframe = self.view.convert(endFrame, from: UIScreen.main.coordinateSpace)
                    let intersection = self.view.frame.intersection(convertedEndframe).height
                    self.bottomLayoutConstraint?.constant = -(max(intersection - safeInset, 0))
                } else {
                    self.bottomLayoutConstraint?.constant = 0.0
                }
                
            }
            
            UIView.animate(withDuration: duration,
                           delay: TimeInterval(0),
                           options: animationCurve,
                           animations: {
                            self.view.layoutIfNeeded()
                           },
                           completion: nil)
        }
    }
}
