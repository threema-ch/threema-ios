import Foundation

extension DistributionListEntity {
    @objc public var distributionListIDObjC: NSNumber {
        NSNumber(integerLiteral: Int(distributionListID))
    }
}
