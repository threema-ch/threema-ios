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

import CocoaLumberjackSwift
import CoreImage.CIFilterBuiltins

enum QRCodeGenerator {
    
    /// Generate a QR code containing the provided string
    /// - Parameters:
    ///   - string: String to encode in QR code
    ///   - size: Size of generated UIImage
    /// - Returns: Image representing the QR code
    static func generateQRCode(for string: String, size: CGFloat? = nil) -> UIImage {
        // For now this creates a black QR code with a white background. This is also the easiest to be scanned.
        // If our needs extend we might create an image with a transparent background that can be tined which needs
        // multiple filters.
        // (e.g. https://www.avanderlee.com/swift/qr-code-generation-swift/#changing-the-color-of-a-qr-code)
        
        // If this function gets called very often we might optimize this and not create a new context for each
        // generation
        let context = CIContext()
        
        let filter = CIFilter.qrCodeGenerator()
        
        filter.message = Data(string.utf8)
        filter.correctionLevel = "Q" // 25% error correction
        
        if let qrCodeImage = filter.outputImage {
            let resizedImage: CIImage
            if let size {
                let xScale = size / qrCodeImage.extent.width
                let yScale = size / qrCodeImage.extent.height
                resizedImage = qrCodeImage.transformed(by: CGAffineTransform(scaleX: xScale, y: yScale))
            }
            else {
                resizedImage = qrCodeImage
            }
            
            // This allows us better control which context is (re)used to render the image instead of using
            // `UIImage(ciImage:)` directly. In our tests directly mapping to UIImage wouldn't actually render the QR
            // code in the view. https://www.kodeco.com/30195423-core-image-tutorial-getting-started#toc-anchor-005
            if let cgImage = context.createCGImage(resizedImage, from: resizedImage.extent) {
                return UIImage(cgImage: cgImage)
            }
        }
        
        DDLogError("Failed to generate QR code")
        return UIImage(systemName: "xmark.circle") ?? UIImage()
    }
}

@available(*, deprecated, renamed: "QRCodeGenerator", message: "Only use from Objective-C")
class QRCodeGeneratorObjC: NSObject {
    @objc static func generateQRCode(for string: String, size: CGFloat) -> UIImage {
        QRCodeGenerator.generateQRCode(for: string, size: size)
    }
}
