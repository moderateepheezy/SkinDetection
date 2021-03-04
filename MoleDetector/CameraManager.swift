//
//  CameraManager.swift
//  MoleDetector
//
//  Created by Simpumind on 04/03/2021.
//

import Foundation
import CoreImage
import AVFoundation
import RxCocoa
import RxSwift
import UIKit

protocol CameraContainer {
	var camera: CameraManager { get }
}

protocol CameraManagerDelegate: AnyObject {
	func didCapturedImage(_ image: CapturedImage)
}

enum CameraManagerError: Error {
	case cameraDeviceNotAvailable
	case cameraDeviceNotSet
	case unableToSetPhotoSession
	case unableToAddCameraInput
	case unableToAddDataOutput
	case unableToAddPhotoOutput
}

struct CameraConfig {
	let defaultVideoZoom: CGFloat = 3
}

final class CameraManager: NSObject {
	enum FlashState {
		case auto
		case off
		case on
		case unavailable
		
		var toggled: FlashState {
			switch self {
			case .auto:
				return .off
			case .off:
				return .on
			case .on:
				return .auto
			case .unavailable:
				return .unavailable
			}
		}
		
		var mode: AVCaptureDevice.FlashMode? {
			switch self {
			case .auto:
				return .auto
			case .off:
				return .off
			case .on:
				return .on
			case .unavailable:
				return .none
			}
		}
	}
	
	enum ZoomLevel {
		case normal
		case magnify
		
		var level: CGFloat {
			switch self {
			case .normal:
				return 1.0
			case .magnify:
				return 2.0
			}
		}
	}
	
	let config: CameraConfig
	var flashState: FlashState = .off
	var zoomLevel: ZoomLevel = .magnify
	
	let isCaptureSessionRunning: BehaviorRelay<Bool> = BehaviorRelay(value: false)
	let videoImage: PublishRelay<CIImage> = PublishRelay() // hot!
	let isTorchEnabled: BehaviorRelay<Bool> = BehaviorRelay(value: false)
	
	private(set) lazy var previewLayer = AVCaptureVideoPreviewLayer(session: session)
	var cameraPosition: AVCaptureDevice.Position = .back
	
	weak var delegate: CameraManagerDelegate?
	
	private let sessionQueue = DispatchQueue(label: "ai.afees.camera.session.\(UUID().uuidString)")
	private let dataOutputQueue = DispatchQueue(label: "ai.afees.camera.data.\(UUID().uuidString)")
	
	private let session = AVCaptureSession()
	
	private var cameraDevice: AVCaptureDevice? {
		didSet {
			if oldValue != cameraDevice {
				observeCamera()
			}
		}
	}
	
	private lazy var photoOutput: AVCapturePhotoOutput = {
		let output = AVCapturePhotoOutput()
		output.isHighResolutionCaptureEnabled = true
		return output
	}()
	
	private lazy var videoDataOutput: AVCaptureVideoDataOutput = {
		let output = AVCaptureVideoDataOutput()
		output.alwaysDiscardsLateVideoFrames = true
		output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
		return output
	}()
	
	private var videoDataOutputEnabled = true
	
	private let disposeBag = DisposeBag()
	
	private var cameraDisposeBag = DisposeBag()
	
	override private init() {
		fatalError()
	}
	
	init(config: CameraConfig = CameraConfig()) {
		self.config = config
		
		super.init()
		
		observeSession()
	}
	
	func setCamera(position: AVCaptureDevice.Position) throws {
		cameraDevice = AVCaptureDevice.DiscoverySession(
			deviceTypes: [.builtInWideAngleCamera],
			mediaType: .video,
			position: position
		).devices.first
		
		guard cameraDevice != nil else {
			throw CameraManagerError.cameraDeviceNotAvailable
		}
	}
	
	func flipCamera() {
		stopRecording()
		cameraDevice = nil
		zoomLevel = .magnify
		flashState = .off
		
		/// This should do the flip here
		switch cameraPosition {
		case .back:
			try? startSession(position: .front)
		case .front:
			try? startSession(position: .back)
		case .unspecified:
			break
		@unknown default:
			break
		}
		
		/// Reconfigure everything here
		try? configureSession()
		try? configureCamera()
		startRecording(async: true)
	}
	
