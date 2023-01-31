//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2023 Threema GmbH
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
import ThreemaFramework
import UIKit

@objc class MessageDetailsViewController: ThemedCodeModernGroupedTableViewController {
   
    private var messageID: NSManagedObjectID?
    private var groupAckList = [GroupDeliveryReceipt]()
    private var groupDeclineList = [GroupDeliveryReceipt]()
    
    private lazy var message: BaseMessage? = {
        let entityManager = EntityManager()
        var message: BaseMessage?
        
        entityManager.performBlockAndWait {
            message = entityManager.entityFetcher.existingObject(with: self.messageID) as? BaseMessage
        }
        
        if let message = message {
            addObservers(message)
        }
                
        return message
        
    }()
    
    // Cells
        
    private lazy var emptyCell: UITableViewCell = {
        let cell = createCell("emptyCell")
        return cell
    }()
    
    private lazy var sentCell: UITableViewCell = {
        let cell = createCell("sentCell")
        cell.textLabel!.text = BundleUtil.localizedString(forKey: "detailView_sent")
        return cell
    }()
    
    private lazy var deliveredCell: UITableViewCell = {
        let cell = createCell("deliveredCell")
        cell.textLabel!.text = BundleUtil.localizedString(forKey: "detailView_delivered")
        return cell
    }()
    
    private lazy var readCell: UITableViewCell = {
        let cell = createCell("readCell")
        cell.textLabel!.text = BundleUtil.localizedString(forKey: "detailView_read")
        return cell
    }()
    
    private lazy var ackCell: UITableViewCell = {
        let cell = createCell("ackCell")
        cell.textLabel!.text = BundleUtil.localizedString(forKey: "detailView_ackd")
        return cell
    }()
    
    private lazy var messageIDCell: UITableViewCell = {
        let cell = createCell("messageIDCell")
        cell.textLabel!.text = BundleUtil.localizedString(forKey: "detailView_messageID")
        return cell
    }()
    
    private lazy var forwardSecurityCell: UITableViewCell = {
        let cell = createCell("forwardSecurityCell")
        cell.textLabel!.text = BundleUtil.localizedString(forKey: "forward_security")
        return cell
    }()
    
    private lazy var debugTextView: UITextView = {
        let textView = UITextView()
        
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.isScrollEnabled = false
        
        return textView
    }()
    
    private lazy var debugCell: UITableViewCell = {
        let cell = createCell("debugCell")
        cell.addSubview(debugTextView)

        return cell
    }()
    
    private lazy var debugCellConstraints: [NSLayoutConstraint] = {
        [
            debugTextView.topAnchor.constraint(equalTo: debugCell.topAnchor, constant: 5),
            debugTextView.trailingAnchor.constraint(equalTo: debugCell.trailingAnchor, constant: 5),
            debugTextView.bottomAnchor.constraint(equalTo: debugCell.bottomAnchor, constant: 5),
            debugTextView.leadingAnchor.constraint(equalTo: debugCell.leadingAnchor, constant: 5),
        ]
    }()
    
    // Bools
    
    private var showDelivered = false
    private var showRead = false
    private var showAck = false
    private var showFs = false
    
    // MARK: - Lifecycle

    @objc init(messageID: NSManagedObjectID?) {
        self.messageID = messageID
        super.init()
    }
    
    deinit {
        removeObservers(message)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationBarTitle = BundleUtil.localizedString(forKey: "detailView_title")
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(MessageDetailReactionCell.self, forCellReuseIdentifier: "reactionCell")
                
        if ThreemaEnvironment.env() == .xcode {
            tableView.rowHeight = UITableView.automaticDimension
            tableView.estimatedRowHeight = UITableView.automaticDimension
            
            debugTextView.text = message.debugDescription
            
            debugCell.addSubview(debugTextView)
            NSLayoutConstraint.activate(debugCellConstraints)
        }

        configureLayout()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Updates

    override func updateColors() {
        super.updateColors()
    }
    
    // MARK: - Private functions
    
    @objc private func configureLayout() {
        
        guard let message = message else {
            return
        }
        
        sentCell.detailTextLabel!.text = DateFormatter.shortStyleDateTime(message.remoteSentDate)
        
        if let deliveryDate = message.deliveryDate {
            deliveredCell.detailTextLabel!.text = DateFormatter.shortStyleDateTime(deliveryDate)
            showDelivered = true
        }
        
        if let readDate = message.readDate {
            readCell.detailTextLabel!.text = DateFormatter.shortStyleDateTime(readDate)
            showRead = true
        }
        
        if let ackDate = message.userackDate {
            ackCell.detailTextLabel!.text = DateFormatter.shortStyleDateTime(ackDate)
            showAck = true
        }
        
        if !message.isGroupMessage {
            showFs = true
        }

        messageIDCell.detailTextLabel!.text = NSString(hexData: message.id) as String?
        
        let forwardSecurityMode = ForwardSecurityMode(message.forwardSecurityMode.uintValue)
        switch forwardSecurityMode {
        case kForwardSecurityModeTwoDH:
            forwardSecurityCell.detailTextLabel!.text = BundleUtil.localizedString(forKey: "forward_security_2dh")
        case kForwardSecurityModeFourDH:
            forwardSecurityCell.detailTextLabel!.text = BundleUtil.localizedString(forKey: "forward_security_4dh")
        default:
            forwardSecurityCell.detailTextLabel!.text = BundleUtil.localizedString(forKey: "forward_security_none")
        }
        
        groupAckList = message.groupReactions(for: .acknowledged)
        groupDeclineList = message.groupReactions(for: .declined)
    }
    
    private func addObservers(_ message: BaseMessage) {
        message.addObserver(self, forKeyPath: "deliveryDate", options: [], context: nil)
        message.addObserver(self, forKeyPath: "readDate", options: [], context: nil)
        message.addObserver(self, forKeyPath: "userackDate", options: [], context: nil)
        message.addObserver(self, forKeyPath: "groupDeliveryReceipts", options: [], context: nil)
    }
    
    private func removeObservers(_ message: BaseMessage?) {
        message?.removeObserver(self, forKeyPath: "deliveryDate")
        message?.removeObserver(self, forKeyPath: "readDate")
        message?.removeObserver(self, forKeyPath: "userackDate")
        message?.removeObserver(self, forKeyPath: "groupDeliveryReceipts")
    }
    
    override internal func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey: Any]?,
        context: UnsafeMutableRawPointer?
    ) {
        
        configureLayout()
        tableView.reloadData()
    }
    
    private func createCell(_ reuseIdentifier: String) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: reuseIdentifier)
        cell.selectionStyle = .none
        cell.backgroundColor = Colors.backgroundTableViewCell
        return cell
    }
    
    private func numberOfCells() -> Int {
        detailCells.count
    }
    
    private func cellForRow(_ row: Int) -> UITableViewCell {
        detailCells[row]
    }
    
    private lazy var detailCells: [UITableViewCell] = {
        var cells = [sentCell]
        if showDelivered {
            cells.append(deliveredCell)
        }
        if showRead {
            cells.append(readCell)
        }
        if showAck {
            cells.append(ackCell)
        }
        if showFs {
            cells.append(forwardSecurityCell)
        }
        cells.append(messageIDCell)
        
        if ThreemaEnvironment.env() == .xcode {
            cells.append(debugCell)
        }
        return cells
    }()
}

