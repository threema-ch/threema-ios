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

import CocoaLumberjackSwift
import Foundation
import GroupCalls
import ThreemaFramework

protocol GroupCallBannerButtonViewDelegate: AnyObject {
    func joinCall() async
}

final class GroupCallBannerView: UIView {
    
    // MARK: - Private Properties

    private var joinHandler: (() async -> Void)?
    private var startDate: Date?
    private var timer: Timer?

    // MARK: - Subviews

    private lazy var joinButton: UIButton = {
        let action = UIAction { [weak self] _ in
            DDLogVerbose("[GroupCall] Video Mute Button")
            Task {
                await self?.delegate?.joinCall()
            }
        }
        
        var buttonConfig = UIButton.Configuration.bordered()
        buttonConfig.title = BundleUtil.localizedString(forKey: "group_call_join_button_tittle")
        buttonConfig.image = UIImage(named: "phone.fill")
        buttonConfig.cornerStyle = .capsule

        let button = UIButton(configuration: buttonConfig, primaryAction: action)
        
        button.translatesAutoresizingMaskIntoConstraints = false
        
        return button
    }()
    
    private lazy var timeLabel: UILabel = {
        let label = UILabel()
        
        label.text = "0:00"
        label.font = UIFont.preferredFont(forTextStyle: .footnote).bold()
        label.sizeToFit()
        label.translatesAutoresizingMaskIntoConstraints = false
        
        return label
    }()
    
    private lazy var participantsLabel: UILabel = {
        let label = UILabel()
        
        // Since it takes some time to update, we initialize the label with 1 participant
        label.text = String.localizedStringWithFormat(
            BundleUtil.localizedString(forKey: "group_call_participants_title"),
            String(1)
        )
        label.font = UIFont.preferredFont(forTextStyle: .footnote).bold()
        label.sizeToFit()
        label.translatesAutoresizingMaskIntoConstraints = false
        
        return label
    }()
    
    private lazy var blurEffectView: UIVisualEffectView = {
        let blurEffect = UIBlurEffect(style: .systemMaterial)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        
        blurEffectView.translatesAutoresizingMaskIntoConstraints = false
        
        return blurEffectView
    }()
    
    private weak var delegate: GroupCallBannerButtonViewDelegate?

    // MARK: - Lifecycle

    convenience init(delegate: GroupCallBannerButtonViewDelegate) {
        self.init(frame: .zero)
        self.delegate = delegate
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        configureLayout()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func configureLayout() {
        layer.cornerCurve = .continuous
        layer.cornerRadius = 10
        layer.masksToBounds = true
        
        addSubview(blurEffectView)
        addSubview(joinButton)
        addSubview(timeLabel)
        addSubview(participantsLabel)

        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: blurEffectView.topAnchor),
            leadingAnchor.constraint(equalTo: blurEffectView.leadingAnchor),
            bottomAnchor.constraint(equalTo: blurEffectView.bottomAnchor),
            trailingAnchor.constraint(equalTo: blurEffectView.trailingAnchor),
            
            leadingAnchor.constraint(equalTo: participantsLabel.leadingAnchor, constant: -25),
            centerYAnchor.constraint(equalTo: participantsLabel.centerYAnchor),
            
            timeLabel.leadingAnchor.constraint(equalTo: participantsLabel.trailingAnchor, constant: 5),
            timeLabel.centerYAnchor.constraint(equalTo: participantsLabel.centerYAnchor),
            
            topAnchor.constraint(equalTo: joinButton.topAnchor, constant: -10),
            trailingAnchor.constraint(equalTo: joinButton.trailingAnchor, constant: 25),
            bottomAnchor.constraint(equalTo: joinButton.bottomAnchor, constant: 10),
            
            widthAnchor.constraint(greaterThanOrEqualToConstant: 100),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 50),
            heightAnchor.constraint(lessThanOrEqualToConstant: 100),
        ])
    }
    
    // MARK: - Updates
    
    public func updateBannerState(state: GroupCallButtonBannerState) {
        Task { @MainActor in
            switch state {
            case let .visible(info):
                participantsLabel.text = String.localizedStringWithFormat(
                    BundleUtil.localizedString(forKey: "group_call_participants_title"),
                    String(info.numberOfParticipants)
                )
                
                let text = info.joinState == .runningLocal ? BundleUtil
                    .localizedString(forKey: "group_call_open_button_title") : BundleUtil
                    .localizedString(forKey: "group_call_join_button_title")
                joinButton.configuration?.title = text
                
                startTimeLabelUpdates(startDate: info.startDate)
                isHidden = false
                
            case .hidden:
                timer?.invalidate()
                startDate = nil
                isHidden = true
            }
        }
    }
    
    private func startTimeLabelUpdates(startDate: Date) {
        guard self.startDate != startDate else {
            return
        }
        self.startDate = startDate
        
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { _ in
            let timeDiff = Date().timeIntervalSince(self.startDate ?? .now)
            let formatted = DateFormatter.timeFormatted(Int(timeDiff))
            self.timeLabel.text = formatted
        })
    }
}
