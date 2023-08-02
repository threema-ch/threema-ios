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
            groupCallViewControllerDelegate: self,
            dependencies: dependencies
        )
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        
        toolbar.clipsToBounds = true
        return toolbar
    }()
    
    private lazy var collectionView: GroupCallCollectionView = {
        let collectionView = GroupCallCollectionView(groupCallViewModel: viewModel)
        
        collectionView.contentInsetAdjustmentBehavior = .never
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
        
        // TODO: Make this prettier
        self.viewModel.viewDelegate = self
        self.hidesBottomBarWhenPushed = true
        
        isModalInPresentation = true
        modalPresentationStyle = .overFullScreen
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        setup()
        
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(hideOverlay(_:)))
        collectionView.addGestureRecognizer(tapGestureRecognizer)
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updateLayout()
        
        viewModel.startPeriodicUIUpdatesIfNeeded()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(orientationChanged),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
    }
    
    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
    }
    
    override public var prefersStatusBarHidden: Bool {
        true
    }
    
    public func has(_ viewModel: GroupCallViewModel) -> Bool {
        viewModel.groupCallActor == self.viewModel.groupCallActor
    }
    
    private func setup() {
        
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
    
    @objc private func orientationChanged() {
        // "Fixes" a bug when rotating iPhones
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100)) {
            self.updateLayout()
        }
    }
    
    // MARK: - Private Functions
    
    @objc private func hideOverlay(_ sender: UITapGestureRecognizer) {
        if sender.state == .ended {
            toolbar.toggleVisibility()
            groupCallNavigationBar.toggleVisibility()
        }
    }
}

// MARK: - GroupCallViewControllerDelegate

extension GroupCallViewController: GroupCallViewControllerDelegate {
    func dismiss() {
        dismiss(animated: true)
    }
}

// MARK: - GroupCallViewProtocol

extension GroupCallViewController: GroupCallViewProtocol {
    func updateNavigationContent(_ contentUpdate: GroupCallNavigationBarContentUpdate) async {
        groupCallNavigationBar.updateContent(contentUpdate)
    }

    @MainActor
    func updateLayout() {
        collectionView.updateLayout()
    }
    
    @MainActor
    func close() async {
        // TODO: This needs to handle global group call views
        await withCheckedContinuation { continuation in
            self.dismiss(animated: true) { [self] in
                if navigationController?.topViewController is GroupCallViewController {
                    navigationController?.popViewController(animated: true)
                }
                continuation.resume()
            }
        }
    }
}
