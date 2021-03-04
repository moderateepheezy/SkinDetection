//
//  CameraPreviewView.swift
//  MoleDetector
//
//  Created by Simpumind on 04/03/2021.
//

import AVFoundation
import UIKit

class CameraPreviewView: UIView {
  var videoPreviewLayer: AVCaptureVideoPreviewLayer? {
	didSet {
	  guard oldValue != videoPreviewLayer else { return }
	  oldValue?.removeFromSuperlayer()
	  if let previewLayer = videoPreviewLayer {
		layer.addSublayer(previewLayer)
		previewLayer.frame = layer.bounds
		previewLayer.videoGravity = videoGravity
		previewLayer.connection?.videoOrientation = videoOrientation
	  }
	}
  }

  var videoGravity: AVLayerVideoGravity = .resizeAspectFill {
	didSet {
	  videoPreviewLayer?.videoGravity = videoGravity
	}
  }

  var videoOrientation: AVCaptureVideoOrientation = .portrait {
	didSet {
	  videoPreviewLayer?.connection?.videoOrientation = videoOrientation
	}
  }

  override func layoutSubviews() {
	super.layoutSubviews()

	videoPreviewLayer?.frame = bounds
  }
}

