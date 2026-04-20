import Foundation

protocol GroupCallViewModelDelegate: AnyObject {
    func updateNavigationContent(_ contentUpdate: GroupCallNavigationBarContentUpdate) async
    func updateCollectionViewLayout()
    func dismissGroupCallView(animated: Bool) async
    @MainActor func showRecordAudioPermissionAlert()
    @MainActor func showRecordVideoPermissionAlert()
}

struct GroupCallNavigationBarContentUpdate {
    let title: String?
    let participantCount: Int?
    let timeInterval: TimeInterval
}
