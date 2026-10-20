import SwiftUI
import UIKit

@MainActor
enum ScreenshotGenerator {
    enum ScreenshotError: Error {
        case pngEncodingFailed
        case noWindowScene
    }

    /// How long to wait for the preview content to appear on screen.
    private static let contentAppearanceTimeout = Duration.seconds(2)

    /// How long to look for a modal presentation at all. A screen without one waits this out, so it is
    /// paid once per preview.
    private static let modalDetectionTimeout = Duration.milliseconds(300)

    /// How long to let a modal that is presenting finish its transition.
    private static let modalSettleTimeout = Duration.seconds(1)

    /// Time for the render server to compose the window between the two capture passes.
    private static let renderSettleDelay = Duration.milliseconds(100)

    struct ScreenshotRequest: Sendable {
        let name: String
        let size: CGSize
        let colorScheme: ColorScheme
        let makeView: @MainActor @Sendable () -> AnyView
    }

    nonisolated static let outputDirectory = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent() // Repository root
        .appending(path: "build/PreviewScreenshots")

    nonisolated static let workingDirectory = outputDirectory
        .appending(path: Bundle.main.preferredLocalizations.first ?? "unknown")

    nonisolated static let completionMarker = outputDirectory.appending(path: ".generated")

    static func generate(_ previews: [PreviewTestCase]) async throws {
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        // A run that fails before finishing must not leave a marker of an earlier run behind.
        try? FileManager.default.removeItem(at: completionMarker)

        // Sheet presentations and `onAppear` transitions are animated, and a capture taken mid
        // animation shows a half-presented screen or nothing at all. Without animations every
        // transition lands on the next run loop turn instead.
        UIView.setAnimationsEnabled(false)
        defer { UIView.setAnimationsEnabled(true) }

        let window = try await makeWindow()
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }

        // One turn for the render server to host the fresh window, so the first capture doesn't sample
        // effect views from a context that was created a moment ago.
        try await Task.sleep(for: renderSettleDelay)

        for preview in previews {
            let request = ScreenshotRequest(
                name: "\(preview.preview.name)",
                size: preview.device.size,
                colorScheme: preview.appearance.colorScheme,
                makeView: { preview.preview.makeView() }
            )

            let requestDirectory = workingDirectory
                .appendingPathComponent(preview.device.name)
                .appendingPathComponent(preview.appearance.name)

            try FileManager.default.createDirectory(at: requestDirectory, withIntermediateDirectories: true)

            try await save(
                request.makeView(),
                size: request.size,
                colorScheme: request.colorScheme,
                deviceName: preview.device.name,
                in: window,
                to: requestDirectory.appendingPathComponent("\(request.name).png")
            )

            print("\(request.name).png")
        }

        try Data(workingDirectory.path.utf8).write(to: completionMarker)

