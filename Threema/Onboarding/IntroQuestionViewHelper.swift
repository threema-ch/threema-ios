import Foundation

final class IntroQuestionViewHelper: NSObject, IntroQuestionDelegate {
    
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
            alert?.frame = rect(alert!.frame, centerIn: parent.view.frame, round: true)
            
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
            confirm?.frame = rect(confirm!.frame, centerIn: parent.view.frame, round: true)

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
    
    private func rect(_ rect: CGRect, centerIn outerRect: CGRect, round: Bool) -> CGRect {
        let innerWidth = rect.size.width
        let outerWidth = outerRect.size.width
        
        let innerHeight = rect.size.height
        let outerHeight = outerRect.size.height
        
        var x: Double = (outerWidth - innerWidth) / 2.0
        var y: Double = (outerHeight - innerHeight) / 2.0
        
        if round {
            x = roundl(x)
            y = roundl(y)
        }
        
        return CGRectMake(x, y, rect.size.width, rect.size.height)
    }
}
