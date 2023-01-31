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

import CocoaLumberjackSwift
import UIKit

class ThreemaStorageSMTableViewCell: ThemedCodeStackTableViewCell {

    var label: String? {
        didSet {
            labelLabel.text = label
        }
    }
    
    var storageType: StorageType? {
        didSet {
            calcStorage()
        }
    }
    
    enum StorageType {
        case total
        case totalInUse
        case totalFree
        case threema
    }
        
    private lazy var labelLabel: UILabel = {
        let label = UILabel()
        
        label.font = UIFont.preferredFont(forTextStyle: .body)
        
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        label.numberOfLines = 0
        
        return label
    }()
    
    private lazy var valueLabel: CopyLabel = {
        let label = CopyLabel()
        
        label.font = UIFont.preferredFont(forTextStyle: .body)
        
        label.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        
        if traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
            label.numberOfLines = 0
        }
        
        return label
    }()
    
    private lazy var activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.hidesWhenStopped = true
        indicator.stopAnimating()
        return indicator
    }()
    
    override func configureCell() {
        super.configureCell()
        
        selectionStyle = .none
        
        contentStack.addArrangedSubview(labelLabel)
        contentStack.addArrangedSubview(valueLabel)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        label = nil
        storageType = nil
    }
    
    override func updateColors() {
        super.updateColors()
        
        valueLabel.textColor = Colors.textLight
    }
    
    // MARK: - Accessibility
    
    override public var accessibilityLabel: String? {
        get {
            labelLabel.accessibilityLabel
        }
        set { }
    }
    
    override public var accessibilityValue: String? {
        get {
            valueLabel.accessibilityLabel
        }
        set { }
    }
    
    private func calcStorage() {
        let deviceStorage = DeviceUtility.getStorageSize()
        
        switch storageType {
        case .total:
            valueLabel.text = ByteCountFormatter.string(
                fromByteCount: deviceStorage.totalSize ?? 0,
                countStyle: ByteCountFormatter.CountStyle.file
            )
        case .totalFree:
            valueLabel.text = ByteCountFormatter.string(
                fromByteCount: deviceStorage.totalFreeSize ?? 0,
                countStyle: ByteCountFormatter.CountStyle.file
            )
        case .totalInUse:
            valueLabel.text = ByteCountFormatter.string(
                fromByteCount: (deviceStorage.totalSize ?? 0) - (deviceStorage.totalFreeSize ?? 0),
                countStyle: ByteCountFormatter.CountStyle.file
            )
        case .threema:
            calcThreemaStorage()
        case .none:
            valueLabel.text = "-"
        }
    }
    
    private func calcThreemaStorage() {
        contentStack.removeArrangedSubview(valueLabel)
        contentStack.addArrangedSubview(activityIndicator)
        activityIndicator.startAnimating()
        
        DispatchQueue.global(qos: .background).async {
            var dbSize: Int64 = 0
            var appSize: Int64 = 0
            if let appDataURL = FileUtility.appDataDirectory {
                // Check DatabaseManager.storeSize
                let dbURL = appDataURL.appendingPathComponent("ThreemaData.sqlite")
                dbSize = FileUtility.fileSizeInBytes(fileURL: dbURL) ?? 0
                DDLogInfo(
                    "DB size \(ByteCountFormatter.string(fromByteCount: dbSize, countStyle: ByteCountFormatter.CountStyle.file))"
                )
                
                FileUtility.pathSizeInBytes(pathURL: appDataURL, size: &appSize)
                FileUtility.pathSizeInBytes(pathURL: FileManager.default.temporaryDirectory, size: &appSize)
                DDLogInfo(
                    "APP size \(ByteCountFormatter.string(fromByteCount: appSize, countStyle: ByteCountFormatter.CountStyle.file))"
                )
            }
                        
            DispatchQueue.main.async {
                self.valueLabel.text = ByteCountFormatter.string(
                    fromByteCount: appSize,
                    countStyle: ByteCountFormatter.CountStyle.file
                )
                
                self.activityIndicator.stopAnimating()
                
                self.contentStack.removeArrangedSubview(self.activityIndicator)
                self.contentStack.addArrangedSubview(self.valueLabel)
            }
        }
    }
}

// MARK: - Reusable

extension ThreemaStorageSMTableViewCell: Reusable { }
