import CocoaLumberjackSwift
import Foundation

extension BallotMessageEntity: PreviewableMessage {
    public var privatePreviewText: String {
        guard let ballotTitle = ballot?.title else {
            DDLogError("Ballot title is nil")
            return ""
        }
        
        return ballotTitle
    }
    
    public var previewSymbolName: String? {
        "chart.pie.fill"
    }
}
