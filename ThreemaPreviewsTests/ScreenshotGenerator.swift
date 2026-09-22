import SwiftUI
import UIKit

@MainActor
enum ScreenshotGenerator {
    enum ScreenshotError: Error {
        case pngEncodingFailed
    }

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
        to url: URL
    ) async throws {
        let style: UIUserInterfaceStyle = colorScheme == .dark ? .dark : .light

        let hostingController = UIHostingController(
            rootView: AnyView(view.environment(\.colorScheme, colorScheme))
        )
        hostingController.overrideUserInterfaceStyle = style

        // Attach the window to a real scene, otherwise the render server never composites effect
        // views (blur, iOS 26 Liquid Glass) and the screenshot loses e.g. the glass back button.
        let window: UIWindow
        if let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first {
            window = UIWindow(windowScene: scene)
            window.frame = CGRect(origin: .zero, size: size)
        }
        else {
            window = UIWindow(frame: CGRect(origin: .zero, size: size))
        }
        window.overrideUserInterfaceStyle = style

        hostingController.view.frame = window.bounds
        hostingController.view.backgroundColor = .systemBackground

        window.rootViewController = hostingController
        window.makeKeyAndVisible()

        hostingController.view.setNeedsLayout()
        hostingController.view.layoutIfNeeded()
        window.layoutIfNeeded()

        // Give the render server enough time to composite the window before capturing it.
        try await Task.sleep(for: .milliseconds(200))

        let renderer = UIGraphicsImageRenderer(size: size)

        let image = renderer.image { _ in
            window.drawHierarchy(
                in: window.bounds,
                afterScreenUpdates: true
            )
        }

        let framedImage = applyBezel(
            to: image,
            deviceName: deviceName,
            colorScheme: colorScheme
        )

        guard let data = framedImage.pngData() else {
            throw ScreenshotError.pngEncodingFailed
        }

        try data.write(to: url)

        window.isHidden = true
        window.rootViewController = nil
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
