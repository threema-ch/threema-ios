import libthreemaSwift

extension LibthreemaWorkAvailabilityStatus {
    init?(_ workAvailabilityStatus: WorkAvailabilityStatusEntity) throws {
        let text = workAvailabilityStatus.text ?? String.empty

        self =
            switch workAvailabilityStatus.value.int32Value {
            case WorkAvailabilityStatusCategory.none.rawValue: .none
            case WorkAvailabilityStatusCategory.busy.rawValue: .busy(text)
            case WorkAvailabilityStatusCategory.unavailable.rawValue: .unavailable(text)
            default:
                throw MappingError.workAvailibilityStatus
            }
    }
}
