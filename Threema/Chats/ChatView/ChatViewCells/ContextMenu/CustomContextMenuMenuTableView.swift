//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2025 Threema GmbH
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

protocol CustomContextMenuMenuTableViewDelegate: AnyObject {
    func didSelectAction(completion: @escaping () -> Void)
}

class CustomContextMenuMenuTableView: UITableView {
    
    private let config: CustomContextMenuMenuTableViewConfig = .defaultConfig
    
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
        backgroundView = blurBackgroundView
        backgroundColor = .clear
        
        separatorInset = .zero
        separatorEffect = UIVibrancyEffect(blurEffect: blurEffect, style: .separator)
        
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
        
        if indexPath.row < numberOfRows(inSection: indexPath.section) - 1 {
            cell.separatorInset = .zero
        }
        else {
            cell.separatorInset = UIEdgeInsets(top: 0, left: bounds.size.width, bottom: 0, right: 0)
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        menuDelegate?.didSelectAction {
            self.actions[indexPath.section].actions[indexPath.row].handler()
        }
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        if section < actions.count - 1 {
            return config.sectionSpacingHeight
        }
        
        return 0
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let blurEffect = UIBlurEffect(style: .systemThinMaterial)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurEffectView.frame = bounds
        blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        blurEffectView.backgroundColor = traitCollection.userInterfaceStyle == .dark ? config
            .sectionBackgroundColorDark : config.sectionBackgroundColorLight
        return blurEffectView
    }
}
