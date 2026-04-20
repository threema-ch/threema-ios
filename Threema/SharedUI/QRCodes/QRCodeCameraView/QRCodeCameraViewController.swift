@preconcurrency
import AVFoundation

import CocoaLumberjackSwift
import ThreemaMacros
import UIKit

final class QRCodeCameraViewController: UIViewController {

    // MARK: - Public properties

    var onCompletion: ((String?) -> Void)?

    // MARK: - Private properties

    private let audioSessionManager: AudioSessionManagerProtocol
    private let systemFeedbackManager: SystemFeedbackManagerProtocol
    private let systemPermissionsManager: SystemPermissionsManagerProtocol

    private var captureSession: AVCaptureSession?
    private var isRunning = false
    private var previewLayer = AVCaptureVideoPreviewLayer()
    private var previewView = UIView()
    private var initialPinchZoom: CGFloat = 1.0
    private var videoDevice: AVCaptureDevice?

    // MARK: - Lifecycle

    init(
        audioSessionManager: AudioSessionManagerProtocol,
        systemFeedbackManager: SystemFeedbackManagerProtocol,
        systemPermissionsManager: SystemPermissionsManagerProtocol
    ) {
        self.audioSessionManager = audioSessionManager
        self.systemFeedbackManager = systemFeedbackManager
        self.systemPermissionsManager = systemPermissionsManager
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("Not available")
    }

    // MARK: - Override super class

    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        setupObservers()
        setupPinchGesture()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateViews()
        resumeRunning()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Task {
            await handlePermissionsAndStartIfGranted()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopRunning()
        NotificationCenter.default.removeObserver(self)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        let targetTransform = coordinator.targetTransform
        let inverseTransform = CGAffineTransformInvert(targetTransform)
        coordinator.animate { [weak self] _ in
            guard let self else {
                return
            }
            previewView.transform = CGAffineTransformConcat(previewView.transform, inverseTransform)
            previewView.frame = view.bounds
            previewLayer.frame = previewView.bounds
        }
    }

    // MARK: - Public methods

    func resumeRunning() {
        removeCornersPathLayers()
        guard !isRunning, let captureSession else {
            return
        }
        audioSessionManager.setAmbientAudioActive(true)
        Task.detached {
            captureSession.startRunning()
        }
        isRunning = true
    }

    func stopRunning() {
        guard isRunning else {
            return
        }
        captureSession?.stopRunning()
        audioSessionManager.setAmbientAudioActive(false)
        isRunning = false
    }

    // MARK: - Private types

    private struct ScannedCode {
        let value: String?
        let bezierPath: UIBezierPath
    }

    // MARK: - Helpers

    private func setupViews() {
        view.backgroundColor = .black
        view.addSubview(previewView)
    }

    private func updateViews() {
        previewView.frame = view.bounds
        previewLayer.frame = previewView.bounds
    }

