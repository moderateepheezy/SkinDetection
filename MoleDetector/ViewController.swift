//
//  ViewController.swift
//  MoleDetector
//
//  Created by Simpumind on 04/03/2021.
//

import UIKit
import RxSwift
import RxCocoa
import AVFoundation

class ViewController: UIViewController {
	
	private let disposeBag = DisposeBag()
	
	private var cameraManager = CameraManager()
	
	private let skinClassifer = SkinClassifier()
	
	private var cameraEnabled: Bool = false
	
	private lazy var captureHaptic = UINotificationFeedbackGenerator()
	private lazy var smartHaptic = UISelectionFeedbackGenerator()
	
	private var smartCaptureIsActive: Bool = true {
	  didSet {
		updateCaptureControls()
	  }
	}

	private var smartCaptureWanted: Bool = true {
	  didSet {
		smartCaptureIsActive = smartCaptureWanted
	  }
	}

	private var stability: Int = 0
	
	let customView = View()
	
	override func loadView() {
		view = customView
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		// camera observers
		configureCameraPreview()
		configureSkinTypeMonitor()
		configureCaptureControls()
		
		smartCaptureWanted = false
		customView.captureButton.mode = .smart
		
		NotificationCenter.default.rx.notification(Notification.Name("restartCamera"))
		  .subscribe { [weak self] _ in
			self?.resumeCamera()
		  }
		  .disposed(by: disposeBag)
	}
	
