import CocoaLumberjackSwift
import Foundation
import ThreemaMacros
import ThreemaProtocols

@objc public final class WorkAvailabilityStatus: NSObject {
    
    // MARK: - Category
    
    public enum Category: Int, CaseIterable, Identifiable {
        public var id: Int {
            rawValue
        }
        
        // If a contact has no status, its `workAvailabilityStatus` relationship is nil. Thus a business `Contact`
        // should never have the `none` state.
        // The order in protocol and in UI is different, so we set the `Int` explicitly.
        case none = 0
        case busy = 2
        case unavailable = 1
        
        public var localizedDescription: String {
            switch self {
            case .none:
                #localize("work_availability_status_none")
            case .busy:
                #localize("work_availability_status_busy")
            case .unavailable:
                #localize("work_availability_status_unavailable")
            }
        }
        
        public var color: UIColor {
            switch self {
            case .none:
                .dynamic(dark: .gray400, light: .gray700)
            case .busy:
                .dynamic(
                    dark: UIColor(red: 246.0 / 255.0, green: 164.0 / 255.0, blue: 33.0 / 255.0, alpha: 1.0),
                    light: UIColor(red: 214.0 / 255.0, green: 137.0 / 255.0, blue: 16.0 / 255.0, alpha: 1.0)
                )
            case .unavailable:
                .dynamic(
                    dark: UIColor(red: 253.0 / 255.0, green: 67.0 / 255.0, blue: 70.0 / 255.0, alpha: 1.0),
                    light: UIColor(red: 192.0 / 255.0, green: 57.0 / 255.0, blue: 43.0 / 255.0, alpha: 1.0)
                )
            }
        }

        public var colorBackground: UIColor {
            switch self {
            case .none:
                .dynamic(dark: .gray700, light: .gray100)
            case .busy:
                .dynamic(
                    dark: UIColor(red: 1.0, green: 214.0 / 255.0, blue: 0.0 / 255.0, alpha: 0.2),
                    light: UIColor(red: 1.0, green: 204.0 / 255.0, blue: 0.0 / 255.0, alpha: 0.2)
                )
            case .unavailable:
                .dynamic(
                    dark: UIColor(red: 1.0, green: 66.0 / 255.0, blue: 69.0 / 255.0, alpha: 0.2),
                    light: UIColor(red: 1.0, green: 55.0 / 255.0, blue: 60.0 / 255.0, alpha: 0.2)
                )
            }
        }

        public var bannerColor: UIColor {
            switch self {
            case .none:
                .clear
            case .busy:
                .dynamic(
                    dark: UIColor(red: 1.0, green: 214.0 / 255.0, blue: 0.0 / 255.0, alpha: 0.3),
                    light: UIColor(red: 1.0, green: 204.0 / 255.0, blue: 0.0 / 255.0, alpha: 0.3)
                )
            case .unavailable:
                .dynamic(
                    dark: UIColor(red: 1.0, green: 66.0 / 255.0, blue: 69.0 / 255.0, alpha: 0.3),
                    light: UIColor(red: 1.0, green: 55.0 / 255.0, blue: 60.0 / 255.0, alpha: 0.3)
                )
            }
        }

        public var systemImageName: String {
            switch self {
            case .none:
                "circle.fill"
            case .busy:
                "clock.fill"
            case .unavailable:
                "minus.circle.fill"
            }
        }
    }
    
    // MARK: - Properties
    
    public let category: Category
    @objc public let text: String?
    
    @available(*, deprecated, message: "Only use in Objective-C.")
    @objc public var categoryRawValue: Int {
        category.rawValue
    }
    
    public var accessibilityLabelWithoutText: String? {
        switch category {
        case .none:
            nil
        case .busy:
            #localize("work_availability_status_accessibility_label") + #localize("work_availability_status_busy")
        case .unavailable:
            #localize("work_availability_status_accessibility_label") +
                #localize("work_availability_status_unavailable")
        }
    }
    
    public var accessibilityLabelWithText: String? {
        switch category {
        case .none:
            nil
        case .busy:
            #localize("work_availability_status_accessibility_label") +
                (
                    text != nil ? #localize("work_availability_status_busy") + ". " + text! :
                        #localize("work_availability_status_busy")
                )
        case .unavailable:
            #localize("work_availability_status_accessibility_label") +
                (
                    text != nil ? #localize("work_availability_status_unavailable") + ". " + text! :
                        #localize("work_availability_status_unavailable")
                )
        }
    }
    
    // MARK: - Lifecycle
    
    init(value: Int, text: String?) {
        self.category = Category(rawValue: value) ?? .none
        self.text = text
    }
    
    public init(category: Category, text: String?) {
        self.category = category
        self.text = text
    }
    
    public init(d2dStatus: D2dSync_WorkAvailabilityStatus) {
        self.category = Category(rawValue: d2dStatus.category.rawValue) ?? .none
        self.text = d2dStatus.description_p
    }
    
    @objc public static func fromEncodedString(_ string: String?) -> WorkAvailabilityStatus? {
        guard let string, let data = Data(urlSafeBase64Encoded: string) else {
            return nil
        }
        do {
            let d2dStatus = try D2dSync_WorkAvailabilityStatus(serializedBytes: data)
            return WorkAvailabilityStatus(d2dStatus: d2dStatus)
        }
        catch {
            DDLogError("[WorkAvailabilityStatus] Failed to decode D2D WorkAvailabilityStatus from \(string)")
            return nil
        }
    }
}
