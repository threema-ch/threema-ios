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

protocol CustomContextMenuViewControllerDelegate: AnyObject {
    func dismiss(completion: (() -> Void)?)
}

class CustomContextMenuViewController: UIViewController {
    
    typealias Config = CustomContextMenuConfiguration
    
    private weak var delegate: CustomContextMenuViewControllerDelegate?
        
    /// The bounds of the snapshot in its window
    private let snapshotBounds: CGRect
    // The bounds of the chat view, needed for iPad
    private let chatViewBounds: CGRect
    private let isOwnMessage: Bool
    private let showEmojiPicker: Bool
    private let reactionsManager: ReactionsManager?
    private let actions: [ChatViewMessageActionsProvider.MessageActionsSection]?
    
    private lazy var transform: CGAffineTransform =
        if snapshotBounds.height > UIScreen.main.bounds.height * 0.7 {
            Config.Animation.transformDown
        }
        else {
            Config.Animation.transformUp
        }
    
    // MARK: - Subviews
    
    // MARK: AuxiliaryView

    private lazy var auxiliaryView: UIView = {
        let reactionView = MessageReactionContextMenuUIView(
            forHighlighting: true,
            isOwnMessage: isOwnMessage,
            reactionsManager: reactionsManager
        ).view ?? UIView()
        
        reactionView.setContentCompressionResistancePriority(.required, for: .vertical)
        reactionView.translatesAutoresizingMaskIntoConstraints = false
        return reactionView
    }()
    
