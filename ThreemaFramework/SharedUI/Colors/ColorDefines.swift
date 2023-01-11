//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2022 Threema GmbH
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

#if os(macOS)
  import AppKit
#elseif os(iOS)
  import UIKit
#elseif os(tvOS) || os(watchOS)
  import UIKit
#endif
#if canImport(SwiftUI)
  import SwiftUI
#endif

// Deprecated typealiases
@available(*, deprecated, renamed: "ColorAsset.Color", message: "This typealias will be removed in SwiftGen 7.0")
internal typealias AssetColorTypeAlias = ColorAsset.Color

// swiftlint:disable superfluous_disable_command file_length implicit_return

// MARK: - Asset Catalogs

// swiftlint:disable identifier_name line_length nesting type_body_length type_name
internal enum Asset {
  internal enum SharedColors {
    internal static let backgroundCellDark = ColorAsset(name: "BackgroundCellDark")
    internal static let backgroundCellSelectedDark = ColorAsset(name: "BackgroundCellSelectedDark")
    internal static let backgroundCellSelectedLight = ColorAsset(name: "BackgroundCellSelectedLight")
    internal static let black = ColorAsset(name: "Black")
    internal static let blue = ColorAsset(name: "Blue")
    internal static let gray100 = ColorAsset(name: "Gray100")
    internal static let gray1000 = ColorAsset(name: "Gray1000")
    internal static let gray150 = ColorAsset(name: "Gray150")
    internal static let gray200 = ColorAsset(name: "Gray200")
    internal static let gray250 = ColorAsset(name: "Gray250")
    internal static let gray30 = ColorAsset(name: "Gray30")
    internal static let gray300 = ColorAsset(name: "Gray300")
    internal static let gray350 = ColorAsset(name: "Gray350")
    internal static let gray400 = ColorAsset(name: "Gray400")
    internal static let gray450 = ColorAsset(name: "Gray450")
    internal static let gray50 = ColorAsset(name: "Gray50")
    internal static let gray500 = ColorAsset(name: "Gray500")
    internal static let gray550 = ColorAsset(name: "Gray550")
    internal static let gray600 = ColorAsset(name: "Gray600")
    internal static let gray650 = ColorAsset(name: "Gray650")
    internal static let gray700 = ColorAsset(name: "Gray700")
    internal static let gray750 = ColorAsset(name: "Gray750")
    internal static let gray80 = ColorAsset(name: "Gray80")
    internal static let gray800 = ColorAsset(name: "Gray800")
    internal static let gray850 = ColorAsset(name: "Gray850")
    internal static let gray900 = ColorAsset(name: "Gray900")
    internal static let green = ColorAsset(name: "Green")
    internal static let idColorAmber = ColorAsset(name: "IDColorAmber")
    internal static let idColorBlue = ColorAsset(name: "IDColorBlue")
    internal static let idColorCyan = ColorAsset(name: "IDColorCyan")
    internal static let idColorDeepOrange = ColorAsset(name: "IDColorDeepOrange")
    internal static let idColorDeepPurple = ColorAsset(name: "IDColorDeepPurple")
    internal static let idColorGreen = ColorAsset(name: "IDColorGreen")
    internal static let idColorIndigo = ColorAsset(name: "IDColorIndigo")
    internal static let idColorLightBlue = ColorAsset(name: "IDColorLightBlue")
    internal static let idColorLightGreen = ColorAsset(name: "IDColorLightGreen")
    internal static let idColorOlive = ColorAsset(name: "IDColorOlive")
    internal static let idColorOrange = ColorAsset(name: "IDColorOrange")
    internal static let idColorPink = ColorAsset(name: "IDColorPink")
    internal static let idColorPurple = ColorAsset(name: "IDColorPurple")
    internal static let idColorRed = ColorAsset(name: "IDColorRed")
    internal static let idColorTeal = ColorAsset(name: "IDColorTeal")
    internal static let idColorYellow = ColorAsset(name: "IDColorYellow")
    internal static let orange = ColorAsset(name: "Orange")
    internal static let pin = ColorAsset(name: "Pin")
    internal static let red = ColorAsset(name: "Red")
    internal static let white = ColorAsset(name: "White")
  }
  internal enum TargetColors {
    internal enum OnPrem {
      internal static let chatBubbleSent = ColorAsset(name: "OnPrem/ChatBubbleSent")
      internal static let chatBubbleSentSelected = ColorAsset(name: "OnPrem/ChatBubbleSentSelected")
      internal static let circleButton = ColorAsset(name: "OnPrem/CircleButton")
      internal static let navigationBarCall = ColorAsset(name: "OnPrem/NavigationBarCall")
      internal static let navigationBarWeb = ColorAsset(name: "OnPrem/NavigationBarWeb")
      internal static let primary = ColorAsset(name: "OnPrem/Primary")
      internal static let secondary = ColorAsset(name: "OnPrem/Secondary")
      internal static let chatBubbleSentDark = ColorAsset(name: "OnPrem/ChatBubbleSent+Dark")
      internal static let chatBubbleSentSelectedDark = ColorAsset(name: "OnPrem/ChatBubbleSentSelected+Dark")
      internal static let circleButtonDark = ColorAsset(name: "OnPrem/CircleButton+Dark")
      internal static let navigationBarCallDark = ColorAsset(name: "OnPrem/NavigationBarCall+Dark")
      internal static let primaryDark = ColorAsset(name: "OnPrem/Primary+Dark")
      internal static let secondaryDark = ColorAsset(name: "OnPrem/Secondary+Dark")
    }
    internal enum Threema {
      internal static let chatBubbleSent = ColorAsset(name: "Threema/ChatBubbleSent")
      internal static let chatBubbleSentSelected = ColorAsset(name: "Threema/ChatBubbleSentSelected")
      internal static let circleButton = ColorAsset(name: "Threema/CircleButton")
      internal static let navigationBarCall = ColorAsset(name: "Threema/NavigationBarCall")
      internal static let navigationBarWeb = ColorAsset(name: "Threema/NavigationBarWeb")
      internal static let primary = ColorAsset(name: "Threema/Primary")
      internal static let secondary = ColorAsset(name: "Threema/Secondary")
      internal static let chatBubbleSentDark = ColorAsset(name: "Threema/ChatBubbleSent+Dark")
      internal static let chatBubbleSentSelectedDark = ColorAsset(name: "Threema/ChatBubbleSentSelected+Dark")
      internal static let circleButtonDark = ColorAsset(name: "Threema/CircleButton+Dark")
      internal static let navigationBarCallDark = ColorAsset(name: "Threema/NavigationBarCall+Dark")
      internal static let primaryDark = ColorAsset(name: "Threema/Primary+Dark")
      internal static let secondaryDark = ColorAsset(name: "Threema/Secondary+Dark")
    }
    internal enum ThreemaRed {
      internal static let chatBubbleSent = ColorAsset(name: "ThreemaRed/ChatBubbleSent")
      internal static let chatBubbleSentSelected = ColorAsset(name: "ThreemaRed/ChatBubbleSentSelected")
      internal static let circleButton = ColorAsset(name: "ThreemaRed/CircleButton")
      internal static let navigationBarCall = ColorAsset(name: "ThreemaRed/NavigationBarCall")
      internal static let navigationBarWeb = ColorAsset(name: "ThreemaRed/NavigationBarWeb")
      internal static let primary = ColorAsset(name: "ThreemaRed/Primary")
      internal static let secondary = ColorAsset(name: "ThreemaRed/Secondary")
      internal static let chatBubbleSentDark = ColorAsset(name: "ThreemaRed/ChatBubbleSent+Dark")
      internal static let chatBubbleSentSelectedDark = ColorAsset(name: "ThreemaRed/ChatBubbleSentSelected+Dark")
      internal static let circleButtonDark = ColorAsset(name: "ThreemaRed/CircleButton+Dark")
      internal static let navigationBarCallDark = ColorAsset(name: "ThreemaRed/NavigationBarCall+Dark")
      internal static let primaryDark = ColorAsset(name: "ThreemaRed/Primary+Dark")
      internal static let secondaryDark = ColorAsset(name: "ThreemaRed/Secondary+Dark")
    }
    internal enum ThreemaWork {
      internal static let chatBubbleSent = ColorAsset(name: "ThreemaWork/ChatBubbleSent")
      internal static let chatBubbleSentSelected = ColorAsset(name: "ThreemaWork/ChatBubbleSentSelected")
      internal static let circleButton = ColorAsset(name: "ThreemaWork/CircleButton")
      internal static let navigationBarCall = ColorAsset(name: "ThreemaWork/NavigationBarCall")
      internal static let navigationBarWeb = ColorAsset(name: "ThreemaWork/NavigationBarWeb")
      internal static let primary = ColorAsset(name: "ThreemaWork/Primary")
      internal static let secondary = ColorAsset(name: "ThreemaWork/Secondary")
      internal static let chatBubbleSentDark = ColorAsset(name: "ThreemaWork/ChatBubbleSent+Dark")
      internal static let chatBubbleSentSelectedDark = ColorAsset(name: "ThreemaWork/ChatBubbleSentSelected+Dark")
      internal static let circleButtonDark = ColorAsset(name: "ThreemaWork/CircleButton+Dark")
      internal static let navigationBarCallDark = ColorAsset(name: "ThreemaWork/NavigationBarCall+Dark")
      internal static let primaryDark = ColorAsset(name: "ThreemaWork/Primary+Dark")
      internal static let secondaryDark = ColorAsset(name: "ThreemaWork/Secondary+Dark")
    }
  }
}
// swiftlint:enable identifier_name line_length nesting type_body_length type_name

