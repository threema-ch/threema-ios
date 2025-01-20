//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2025 Threema GmbH
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
import ThreemaMacros
import UIKit

protocol MessageFileTapViewDelegate: AnyObject {
    var currentSearchText: String? { get }
}

/// File message view with a tap gesture recognizer, file icon, file name and some metadata next to it
///
/// The width might change when up- and downloads start and end.
final class MessageFileTapView: UIView {
    
    /// File message to show
    var fileMessage: FileMessage? {
        didSet {
            updateView(with: fileMessage)
        }
    }
    
    weak var delegate: MessageFileTapViewDelegate?
    
    // MARK: - Private properties
        
    private lazy var fileSizeFormatter = ByteCountFormatter()
    
    private lazy var progressFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        return formatter
    }()
    
    private var tapAction: () -> Void
    
    // MARK: - Lifecycle
    
    init(tapAction: @escaping () -> Void) {
        self.tapAction = tapAction
        
        super.init(frame: .zero)
        
        let tapGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tapGestureRecognizer.minimumPressDuration = 0.0
        tapGestureRecognizer.delegate = self
        addGestureRecognizer(tapGestureRecognizer)
        
        configureLayout()
        updateColors()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Views
    
    private lazy var fileIcon = {
        let fileIcon = FileIcon()
        fileIcon.setContentCompressionResistancePriority(.required, for: .horizontal)
        return fileIcon
    }()
    
    private lazy var blobStateCircle = GrayCircleView(sfSymbolName: "person.fill.turn.down")
    
    private lazy var fileNameLabel: UILabel = {
        let label = UILabel()
        
        label.numberOfLines = 0
        
        label.font = ChatViewConfiguration.File.fileNameFont
        label.textColor = .secondaryLabel

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
    
    private func configureLayout() {
        
        clipsToBounds = true
        layer.cornerRadius = ChatViewConfiguration.File.cornerRadius
        layer.cornerCurve = .continuous
        
        addSubview(containerStack)
        containerStack.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(blobStateCircle)
        blobStateCircle.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(fileSizeSizingLabel)
        fileSizeSizingLabel.isHidden = true
        fileSizeSizingLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            containerStack.topAnchor.constraint(
                equalTo: topAnchor,
                constant: ChatViewConfiguration.File.fileTopBottomInset
            ),
            containerStack.leadingAnchor.constraint(
                equalTo: leadingAnchor,
                constant: ChatViewConfiguration.File.fileLeadingTrailingInset
            ),
            containerStack.bottomAnchor.constraint(
                equalTo: bottomAnchor,
                constant: -ChatViewConfiguration.File.fileTopBottomInset
            ),
            containerStack.trailingAnchor.constraint(
                equalTo: trailingAnchor,
                constant: -ChatViewConfiguration.File.fileLeadingTrailingInset
            ),
            
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
        
        // Set inset for file view
        directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: ChatViewConfiguration.File.fileTopBottomInset,
            leading: ChatViewConfiguration.File.fileLeadingTrailingInset,
            bottom: ChatViewConfiguration.File.fileTopBottomInset,
            trailing: ChatViewConfiguration.File.fileLeadingTrailingInset
        )
        
        updateColors()
    }
    
    @objc func handleTap(_ sender: UITapGestureRecognizer) {
        if sender.state == .ended {
            tapAction()
        }
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
        case .remote, .downloading, .pending, .uploading, .fileNotFound, .sendingError:
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
        if let currentSearchText = delegate?.currentSearchText, let fileMessageName = fileMessage?.name {
            let markupParser = MarkupParser()
            let markupText = markupParser.markify(
                attributedString: NSAttributedString(string: fileMessageName),
                font: fileNameLabel.font,
                parseURL: false
            )
            fileNameLabel.attributedText = markupParser.highlightOccurrences(of: currentSearchText, in: markupText)
        }
        else {
            fileNameLabel.text = fileMessage?.name
        }
        
        // Metdata
        
        switch currentBlobDisplayState {
        case .remote, .pending, .processed, .uploaded, .sendingError:
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
            
            fileSizeLabel.text = #localize("file_deleted_title")
            fileSizeSizingLabel.text = nil
            
        case .fileNotFound:
            fileIcon.alpha = 0.6
            
            fileSizeLabel.text = #localize("file_not_found_title")
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
    
    func updateColors() {
        fileIcon.updateColors()
        
        // Works around `Colors` resetting our colors when we actually want to highlight text
        if let currentSearchText = delegate?.currentSearchText, let fileMessageName = fileMessage?.name {
            let markupParser = MarkupParser()
            let markupText = markupParser.markify(
                attributedString: NSAttributedString(string: fileMessageName),
                font: fileNameLabel.font,
                parseURL: false
            )
            fileNameLabel.attributedText = MarkupParser().highlightOccurrences(of: currentSearchText, in: markupText)
        }
    }
}

// MARK: - UIGestureRecognizerDelegate

// This resolves an issue where the gesture recognizer would infer with scrolling interactions
extension MessageFileTapView: UIGestureRecognizerDelegate {
    
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        if otherGestureRecognizer is UIPanGestureRecognizer {
            return true
        }
        return false
    }
    
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        if otherGestureRecognizer is UIPanGestureRecognizer {
            return true
        }
        return false
    }
}