	private func configureCameraOptions() {
		customView.flashButton.addTarget(self, action: #selector(didTapFlash), for: .touchUpInside)
		updateFlashImage()
	}
	
	private func configureCaptureControls() {
		self.customView.captureButton.alpha = 0.8

		self.customView.captureButton.rx
		.controlEvent(.primaryActionTriggered)
		.subscribe(onNext: { [weak self] in
		  self?.captureImage()
		})
		.disposed(by: disposeBag)

		self.customView.smartCaptureButton.rx.tap
		.subscribe(onNext: { [weak self] in
			self?.smartHaptic.selectionChanged()
			self?.smartCaptureWanted = true
			self?.customView.captureButton.mode = .smart
			self?.customView.descriptionLabel.text = nil
			self?.customView.captureButton.setNeedsDisplay()
		})
		.disposed(by: disposeBag)

		self.customView.manualCaptureButton.rx.tap
		.subscribe(onNext: { [weak self] in
			self?.smartHaptic.selectionChanged()
			self?.smartCaptureWanted = false
			self?.customView.captureButton.mode = .manual
			self?.customView.descriptionLabel.text = nil
			self?.customView.captureButton.setNeedsDisplay()
		})
		.disposed(by: disposeBag)

	  configureSmartCapture()
	}
	
	func configureSmartCapture() {
	  // TODO: KAO, check device type and disable smart capture
	  // features if the device type isn't capable of realtime assessment
	  updateCaptureControls()
	}
	
	@objc func didTapFlash() {
	  cameraManager.toggleFlashSetting()
	  updateFlashImage()
	}
	
	private func updateFlashImage() {
	  UIView.animate(withDuration: 1.0) { [weak self] in
		switch self?.cameraManager.flashState {
		case .off:
			self?.customView.flashButton.setTitle("Flash Off", for: .normal)
		case .on:
			self?.customView.flashButton.setTitle("Flash On", for: .normal)
		case .auto:
			self?.customView.flashButton.setTitle("Flash Auto", for: .normal)
		case .unavailable, .none:
			self?.customView.flashButton.setTitle("Flash Off", for: .normal)
		}
	  }
	}
	
	func hideControls() {
		[customView.captureButtonContainer, customView.captureButton].forEach {
			$0.isHidden = true
			$0.alpha = 0.0
		}
	}

	func showControls() {
		[customView.captureButtonContainer, customView.captureButton].forEach {
			$0.isHidden = false
			$0.alpha = 0.0
		}
	 customView.captureButton.setNeedsLayout()

	  UIView.animate(
		withDuration: 0.2,
		delay: 0.15,
		animations: { [weak self] in
			[self?.customView.captureButtonContainer, self?.customView.captureButton].forEach {
				$0?.alpha = 0.0
			}
		  self?.updateFlashImage()
		},
		completion: { [weak self] completed in
			[self?.customView.captureButtonContainer, self?.customView.captureButton].forEach {
				$0?.isUserInteractionEnabled = completed
			}
		  self?.cameraEnabled = completed
		}
	  )
	}
	
	private func configureCameraPreview(isHidden: Bool = true) {
		customView.cameraPreviewView.makeRound(radius: 5)

		customView.backgroundVideoContainerView.alpha = isHidden ? 0 : 1
		customView.cameraPreviewView.alpha = isHidden ? 0 : 1

		customView.cameraPreviewView.videoGravity = .resizeAspectFill
		customView.cameraPreviewView.videoOrientation = .portrait
		customView.cameraPreviewView.videoPreviewLayer = cameraManager.previewLayer

	  cameraManager.videoImage.asObservable()
		.map { UIImage(ciImage: $0) }
		.observe(on: MainScheduler.asyncInstance)
		.bind(to: customView.backgroundVideoContainerView.imageView.rx.image)
		.disposed(by: disposeBag)
	}
	
	private func configureSkinTypeMonitor() {
	  cameraManager.videoImage.asObservable()
		.flatMap(clasify(image:))
		.observe(on: MainScheduler.asyncInstance)
		.do(onNext: handle(value:)) // side effect of changing color
		.map(handle(significance:))
		.throttle(.milliseconds(5), scheduler: ConcurrentMainScheduler.instance)
		.do(onNext: observe(significant:)) // look at the stability of the significance
		.subscribe(onNext: handle(capture:))
		.disposed(by: disposeBag)
	}
	
	private func clasify(image: CIImage) -> Observable<Float> {
	  //guard smartCaptureIsActive else { return Observable.empty() }

	  return skinClassifer.rx.skinType(image: image).asObservable()
	}
	
	private func handle(value: Float) {
	  guard smartCaptureIsActive else { return }

	  UIView.animate(
		withDuration: 0.25,
		delay: 0,
		options: [.beginFromCurrentState, .curveEaseIn],
		animations: {
			self.customView.descriptionLabel.text = value >= 0.85 ? "Skin with accuracy of \(value)" : "This is not a skin, please place camera on a skin: accuracy => \(value)"
			let color: UIColor = value >= 0.85 ? .green : value > 0.2 ? .orange : .red
			self.customView.captureButton.smartModeColor = color
			self.customView.captureButton.setNeedsLayout()
			self.customView.captureButton.setNeedsDisplay()
		},
		completion: nil
	  )
	}

	private func handle(significance: Float) -> Bool {
	  return significance >= 0.85
	}

	private func observe(significant: Bool) {
	  if significant {
		stability += 1
	  } else {
		stability = max(stability - 1, 0)
	  }
	}

	private func handle(capture: Bool) {
	  guard capture, cameraEnabled, stability >= 20 else { return }

	  cameraEnabled = false
		self.customView.captureButton.animateCapture()
	  captureImage()
	}

	/// Shows camera preview and background video view once both are available.
	private func showCameraPreview(animated: Bool) {
	  // do not display until both the camera preview and video data output are available
		customView.backgroundVideoContainerView.alpha = 0
		customView.cameraPreviewView.alpha = 0

	  let animation: (() -> Void) = { [weak self] in
		self?.customView.backgroundVideoContainerView.alpha = 1
		self?.customView.cameraPreviewView.alpha = 1
	  }

	  cameraManager.videoImage.map { _ in }
		.take(1)
		.observe(on: MainScheduler.asyncInstance)
		.subscribe(onNext: {
		  if animated {
			let animator = UIViewPropertyAnimator(duration: 0.5, curve: .easeInOut, animations: animation)
			animator.startAnimation()
		  } else {
			animation()
		  }
		})
		.disposed(by: disposeBag)
	}
	
	private func updateCaptureControls() {
	  guard isViewLoaded else { return }

	  if smartCaptureIsActive {
		UIView.animate(
		  withDuration: 0.3,
		  delay: 0,
		  options: [.beginFromCurrentState, .curveEaseOut],
		  animations: {
			self.customView.smartCaptureButton.tintColor = UIColor.red
			self.customView.manualCaptureButton.tintColor = #colorLiteral(red: 0.501960814, green: 0.501960814, blue: 0.501960814, alpha: 1)
		  },
		  completion: nil
		)
		UIView.animate(
		  withDuration: 0.9,
		  delay: 0,
		  options: [.beginFromCurrentState, .curveEaseInOut, .autoreverse, .repeat, .allowUserInteraction],
		  animations: {
			self.customView.captureButton.alpha = 0.5
		  },
		  completion: nil
		)
	  } else {
		self.customView.captureButton.layer.removeAllAnimations()
		UIView.animate(
		  withDuration: 0.3,
		  delay: 0,
		  options: [.beginFromCurrentState, .curveEaseInOut],
		  animations: {
			self.customView.captureButton.alpha = 0.8
		  },
		  completion: nil
		)
		UIView.animate(
		  withDuration: 0.3,
		  delay: 0,
		  options: [.beginFromCurrentState, .curveEaseOut],
		  animations: {
			self.customView.smartCaptureButton.tintColor = #colorLiteral(red: 0.501960814, green: 0.501960814, blue: 0.501960814, alpha: 1)
			self.customView.manualCaptureButton.tintColor = UIColor.red
		  },
		  completion: nil
		)
	  }
	}

	private func captureImage() {
	  captureHaptic.notificationOccurred(.success)
	  stability = 0
	  cameraManager.captureImage()
	}

	/// Checks if app has permission to use camera and if so starts capture session.
	private func activateCamera() {
	  let startCamera = { [weak self] in
		do {
		  try self?.cameraManager.startSession()
		} catch {
		  print("Failed to start the camera manager: \(error)")
		}
	  }

		guard AVCaptureDevice.authorizationStatus(for: .video) != .authorized else {
			startCamera()
			return
		}
		
		if AVCaptureDevice.authorizationStatus(for: .video) == .denied {
			let message = "Access to your device's Camera is needed for taking Selfies"
			let alert = UIAlertController(title: "Access to Camera Denied",
										  message: message,
										  preferredStyle: .alert)
			alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: { _ in
			  alert.dismiss(animated: true)
			}))
			alert.addAction(UIAlertAction(title: "Settings", style: .default, handler: { _ in
			  let url = URL(string: UIApplication.openSettingsURLString)!
			  UIApplication.shared.open(url, options: [:], completionHandler: nil)
			}))
			self.present(alert, animated: true)
		} else {
			startCamera()
		}
	}

	override func viewWillAppear(_ animated: Bool) {
	  super.viewWillAppear(animated)

	  navigationController?.isNavigationBarHidden = true
	  cameraEnabled = true

	  // TODO: PPP clean the interface and the way of using it
	  resumeCamera()

	  configureCameraOptions()
	}

	override func viewWillDisappear(_ animated: Bool) {
	  super.viewWillDisappear(animated)

	  cameraEnabled = false
	}

	override func viewDidAppear(_ animated: Bool) {
	  super.viewDidAppear(animated)
	  resumeCamera()
	}

	private func resumeCamera() {
	  cameraEnabled = true
	  cameraManager.delegate = self
		self.customView.cameraPreviewView.videoPreviewLayer = cameraManager.previewLayer
	  cameraManager.setVideoOutputEnabled(true)
	  activateCamera()

	  showCameraPreview(animated: cameraManager.isCaptureSessionRunning.value == false)
	}

	override func viewDidDisappear(_ animated: Bool) {
	  super.viewDidDisappear(animated)

	  pauseCamera()
	}

	private func pauseCamera() {
	  cameraManager.delegate = nil
		self.customView.cameraPreviewView.videoPreviewLayer = nil
	  cameraManager.setVideoOutputEnabled(false)
	}
}

extension ViewController: CameraManagerDelegate {
  func didCapturedImage(_ image: CapturedImage) {
	
  }
}

extension UIView {

	func makeRound(radius: CGFloat? = nil) {
		layoutIfNeeded()
		layer.cornerRadius = radius ?? bounds.height / 2.0
		layer.masksToBounds = true
	}

}