	/// Configures and starts capture session.
	/// Does not reconfigure the session if already configured nor restart if already running.
	/// Create AVCaptureVideoPreviewLayer to see the preview or observe video data ouput.
	func startSession(position: AVCaptureDevice.Position = .back) throws {
		#if targetEnvironment(simulator)
		return
		#endif
		
		guard session.isRunning == false else {
			return
		}
		
		if cameraDevice == nil {
			try setCamera(position: position)
		}
		
		let sessionConfigured = !session.inputs.isEmpty && !session.outputs.isEmpty
		if !sessionConfigured {
			try configureSession()
			try configureCamera()
			startRecording(async: true)
		} else {
			// it just does not look good to have the preview "replaced"
			// block until session is started
			startRecording(async: false)
		}
		
		cameraPosition = position
	}
	
	private func observeSession() {
		#if targetEnvironment(simulator)
		return
		#endif
		
		let currentSessionStarted = NotificationCenter.default.rx.notification(.AVCaptureSessionDidStartRunning)
			.map { $0.object as? AVCaptureSession }
			.filter { [weak self] in self?.session == $0 }
		
		let currentSessionStopped = NotificationCenter.default.rx.notification(.AVCaptureSessionDidStopRunning)
			.map { $0.object as? AVCaptureSession }
			.filter { [weak self] in self?.session == $0 }
		
		Observable.merge(currentSessionStarted.map { _ in true },
						 currentSessionStopped.map { _ in false })
			.bind(to: isCaptureSessionRunning)
			.disposed(by: disposeBag)
		
		NotificationCenter.default.rx.notification(.AVCaptureSessionRuntimeError)
			.filter { [weak self] in self?.session == $0.object as? AVCaptureSession }
			.map { $0.userInfo?[AVCaptureSessionErrorKey] as? Error }
			//.filterNil()
			.subscribe(onNext: { error in
				print("AV Capture runtime error: \(String(describing: error))")
			})
			.disposed(by: disposeBag)
		
		NotificationCenter.default.rx.notification(.AVCaptureSessionWasInterrupted)
			.filter { [weak self] in self?.session == $0.object as? AVCaptureSession }
			.map { $0.userInfo?[AVCaptureSessionInterruptionReasonKey] as? AVCaptureSession.InterruptionReason }
			//.filterNil()
			.subscribe(onNext: { reason in
				print("AV Capture interrupted because: \(String(describing: reason))")
			})
			.disposed(by: disposeBag)
	}
	
	private func observeCamera() {
		cameraDisposeBag = DisposeBag()
		
		guard let camera = cameraDevice else { return }
		
		camera.rx.observe(AVCaptureDevice.TorchMode.self, "torchMode")
			//.filterNil()
			.map({ $0 == .on || $0 == .auto })
			.bind(to: isTorchEnabled)
			.disposed(by: cameraDisposeBag)
	}
	
	private func configureSession() throws {
		guard let camera = cameraDevice else {
			throw CameraManagerError.cameraDeviceNotSet
		}
		
		session.beginConfiguration()
		defer { session.commitConfiguration() }
		
		if session.canSetSessionPreset(.photo) {
			session.sessionPreset = .photo
		} else {
			throw CameraManagerError.unableToSetPhotoSession
		}
		
		// remove old camera input and output
		session.inputs.compactMap { $0 as? AVCaptureDeviceInput }.forEach { self.session.removeInput($0) }
		session.outputs.compactMap { $0 as? AVCapturePhotoOutput }.forEach { self.session.removeOutput($0) }
		session.outputs.compactMap { $0 as? AVCaptureVideoDataOutput }.forEach { self.session.removeOutput($0) }
		
		let input = try AVCaptureDeviceInput(device: camera)
		
		if session.canAddInput(input) {
			session.addInput(input)
		} else {
			throw CameraManagerError.unableToAddCameraInput
		}
		
		if session.canAddOutput(videoDataOutput) {
			videoDataOutput.setSampleBufferDelegate(self, queue: dataOutputQueue)
			session.addOutput(videoDataOutput)
		} else {
			throw CameraManagerError.unableToAddDataOutput
		}
		
		if session.canAddOutput(photoOutput) {
			session.addOutput(photoOutput)
		} else {
			throw CameraManagerError.unableToAddPhotoOutput
		}
	}
	
	func setVideoOutputEnabled(_ isEnabled: Bool) {
		videoDataOutputEnabled = isEnabled
	}
	
	func toggleZoom() {
		try? cameraDevice?.lockForConfiguration()
		
		switch zoomLevel {
		case .normal:
			zoomLevel = .magnify
		case .magnify:
			zoomLevel = .normal
		}
		
		cameraDevice?.ramp(toVideoZoomFactor: zoomLevel.level, withRate: 2)
		cameraDevice?.unlockForConfiguration()
	}
	
