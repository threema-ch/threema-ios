//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2023 Threema GmbH
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

/// Show and change `PushSetting` for a conversation or contact
///
/// It is only optimized to be shown modally. Please wrap it into a `ThemedNavigationController` when doing so. It will dismiss
/// itself.
///
/// Don't change the settings of the same conversation or contact at another place the same time. Otherwise they changes will be
/// overridden when the controller dismisses itself.
final class DoNotDisturbViewController: ThemedCodeModernGroupedTableViewController {

    // MARK: - Private types

    private enum Section: Hashable {
        case activeDND
        case selectPeriod
        case notifyWhenMentionedSetting
    }
    
    private enum Row: Hashable {
        case activeDNDInfo
        case turnOffDNDButton
        case periodButton(duration: PeriodOffTime)
        case foreverButton
        case notifyWhenMentionedSetting
    }
    
    /// Simple subclass to provide easy header and footer string configuration
    private class DataSource: UITableViewDiffableDataSource<Section, Row> {
        typealias SupplementaryProvider = (UITableView, Section) -> String?
        
        let headerProvider: SupplementaryProvider
        let footerProvider: SupplementaryProvider
        
        init(
            tableView: UITableView,
            cellProvider: @escaping UITableViewDiffableDataSource<Section, Row>.CellProvider,
            headerProvider: @escaping SupplementaryProvider,
            footerProvider: @escaping SupplementaryProvider
        ) {
            self.headerProvider = headerProvider
            self.footerProvider = footerProvider
            
            super.init(tableView: tableView, cellProvider: cellProvider)
        }
        
        @available(*, unavailable)
        override init(
            tableView: UITableView,
            cellProvider: @escaping UITableViewDiffableDataSource<Section, Row>.CellProvider
        ) {
            fatalError("Not supported.")
        }
        
        override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
            let section = snapshot().sectionIdentifiers[section]
            return headerProvider(tableView, section)
        }
        
