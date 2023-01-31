//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2023 Threema GmbH
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

import UIKit

extension DetailsHeaderView {
    struct Configuration {
        /// Show debug background colors
        let debug = false
        
        let defaultSpacing: CGFloat = 35
        let smallerSpacing: CGFloat = 24
        
        let topMargin: CGFloat = 0
        // defaultSpacing - spacing on top of first cell (i.e. 35 - 17)
        let bottomMargin: CGFloat = 18
    }
}

/// Header view for a details screen
///
/// - Note: This views margins don't include safe areas automatically. Either set them yourself or set constraints to
///         `safeAreaLayoutGuide`s.
final class DetailsHeaderView: UIStackView {
    
    /// Set to update shown profile
    var profileContentConfiguration: DetailsHeaderProfileView.ContentConfiguration {
        didSet {
            detailsHeaderProfileView.contentConfiguration = profileContentConfiguration
        }
    }
    
    // MARK: - Private properties
    
    private let avatarImageTapped: () -> Void
    
    private let quickActions: [QuickAction]
    private let mediaAndPollsQuickActions: [QuickAction]
    
    private let configuration: Configuration
        
    // MARK: - Subviews
    
    private lazy var detailsHeaderProfileView = DetailsHeaderProfileView(
        with: profileContentConfiguration,
        avatarImageTapped: avatarImageTapped
    )
    
    private lazy var quickActionsView = QuickActionsView(quickActions: quickActions)
    
    private lazy var mediaAndPollsQuickActionsView = QuickActionsView(
        quickActions: mediaAndPollsQuickActions,
        shadow: false
    )
            
    // MARK: - Initialization
    
    init(
        with contentConfiguration: DetailsHeaderProfileView.ContentConfiguration,
        avatarImageTapped: @escaping () -> Void,
        quickActions: [QuickAction] = [],
        mediaAndPollsQuickActions: [QuickAction] = [],
        configuration: Configuration = Configuration()
    ) {
        self.profileContentConfiguration = contentConfiguration
        self.avatarImageTapped = avatarImageTapped
        self.quickActions = quickActions
        self.mediaAndPollsQuickActions = mediaAndPollsQuickActions
        self.configuration = configuration
        
        super.init(frame: .zero)
        
        configureView()
        
        addObservers()
    }
    
    @available(*, unavailable, message: "Use init(for:delegate:with:)")
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
        
    // MARK: - Configuration
    
    private func configureView() {

        axis = .vertical
        spacing = configuration.defaultSpacing

        directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: configuration.topMargin,
            leading: 0,
            bottom: configuration.bottomMargin,
            trailing: 0
        )
        isLayoutMarginsRelativeArrangement = true
        updateContentPadding()
        
        if configuration.debug {
            backgroundColor = .systemGreen
        }
        
        addArrangedSubview(detailsHeaderProfileView)
        setCustomSpacing(configuration.smallerSpacing, after: detailsHeaderProfileView)
        
        if !quickActions.isEmpty {
            addArrangedSubview(quickActionsView)
        }
        
        if !mediaAndPollsQuickActions.isEmpty {
            addArrangedSubview(mediaAndPollsQuickActionsView)
        }
    }
    
    private func addObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateContentPadding),
            name: Notification.Name(kNotificationNavigationBarColorShouldChange),
            object: nil
        )
    }
    
    @objc private func updateContentPadding() {
        if VoIPHelper.shared().isCallActiveInBackground || WCSessionHelper.isWCSessionConnected {
            directionalLayoutMargins.top = configuration.bottomMargin
        }
        else {
            directionalLayoutMargins.top = configuration.topMargin
        }
    }
    
    // MARK: - Update
    
    func reloadQuickActions() {
        quickActionsView.reload()
    }
    
    // MARK: - Action
    
    func autoShowThreemaTypeInfo() {
        detailsHeaderProfileView.autoShowThreemaTypeInfo()
    }
}
