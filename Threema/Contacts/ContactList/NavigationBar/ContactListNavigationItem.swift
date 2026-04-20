import ThreemaFramework
import ThreemaMacros
import UIKit

final class ContactListNavigationItem: UINavigationItem {
    
    // MARK: - Properties

    private weak var delegate: ContactListActionDelegate?
    private var selectedItem: ContactListFilterItem {
        didSet {
            title = selectedItem.label
        }
    }
    
    var shouldShowWorkButton = true {
        willSet {
            leftBarButtonItem = newValue ? workContactsFilterBarButtonItem : nil
        }
    }
    
    private var workContactsFilterActive = false
    
    // MARK: - Subviews
    
    private lazy var addMenuItem = UIBarButtonItem(
        systemItem: .add,
        menu: UIMenu { [weak self] item in
            self?.delegate?.add(item)
        }
    )
    
    private lazy var workContactsFilterButtonImageConfiguration =
        if #available(iOS 26.0, *) {
            UIImage.SymbolConfiguration(weight: .semibold).applying(
                UIImage.SymbolConfiguration(scale: .medium)
            )
        }
        else {
            UIImage.SymbolConfiguration(textStyle: .footnote).applying(
                UIImage.SymbolConfiguration(weight: .medium)
            )
        }
    
    private lazy var workContactsFilterButton: UIButton = {
        var configuration =
            if #available(iOS 26.0, *) {
                UIButton.Configuration.tinted()
            }
            else {
                UIButton.Configuration.borderedTinted()
            }
        
        configuration.image = UIImage(systemName: "case")
        configuration.preferredSymbolConfigurationForImage = workContactsFilterButtonImageConfiguration
        configuration.cornerStyle = .capsule
        configuration.imagePlacement = .all
       
        if #unavailable(iOS 26.0) {
            // We add a little inset to the content. Together with the reduced font size of
            // `workContactsFilterButtonImageConfiguration`, we get the same size as originally, but with accurate
            // padding.
            configuration.contentInsets = .init(top: 8, leading: 8, bottom: 8, trailing: 8)
        }
        
        let button = UIButton(configuration: configuration)
        button.addTarget(self, action: #selector(didToggleWorkContacts), for: .touchUpInside)
        
        button.configurationUpdateHandler = { [weak self] button in
            guard let self, var configuration = button.configuration else {
                return
            }
            
            if button.isSelected {
                configuration.baseForegroundColor = Colors.textInverted
                configuration.baseBackgroundColor = .tintColor
               
                workContactsFilterBarButtonItem.accessibilityValue = #localize("default_enabled")
            }
            else {
                
                if #available(iOS 26.0, *) {
                    configuration.baseBackgroundColor = .clear
                    configuration.baseForegroundColor = .label
                }
                else {
                    configuration.baseForegroundColor = .tintColor
                    configuration.baseBackgroundColor = .gray
                }
                
                workContactsFilterBarButtonItem.accessibilityValue = #localize("default_disabled")
            }
            
            button.configuration = configuration
        }
        
        return button
    }()
    
    private lazy var workContactsFilterBarButtonItem: UIBarButtonItem = {
        let item = UIBarButtonItem(customView: workContactsFilterButton)
        item.accessibilityLabel = #localize("work_filter_button_accessibility_label")
        return item
    }()
    
    // MARK: - Lifecycle

    init(
        initialFilterItem: ContactListFilterItem = .contacts,
        delegate: ContactListActionDelegate? = nil
    ) {
        self.selectedItem = initialFilterItem
        self.delegate = delegate
        super.init(title: initialFilterItem.label)

        configureNavigationBarItems()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Private functions

    private func configureNavigationBarItems() {
        titleMenuProvider = { [weak self] _ in
            guard let self else {
                return nil
            }
            
            let menuItems = ContactListFilterItem.allCases
                .filter(\.enabled)
                .map { item in
                    UIAction(
                        title: item.label,
                        image: item.icon.uiImage,
                        identifier: UIAction.Identifier(item.label),
                        handler: { [weak self] _ in
                            self?.selectedItem = item
                            self?.delegate?.filterChanged(item)
                        }
                    )
                }
            
            return UIMenu(children: menuItems)
        }
        
        rightBarButtonItem = addMenuItem
        
        if TargetManager.isWork {
            leftBarButtonItem = workContactsFilterBarButtonItem
        }
    }
    
    @objc private func didToggleWorkContacts() {
        guard let delegate else {
            return
        }
        
        workContactsFilterActive.toggle()
        workContactsFilterButton.isSelected = workContactsFilterActive
        delegate.didToggleWorkContacts(workContactsFilterActive)
    }
}
