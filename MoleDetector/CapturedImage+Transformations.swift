//
//  CapturedImage+Transformations.swift
//  MoleDetector
//
//  Created by Simpumind on 04/03/2021.
//

import Foundation
import ImageIO
import CoreImage

enum CapturedImageTransformationError: Error {
  case unableToCreateCGImage
  case unableToCropCGImage
  case unableToCreateCVPixelBuffer
}

extension CapturedImage {
  /// Rotates according to the metadata information.
  func oriented() throws -> CapturedImage {
	guard
	  let orientationProperty = metadata[kCGImagePropertyOrientation as String] as? UInt32,
	  let orientation = CGImagePropertyOrientation(rawValue: orientationProperty)
	else {
	  return self
	}

	let ciImage = CIImage(cgImage: image).oriented(orientation)
	let newImage = try ciImage.createCGImage()
	var newMetadata = metadata
	newMetadata[kCGImagePropertyOrientation as String] = CGImagePropertyOrientation.up.rawValue

	return CapturedImage(image: newImage, metadata: newMetadata)
  }

  /// Crops to (centered) square.
  func centerSquared() throws -> CapturedImage {
	let imageSize = CGSize(width: image.width, height: image.height)
	let newImageRect = CGRect(origin: .zero, size: imageSize).centerSquare
	guard let newImage = image.cropping(to: newImageRect) else {
	  throw CapturedImageTransformationError.unableToCropCGImage
	}
	return CapturedImage(image: newImage, metadata: metadata)
  }
}

private extension CGRect {
  var centerSquare: CGRect {
	let offset = abs((size.width - size.height) / 2)
	let cropX = size.width > size.height ? offset : 0.0
	let cropY = size.width < size.height ? offset : 0.0
	let edgeLength = CGFloat(min(size.width, size.height))
	return CGRect(x: cropX, y: cropY, width: edgeLength, height: edgeLength)
  }
}

private extension CIImage {
  func createCGImage(context: CIContext? = nil) throws -> CGImage {
	let context = context ?? CIContext()
	guard let cgImage = context.createCGImage(self, from: extent) else {
	  throw CapturedImageTransformationError.unableToCreateCGImage
	}
	return cgImage
  }
}
