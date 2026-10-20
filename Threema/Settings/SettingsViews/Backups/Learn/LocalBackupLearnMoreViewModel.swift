import ThreemaMacros

@MainActor
final class LocalBackupLearnMoreViewModel: LearnMoreSheetModel {
    let headerIconName = "folder"
    let title = #localize("backup_center_local_backup_title")
    let content = #localize("backup_local_learn_more_content")
}
