import Foundation
import libthreemaSwift

extension BallotChoiceEntity {
    func update(with pollChoice: PollChoice, orderPosition: Int) {
        name = pollChoice.description
        self.orderPosition = NSNumber(value: orderPosition)
    }
}
