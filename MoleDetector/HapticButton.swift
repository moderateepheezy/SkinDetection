//
//  HapticButton.swift
//  MoleDetector
//
//  Created by Simpumind on 04/03/2021.
//

import UIKit

class HapticButton: UIControl {
  enum Mode {
	case smart
	case manual
	case labeled
  }

  var smartModeColor: UIColor = .white
  var mode: Mode = .smart {
	didSet {
	  switch mode {
	  case .smart, .labeled:
		label?.isHidden = false
	  case .manual:
		label?.isHidden = true
	  }
	  label?.setNeedsUpdateConstraints()
	  setNeedsLayout()
	}
  }

  @IBInspectable var labelText: String = "Ai" {
	didSet {
	  addText()
	}
  }

  @IBInspectable var labelColor = UIColor.white {
	didSet {
	  label?.textColor = labelColor
	}
  }

  var labelFont: UIFont = .systemFont(ofSize: 32, weight: .semibold) {
	didSet {
	  label?.font = labelFont
	}
  }

  private var animator: UIViewPropertyAnimator?
  private var label: UILabel?
  private var outlineLayer: CAShapeLayer?
  private var circleLayer: CAShapeLayer?

  override init(frame: CGRect) {
	super.init(frame: frame)

	addText()
  }

  required init?(coder: NSCoder) {
	super.init(coder: coder)

	addText()
  }

  override func layoutSubviews() {
	super.layoutSubviews()

	control(in: bounds)
	outline(in: bounds)

	if let text = label {
	  bringSubviewToFront(text)
	}
  }

  override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
	guard case .some(.touches) = event?.type else {
	  return super.beginTracking(touch, with: event)
	}

	animateCapture()

	return super.beginTracking(touch, with: event)
  }

  override func cancelTracking(with event: UIEvent?) {
	super.cancelTracking(with: event)

	resetAnimation()
  }

  override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
	super.endTracking(touch, with: event)

	resetAnimation()
	sendActions(for: .primaryActionTriggered)
  }

  public func animateCapture() {
	animator = UIViewPropertyAnimator(duration: 0.2, curve: .easeInOut) { [weak self] in
	  self?.transform = CGAffineTransform(scaleX: 0.75, y: 0.75)
	}

	animator?.startAnimation()
  }

  public func resetAnimation() {
	animator?.stopAnimation(true)
	animator?.finishAnimation(at: .current)
	transform = .identity
  }

  private func addText() {
	guard label == nil else {
	  label?.text = labelText
	  return
	}

	let text = UILabel()
	text.text = labelText
	text.textColor = labelColor
	text.font = labelFont
	text.frame.size = CGSize(width: 40, height: 40)
	text.translatesAutoresizingMaskIntoConstraints = false

	addSubview(text)

	NSLayoutConstraint.activate(
	  [
		text.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -1),
		text.centerXAnchor.constraint(equalTo: centerXAnchor, constant: -1),
	  ]
	)

	label = text
  }

  private func outline(in rect: CGRect) {
	let sublayer = outlineLayer ?? CAShapeLayer()
	let outlinePath = UIBezierPath(ovalIn: rect)

	sublayer.fillColor = UIColor.clear.cgColor
	sublayer.lineWidth = 3

	sublayer.strokeColor = UIColor.white.cgColor
	sublayer.lineDashPattern = []

	sublayer.path = outlinePath.cgPath

	if sublayer.superlayer == nil {
	  layer.addSublayer(sublayer)
	}

	outlineLayer = sublayer
  }

  private func control(in rect: CGRect) {
	let sublayer = circleLayer ?? CAShapeLayer()

	let adjustedRect = CGRect(
	  origin: CGPoint(x: 3, y: 3),
	  size: CGSize(width: rect.width - 6, height: rect.height - 6)
	)

	switch mode {
	case .smart:
	  sublayer.fillColor = smartModeColor.cgColor
	case .manual, .labeled:
	  sublayer.fillColor = UIColor.white.cgColor
	}
	let path = UIBezierPath(ovalIn: adjustedRect)
	sublayer.path = path.cgPath

	if sublayer.superlayer == nil {
	  layer.addSublayer(sublayer)
	}

	circleLayer = sublayer
  }
}