	private func configureCamera() throws {
		guard let camera = cameraDevice else {
			throw CameraManagerError.cameraDeviceNotSet
		}
		
		do {
			try camera.lockForConfiguration()
			defer {
				camera.unlockForConfiguration()
			}
			
			camera.videoZoomFactor = zoomLevel.level
			
			let focusPoint = CGPoint(x: 0.5, y: 0.5)
			
			if camera.isFocusModeSupported(.continuousAutoFocus), camera.isFocusPointOfInterestSupported {
				camera.focusPointOfInterest = focusPoint
				camera.focusMode = .continuousAutoFocus
			} else {
				print("focus mode not supported")
			}
			
			if camera.isExposureModeSupported(.continuousAutoExposure), camera.isExposurePointOfInterestSupported {
				camera.exposurePointOfInterest = focusPoint
				camera.exposureMode = .continuousAutoExposure
			} else {
				print("exposure mode not supported")
			}
			
			if camera.isAutoFocusRangeRestrictionSupported {
				camera.autoFocusRangeRestriction = .near
			} else {
				print("range restirction not supported")
			}
		} catch {
			print("unable to lock the camera for initial configuration: \(error.localizedDescription)")
		}
	}
	
	private func stopRecording(async: Bool = false) {
		let curSession = session
		
		guard curSession.isRunning else { return }
		
		if async {
			sessionQueue.async {
				curSession.stopRunning()
			}
		} else {
			sessionQueue.sync {
				curSession.stopRunning()
			}
		}
	}
	
	private func startRecording(async: Bool = true) {
		let curSession = session
		
		guard curSession.isRunning == false else { return }
		
		if async {
			sessionQueue.async {
				curSession.startRunning()
			}
		} else {
			sessionQueue.sync {
				curSession.startRunning()
			}
		}
	}
	
	func focusAtCenter() {
		let centerFocusPoint = CGPoint(x: 0.5, y: 0.5)
		focus(at: centerFocusPoint)
	}
	
	func focus(at focusPoint: CGPoint) {
		guard let camera = cameraDevice else { return }
		
		guard session.isRunning else { return }
		
		do {
			try camera.lockForConfiguration()
			defer { camera.unlockForConfiguration() }
			
			if camera.isFocusModeSupported(.continuousAutoFocus), camera.isFocusPointOfInterestSupported {
				camera.focusPointOfInterest = focusPoint
				camera.focusMode = .continuousAutoFocus
			} else {
				print("focus mode not supported")
			}
			
			if camera.isExposureModeSupported(.continuousAutoExposure), camera.isExposurePointOfInterestSupported {
				camera.exposurePointOfInterest = focusPoint
				camera.exposureMode = .continuousAutoExposure
			} else {
				print("exposure mode not supported")
			}
		} catch {
			print("unable to lock the camera to set focus: \(error.localizedDescription)")
		}
	}
	
	func captureImage() {
		guard delegate != nil else {
			print("delegate not set")
			return
		}
		
		// check if simulator
		#if targetEnvironment(simulator)
		delegate?.didCapturedImage(CapturedImage(image: createImage(), metadata: ImageMetadata()))
		#else
		
		guard
			let format = photoOutput.supportedPhotoCodecTypes(for: .jpg).first
		else {
			print("JPEG not supported")
			return
		}
		
		let settings = AVCapturePhotoSettings(format: [
			AVVideoCodecKey: format,
			AVVideoCompressionPropertiesKey: [AVVideoQualityKey: 8],
		])
		settings.isAutoStillImageStabilizationEnabled = photoOutput.isStillImageStabilizationSupported
		settings.isHighResolutionPhotoEnabled = true
		
		switch flashState {
		case .off, .on, .unavailable:
			settings.flashMode = .off
		case .auto:
			settings.flashMode = .auto
		}
		
		photoOutput.capturePhoto(with: settings, delegate: self)
		#endif
	}
	
	func toggleFlashSetting() {
		flashState = flashState.toggled
		
		guard cameraDevice?.isTorchAvailable == true else { return }
		
		try? cameraDevice?.lockForConfiguration()
		if case .on = flashState {
			try? cameraDevice?.setTorchModeOn(level: 1)
		} else {
			cameraDevice?.torchMode = .off
		}
		
		cameraDevice?.unlockForConfiguration()
	}
	
