//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2020 Threema GmbH
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
        if self.alert == nil {
            self.alert = NibUtil.loadViewFromNib(withName: "IntroQuestionView") as? IntroQuestionView
            self.alert?.showOnlyOkButton = true
            self.alert?.delegate = self
            self.alert?.frame = RectUtil.rect(self.alert!.frame, centerIn: self.parent.view.frame, round: true)
            
            self.parent.view.addSubview(self.alert!)
        }
        if let title = title {
            self.alert?.title = title
        }
        self.alert?.questionLabel.text = text
        self.alert?.questionLabel.sizeToFit()
        
        self.parent.showMessageView(self.alert)
    }
    
    func showConfirm(_ text: String, noButtonLabel: String? = nil, yesButtonLabel: String? = nil) {
        if self.confirm == nil {
            self.confirm = NibUtil.loadViewFromNib(withName: "IntroQuestionView") as? IntroQuestionView
            self.confirm?.delegate = self
            self.confirm?.frame = RectUtil.rect(self.confirm!.frame, centerIn: self.parent.view.frame, round: true)

            self.parent.view.addSubview(self.confirm!)
        }

        self.confirm?.questionLabel.text = text
        if let no = noButtonLabel {
            self.confirm?.noButton.setTitle(no, for: .normal)
        }
        if let yes = yesButtonLabel {
            self.confirm?.yesButton.setTitle(yes, for: .normal)
        }

        self.parent.showMessageView(self.confirm)
    }
    
    private func answer(_ sender: IntroQuestionView, answer: Answer) {
        self.parent.hideMessageView(sender)
        if let onAnswer = self.onAnswer {
            onAnswer(sender, answer)
        }
    }
    
    //MARK: - IntroQuestionViewDelegate
    
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