// MARK: - Implementation Details

internal final class ColorAsset {
  internal fileprivate(set) var name: String

  #if os(macOS)
  internal typealias Color = NSColor
  #elseif os(iOS) || os(tvOS) || os(watchOS)
  internal typealias Color = UIColor
  #endif

  @available(iOS 11.0, tvOS 11.0, watchOS 4.0, macOS 10.13, *)
  internal private(set) lazy var color: Color = {
    guard let color = Color(asset: self) else {
      fatalError("Unable to load color asset named \(name).")
    }
    return color
  }()

  #if os(iOS) || os(tvOS)
  @available(iOS 11.0, tvOS 11.0, *)
  internal func color(compatibleWith traitCollection: UITraitCollection) -> Color {
    let bundle = BundleToken.bundle
    guard let color = Color(named: name, in: bundle, compatibleWith: traitCollection) else {
      fatalError("Unable to load color asset named \(name).")
    }
    return color
  }
  #endif

  #if canImport(SwiftUI)
  @available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
  internal private(set) lazy var swiftUIColor: SwiftUI.Color = {
    SwiftUI.Color(asset: self)
  }()
  #endif

  fileprivate init(name: String) {
    self.name = name
  }
}

internal extension ColorAsset.Color {
  @available(iOS 11.0, tvOS 11.0, watchOS 4.0, macOS 10.13, *)
  convenience init?(asset: ColorAsset) {
    let bundle = BundleToken.bundle
    #if os(iOS) || os(tvOS)
    self.init(named: asset.name, in: bundle, compatibleWith: nil)
    #elseif os(macOS)
    self.init(named: NSColor.Name(asset.name), bundle: bundle)
    #elseif os(watchOS)
    self.init(named: asset.name)
    #endif
  }
}

#if canImport(SwiftUI)
@available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
internal extension SwiftUI.Color {
  init(asset: ColorAsset) {
    let bundle = BundleToken.bundle
    self.init(asset.name, bundle: bundle)
  }
}
#endif

// swiftlint:disable convenience_type
private final class BundleToken {
  static let bundle: Bundle = {
    #if SWIFT_PACKAGE
    return Bundle.module
    #else
    return Bundle(for: BundleToken.self)
    #endif
  }()
}
// swiftlint:enable convenience_type