    private func setupObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(willEnterForegroundNotification),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didEnterBackgroundNotification),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }

    private func updateCameraOrientation() {
        guard let connection = previewLayer.connection else {
            return
        }

        let orientation = view.window?.windowScene?.effectiveGeometry.interfaceOrientation ?? .unknown

        let rotationAngle: CGFloat =
            switch orientation {
            case .portrait: 90.0
            case .portraitUpsideDown: 270.0
            case .landscapeLeft: 180.0
            case .landscapeRight: 0.0
            default: 90.0 // default Portrait for Unknown, FaceUp, FaceDown
            }
        if connection.isVideoRotationAngleSupported(rotationAngle) {
            connection.videoRotationAngle = rotationAngle
        }
        else {
            let fallbackAngles: [CGFloat] = [0.0, 90.0, 180.0, 270.0]
            for angle in fallbackAngles {
                if connection.isVideoRotationAngleSupported(angle) {
                    connection.videoRotationAngle = angle
                    break
                }
            }
        }
    }

    private func handlePermissionsAndStartIfGranted() async {
        let granted = await systemPermissionsManager.hasVideoCapturePermission()
        if granted {
            setupCaptureSessionIfNeeded()
            updateCameraOrientation()
            resumeRunning()
        }
        else {
            showCameraAccessAlert()
        }
    }

    private func setInitialZoomFactor() {
        do {
            guard let videoDevice else {
                return
            }
            try videoDevice.lockForConfiguration()
            defer { videoDevice.unlockForConfiguration() }
            videoDevice.videoZoomFactor = 1.0
        }
        catch { /* no-op */ }
    }

    private func setupCaptureSessionIfNeeded() {
        guard captureSession == nil else {
            return
        }

        guard let device = AVCaptureDevice.default(for: .video) else {
            return
        }
        videoDevice = device

        setInitialZoomFactor()

        let session = AVCaptureSession()

        guard
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else {
            return
        }

        session.addInput(input)

        let queue = DispatchQueue(label: "ch.threema.app.qrmetadata.serialQueue")
        let output = AVCaptureMetadataOutput()

        if session.canAddOutput(output) {
            session.addOutput(output)
        }
        captureSession = session

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = previewView.bounds
        previewView.layer.addSublayer(layer)
        previewLayer = layer

        // This needs to be done after the output has been added to the session
        output.metadataObjectTypes = [.qr, .microQR]
        output.setMetadataObjectsDelegate(self, queue: queue)
    }

    private func setupPinchGesture() {
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        previewView.addGestureRecognizer(pinch)
    }

    private func showCameraAccessAlert() {
        UIAlertTemplate.showOpenSettingsAlert(owner: self, noAccessAlertType: .camera)
    }

    private func getFirstCodeFromMetadata(_ metadataObjects: [AVMetadataObject]) -> ScannedCode? {
        let code: ScannedCode? = metadataObjects
            .compactMap { previewLayer.transformedMetadataObject(for: $0) }
            .compactMap { $0 as? AVMetadataMachineReadableCodeObject }
            .compactMap { object in
                let points = object.corners
                guard let firstPoint = points.first else {
                    return nil
                }
                let bezierPath = UIBezierPath()
                bezierPath.move(to: firstPoint)
                for point in points.dropFirst() {
                    bezierPath.addLine(to: point)
                }
                bezierPath.close()
                return ScannedCode(value: object.stringValue, bezierPath: bezierPath)
            }
            .first
        return code
    }

    private func addCornersPathLayer(from code: ScannedCode) {
        let layer = CAShapeLayer()
        layer.path = code.bezierPath.cgPath
        layer.lineWidth = 2.0
        layer.strokeColor = UIColor.blue.cgColor
        layer.fillColor = UIColor.blue.withAlphaComponent(0.5).cgColor
        previewLayer.addSublayer(layer)
    }

    private func removeCornersPathLayers() {
        previewLayer.sublayers.map { layers in
            layers
                .filter { $0 is CAShapeLayer }
                .forEach { $0.removeFromSuperlayer() }
        }
    }

    // MARK: - ObjectiveC methods

    @objc private func willEnterForegroundNotification() {
        resumeRunning()
    }

    @objc private func didEnterBackgroundNotification() {
        stopRunning()
    }

    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        guard let device = videoDevice else {
            return
        }
        if gesture.state == .began {
            initialPinchZoom = device.videoZoomFactor
        }
        if gesture.state == .changed {
            let maxZoomFactor = min(device.activeFormat.videoMaxZoomFactor, 10.0)
            let newZoomFactor = min(max(1.0, device.videoZoomFactor * gesture.scale), maxZoomFactor)
            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = newZoomFactor
                device.unlockForConfiguration()
            }
            catch { }
            gesture.scale = 1.0
        }
    }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate

extension QRCodeCameraViewController: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        stopRunning()
        guard let scannedCode = getFirstCodeFromMetadata(metadataObjects) else {
            Task { @MainActor [weak self] in
                self?.resumeRunning()
            }
            return
        }

        Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            systemFeedbackManager.vibrate()
            removeCornersPathLayers()
            addCornersPathLayer(from: scannedCode)
            try await Task.sleep(seconds: 0.25)
            onCompletion?(scannedCode.value)
        }
    }
}
