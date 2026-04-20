import Foundation

protocol CustomContextMenuMenuTableViewDelegate: AnyObject {
    func didSelectAction(completion: @escaping () -> Void)
}

final class CustomContextMenuMenuTableView: UITableView {
    
    private let config: CustomContextMenuMenuTableViewConfig =
        if #available(iOS 26.0, *) {
            .glassConfig
        }
        else {
            .defaultConfig
        }
    
    private let actions: [ChatViewMessageActionsProvider.MessageActionsSection]
    private weak var menuDelegate: CustomContextMenuMenuTableViewDelegate?

    private let blurEffect = UIBlurEffect(style: .systemThinMaterial)
    
    private lazy var blurBackgroundView: UIVisualEffectView = {
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        
        blurEffectView.frame = bounds
        blurEffectView.backgroundColor = traitCollection.userInterfaceStyle == .dark ? config
            .tableViewBackgroundColorDark : config.tableViewBackgroundColorLight
        blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        return blurEffectView
    }()
    
    // MARK: - Lifecycle

    init(
        actions: [ChatViewMessageActionsProvider.MessageActionsSection],
        menuDelegate: CustomContextMenuMenuTableViewDelegate
    ) {
        self.actions = actions
        self.menuDelegate = menuDelegate
        
        super.init(frame: .zero, style: .plain)
        
        configureTableView()
        configureView()
        registerCells()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        
        if bounds.size != intrinsicContentSize {
            invalidateIntrinsicContentSize()
        }
    }
        
    override public var intrinsicContentSize: CGSize {
        layoutIfNeeded()
        return contentSize
    }
    
    // MARK: - Private functions

    private func configureTableView() {
        dataSource = self
        delegate = self
        
        rowHeight = UITableView.automaticDimension
        estimatedRowHeight = 44
    }
    
    private func configureView() {
        
        if #available(iOS 26.0, *) {
            backgroundColor = .clear
            
            contentInset = UIEdgeInsets(
                top: config.tableViewInset,
                left: 0,
                bottom: -config.tableViewInset,
                right: 0
            )
            
            separatorInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: .greatestFiniteMagnitude)
        }
        else {
            backgroundView = blurBackgroundView
            backgroundColor = .clear
            
            separatorInset = .zero
            separatorEffect = UIVibrancyEffect(blurEffect: blurEffect, style: .separator)
        }
        
        alwaysBounceVertical = false
        showsVerticalScrollIndicator = false
        
        layer.cornerRadius = config.tableViewCornerRadius
        layer.cornerCurve = .continuous
        
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: config.tableViewWidth).isActive = true
    }
    
    private func registerCells() {
        registerCell(CustomContextMenuMenuTableViewDefaultCell.self)
        registerCell(CustomContextMenuMenuTableViewStackCell.self)
    }
}

// MARK: - UITableViewDataSource, UITableViewDelegate

extension CustomContextMenuMenuTableView: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        actions.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard section < actions.count else {
            return 0
        }
        
        if case .horizontalInline = actions[section].sectionType {
            return 1
        }
        else {
            return actions[section].actions.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let sectionActions = actions[indexPath.section]
        
        let cell: UITableViewCell
        if case .horizontalInline = sectionActions.sectionType {
            let stackCell: CustomContextMenuMenuTableViewStackCell = tableView.dequeueCell(for: indexPath)
            
            stackCell.actions = actions[indexPath.section].actions
            stackCell.menuDelegate = menuDelegate
            
            cell = stackCell
        }
        else {
            let defaultCell: CustomContextMenuMenuTableViewDefaultCell = tableView.dequeueCell(for: indexPath)
            
            defaultCell.action = actions[indexPath.section].actions[indexPath.row]
            
            cell = defaultCell
        }
        
        if #unavailable(iOS 26.0) {
            if indexPath.row < numberOfRows(inSection: indexPath.section) - 1 {
                cell.separatorInset = .zero
            }
            else {
                cell.separatorInset = UIEdgeInsets(top: 0, left: bounds.size.width, bottom: 0, right: 0)
            }
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        menuDelegate?.didSelectAction {
            self.actions[indexPath.section].actions[indexPath.row].handler()
        }
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        if #available(iOS 26.0, *) {
            guard section < actions.count - 1 else {
                // After the last section we only need a bit of space w/o any view
                // One config.tableViewInset is removed a again with the contentInset. This prevents the menu to scroll
                // when it fits the screen
                return config.tableViewInset * 2
            }
            
            return config.sectionSpacingHeight
        }
        
        if section < actions.count - 1 {
            return config.sectionSpacingHeight
        }
        
        return 0
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        if #available(iOS 26.0, *) {
            // Exempt last footer
            guard section < actions.count - 1 else {
                return nil
            }
            
            let hairlineView = UIView()
            hairlineView.backgroundColor = traitCollection.userInterfaceStyle == .dark ? config
                .sectionBackgroundColorDark : config.sectionBackgroundColorLight
            hairlineView.translatesAutoresizingMaskIntoConstraints = false
            
            let view = UIView()
            view.backgroundColor = .clear
            view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            
            view.addSubview(hairlineView)
            
            NSLayoutConstraint.activate([
                hairlineView.leadingAnchor.constraint(
                    equalTo: view.leadingAnchor,
                    constant: config.itemLeadingTrailingInset + config.additionalSeparatorInset
                ),
                hairlineView.trailingAnchor.constraint(
                    equalTo: view.trailingAnchor,
                    constant: -config.itemLeadingTrailingInset - config.additionalSeparatorInset
                ),
                hairlineView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                hairlineView.heightAnchor.constraint(equalToConstant: 1),
            ])

            return view
        }
        else {
            let blurEffect = UIBlurEffect(style: .systemThinMaterial)
            let blurEffectView = UIVisualEffectView(effect: blurEffect)
            blurEffectView.frame = bounds
            blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            blurEffectView.backgroundColor = traitCollection.userInterfaceStyle == .dark ? config
                .sectionBackgroundColorDark : config.sectionBackgroundColorLight
            return blurEffectView
        }
    }
}