        print("\nopen '\(workingDirectory.path)'\n")
    }

    // MARK: - Helpers

    private static func save(
        _ view: AnyView,
        size: CGSize,
        colorScheme: ColorScheme,
        deviceName: String,
        in window: UIWindow,
        to url: URL
    ) async throws {
        let style: UIUserInterfaceStyle = colorScheme == .dark ? .dark : .light

        let appearance = PreviewAppearance()
        let hostingController = UIHostingController(
            rootView: AnyView(
                PreviewHost(appearance: appearance) {
                    view.environment(\.colorScheme, colorScheme)
                }
            )
        )
        hostingController.overrideUserInterfaceStyle = style

        window.frame = CGRect(origin: .zero, size: size)
        window.overrideUserInterfaceStyle = style
        if !window.isKeyWindow {
            window.makeKeyAndVisible()
        }

        // The window is on screen already, so a `.sheet` or an `.alert` that `PreviewHost` installs in
        // `onAppear` is requested from a presenter that is in the window, with the final size and traits.
        window.rootViewController = hostingController

        hostingController.view.backgroundColor = .systemBackground
        window.layoutIfNeeded()

        // `PreviewHost` renders the content on the run loop turn after the root view appears.
        await wait(upTo: contentAppearanceTimeout) { appearance.hasAppeared }
        window.layoutIfNeeded()

        await settleModalPresentation(of: hostingController)

        let image = try await capture(window, size: size)

        let framedImage = applyBezel(
            to: image,
            deviceName: deviceName,
            colorScheme: colorScheme
        )

        guard let data = framedImage.pngData() else {
            throw ScreenshotError.pngEncodingFailed
        }

        try data.write(to: url)

        await unwind(hostingController)
    }

    /// The window every screenshot of a run is rendered in.
    ///
    /// It is created once and stays visible. A fresh `UIWindow` per screenshot makes the render server
    /// set up and tear down a hosting context every time, which is what the `cannot add handler to 0
    /// from 0` and `IOSurfaceClientSetSurfaceNotify` messages in the log report, and a context that has
    /// only just been created composites effect views (blur, iOS 26 Liquid Glass) from a backdrop it has
    /// not sampled yet.
    ///
    /// The window is attached to the scene of the test host, because a scene-less window is never handed
    /// to the render server at all: no effects, and modal presentations misbehave.
    private static func makeWindow() async throws -> UIWindow {
        let scene = try await windowScene()

        let window = UIWindow(windowScene: scene)
        // Without a root view controller the window is not laid out, so the render server has nothing
        // to host until the first preview arrives.
        window.rootViewController = UIViewController()
        window.makeKeyAndVisible()
        return window
    }

    /// Takes the preview content back off screen.
    ///
    /// Removing the content is what lets SwiftUI unwind its own presentation. Dismissing instead makes a
    /// preview whose `isPresented` is a constant (`.sheet(isPresented: .constant(true))`) request the
    /// presentation once more, and by then the content is on its way out: that is the "A sheet was
    /// presented but its presenter is not yet in the window" fault, which the log shows *after* the
    /// screenshot was written, not before.
    private static func unwind(_ hostingController: UIHostingController<AnyView>) async {
        hostingController.rootView = AnyView(EmptyView())
        hostingController.view.layoutIfNeeded()

        let isUnwound = await wait(upTo: modalSettleTimeout) {
            hostingController.presentedViewController == nil
        }

        // Nothing is left to re-request the presentation now, so dismissing is safe as a last resort.
        if !isUnwound {
            hostingController.dismiss(animated: false)
        }
    }

    /// Renders the window, including anything presented on top of it.
    ///
    /// The window is captured twice and only the second image is kept: `drawHierarchy(in:afterScreenUpdates:)`
    /// is what triggers the screen update it needs, so effect views that sample their backdrop (blur,
    /// Liquid Glass) are composed from the very frame the first pass requests. The second pass finds
    /// that frame already there.
    private static func capture(_ window: UIWindow, size: CGSize) async throws -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)

        func draw() -> UIImage {
            renderer.image { _ in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
        }

        _ = draw()
        try await Task.sleep(for: renderSettleDelay)
        return draw()
    }

    /// Waits for a `.sheet` or an `.alert` to finish presenting, so the capture doesn't happen while the
    /// transition is only halfway through.
    ///
    /// SwiftUI drives both through UIKit, so nothing is presented yet when the content appears: the
    /// presentation is only requested on one of the next run loop turns, and a preview that flips its
    /// state in a `.task` needs another turn on top of that. A screen without a modal finds nothing and
    /// falls through after the detection window.
    private static func settleModalPresentation(of controller: UIViewController) async {
        guard await wait(upTo: modalDetectionTimeout, until: { controller.presentedViewController != nil }),
              let presented = controller.presentedViewController else {
            return
        }

        // `isBeingPresented` stays true for the whole transition, and the view only reaches the window
        // once the presentation is committed.
        await wait(upTo: modalSettleTimeout) {
            !presented.isBeingPresented && presented.view.window != nil
        }

        presented.view.setNeedsLayout()
        presented.view.layoutIfNeeded()

        // A modal can present something itself, e.g. an alert on top of a sheet.
        await settleModalPresentation(of: presented)
    }

    /// The scene of the test host.
    ///
    /// It can take a moment to connect, so it is awaited rather than taken as given. Not having one is
    /// worth failing over instead of writing screenshots that silently lost every effect.
    private static func windowScene() async throws -> UIWindowScene {
        await wait(upTo: contentAppearanceTimeout) { connectedWindowScene() != nil }

        guard let scene = connectedWindowScene() else {
            throw ScreenshotError.noWindowScene
        }
        return scene
    }

    private static func connectedWindowScene() -> UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
    }

    /// Lets the run loop run until `condition` holds and reports whether it did.
    ///
    /// Sleeping hands the main actor back to UIKit, so pending layout, `onAppear` and presentation work
    /// runs between the checks.
    @discardableResult
    private static func wait(
        upTo timeout: Duration,
        step: Duration = .milliseconds(10),
        until condition: @MainActor () -> Bool
    ) async -> Bool {
        if condition() {
            return true
        }

        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            try? await Task.sleep(for: step)
            if condition() {
                return true
            }
        }
        return false
    }

    // MARK: - Preview hosting

    /// Records that the preview content has appeared on screen.
    @MainActor
    private final class PreviewAppearance {
        var hasAppeared = false
    }

    /// Holds the preview content back until the hosting view is on screen, and reports when it is.
    ///
    /// A preview that starts with a sheet already presented (`isPresented` is `true` on the first body
    /// evaluation) otherwise requests the presentation while the hosting view is still outside any
    /// window. UIKit logs "A sheet was presented but its presenter is not yet in the window", defers the
    /// presentation and runs it later, against whatever the window looks like by then. Building the
    /// content in `onAppear` instead means every presentation is requested from a view that is in the
    /// window, with the final size and traits.
    private struct PreviewHost<Content: View>: View {
        private let appearance: PreviewAppearance
        private let content: Content

        @State private var isOnScreen = false

        init(appearance: PreviewAppearance, @ViewBuilder content: () -> Content) {
            self.appearance = appearance
            self.content = content()
        }

        var body: some View {
            ZStack {
                if isOnScreen {
                    content
                        .onAppear { appearance.hasAppeared = true }
                }
            }
            // Keeps the hosting view at full size while the content is still held back, so the content
            // never lays out against an empty frame first.
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear { isOnScreen = true }
        }
    }

    // MARK: - Bezels

    /// Composites the device bezel over the screenshot, so that the result looks like a real device photo.
    ///
    /// The bezel image is named `<deviceName>_bezel_dark` for dark mode and `<deviceName>_bezel_light` for
    /// light mode, with `<deviceName>_bezel` as fallback. Its screen hole must be transparent and exactly
    /// the size of the rendered screenshot. The output is the full bezel at its native size, so the phone
    /// frame is visible around the screen. The area outside the bezel stays transparent.
    ///
    /// The screenshot's corners are clipped to the screen hole's rounded shape with a crisp edge, so they
    /// don't poke out over the frame. The clip is rendered without antialiasing so its edge has no
    /// partially transparent rim, which would otherwise let the frame bleed through against dark content.
    ///
    /// If no bezel image exists for the device, the screenshot is written as-is.
    private static func applyBezel(
        to image: UIImage,
        deviceName: String,
        colorScheme: ColorScheme
    ) -> UIImage {
        guard let bezel = bezelImage(for: deviceName, colorScheme: colorScheme),
              let hole = screenHole(in: bezel) else {
            return image
        }

        let outputSize = bezel.size
        let renderer = UIGraphicsImageRenderer(size: outputSize)

        let roundedImage = UIGraphicsImageRenderer(size: image.size).image { context in
            context.cgContext.setShouldAntialias(false)
            UIBezierPath(
                roundedRect: CGRect(origin: .zero, size: image.size),
                cornerRadius: hole.cornerRadius
            ).addClip()
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }

        return renderer.image { _ in
            roundedImage.draw(in: hole.rect)
            bezel.draw(in: CGRect(origin: .zero, size: outputSize))
        }
    }

    /// The screen hole of a bezel: its bounding rect in the screenshot's coordinate space, plus the
    /// corner radius of its rounded shape in points.
    private struct ScreenHole {
        let rect: CGRect
        let cornerRadius: CGFloat
    }

    /// Locates the bezel image's transparent screen hole and measures its corner radius.
    ///
    /// The transparent pixels connected to the image border (the area around the phone) are flood-filled
    /// away, so that the remaining transparent region is the screen cutout.
    ///
    /// The corner radius is measured from the hole shape itself, so it adapts to whatever bezel asset is
    /// used instead of being hardcoded per device. For each bbox corner a diagonal is walked toward the
    /// center until the first hole pixel. A rounded rect of radius `r` first meets that diagonal at
    /// `r · (1 − 1/√2) ≈ 0.2929 · r`, so `r` is the walk length divided by that factor. A small margin is
    /// added so the clipped corner sits just behind the opaque frame instead of riding its inner edge.
    private static func screenHole(in bezel: UIImage) -> ScreenHole? {
        guard let cgImage = bezel.cgImage else {
            return nil
        }

        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else {
            return nil
        }

        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Pixels with at most this alpha count as transparent; the tolerance absorbs the anti-aliased
        // hole edge so the measured hole is the full screen size.
        let alphaThreshold: UInt8 = 16

        func isTransparent(_ x: Int, _ y: Int) -> Bool {
            pixels[(y * width + x) * 4 + 3] <= alphaThreshold
        }

        // Flood-fill the transparent area connected to the image border (the region around the phone).
        var outside = [Bool](repeating: false, count: width * height)
        var queue = [(x: Int, y: Int)]()
        var head = 0

        func enqueueIfTransparent(_ x: Int, _ y: Int) {
            guard x >= 0, x < width, y >= 0, y < height else {
                return
            }
            guard !outside[y * width + x], isTransparent(x, y) else {
                return
            }
            outside[y * width + x] = true
            queue.append((x, y))
        }

        for x in 0..<width {
            enqueueIfTransparent(x, 0)
            enqueueIfTransparent(x, height - 1)
        }
        for y in 0..<height {
            enqueueIfTransparent(0, y)
            enqueueIfTransparent(width - 1, y)
        }

        while head < queue.count {
            let (x, y) = queue[head]
            head += 1
            enqueueIfTransparent(x + 1, y)
            enqueueIfTransparent(x - 1, y)
            enqueueIfTransparent(x, y + 1)
            enqueueIfTransparent(x, y - 1)
        }

        // The screen hole is the transparent area not connected to the border.
        var minX = width, minY = height, maxX = -1, maxY = -1
        for y in 0..<height {
            for x in 0..<width {
                guard isTransparent(x, y), !outside[y * width + x] else {
                    continue
                }
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }
        guard maxX >= minX, maxY >= minY else {
            return nil
        }

        // Walk a diagonal from each bbox corner toward the center until the first hole pixel. The bbox
        // edges themselves aren't reliable: the anti-aliased frame edge shifts the straight-edge start by
        // several pixels, so the radius is fit from the arc that hugs the corner instead.
        var diagonal: CGFloat = 0
        let corners = [
            (minX, maxY, 1, -1), // bottom-left
            (maxX, maxY, -1, -1), // bottom-right
            (maxX, minY, -1, 1), // top-right
            (minX, minY, 1, 1), // top-left
        ]
        for (cx, cy, dx, dy) in corners {
            var k = 1
            while k < min(width, height) {
                let x = cx + dx * k
                let y = cy + dy * k
                guard x >= 0, x < width, y >= 0, y < height else {
                    break
                }
                if isTransparent(x, y), !outside[y * width + x] {
                    diagonal = max(diagonal, CGFloat(k))
                    break
                }
                k += 1
            }
        }
        guard diagonal > 0 else {
            return nil
        }

        // The diagonal first meets a rounded-rect corner of radius r at r · (1 − 1/√2). The margin (in
        // bezel pixels, i.e. points for these 1x assets) pushes the clip edge under the opaque frame.
        let cornerRadius = diagonal / (1 - 1 / sqrt(2)) - 5

        let scale = bezel.scale
        return ScreenHole(
            rect: CGRect(
                x: CGFloat(minX) / scale,
                y: CGFloat(minY) / scale,
                width: CGFloat(maxX - minX + 1) / scale,
                height: CGFloat(maxY - minY + 1) / scale
            ),
            cornerRadius: cornerRadius
        )
    }

    private static func bezelImage(for deviceName: String, colorScheme: ColorScheme) -> UIImage? {
        let testBundle = Bundle(for: ScreenshotGeneratorBundle.self)
        let names = [
            "\(deviceName)_bezel_\(colorScheme == .dark ? "dark" : "light")",
            "\(deviceName)_bezel",
        ]

        for name in names {
            if let image = UIImage(named: name, in: testBundle, compatibleWith: nil)
                ?? UIImage(named: name) {
                return image
            }
        }
        return nil
    }

    /// Bundle marker so that bezel assets bundled into the test target can be found.
    private final class ScreenshotGeneratorBundle { }
}