	func toggleTorch() {
		guard
			let device = cameraDevice,
			device.hasTorch
		else {
			return
		}
		
		let isActive = device.isTorchActive
		
		do {
			try device.lockForConfiguration()
			defer { device.unlockForConfiguration() }
			
			if isActive {
				device.torchMode = .off
			} else {
				try device.setTorchModeOn(level: 1)
			}
		} catch {
			print("unable to toggle torch: \(error.localizedDescription)")
		}
	}
	
	func setTorchActive(_ isActive: Bool) {
		guard
			let device = cameraDevice,
			device.hasTorch,
			device.isTorchActive != isActive
		else {
			return
		}
		
		do {
			try device.lockForConfiguration()
			defer { device.unlockForConfiguration() }
			
			if !isActive {
				device.torchMode = .off
			} else {
				try device.setTorchModeOn(level: 1)
			}
		} catch {
			print("unable to activate torch: \(error.localizedDescription)")
		}
	}
	
	func setZoom(_ zoomFactor: CGFloat) {
		guard
			let device = cameraDevice,
			device.videoZoomFactor != zoomFactor
		else {
			return
		}
		
		guard
			zoomFactor <= device.maxAvailableVideoZoomFactor,
			zoomFactor >= device.minAvailableVideoZoomFactor
		else {
			print("not supported zoom factor: \(zoomFactor)")
			return
		}
		
		do {
			try device.lockForConfiguration()
			defer { device.unlockForConfiguration() }
			
			device.videoZoomFactor = zoomFactor
		} catch {
			print("unable to set zoom: \(error.localizedDescription)")
		}
	}
}

private extension CapturedImage {
	init?(photo: AVCapturePhoto) {
		guard let cgImage = photo.cgImageRepresentation()?.takeUnretainedValue().copy() else { return nil }
		image = cgImage
		metadata = photo.metadata
	}
}

extension CameraManager: AVCapturePhotoCaptureDelegate {
	func photoOutput(_: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
		guard let delegate = delegate else { return }
		guard
			error == nil,
			let image = CapturedImage(photo: photo)
		else {
			if let error = error {
				print(error.localizedDescription)
			} else {
				print("Unable to process captured image")
			}
			
			return
		}
		
		do {
			let normalizedImage = try image.oriented().centerSquared()
			print("captured \(normalizedImage)")
			let ciImage = CIImage(cgImage: normalizedImage.image)
			self.videoImage.accept(ciImage)
			delegate.didCapturedImage(normalizedImage)
		} catch {
			print("Unable to normalize captured image")
		}
	}
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
	func captureOutput(_: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from _: AVCaptureConnection) {
		guard videoDataOutputEnabled else { return }
		guard
			let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer),
			let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
		else {
			print("unable to get video data image buffer")
			return
		}
		
		let srcImage = CIImage(cvImageBuffer: imageBuffer)
		
		// rotate to have portrait video
		let videoDimension = CMVideoFormatDescriptionGetDimensions(formatDesc)
		let videoWidth = CGFloat(videoDimension.width)
		let transform = CGAffineTransform(rotationAngle: -.pi / 2).translatedBy(x: -videoWidth, y: 0)
		let transformedImage = srcImage.transformed(by: transform)
		
		videoImage.accept(transformedImage)
	}
	
	func captureOutput(_: AVCaptureOutput, didDrop _: CMSampleBuffer, from _: AVCaptureConnection) {
		#if DEBUG
		print("didDrop video data frame")
		#endif
	}
}

private func createImage() -> CGImage {
	let size = CGSize(width: 800, height: 800)
	let image = UIImage.withColor(UIColor.random(), size: size)
	
	guard let cgImage = image.cgImage else {
		fatalError("unable to create CGImage for simuator image")
	}
	
	return cgImage
}

extension UIColor {
	static func random() -> UIColor {
		return UIColor(
			hue: .random(in: 0 ... 1),
			saturation: .random(in: 0.5 ... 1),
			brightness: .random(in: 0.5 ... 1),
			alpha: 1
		)
	}
}


extension UIImage {
  static func withColor(_ color: UIColor, size: CGSize = CGSize(width: 1, height: 1)) -> UIImage {
	UIGraphicsBeginImageContext(size)

	guard let context = UIGraphicsGetCurrentContext() else {
	  fatalError("Unable to create image context")
	}

	context.setFillColor(color.cgColor)
	context.fill(CGRect(origin: .zero, size: size))

	guard let image = UIGraphicsGetImageFromCurrentImageContext() else {
	  fatalError("Unable to create image from current context")
	}

	UIGraphicsEndImageContext()

	return image
  }
}
