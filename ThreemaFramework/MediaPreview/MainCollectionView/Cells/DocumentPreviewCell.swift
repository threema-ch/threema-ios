//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021 Threema GmbH
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
import QuickLook
import CocoaLumberjackSwift

class DocumentPreviewCell : ScreenWidthSizedCell, QLPreviewControllerDelegate {
    
    @IBOutlet weak var loadingText: UILabel!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var loadingView: UIView!
    
    @IBOutlet weak var documentNameLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var previewContentView: UIView!
    @IBOutlet weak var largePreviewImageView: UIImageView!
    
    @IBOutlet weak var largePreviewHeightConstraint: NSLayoutConstraint!
    
    @IBOutlet weak var smallPreviewContentView: UIView!
    @IBOutlet weak var smallDocumentNameLabel: UILabel!
    @IBOutlet weak var smallDocumentDescriptionLabel: UILabel!
    @IBOutlet weak var smallThumbnailView: UIImageView!
    
    var indexPath : IndexPath?
    
    var item : DocumentPreviewItem?
    
    var parent : UIViewController?
    
    var frameView : UIView?
    
    private let lineWidth : CGFloat = 4.0
    private let cornerRadius : CGFloat = 6.0
    
    
    override func prepareForReuse() {
        self.showLoadingScreen()
    }
    
    func addAccessibilityLabels() {
        self.largePreviewImageView.accessibilityLabel = self.item?.getAccessiblityDescription()
        self.smallPreviewContentView.accessibilityLabel = self.item?.getAccessiblityDescription()
    }
    
    func setColors() {
        self.backgroundColor = .clear
        self.backgroundColor = .clear
        self.largePreviewImageView.backgroundColor = .clear
        self.smallPreviewContentView.backgroundColor = .clear
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        self.loadingView.frame = self.bounds
        self.previewContentView.frame = self.bounds
        self.smallPreviewContentView.frame = self.bounds
        self.largePreviewHeightConstraint.constant = self.bounds.height
    }
    
    func imageWithBorder(from source: UIImage?) -> UIImage? {
        guard let source = source else {
            return nil
        }
        let sourceSize = source.size
        let finalSize = CGSize(width: sourceSize.width + 2*lineWidth, height: sourceSize.height + 2*lineWidth)
        
        let sourceSizedRect = CGRect(x: lineWidth, y: lineWidth, width: sourceSize.width, height: sourceSize.height)
        let finalSizedRect = CGRect(x: 0, y: 0, width: sourceSize.width + 2*lineWidth, height: sourceSize.height + 2*lineWidth)
        
        UIGraphicsBeginImageContextWithOptions(finalSize, false, UIScreen.main.scale)
        guard let context = UIGraphicsGetCurrentContext() else {
            return source
        }
        
        let path = UIBezierPath(roundedRect: finalSizedRect, cornerRadius: cornerRadius)
        path.lineWidth = lineWidth
        path.addClip()
        
        // Redraw image
        source.draw(in: sourceSizedRect, blendMode: .normal, alpha: 1.0)
        
        // Draw border around image
        guard let mainColor = Colors.main()?.cgColor else {
            return source
        }
        
        context.setStrokeColor(mainColor)
        
        let coloredPath = UIBezierPath(roundedRect: sourceSizedRect, cornerRadius: cornerRadius)
        coloredPath.lineWidth = lineWidth
        coloredPath.stroke()
        
        let imageWithBorder = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return imageWithBorder
    }
    
    func showLoadingScreen() {
        self.setColors()
        
        self.loadingView.isHidden = false
        self.previewContentView.isHidden = true
        self.smallPreviewContentView.isHidden = true
        
        activityIndicator.startAnimating()
        loadingText.text = BundleUtil.localizedString(forKey:"loading_document")
    }
    
    func showPreview() {
        let ql = ThreemaQLPreviewController()
        ql.dataSource = self
        ql.delegate = self
        ql.modalPresentationStyle = .currentContext
        if #available(iOSApplicationExtension 13.0, *) {
            ql.isModalInPresentation = true
        }

        if let p = parent {
            p.present(ql, animated: true, completion: nil)
        } else {
            DDLogError("Could not open preview because parent was nil")
        }
        
    }
    
    func getDescription(for item : DocumentPreviewItem?) -> String {
        return (self.item?.getType())! + " " + BundleUtil.localizedString(forKey:"document") + " - " + (self.item?.getSize())!
    }
    
    func loadDocument(_ newItem : DocumentPreviewItem) {
        self.item = newItem
        _ = item?.generateLargeThumbnail(with: self.bounds.size).done({ [self] (thumbnail) in
            if thumbnail != nil {
                self.loadingView.isHidden = true
                self.previewContentView.isHidden = false
                self.smallPreviewContentView.isHidden = true
                
                self.largePreviewImageView.image = self.imageWithBorder(from: thumbnail)
                self.largePreviewImageView.isHidden = false
                
                self.addTapGestureRecognizer(view: self.largePreviewImageView)
                
                self.documentNameLabel.text = self.item?.getFilename()
                self.descriptionLabel.text = self.getDescription(for: self.item)
                
                self.layoutSubviews()
            } else {
                self.activityIndicator.stopAnimating()
                self.loadingText.text = BundleUtil.localizedString(forKey:"loading_failed")
            }
        }).recover({ (err) in
            self.loadingView.isHidden = true
            self.previewContentView.isHidden = true
            self.smallPreviewContentView.isHidden = false
            
            self.smallDocumentNameLabel.text = self.item?.getFilename()
            self.smallDocumentDescriptionLabel.text = self.getDescription(for: self.item)
            
            let uti = UTIConverter.uti(forFileURL: newItem.previewItemURL)
            let icon = UTIConverter.getDefaultThumbnail(forMimeType: uti)
            self.smallThumbnailView.image = icon
            self.smallThumbnailView.contentMode = .center
            
            self.addTapGestureRecognizer(view: self.smallThumbnailView)
        })
    }
    
    func addTapGestureRecognizer(view : UIView) {
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
        self.showPreview()
    }
}

extension DocumentPreviewCell : UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard let imageSize = self.largePreviewImageView.image?.size else {
            return false
        }
        
        let point = touch.preciseLocation(in: self.largePreviewImageView)
        let imageRect = AVMakeRect(aspectRatio: imageSize,
                                   insideRect: self.largePreviewImageView.frame)
        
        return imageRect.contains(point)
    }
}

extension DocumentPreviewCell : QLPreviewControllerDataSource {
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        1
    }
    
    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        return self.item!
    }
}
