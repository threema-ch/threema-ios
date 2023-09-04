//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023 Threema GmbH
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
import UIKit

protocol GroupCallViewControllerDelegate: AnyObject {
    func dismiss() async
}

public class GroupCallViewController: UIViewController {
    
    // MARK: - Subviews
    
    private lazy var toolbar: GroupCallToolbar = {
        let toolbar = GroupCallToolbar(
            viewModel: viewModel,
            dependencies: dependencies
        )
                
        toolbar.clipsToBounds = true
        
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        return toolbar
    }()
    
    private lazy var collectionView: GroupCallCollectionView = {
        let collectionView = GroupCallCollectionView(groupCallViewModel: viewModel)
        
        collectionView.contentInsetAdjustmentBehavior = .never // TODO: (IOS-4049) Verify insets
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        return collectionView
    }()
    
    private lazy var groupCallNavigationBar: GroupCallNavigationBar = {
        let navigationBar = GroupCallNavigationBar(groupCallViewControllerDelegate: self)
        navigationBar.translatesAutoresizingMaskIntoConstraints = false
        return navigationBar
    }()
    
    // MARK: - Private Properties

    // TODO: Maybe Allow dynamic view model change
    var viewModel: GroupCallViewModel
    private var dependencies: Dependencies
    
    // MARK: - Lifecycle
    
    public init(viewModel: GroupCallViewModel, dependencies: Dependencies) {
        self.viewModel = viewModel
        self.dependencies = dependencies

        super.init(nibName: nil, bundle: nil)

        self.viewModel.setViewDelegate(self)

        configureViewController()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        configureSubviews()
        addGestureRecognizer()
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        UIApplication.shared.isIdleTimerDisabled = true

        updateCollectionViewLayout()
        
        viewModel.startPeriodicUIUpdatesIfNeeded()

        // TODO: (IOS-4049) This is apparently also needed to get the correct layout when number of users changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(orientationChanged),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
    }
    
    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        UIApplication.shared.isIdleTimerDisabled = false

        NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
    }
    
    // MARK: - Configuration
    
    private func configureViewController() {
        hidesBottomBarWhenPushed = true
        modalPresentationStyle = .overFullScreen // TODO: (IOS-4049) Whats the difference to `.fullScreen`?
        
        // TODO: (IOS-4049) Should we adapt dark mode for all GC views?
        // overrideUserInterfaceStyle = .dark
    }
    
    private func configureSubviews() {
        view.addSubview(collectionView)
        view.addSubview(groupCallNavigationBar)
        view.addSubview(toolbar)
        
        NSLayoutConstraint.activate([
            groupCallNavigationBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            groupCallNavigationBar.topAnchor.constraint(equalTo: view.topAnchor),
            groupCallNavigationBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toolbar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }
    
    private func addGestureRecognizer() {
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(hideOverlay(_:)))
        collectionView.addGestureRecognizer(tapGestureRecognizer)
    }
    
    override public var prefersHomeIndicatorAutoHidden: Bool {
        true
    }
    
    // MARK: - Private Functions
    
    @objc private func hideOverlay(_ sender: UITapGestureRecognizer) {
        if sender.state == .ended {
            toolbar.toggleVisibility()
            groupCallNavigationBar.toggleVisibility()
        }
    }
    
    @objc private func orientationChanged() {
        // "Fixes" a bug when rotating iPhones
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100)) {
            self.updateCollectionViewLayout()
        }
    }
}

// MARK: - GroupCallViewControllerDelegate

extension GroupCallViewController: GroupCallViewControllerDelegate {
    func dismiss() {
        dismiss(animated: true)
    }
}

// MARK: - GroupCallViewModelDelegate

extension GroupCallViewController: GroupCallViewModelDelegate {
    func updateNavigationContent(_ contentUpdate: GroupCallNavigationBarContentUpdate) async {
        groupCallNavigationBar.updateContent(contentUpdate)
    }

    func updateCollectionViewLayout() {
        Task { @MainActor in
            collectionView.updateLayout()
        }
    }
    
    func dismissGroupCallView() {
        Task { @MainActor in
            self.dismiss(animated: true)
        }
    }
}
