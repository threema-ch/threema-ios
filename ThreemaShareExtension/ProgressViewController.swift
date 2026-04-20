import CocoaLumberjackSwift
import ThreemaFramework
import ThreemaMacros
import UIKit

protocol ProgressViewDelegate {
    func progressViewDidCancel()
}

class ProgressViewController: UIViewController {
    
    var itemsToSend: NSMutableDictionary?
    var blurView: UIVisualEffectView?
    
    var totalCount = 0
    
    var delegate: ProgressViewDelegate?
    
    @IBOutlet var label: UILabel!
    @IBOutlet var contentView: UIView!
    @IBOutlet var visualEffectsView: UIVisualEffectView!
    @IBOutlet var cancelButton: UIButton!
    @IBOutlet var progressView: UIProgressView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        itemsToSend = NSMutableDictionary()
        cancelButton!.setTitle(#localize("cancel"), for: .normal)
                
        view.backgroundColor = .systemGroupedBackground
        
        view.tintColor = .tintColor
        contentView!.backgroundColor = .secondarySystemGroupedBackground
        contentView?.layer.cornerRadius = 15.0
        label.textColor = .label
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        navigationController?.isNavigationBarHidden = true
        
        updateProgressLabel()
        progressView?.progress = 0.0
    }
    
    func setProgress(progress: NSNumber, item: Any?) {
        if item != nil {
            itemsToSend?.setObject(progress, forKey: item as! NSCopying)
        }
        
        DispatchQueue.main.async {
            self.updateProgressLabel()
            self.updateProgressView()
        }
    }
    
    func finishedItem(item: Any) {
        setProgress(progress: NSNumber(floatLiteral: 1.0), item: item)
    }
    
    private func updateProgressLabel() {
        var inProgressOrSentCount = 0
        var sentCount = 0
        for key in itemsToSend!.keyEnumerator() {
            let progress: NSNumber = itemsToSend!.object(forKey: key) as! NSNumber
            if progress.floatValue > 0.0 {
                inProgressOrSentCount = inProgressOrSentCount + 1
            }
            if progress.floatValue == 1.0 {
                sentCount += 1
            }
        }
        
        let currentItemCount = inProgressOrSentCount <= totalCount ? inProgressOrSentCount : totalCount
        
        var text = ""
        
        if sentCount == totalCount {
            text = #localize("finished_sending_title")
        }
        else {
            let sendingText = #localize("sending_count")
            text = String.localizedStringWithFormat(sendingText, currentItemCount, totalCount)
        }
        
        label!.text = text
    }
    
    private func updateProgressView() {
        var progress: Float = 0.0
        for key in itemsToSend!.keyEnumerator() {
            let itemProgress: NSNumber = itemsToSend?.object(forKey: key) as! NSNumber
            progress += itemProgress.floatValue
        }
        
        progressView?.progress = progress / Float(totalCount)
    }
    
    @IBAction func cancelButtonPressed(_ sender: Any) {
        guard let rootNavController = delegate else {
            let message = "Delegate was unexpecedly nil"
            DDLogError("\(message)")
            fatalError(message)
        }
        rootNavController.progressViewDidCancel()
    }
}
