@testable import Threema_Blue

import DataBackup
import SwiftUI
import Testing

@MainActor
struct ThreemaPreviewsTests {
    @Test func `Generate screenshots iPhone Light`() async throws {
        try await ScreenshotGenerator.generate(
            PreviewDefinition.values.map { preview in
                PreviewTestCase(preview: preview, device: .iPhone17ProMax, appearance: .light)
            }
        )
    }

    @Test func `Generate screenshots iPhone Dark`() async throws {
        try await ScreenshotGenerator.generate(
            PreviewDefinition.values.map { preview in
                PreviewTestCase(preview: preview, device: .iPhone17ProMax, appearance: .dark)
            }
        )
    }

    @Test func `Generate screenshots iPad Light`() async throws {
        try await ScreenshotGenerator.generate(
            PreviewDefinition.values.map { preview in
                PreviewTestCase(preview: preview, device: .iPad11M5, appearance: .light)
            }
        )
    }

    @Test func `Generate screenshots iPad Dark`() async throws {
        try await ScreenshotGenerator.generate(
            PreviewDefinition.values.map { preview in
                PreviewTestCase(preview: preview, device: .iPad11M5, appearance: .dark)
            }
        )
    }
}

@MainActor
struct PreviewTestCase: Sendable {
    struct ScreenshotDevice: Sendable {
        let name: String
        let size: CGSize

        static let iPhone17ProMax = Self(name: "iPhone_17_Pro_Max", size: CGSize(width: 440, height: 956))
        static let iPad11M5 = Self(name: "iPad_11_M5", size: CGSize(width: 834, height: 1210))

        static let values: [Self] = [iPhone17ProMax, iPad11M5]
    }

    struct Appearance: Sendable {
        let name: String
        let colorScheme: ColorScheme

        static let light = Self(name: "Light", colorScheme: .light)
        static let dark = Self(name: "Dark", colorScheme: .dark)

        static let values: [Self] = [.light, .dark]
    }
    
    let preview: PreviewDefinition
    let device: ScreenshotDevice
    let appearance: Appearance

    static let values: [Self] =
        PreviewDefinition.values.flatMap { preview in
            ScreenshotDevice.values.flatMap { device in
                Appearance.values.map { PreviewTestCase(preview: preview, device: device, appearance: $0) }
            }
        }
}

extension PreviewCase {
    /// This case as a screenshot request.
    @MainActor
    var previewDefinition: PreviewDefinition {
        PreviewDefinition(name: title, makeView: { AnyView(view) })
    }

    /// Every case of this screen as a screenshot request, so that a new case is picked up here automatically.
    @MainActor
    static var previewDefinitions: [PreviewDefinition] {
        // A key path cannot reach `previewDefinition`, because it is main-actor isolated.
        // swiftformat:disable:next preferKeyPath
        allCases.map { $0.previewDefinition }
    }
}

@MainActor
struct PreviewDefinition: Sendable {
    let name: String
    let makeView: @MainActor @Sendable () -> AnyView
    
    static var values: [Self] {
        []
            + BackupCenterView.Stance.previewDefinitions
            + ThreemaSafeLearnMoreView.Stance.previewDefinitions
            + LocalBackupLearnMoreView.Stance.previewDefinitions
            + LocalBackupCreateBackupView.Stance.previewDefinitions
            + LocalBackupDetailsView.Stance.previewDefinitions
            + LocalBackupRecoveryKeyConfirmationView.Stance.previewDefinitions
            + LocalBackupRecoveryKeyView.Stance.previewDefinitions
            + LocalBackupSettingsView.Stance.previewDefinitions
    }
}