    private lazy var auxTopConstraint = auxiliaryView.topAnchor
        .constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.topAnchor)
    
    private lazy var auxWidthConstraint = auxiliaryView.widthAnchor
        .constraint(lessThanOrEqualToConstant: chatViewBounds.width)
    
    private lazy var auxTrailingConstraint = auxiliaryView.trailingAnchor
        .constraint(equalTo: snapshotContainerView.trailingAnchor)
    
    private lazy var auxLeadingConstraint = auxiliaryView.leadingAnchor
        .constraint(equalTo: snapshotContainerView.leadingAnchor)
    
    private lazy var auxBottomConstraint = {
        let constraint = auxiliaryView.bottomAnchor.constraint(
            equalTo: snapshotContainerView.topAnchor,
            constant: -Config.Layout.verticalSpacing
        )
        constraint.priority = .required
        return constraint
    }()
    
    private lazy var auxConstraints: [NSLayoutConstraint] = {
        var constraints = [auxTopConstraint, auxBottomConstraint, auxWidthConstraint]
        if isOwnMessage {
            constraints.append(auxTrailingConstraint)
        }
        else {
            constraints.append(auxLeadingConstraint)
        }
        
        return constraints
    }()
    
    // MARK: SnapshotView

    private var snapshotView: UIView
    
    // Adding a container view facilitates the constraint handling when transforming the snapshot view itself
    private lazy var snapshotContainerView: UIView = {
        let snapshotContainerView = UIView()
        snapshotContainerView.translatesAutoresizingMaskIntoConstraints = false
        return snapshotContainerView
    }()
    
    private lazy var snapshotVerticalAlignmentConstraint = {
        let constraint = snapshotView.topAnchor.constraint(equalTo: view.topAnchor, constant: snapshotBounds.minY)
        constraint.priority = .defaultHigh
        return constraint
    }()
    
    private lazy var snapshotHeightConstraint = snapshotView.heightAnchor
        .constraint(equalToConstant: snapshotBounds.height)
    
    private lazy var snapshotCenterXConstraint = snapshotContainerView.centerXAnchor
        .constraint(equalTo: snapshotView.centerXAnchor)
    
    private lazy var snapshotHorizontalAlignmentConstraint = {
        let constraint = snapshotView.leadingAnchor.constraint(
            equalTo: view.leadingAnchor,
            constant: snapshotBounds.minX
        )
        constraint.priority = .defaultHigh
        return constraint
    }()
    
    private lazy var snapshotWidthConstraint = snapshotView.widthAnchor
        .constraint(equalToConstant: snapshotBounds.width)
    
    private lazy var snapshotCenterYConstraint = snapshotContainerView.centerYAnchor
        .constraint(equalTo: snapshotView.centerYAnchor)
    
    // Collection of constraints used to align the cell to the same position as in the ChatView
    private lazy var initialSnapshotConstraints: [NSLayoutConstraint] = [
        snapshotHorizontalAlignmentConstraint,
        snapshotVerticalAlignmentConstraint,
        snapshotWidthConstraint,
        snapshotHeightConstraint,
        snapshotCenterXConstraint,
        snapshotCenterYConstraint,
    ]
    
    private lazy var snapshotContainerBottomConstraint: NSLayoutConstraint = {
        let constraint = snapshotContainerView.bottomAnchor.constraint(
            equalTo: menuView.topAnchor,
            constant: -Config.Layout.verticalSpacing
        )
        constraint.priority = .required - 1
        return constraint
    }()
    
    private lazy var snapshotContainerHorizontalAlignmentConstraint: NSLayoutConstraint =
        if isOwnMessage {
            snapshotContainerView.trailingAnchor.constraint(
                equalTo: view.trailingAnchor,
                constant: -Config.Layout.leadingTrailingInset
            )
        }
        else {
            snapshotContainerView.leadingAnchor.constraint(
                equalTo: view.trailingAnchor,
                constant: -chatViewBounds.width + Config.Layout.leadingTrailingInset
            )
        }
    
    private lazy var snapshotContainerSizeConstraints = [
        snapshotContainerView.widthAnchor
            .constraint(equalToConstant: snapshotBounds.width * transform.a),
        snapshotContainerView.heightAnchor
            .constraint(equalToConstant: snapshotBounds.height * transform.d),
    ]
    
    // Collection of constraints used to make the snapshot animate
    private lazy var targetSnapshotConstraints: [NSLayoutConstraint] = [
        snapshotContainerHorizontalAlignmentConstraint,
    ] + snapshotContainerSizeConstraints + [snapshotContainerBottomConstraint]
    
    // MARK: MenuView

    private lazy var menuView: UIView = {
        let menuView = CustomContextMenuMenuTableView(actions: actions!, menuDelegate: self)
        menuView.translatesAutoresizingMaskIntoConstraints = false
        menuView.setContentCompressionResistancePriority(.required, for: .vertical)
        menuView.setContentCompressionResistancePriority(.required, for: .horizontal)

        let containerView = UIView()
        containerView.addSubview(menuView)
        containerView.layer.opacity = 0
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.layer.shadowRadius = Config.SnapshotView.shadowRadius
        containerView.layer.shadowOffset = Config.SnapshotView.shadowOffset
        containerView.layer.shadowColor = Config.SnapshotView.shadowColor.cgColor
        containerView.layer.shadowOpacity = Config.SnapshotView.shadowOpacity
        
        NSLayoutConstraint.activate([
            menuView.topAnchor.constraint(equalTo: containerView.topAnchor),
            menuView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            menuView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            menuView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
        ])
        
        return containerView
    }()
    
    private lazy var menuTrailingConstraint = menuView.trailingAnchor
        .constraint(equalTo: snapshotContainerView.trailingAnchor)
    
    private lazy var menuLeadingConstraint = menuView.leadingAnchor
        .constraint(equalTo: snapshotContainerView.leadingAnchor)
    
    private lazy var menuHeightConstraint = menuView.heightAnchor
        .constraint(lessThanOrEqualToConstant: chatViewBounds.height / 2)
    
    private lazy var menuBottomConstraint = {
        let constraint = menuView.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor)
        constraint.priority = .required
        return constraint
    }()
    
    private lazy var menuConstraints: [NSLayoutConstraint] = {
        var constraints = [menuHeightConstraint, menuBottomConstraint]
        
        if isOwnMessage {
            constraints.append(menuTrailingConstraint)
        }
        else {
            constraints.append(menuLeadingConstraint)
        }
        
        return constraints
    }()
    
    // MARK: BlurBackgroundView
    
    private lazy var blurBackgroundView: UIVisualEffectView = {
        let blurEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurEffectView.frame = view.bounds
        blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        blurEffectView.layer.opacity = 0.0
      
        return blurEffectView
    }()
    
    // MARK: - Private properties
    
    private lazy var backgroundTapGestureRecognizer: UITapGestureRecognizer = {
        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(tappedToDismiss))
        return gestureRecognizer
    }()
    
    private lazy var snapshotTapGestureRecognizer: UITapGestureRecognizer = {
        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(tappedToDismiss))
        return gestureRecognizer
    }()
    
    // MARK: - Lifecycle

    public init(
        delegate: CustomContextMenuViewControllerDelegate,
        snapshot: UIView,
        snapshotBounds: CGRect,
        chatViewBounds: CGRect,
        isOwnMessage: Bool,
        showEmojiPicker: Bool,
        reactionsManager: ReactionsManager?,
        actions: [ChatViewMessageActionsProvider.MessageActionsSection]?
    ) {
        self.delegate = delegate
        self.snapshotView = snapshot
        self.snapshotBounds = snapshotBounds
        self.chatViewBounds = chatViewBounds
        self.showEmojiPicker = showEmojiPicker
        self.isOwnMessage = isOwnMessage
        self.reactionsManager = reactionsManager
        self.actions = actions
        super.init(nibName: nil, bundle: nil)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureLayout()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        animateIn()
    }
    
    // MARK: - Layout

    private func configureLayout() {
        configureSnapshotView()
        
        snapshotContainerView.addSubview(snapshotView)
        view.addSubview(blurBackgroundView)
        view.addSubview(snapshotContainerView)
        view.addSubview(menuView)
        if showEmojiPicker {
            view.addSubview(auxiliaryView)
        }
        
        NSLayoutConstraint.activate(initialSnapshotConstraints)
        
        snapshotView.addGestureRecognizer(snapshotTapGestureRecognizer)
        blurBackgroundView.addGestureRecognizer(backgroundTapGestureRecognizer)
    }
    
    private func configureSnapshotView() {
        snapshotView.layer.shadowRadius = Config.SnapshotView.shadowRadius
        snapshotView.layer.shadowOffset = Config.SnapshotView.shadowOffset
        snapshotView.layer.shadowColor = Config.SnapshotView.shadowColor.cgColor
        snapshotView.layer.shadowOpacity = Config.SnapshotView.shadowOpacity
        snapshotView.translatesAutoresizingMaskIntoConstraints = false
    }
    
    // MARK: - Animation
    
    private func animateIn() {
        if showEmojiPicker {
            NSLayoutConstraint.activate(auxConstraints)
        }
        NSLayoutConstraint.activate(targetSnapshotConstraints)
        NSLayoutConstraint.activate(menuConstraints)
        
        view.setNeedsLayout()
        
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseIn) {
            self.blurBackgroundView.layer.opacity = 1.0
            // First we always want to slightly increase the size of the message bubble
            self.snapshotView.transform = Config.Animation.transformUp
        }
        
        UIView.animate(
            withDuration: 0.3,
            delay: 0.3,
            usingSpringWithDamping: 0.75,
            initialSpringVelocity: 0.1,
            options: .curveEaseIn
        ) {
            self.snapshotView.transform = self.transform
            self.view.layoutIfNeeded()
        }
        
        UIView.animate(withDuration: 0.2, delay: 0.5, options: .curveEaseOut) {
            self.menuView.layer.opacity = 1.0
            self.auxiliaryView.layer.opacity = 1.0
        }
    }
    
    private func animateOut(completion: @escaping () -> Void) {
        if showEmojiPicker {
            NSLayoutConstraint.deactivate(auxConstraints)
        }
        NSLayoutConstraint.deactivate(targetSnapshotConstraints)
        NSLayoutConstraint.deactivate(menuConstraints)
        
        view.setNeedsLayout()
        
        UIView.animate(withDuration: 0.2, delay: 0.0, options: .curveEaseIn) {
            self.menuView.layer.opacity = 0
            self.auxiliaryView.layer.opacity = 0
        }
        
        UIView.animate(
            withDuration: 0.25,
            delay: 0.2,
            usingSpringWithDamping: 1,
            initialSpringVelocity: 0.1,
            options: .curveEaseOut
        ) {
            self.snapshotView.transform = .identity
            self.view.layoutIfNeeded()
        }
        
        UIView.animate(withDuration: 0.32, delay: 0.2, options: .curveEaseIn) {
            self.blurBackgroundView.layer.opacity = 0.0
        } completion: { _ in
            // Ensure that this completion hander is called after the last animation is completed
            completion()
        }
    }
    
    /// This should not be called directly from within this class; call ` delegate?.dismiss()` instead.
    public func dismiss(completion: (() -> Void)? = nil) {
        animateOut { [weak self] in
            self?.view.removeFromSuperview()
            completion?()
        }
    }
    
    // MARK: - Private functions

    @objc private func tappedToDismiss() {
        // We handle dismissing via the delegate to facilitate updating the chat view
        delegate?.dismiss(completion: nil)
    }
}

// MARK: - CustomContextMenuMenuTableViewDelegate

extension CustomContextMenuViewController: CustomContextMenuMenuTableViewDelegate {
    func didSelectAction(completion: @escaping () -> Void) {
        // We handle dismissing via the delegate to facilitate updating the chat view
        delegate?.dismiss(completion: completion)
    }
}
