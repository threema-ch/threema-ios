//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022 Threema GmbH
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

import ThreemaFramework
import UIKit

/// File message button with file icon, file name and some metadata next to it
///
/// The width might change when up- and downloads start and end.
final class MessageFileButton: ThemedCodeButton {
    
    /// File message to show
    var fileMessage: FileMessage? {
        didSet {
            updateView(with: fileMessage)
        }
    }
    
    // MARK: - Private properties
    
    private lazy var fileSizeFormatter = ByteCountFormatter()
    private lazy var progressFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        return formatter
    }()
    
    // MARK: - Views
    
    private lazy var fileIcon = FileIcon()
    private lazy var blobStateCircle = GrayCircleView(sfSymbolName: "person.fill.turn.down")
    
    private lazy var fileNameLabel: UILabel = {
        let label = UILabel()
        
        label.numberOfLines = 0
        
        label.font = ChatViewConfiguration.File.fileNameFont
        label.adjustsFontForContentSizeCategory = true
        
        // No truncation should happen, but if it would we should try to show at least the extension
        label.lineBreakMode = .byTruncatingMiddle
        
        label.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        
        return label
    }()
    
    // For now we don't use a fixed number width font as it looked good in our tests
    private lazy var fileSizeLabel = MessageMetadataTextLabel()
    // Added during up- and download to get a fixed width (with numbers up to 100%)
    private lazy var fileSizeSizingLabel = MessageMetadataTextLabel()
    
    private lazy var dateAndStateView: MessageDateAndStateView = {
        let dateAndStateView = MessageDateAndStateView()
        dateAndStateView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        return dateAndStateView
    }()
    
    // MARK: Stacks
    
    private lazy var metadataStack: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [
            fileSizeLabel,
            dateAndStateView,
        ])
        
        stackView.axis = .horizontal
        stackView.alignment = .firstBaseline
        stackView.spacing = ChatViewConfiguration.File.minFileSizeAndDateAndStateSpace
        
        if traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
            stackView.axis = .vertical
            stackView.alignment = .trailing
        }
        
        return stackView
    }()
    
    private lazy var fileInfoStack: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [
            fileNameLabel,
            metadataStack,
        ])
        
        stackView.axis = .vertical
        stackView.spacing = ChatViewConfiguration.File.fileNameAndMetadataSpace
        
        return stackView
    }()
    
    private lazy var containerStack: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [
            fileIcon,
            fileInfoStack,
        ])
        
        stackView.axis = .horizontal
        stackView.alignment = .top
        stackView.spacing = ChatViewConfiguration.File.fileIconAndFileInfoSpace
        
        stackView.isUserInteractionEnabled = false
        
        return stackView
    }()
    
    // MARK: - Configuration
    
    override func configureButton() {
        super.configureButton()
        
        addSubview(containerStack)
        containerStack.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(blobStateCircle)
        blobStateCircle.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(fileSizeSizingLabel)
        fileSizeSizingLabel.isHidden = true
        fileSizeSizingLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            containerStack.topAnchor.constraint(equalTo: topAnchor),
            containerStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerStack.bottomAnchor.constraint(equalTo: bottomAnchor),
            containerStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            
            blobStateCircle.leadingAnchor.constraint(
                equalTo: fileIcon.leadingAnchor,
                constant: -ChatViewConfiguration.File.defaultStateCircleOffsetFromFileIcon
            ),
            blobStateCircle.bottomAnchor.constraint(
                equalTo: fileIcon.bottomAnchor,
                constant: ChatViewConfiguration.File.defaultStateCircleOffsetFromFileIcon
            ),
            
            // Connect the shown label with the sizing label
            fileSizeLabel.widthAnchor.constraint(greaterThanOrEqualTo: fileSizeSizingLabel.widthAnchor),
        ])
        
        updateColors()
    }
        
    // MARK: - Update
    
    private func updateView(with fileMessage: FileMessage?) {
        
        let currentBlobDisplayState = fileMessage?.blobDisplayState ?? .fileNotFound
        
        // Icon & status
        
        if let extensionString = fileMessage?.extension {
            if currentBlobDisplayState == .dataDeleted {
                fileIcon.setFileSymbol(to: .customSFSymbol(named: "rectangle.portrait.slash.fill"))
            }
            else {
                fileIcon.setFileSymbol(to: .extension(extensionString))
            }
        }
        else {
            fileIcon.setFileSymbol(to: .noSymbol)
        }
        
        switch currentBlobDisplayState {
        case .remote, .downloading, .pending, .uploading, .fileNotFound:
            if let symbolName = currentBlobDisplayState.symbolName {
                blobStateCircle.updateSymbol(to: symbolName)
                blobStateCircle.isHidden = false
            }
            else {
                blobStateCircle.isHidden = true
            }
        case .processed, .uploaded, .dataDeleted:
            blobStateCircle.isHidden = true
        }
                
        // Name
        
        fileNameLabel.text = fileMessage?.name
        
        // Metdata
        
        switch currentBlobDisplayState {
        case .remote, .pending, .processed, .uploaded:
            fileIcon.alpha = 1.0
            
            fileSizeLabel.text = fileSizeFormatter.string(for: fileMessage?.dataBlobFileSize)
            fileSizeSizingLabel.text = nil
            
        case let .downloading(progress: progress), let .uploading(progress: progress):
            fileIcon.alpha = 1.0
            
            if let progressString = progressFormatter.string(from: Double(progress) as NSNumber) {
                fileSizeLabel.text = """
                    \(fileSizeFormatter.string(for: fileMessage?.dataBlobFileSize) ?? "") \
                    (\(progressString))
                    """
            }
            else {
                fileSizeLabel.text = fileSizeFormatter.string(for: fileMessage?.dataBlobFileSize)
            }
            
            // We keep the sizing label at a constant size during up and download
            fileSizeSizingLabel.text = """
                \(fileSizeFormatter.string(for: fileMessage?.dataBlobFileSize) ?? "") \
                (\(progressFormatter.string(from: 1.0) ?? ""))
                """
            
        case .dataDeleted:
            fileIcon.alpha = 0.6
            
            fileSizeLabel.text = BundleUtil.localizedString(forKey: "file_deleted_title")
            fileSizeSizingLabel.text = nil
            
        case .fileNotFound:
            fileIcon.alpha = 0.6
            
            fileSizeLabel.text = BundleUtil.localizedString(forKey: "file_not_found_title")
            fileSizeSizingLabel.text = nil
        }
        
        dateAndStateView.message = fileMessage
        
        if fileMessage?.showDateAndStateInline ?? false {
            dateAndStateView.isHidden = false
        }
        else {
            dateAndStateView.isHidden = true
        }
    }
    
    override func updateColors() {
        super.updateColors()
        
        Colors.setTextColor(Colors.textLight, label: fileNameLabel)
        fileSizeLabel.updateColors()
        dateAndStateView.updateColors()
    }
}