        override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
            let section = snapshot().sectionIdentifiers[section]
            return footerProvider(tableView, section)
        }
    }
        
    // MARK: - Properties
    
    private lazy var dataSource = DataSource(
        tableView: tableView,
        cellProvider: { [weak self] tableView, indexPath, row -> UITableViewCell? in
        
            switch row {
            case .activeDNDInfo:
                let activeDNDInfoCell: ActiveDNDInfoCell = tableView.dequeueCell(for: indexPath)
            
                // Show current state icon if there is any
                if let symbolName = self?.pushSetting.sfSymbolNameForPushSetting {
                    let image = BundleUtil.imageNamed("\(symbolName)_regular.M")
                    assert(image != nil, "SF Symbol: regular & M required")
                    activeDNDInfoCell.imageView?.image = image
                    activeDNDInfoCell.tintColor = activeDNDInfoCell.textLabel?.textColor
                }
            
                activeDNDInfoCell.textLabel?.text = self?.pushSetting.localizedLongDescription
            
                return activeDNDInfoCell
            
            case .turnOffDNDButton:
                let turnOffDNDButtonCell: TurnOffDNDButtonCell = tableView.dequeueCell(for: indexPath)
                turnOffDNDButtonCell.textLabel?.text = BundleUtil
                    .localizedString(forKey: "doNotDisturb_turn_off_button")
                return turnOffDNDButtonCell
        
            case let .periodButton(duration: duration):
                let periodButtonCell: PeriodButtonCell = tableView.dequeueCell(for: indexPath)
                periodButtonCell.textLabel?.text = duration.localizedString
                return periodButtonCell
            
            case .foreverButton:
                let periodButtonCell: PeriodButtonCell = tableView.dequeueCell(for: indexPath)
                periodButtonCell.textLabel?.text = BundleUtil.localizedString(forKey: "doNotDisturb_on_forever")
                return periodButtonCell
            
            case .notifyWhenMentionedSetting:
                let notifyWhenMentionedSettingCell: NotifyWhenMentionedSettingCell = tableView
                    .dequeueCell(for: indexPath)
            
                notifyWhenMentionedSettingCell.textLabel?.text = BundleUtil
                    .localizedString(forKey: "doNotDisturb_mention")
            
                notifyWhenMentionedSettingCell.isOn = self?.pushSetting.mentions ?? false
                notifyWhenMentionedSettingCell.valueDidChange = { [weak self] isOn in
                    self?.pushSetting.mentions = isOn
                    self?.pushSetting.save()
                    self?.updateContent()
                }
            
                return notifyWhenMentionedSettingCell
            }
        
        },
        headerProvider: { [weak self] _, section -> String? in
            guard let strongSelf = self else {
                return nil
            }
        
            // Show reset title when DND is active
            if section == .selectPeriod,
               strongSelf.pushSetting.type == .offPeriod || strongSelf.pushSetting.type == .off {
                return BundleUtil.localizedString(forKey: "doNotDisturb_onPeriod_reset")
            }
        
            return nil
        
        },
        footerProvider: { [weak self] _, section -> String? in
            guard let strongSelf = self else {
                return nil
            }
        
            switch section {
            case .activeDND:
                return strongSelf.offHoursDescription
            case .notifyWhenMentionedSetting:
                if strongSelf.pushSetting.mentions {
                    return BundleUtil.localizedString(forKey: "doNotDisturb_mention_footer_on")
                }
                else {
                    return BundleUtil.localizedString(forKey: "doNotDisturb_mention_footer_off")
                }
            default:
                return nil
            }
        }
    )
        
    private let areOffHoursEnabled = UserSettings.shared()?.enableMasterDnd ?? false
    private lazy var offHoursDescription: String? = {
        guard areOffHoursEnabled else {
            return nil
        }
        
        let localizedInfo = BundleUtil.localizedString(forKey: "doNotDisturb_offHours_info")
        let localizedDetailsFormatString = BundleUtil.localizedString(forKey: "doNotDisturb_offHours_details")
    
        guard let localizedWeekdaysList = localizedOffHoursWeekdays() else {
            return localizedInfo
        }
        
        guard let localizedStartTime = localizedFormattedTime(for: UserSettings.shared()?.masterDndStartTime) else {
            return localizedInfo
        }
        
        guard let localizedEndTime = localizedFormattedTime(for: UserSettings.shared()?.masterDndEndTime) else {
            return localizedInfo
        }
        
        let localizedDetails = String.localizedStringWithFormat(
            localizedDetailsFormatString,
            localizedWeekdaysList,
            localizedStartTime,
            localizedEndTime
        )
        
        return "\(localizedInfo) \(localizedDetails)"
    }()
    
    /// The main data provider here
    private let pushSetting: PushSetting
    
    private let willDismiss: ((PushSetting) -> Void)?

    private var isGroup = false

    // MARK: - Lifecycle
    
    /// New DND view controller for a conversation
    ///
    /// - Parameters:
    ///   - conversation: The settings of this conversation are shown and can be changed (usable for single chats and groups)
    ///   - willDismiss: This closure will be called with the final `PushSetting` just before the view controller is dismissed
    @objc init(for conversation: Conversation, willDismiss: ((PushSetting) -> Void)? = nil) {
        self.pushSetting = PushSetting(for: conversation)
        self.willDismiss = willDismiss
        
        self.isGroup = conversation.isGroup()
        
        super.init()
    }
    
    /// New DND view controller for a contact
    ///
    /// - Parameters:
    ///   - contact: The settings of this contact are shown and can be changed
    ///   - willDismiss: This closure will be called with the final `PushSetting` just before the view controller is dismissed
    init(for contact: Contact, willDismiss: ((PushSetting) -> Void)? = nil) {
        self.pushSetting = PushSetting(for: contact)
        self.willDismiss = willDismiss
        
        super.init()
    }
    
    /// New DND view controller for a group conversation
    ///
    /// - Parameters:
    ///   - group: The settings of this group are shown and can be changed
    ///   - willDismiss: This closure will be called with the final `PushSetting` just before the view controller is dismissed
    convenience init(for group: Group, willDismiss: ((PushSetting) -> Void)? = nil) {
        self.init(for: group.conversation, willDismiss: willDismiss)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureNavigationBar()
        configureTableView()
        registerCells()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        updateContent()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        pushSetting.save()
        willDismiss?(pushSetting)
    }
}
    
// MARK: - Configuration

extension DoNotDisturbViewController {
    
    private func configureNavigationBar() {
        navigationBarTitle = BundleUtil.localizedString(forKey: "doNotDisturb_title")
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(closeButtonTapped)
        )
    }
    
    private func configureTableView() {
        tableView.delegate = self
    }
    
    private func registerCells() {
        tableView.registerCell(ActiveDNDInfoCell.self)
        tableView.registerCell(TurnOffDNDButtonCell.self)
        tableView.registerCell(PeriodButtonCell.self)
        tableView.registerCell(NotifyWhenMentionedSettingCell.self)
    }
}

