import MBProgressHUD

struct ProgressHUD {
    typealias Action = () -> Void
    
    private(set) var hide: Action?
    private(set) var show: Action?
    
    private init() { }
    
    static func make(label: String?) -> ProgressHUD {
        make(label: label, on: AppDelegate.shared().currentTopViewController())
    }
    
    static func make(label: String?, on viewController: UIViewController?) -> ProgressHUD {
        ProgressHUD().then {
            guard let viewController, let view = viewController.view else {
                return
            }
            
            $0.hide = {
                _ = MBProgressHUD.hide(for: view, animated: true)
            }
            
            $0.show = {
                _ = MBProgressHUD.showAdded(to: view, animated: true).then {
                    $0.label.text = label
                }
            }
        }
    }
}

// MARK: - Then

extension ProgressHUD: Then { }
