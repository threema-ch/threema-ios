import UIKit

/// Base class for a modern grouped table view (uses inset starting with iOS 13)
///
/// Delegate and data source are not configured. This is a good starting point if you want to use a diffable datasource.
open class ThemedCodeModernGroupedTableViewController: ThemedViewController {
    
    // MARK: - The (table) view
    
    /// The table view set as root view
    open lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        return tableView
    }()
    
    // MARK: - Scroll edge appearance for non-large titles
    
    /// At which scroll offset does the navigation bar become opaque
    open var navigationBarOpacityBreakpoint: CGFloat = 20 {
        didSet {
            scrollViewDidScroll(tableView)
        }
    }
    
    /// Offset at which point the navigation bar title is set
    open var navigationBarTitleAppearanceOffset: CGFloat = 140 {
        didSet {
            scrollViewDidScroll(tableView)
        }
    }
    
    // Setting this might also change the tab bar item. Use it carefully.
    override open var title: String? {
        didSet {
            navigationBarTitle = title
        }
    }
    
    public var navigationBarTitle: String? {
        didSet {
            navigationItem.accessibilityLabel = navigationBarTitle
            scrollViewDidScroll(tableView)
        }
    }

    public var hideNavigationBarTitleBelowAppearanceOffset = false

    // Implementation detail
    
    // MARK: - Lifecycle
    
    public init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    @available(*, unavailable)
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        fatalError("Not supported. Just call init().")
    }
    
    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func loadView() {
        // Do NOT call `super`!
        view = tableView
    }
    
    override open func updateColors() {
        super.updateColors()
        
        view.backgroundColor = Colors.backgroundGroupedViewController
        
        Colors.update(tableView: tableView)
    }
}

// MARK: - UIScrollViewDelegate

extension ThemedCodeModernGroupedTableViewController: UIScrollViewDelegate {
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard hideNavigationBarTitleBelowAppearanceOffset else {
            navigationItem.title = navigationBarTitle
            return
        }

        let adjustedYOffset = scrollView.contentOffset.y + view.safeAreaInsets.top
        navigationItem.title = adjustedYOffset < navigationBarTitleAppearanceOffset ? nil : navigationBarTitle
    }
}