// MARK: - Updates

extension DoNotDisturbViewController {
    
    private func updateContent() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Row>()
        
        // Always show activeDND section when off-hours are enable to display info in footer
        if pushSetting.type != .on || areOffHoursEnabled {
            snapshot.appendSections([.activeDND])
        }
        
        if pushSetting.type != .on {
            snapshot.appendItems([
                .activeDNDInfo,
                .turnOffDNDButton,
            ])
            
            // Ensure update of icon if mention setting is flipped
            snapshot.reloadItems([.activeDNDInfo])
        }
        
        snapshot.appendSections([.selectPeriod])
        snapshot.appendItems(PeriodOffTime.allCases.map { .periodButton(duration: $0) })
        snapshot.appendItems([.foreverButton])
        
        if isGroup {
            snapshot.appendSections([.notifyWhenMentionedSetting])
            snapshot.appendItems([.notifyWhenMentionedSetting])
            
            // Ensure that we always show the most up to date footer
            snapshot.reloadSections([.notifyWhenMentionedSetting])
        }
        
        dataSource.apply(snapshot)
    }
}

// MARK: - Actions

extension DoNotDisturbViewController {
    @objc private func closeButtonTapped() {
        dismiss()
    }
    
    private func dismiss() {
        dismiss(animated: true)
    }
}

// MARK: - UITableViewDelegate

extension DoNotDisturbViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        guard let row = dataSource.itemIdentifier(for: indexPath) else {
            return nil
        }
        
        switch row {
        case .turnOffDNDButton, .periodButton(duration: _), .foreverButton:
            return indexPath
        default:
            return nil
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let row = dataSource.itemIdentifier(for: indexPath) else {
            tableView.deselectRow(at: indexPath, animated: true)
            return
        }
        
        if row == .turnOffDNDButton {
            pushSetting.type = .on
        }
        else if case let .periodButton(duration: duration) = row {
            pushSetting.type = .offPeriod
            pushSetting.periodOffTime = duration
        }
        else if row == .foreverButton {
            pushSetting.type = .off
        }
        
        dismiss()
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

// MARK: - Off-hours formatting helpers

extension DoNotDisturbViewController {
    
    private func localizedOffHoursWeekdays() -> String? {
        let offHoursWeekdaysArray = localizedOffHoursWeekdaysArray()
        
        guard !offHoursWeekdaysArray.isEmpty else {
            return nil
        }
        
        return ListFormatter.localizedString(byJoining: offHoursWeekdaysArray)
    }
    
    private func localizedOffHoursWeekdaysArray() -> [String] {
        // I don't know why, but `firstWeekday` is "off-by-one" compared to `weekdays`.
        // `weekdays` are always from Sun to Sat. If Sun is the first day of the week `firstWeekday` is 1.
        let firstWeekday = Calendar.current.firstWeekday
        let localizedShortWeekdays = Calendar.current.shortWeekdaySymbols
        
        // Our working days use the same offset as `firstWeekday`
        guard let weekdayOffByOneSet = UserSettings.shared()?.masterDndWorkingDays else {
            return []
        }

        // Cast indexes to `Int` and remove any `nil` values. There should be no `nil` values.
        var weekdayOffByOneIndexes = weekdayOffByOneSet.map { $0 as? Int }.compactMap { $0 }
        assert(weekdayOffByOneSet.count == weekdayOffByOneIndexes.count, "All indexes should be parsable as `Int`.")
        
        // Sort our indexes according to the current locale's `firstWeekday`
        weekdayOffByOneIndexes.sort { left, right -> Bool in
            
            // Basically shift days before the first weekday after the last weekday for our comparison
            let adjust: (Int) -> Int = {
                if $0 < firstWeekday {
                    return $0 + localizedShortWeekdays.count
                }
                
                return $0
            }
            
            let left = adjust(left)
            let right = adjust(right)
            
            return left < right
        }

        // Our indexes are sorted. Thus we can just take the strings form the `localizedShortWeekdays`
        // array. (Here we adjust for the off-by-one.)
        let weekdaysStringsLocalizedAndSorted = weekdayOffByOneIndexes.map { localizedShortWeekdays[$0 - 1] }
        
        return weekdaysStringsLocalizedAndSorted
    }
    
    private func localizedFormattedTime(for timeString: String?) -> String? {
        guard let timeString = timeString,
              let date = DateFormatter.getDate(from: timeString) else {
            return nil
        }
        
        return DateFormatter.shortStyleTimeNoDate(date)
    }
}