// MARK: - UITableViewDelegate, UITableViewDataSource

extension MessageDetailsViewController: UITableViewDelegate, UITableViewDataSource {
      
    func numberOfSections(in tableView: UITableView) -> Int {
        var sections = 1
        
        if !groupAckList.isEmpty {
            sections += 1
        }
        
        if !groupDeclineList.isEmpty {
            sections += 1
        }
        
        return sections
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return numberOfCells()
        case 1:
            if !groupAckList.isEmpty {
                return groupAckList.count
            }
            return groupDeclineList.count
        case 2:
            return groupDeclineList.count
        default:
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return BundleUtil.localizedString(forKey: "details")
        case 1:
            if !groupAckList.isEmpty {
                return String.localizedStringWithFormat(
                    BundleUtil.localizedString(forKey: "detailView_group_acknowledged"),
                    groupAckList.count
                )
            }
            return String.localizedStringWithFormat(
                BundleUtil.localizedString(forKey: "detailView_group_declined"),
                groupDeclineList.count
            )
        case 2:
            return String.localizedStringWithFormat(
                BundleUtil.localizedString(forKey: "detailView_group_declined"),
                groupDeclineList.count
            )
        default:
            return nil
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        switch indexPath.section {
        case 0:
            return cellForRow(indexPath.row)
        case 1:
            let cell = tableView.dequeueReusableCell(withIdentifier: "reactionCell") as? MessageDetailReactionCell ??
                MessageDetailReactionCell(style: .value1, reuseIdentifier: "reactionCell")
            var groupDeliveryReceipt: GroupDeliveryReceipt
            if !groupAckList.isEmpty {
                groupDeliveryReceipt = groupAckList[indexPath.row]
            }
            else {
                groupDeliveryReceipt = groupDeclineList[indexPath.row]
            }
            cell.setGroupDeliveryReceipt(
                groupDeliveryReceipt: groupDeliveryReceipt
            )
            
            return cell
        case 2:
            let cell = tableView.dequeueReusableCell(withIdentifier: "reactionCell") as? MessageDetailReactionCell ??
                MessageDetailReactionCell(style: .value1, reuseIdentifier: "reactionCell")
            cell.setGroupDeliveryReceipt(
                groupDeliveryReceipt: groupDeclineList[indexPath.row]
            )
            
            return cell
        default:
            return emptyCell
        }
    }
    
    // MARK: - Copying
    
    func tableView(_ tableView: UITableView, shouldShowMenuForRowAt indexPath: IndexPath) -> Bool {
        // Only show copy for last cell in second section
        (tableView.cellForRow(at: indexPath)?.detailTextLabel?.text) != nil && indexPath.section == 0 && indexPath
            .row == numberOfCells() - (ThreemaEnvironment.env() == .xcode ? 2 : 1)
    }

    func tableView(
        _ tableView: UITableView,
        canPerformAction action: Selector,
        forRowAt indexPath: IndexPath,
        withSender sender: Any?
    ) -> Bool {
        action == #selector(copy(_:))
    }

    func tableView(
        _ tableView: UITableView,
        performAction action: Selector,
        forRowAt indexPath: IndexPath,
        withSender sender: Any?
    ) {
        if action == #selector(copy(_:)) {
            let cell = tableView.cellForRow(at: indexPath)
            let pasteboard = UIPasteboard.general
            pasteboard.string = cell?.detailTextLabel?.text
        }
    }
}
