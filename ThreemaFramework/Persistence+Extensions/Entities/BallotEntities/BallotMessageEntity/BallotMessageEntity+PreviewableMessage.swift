import CocoaLumberjackSwift
import Foundation
import ThreemaMacros

extension BallotMessageEntity: PreviewableMessage {
    public var privatePreviewText: String {
        guard let ballotTitle = ballot?.title else {
            DDLogError("Ballot title is nil")
            return ""
        }
        
        return ballotTitle
    }

    public var privatePreviewDescription: MessagePreviewDescription {
        MessagePreviewDescription(typeName: #localize("ballot"), quotedText: ballot?.title)
    }

    public var previewSymbolName: String? {
        "chart.pie.fill"
    }
}
