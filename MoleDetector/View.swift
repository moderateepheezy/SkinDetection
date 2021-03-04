//
//  View.swift
//  MoleDetector
//
//  Created by Simpumind on 04/03/2021.
//

import UIKit

final class View: UIView {
	
	let backgroundVideoContainerView: BackgroundVideoViewContainer = {
		let imageView = BackgroundVideoViewContainer()
		imageView.translatesAutoresizingMaskIntoConstraints = false
		return imageView
	}()
	
	let cameraPreviewView: CameraPreviewView = {
		let view = CameraPreviewView()
		view.backgroundColor = #colorLiteral(red: 0.1773551702, green: 0.1773919761, blue: 0.1773503721, alpha: 1)
		view.layer.cornerRadius = 10
		view.clipsToBounds = true
		view.translatesAutoresizingMaskIntoConstraints = false
		return view
	}()
	
	let captureButton: HapticButton = {
		let button = HapticButton()
		button.translatesAutoresizingMaskIntoConstraints = false
		return button
	}()
	
	let manualCaptureButton: UIButton = {
		let button = UIButton()
		button.setTitle("Manual", for: .normal)
		button.setTitleColor(.systemBlue, for: .normal)
		button.translatesAutoresizingMaskIntoConstraints = false
		return button
	}()
	
	let smartCaptureButton: UIButton = {
		let button = UIButton()
		button.setTitle("Smart", for: .normal)
		button.setTitleColor(.systemBlue, for: .normal)
		button.translatesAutoresizingMaskIntoConstraints = false
		return button
	}()
	
	private(set) lazy var captureButtonContainer: UIStackView = {
		let stackView = UIStackView(arrangedSubviews: [smartCaptureButton, manualCaptureButton])
		stackView.spacing = 20
		stackView.axis = .horizontal
		stackView.distribution = .fillEqually
		stackView.translatesAutoresizingMaskIntoConstraints = false
		return stackView
	}()
	
	let flashButton: UIButton = {
		let button = UIButton()
		button.setTitle("Flash Off", for: .normal)
		button.setTitleColor(.systemBlue, for: .normal)
		button.translatesAutoresizingMaskIntoConstraints = false
		return button
	}()
	
	let descriptionLabel: UILabel = {
		let label = UILabel()
		label.numberOfLines = 0
		label.translatesAutoresizingMaskIntoConstraints = false
		return label
	}()
	
	override init(frame: CGRect) {
		super.init(frame: frame)
		setupViewHeirachy()
		setupConstraints()
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	private func setupViewHeirachy() {
		[backgroundVideoContainerView, cameraPreviewView,
		 captureButton, captureButtonContainer,
		 flashButton, descriptionLabel].forEach {
			addSubview($0)
		}
	}

	private func setupConstraints() {
		let safeAreaView = safeAreaLayoutGuide
		
		NSLayoutConstraint.activate([
			backgroundVideoContainerView.topAnchor.constraint(equalTo: topAnchor),
			backgroundVideoContainerView.leadingAnchor.constraint(equalTo: leadingAnchor),
			backgroundVideoContainerView.trailingAnchor.constraint(equalTo: trailingAnchor),
			backgroundVideoContainerView.bottomAnchor.constraint(equalTo: bottomAnchor)
		])
		
		NSLayoutConstraint.activate([
			cameraPreviewView.topAnchor.constraint(equalTo: safeAreaView.topAnchor, constant: 30),
			cameraPreviewView.leadingAnchor.constraint(equalTo: leadingAnchor),
			cameraPreviewView.trailingAnchor.constraint(equalTo: trailingAnchor),
			cameraPreviewView.heightAnchor.constraint(equalTo: widthAnchor)
		])
		
		NSLayoutConstraint.activate([
			captureButton.topAnchor.constraint(equalTo: cameraPreviewView.bottomAnchor, constant: 30),
			captureButton.centerXAnchor.constraint(equalTo: centerXAnchor),
			captureButton.widthAnchor.constraint(equalToConstant: 60),
			captureButton.heightAnchor.constraint(equalToConstant: 60)
		])
		
		NSLayoutConstraint.activate([
			captureButtonContainer.topAnchor.constraint(equalTo: captureButton.bottomAnchor, constant: 20),
			captureButtonContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
			captureButtonContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
			captureButtonContainer.heightAnchor.constraint(equalToConstant: 50)
		])
		
		NSLayoutConstraint.activate([
			flashButton.centerXAnchor.constraint(equalTo: captureButtonContainer.centerXAnchor),
			flashButton.topAnchor.constraint(equalTo: captureButtonContainer.bottomAnchor, constant: 20)
		])
		
		NSLayoutConstraint.activate([
			descriptionLabel.centerXAnchor.constraint(equalTo: flashButton.centerXAnchor),
			descriptionLabel.topAnchor.constraint(equalTo: safeAreaView.bottomAnchor, constant: -20),
			descriptionLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
			descriptionLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20)
		])
	}
}

final class BackgroundVideoViewContainer: UIView {
	
	let imageView: UIImageView = {
		let imageView = UIImageView()
		imageView.contentMode = .scaleAspectFill
		imageView.clipsToBounds = true
		imageView.clearsContextBeforeDrawing = true
		imageView.autoresizesSubviews = true
		imageView.translatesAutoresizingMaskIntoConstraints = false
		return imageView
	}()
	
	let visualEffectView: UIVisualEffectView = {
		let blurEffect = UIBlurEffect(style: .dark)
		let view = UIVisualEffectView(effect: blurEffect)
		view.contentMode = .scaleToFill
		view.isUserInteractionEnabled = true
		view.clearsContextBeforeDrawing = true
		view.autoresizesSubviews = true
		view.translatesAutoresizingMaskIntoConstraints = false
		return view
	}()
	
	override init(frame: CGRect) {
		super.init(frame: frame)
		setupConstraints()
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	private func setupConstraints() {
		[imageView, visualEffectView].forEach {
			addSubview($0)
			$0.topAnchor.constraint(equalTo: topAnchor).isActive = true
			$0.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
			$0.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
			$0.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
		}
	}
}
