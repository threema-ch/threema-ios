import ThreemaMacros
import UIKit

final class MediaShareOptionsViewController: ThemedTableViewController {
    
    @IBOutlet var sendAsFileSwitch: UISwitch!
    
    struct ImageSendOptions {
        var sendAsFile = false
        var imageQuality = ""
    }
    
    var options: ImageSendOptions?
    @IBOutlet var imageSizeLabel: UILabel!
    weak var delegate: MediaPreviewViewController?
    
    @IBOutlet var saveButton: UIBarButtonItem!
    @IBOutlet var navigationBar: UINavigationItem!
    @IBOutlet var sendAsFileCell: UITableViewCell!
    @IBOutlet var imageQualityCell: UITableViewCell!
    
    func setupOptions(options: ImageSendOptions) {
        self.options = options
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
                
        options!.imageQuality = BundleUtil.localizedString(forKey: UserSettings.shared().imageSize)
        sendAsFileSwitch.isOn = options?.sendAsFile ?? false
        navigationBar.title = #localize("more_options")
        sendAsFileCell.textLabel?.text = #localize("send_as_file")
        saveButton.title = #localize("Done")
        saveButton.tintColor = .primary
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        saveOptions()
        super.viewWillDisappear(animated)
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        #localize("send_as_file_description")
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        #localize("send_as_file_title")
    }
    
    @IBAction func donePressed(_ sender: Any) {
        dismiss(animated: true, completion: nil)
        saveOptions()
    }
    
    func saveOptions() {
        options?.sendAsFile = sendAsFileSwitch.isOn
        delegate?.updateOptions(imageSendOptions: options!)
    }
}
