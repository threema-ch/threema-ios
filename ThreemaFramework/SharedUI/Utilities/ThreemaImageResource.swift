import Foundation
import SwiftUI

public enum ThreemaImageResource {
    case systemImage(String)
    case bundleImage(String)
}

extension ThreemaImageResource {
    public var image: Image {
        switch self {
        case let .systemImage(name):
            Image(systemName: name)
        case let .bundleImage(name):
            Image(uiImage: BundleUtil.imageNamed(name) ?? UIImage())
                .renderingMode(.template)
        }
    }
}

extension ThreemaImageResource {
    public var uiImage: UIImage {
        switch self {
        case let .systemImage(name):
            UIImage(systemName: name) ?? UIImage()
        case let .bundleImage(name):
            BundleUtil.imageNamed(name) ?? UIImage()
        }
    }
}

extension Image {
    public init(_ resource: ThreemaImageResource) {
        self = resource.image
    }
}
