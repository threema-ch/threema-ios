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
import Foundation
import QuickLook

class DocumentPreviewCell: ScreenWidthSizedCell, QLPreviewControllerDelegate {
    
    @IBOutlet var loadingText: UILabel!
    @IBOutlet var activityIndicator: UIActivityIndicatorView!
    @IBOutlet var loadingView: UIView!
    
    @IBOutlet var documentNameLabel: UILabel!
    @IBOutlet var descriptionLabel: UILabel!
    @IBOutlet var previewContentView: UIView!
    @IBOutlet var largePreviewImageView: UIImageView!
    
    @IBOutlet var largePreviewHeightConstraint: NSLayoutConstraint!
    
    @IBOutlet var smallPreviewContentView: UIView!
    @IBOutlet var smallDocumentNameLabel: UILabel!
    @IBOutlet var smallDocumentDescriptionLabel: UILabel!
    @IBOutlet var smallThumbnailView: UIImageView!
    
    var indexPath: IndexPath?
    
    var item: DocumentPreviewItem?
    
    var parent: UIViewController?
    
    var frameView: UIView?
    
    private let lineWidth: CGFloat = 4.0
    private let cornerRadius: CGFloat = 6.0
    
    override func prepareForReuse() {
        showLoadingScreen()
    }
    
    func addAccessibilityLabels() {
        largePreviewImageView.accessibilityLabel = item?.getAccessibilityDescription()
        smallPreviewContentView.accessibilityLabel = item?.getAccessibilityDescription()
    }
    
    func setColors() {
        backgroundColor = Colors.backgroundPreviewCollectionViewCell
        largePreviewImageView.backgroundColor = .clear
        smallPreviewContentView.backgroundColor = .clear
        loadingView.backgroundColor = .clear
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        loadingView.frame = bounds
        previewContentView.frame = bounds
        smallPreviewContentView.frame = bounds
        largePreviewHeightConstraint.constant = bounds.height
    }
    
    func imageWithBorder(from source: UIImage?) -> UIImage? {
        guard let source = source else {
            return nil
        }
        let sourceSize = source.size
        let finalSize = CGSize(width: sourceSize.width + 2 * lineWidth, height: sourceSize.height + 2 * lineWidth)
        
        let sourceSizedRect = CGRect(x: lineWidth, y: lineWidth, width: sourceSize.width, height: sourceSize.height)
        let finalSizedRect = CGRect(
            x: 0,
            y: 0,
            width: sourceSize.width + 2 * lineWidth,
            height: sourceSize.height + 2 * lineWidth
        )
        
        UIGraphicsBeginImageContextWithOptions(finalSize, false, UIScreen.main.scale)
        guard let context = UIGraphicsGetCurrentContext() else {
            return source
        }
        
        let path = UIBezierPath(roundedRect: finalSizedRect, cornerRadius: cornerRadius)
        path.lineWidth = lineWidth
        path.addClip()
        
        // Redraw image
        source.draw(in: sourceSizedRect, blendMode: .normal, alpha: 1.0)
        
        context.setStrokeColor(UIColor.primary.cgColor)
        
        let coloredPath = UIBezierPath(roundedRect: sourceSizedRect, cornerRadius: cornerRadius)
        coloredPath.lineWidth = lineWidth
        coloredPath.stroke()
        
        let imageWithBorder = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return imageWithBorder
    }
    
    func showLoadingScreen() {
        setColors()
        
        loadingView.isHidden = false
        previewContentView.isHidden = true
        smallPreviewContentView.isHidden = true
        
        activityIndicator.startAnimating()
        loadingText.text = BundleUtil.localizedString(forKey: "loading_document")
    }
    
    func showPreview() {
        let ql = ThreemaQLPreviewController()
        ql.dataSource = self
        ql.delegate = self
        ql.modalPresentationStyle = .currentContext
        ql.isModalInPresentation = true
        
        if let p = parent {
            p.present(ql, animated: true, completion: nil)
        }
        else {
            DDLogError("Could not open preview because parent was nil")
        }
    }
    
    func getDescription(for item: DocumentPreviewItem?) -> String {
        (self.item?.type)! + " " + BundleUtil
            .localizedString(forKey: "document") + " - " + (self.item?.fileSizeDescription)!
    }
    
    func loadDocument(_ newItem: DocumentPreviewItem) {
        item = newItem
        _ = item?.generateLargeThumbnail(with: bounds.size).done { [self] thumbnail in
            self.loadingView.isHidden = true
            self.previewContentView.isHidden = false
            self.smallPreviewContentView.isHidden = true
            
            self.largePreviewImageView.image = self.imageWithBorder(from: thumbnail)
            self.largePreviewImageView.isHidden = false
            
            self.addTapGestureRecognizer(view: self.largePreviewImageView)
            
            self.documentNameLabel.text = self.item?.originalFilename
            self.descriptionLabel.text = self.getDescription(for: self.item)
            
            self.layoutSubviews()
        }.recover { _ in
            DispatchQueue.main.async {
                self.loadingView.isHidden = true
                self.previewContentView.isHidden = true
                self.smallPreviewContentView.isHidden = false
                
                self.smallDocumentNameLabel.text = self.item?.originalFilename
                self.smallDocumentDescriptionLabel.text = self.getDescription(for: self.item)
                
                let uti = UTIConverter.uti(forFileURL: newItem.previewItemURL)
                let icon = UTIConverter.getDefaultThumbnail(forMimeType: uti)
                self.smallThumbnailView.image = icon
                self.smallThumbnailView.contentMode = .center
            }
            self.addTapGestureRecognizer(view: self.smallThumbnailView)
        }
    }
    
    func addTapGestureRecognizer(view: UIView) {
        DispatchQueue.main.async {
            view.isUserInteractionEnabled = true
            self.isUserInteractionEnabled = true
            let tap = UITapGestureRecognizer(target: self, action: #selector(DocumentPreviewCell.tappedThumbnail(_:)))
            tap.cancelsTouchesInView = false
            tap.numberOfTapsRequired = 1
            tap.delegate = self
            view.addGestureRecognizer(tap)
        }
    }
    
    @objc func tappedThumbnail(_ gesture: UITapGestureRecognizer) {
        showPreview()
    }
}

// MARK: - UIGestureRecognizerDelegate

extension DocumentPreviewCell: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard let imageSize = largePreviewImageView.image?.size else {
            return false
        }
        
        let point = touch.preciseLocation(in: largePreviewImageView)
        let imageRect = AVMakeRect(
            aspectRatio: imageSize,
            insideRect: largePreviewImageView.frame
        )
        
        return imageRect.contains(point)
    }
}

// MARK: - QLPreviewControllerDataSource

extension DocumentPreviewCell: QLPreviewControllerDataSource {
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        1
    }
    
    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        item!
    }
}
