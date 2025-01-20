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

import Foundation

class IntroQuestionViewHelper: NSObject, IntroQuestionDelegate {
    
    private var parent: IDCreationPageViewController
    private var onAnswer: ((Any?, Answer) -> Void)?
    
    private var alert: IntroQuestionView?
    private var confirm: IntroQuestionView?
    
    public enum Answer {
        case ok
        case no
        case yes
    }
    
    init(parent: IDCreationPageViewController, onAnswer: ((Any?, Answer) -> Void)?) {
        self.parent = parent
        self.onAnswer = onAnswer
    }
    
    func showAlert(_ text: String, title: String? = nil) {
        if alert == nil {
            alert = NibUtil.loadViewFromNib(withName: "IntroQuestionView") as? IntroQuestionView
            alert?.showOnlyOkButton = true
            alert?.delegate = self
            alert?.frame = RectUtil.rect(alert!.frame, centerIn: parent.view.frame, round: true)
            
            parent.view.addSubview(alert!)
        }
        if let title {
            alert?.title = title
        }
        alert?.questionLabel.text = text
        alert?.questionLabel.sizeToFit()
        
        parent.showMessageView(alert)
    }
    
    func showConfirm(_ text: String, noButtonLabel: String? = nil, yesButtonLabel: String? = nil) {
        if confirm == nil {
            confirm = NibUtil.loadViewFromNib(withName: "IntroQuestionView") as? IntroQuestionView
            confirm?.delegate = self
            confirm?.frame = RectUtil.rect(confirm!.frame, centerIn: parent.view.frame, round: true)

            parent.view.addSubview(confirm!)
        }

        confirm?.questionLabel.text = text
        if let no = noButtonLabel {
            confirm?.noButton.setTitle(no, for: .normal)
        }
        if let yes = yesButtonLabel {
            confirm?.yesButton.setTitle(yes, for: .normal)
        }

        parent.showMessageView(confirm)
    }
    
    private func answer(_ sender: IntroQuestionView, answer: Answer) {
        parent.hideMessageView(sender)
        if let onAnswer {
            onAnswer(sender, answer)
        }
    }
    
    // MARK: - IntroQuestionViewDelegate
    
    @objc func selectedOk(_ sender: IntroQuestionView) {
        answer(sender, answer: .ok)
    }
    
    @objc func selectedYes(_ sender: IntroQuestionView) {
        answer(sender, answer: .yes)
    }
    
    @objc func selectedNo(_ sender: IntroQuestionView) {
        answer(sender, answer: .no)
    }
}
