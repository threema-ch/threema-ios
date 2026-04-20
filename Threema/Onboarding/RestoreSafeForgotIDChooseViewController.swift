import ThreemaMacros
import UIKit

final class RestoreSafeForgotIDChooseViewController: IDCreationPageViewController {
    
    @IBOutlet var contentView: UIStackView!
    @IBOutlet var descriptionLabel: UILabel!
    @IBOutlet var cancelButton: SetupButton!
    
    var ids: [String]?
    var choosenID: String?

    override func viewDidLoad() {
        super.viewDidLoad()

        overrideUserInterfaceStyle = .dark

        descriptionLabel.text = String.localizedStringWithFormat(
            #localize("safe_select_id"),
            TargetManager.localizedAppName
        )
        
        cancelButton.setTitle(#localize("cancel"), for: .normal)
        
        if let ids {
            var index = 1
            for id in ids {
                print(id)
                let idButton = SetupButton()
                idButton.setTitle(id, for: .normal)
                idButton.addTarget(self, action: #selector(touchIDButton), for: .touchUpInside)

                contentView.insertArrangedSubview(idButton, at: index)
                index += 1
            }
        }
    }
    
    override public var shouldAutorotate: Bool {
        false
    }
    
    @objc func touchIDButton(_ sender: SetupButton) {
        if let id: String = sender.titleLabel?.text {
            choosenID = String(id[id.startIndex..<id.index(id.startIndex, offsetBy: 8)])
            performSegue(withIdentifier: "choosenSafeForgotIDChoose", sender: self)
        }
    }
}
