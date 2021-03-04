//
//  CapturedImage.swift
//  MoleDetector
//
//  Created by Simpumind on 04/03/2021.
//

import Foundation
import ImageIO
import MobileCoreServices

// Valid metadata keys are found in <ImageIO/CGImageProperties.h>
typealias ImageMetadata = [String: Any]

struct CapturedImage {
  let image: CGImage
  let metadata: ImageMetadata

  init(image: CGImage, metadata: ImageMetadata) {
	self.image = image
	self.metadata = metadata
  }
}

enum CapturedImageError: Error {
  case unableToCreateImage
  case unableToCreateImageDestination
  case unableToFinalizeImageDestination
}

extension CapturedImage {
  /// Generates and returns a JPEG data representation of the image and its metadata.
  func jpegData(compressionQuality: CGFloat = 0.8) throws -> Data {
	let dstData = NSMutableData()
	guard let cgImageDst = CGImageDestinationCreateWithData(dstData, kUTTypeJPEG, 1, nil)
	else {
	  throw CapturedImageError.unableToCreateImageDestination
	}

	// add image and the metadata
	var properties = metadata
	properties[kCGImageDestinationLossyCompressionQuality as String] = compressionQuality
	CGImageDestinationAddImage(cgImageDst, image, properties as CFDictionary)

	if CGImageDestinationFinalize(cgImageDst) == false {
	  throw CapturedImageError.unableToFinalizeImageDestination
	}

	return dstData as Data
  }
}

extension CapturedImage: CustomDebugStringConvertible {
  var orientation: CGImagePropertyOrientation? {
	guard
	  let orientationProperty = metadata[kCGImagePropertyOrientation as String] as? UInt32,
	  let orientation = CGImagePropertyOrientation(rawValue: orientationProperty)
	else {
	  return nil
	}
	return orientation
  }

  var debugDescription: String {
	let sizeDesc = "\(image.width)x\(image.height)"
	let orientationDesc = orientation?.debugDescription ?? "?"
	// extract selected meta information
	var meta = [String: String]()
	if let exifDict = metadata[kCGImagePropertyExifDictionary as String] as? [CFString: Any] {
	  for key in [
		kCGImagePropertyExifExposureTime,
		kCGImagePropertyExifISOSpeedRatings,
		kCGImagePropertyExifISOSpeed,
		kCGImagePropertyExifShutterSpeedValue,
		kCGImagePropertyExifApertureValue,
		kCGImagePropertyExifBrightnessValue,
		kCGImagePropertyExifFocalLength,
		kCGImagePropertyExifDigitalZoomRatio,
		kCGImagePropertyExifFocalLenIn35mmFilm,
		kCGImagePropertyExifLensModel,
	  ] {
		if let value = exifDict[key] {
		  meta[key as String] = "\(value)"
		}
	  }
	}
	return "<CapturedImage \(sizeDesc) \(orientationDesc) \(meta))>"
  }
}

extension CGImagePropertyOrientation: CustomStringConvertible, CustomDebugStringConvertible {
  public var description: String {
	switch self {
	case .up: return "up"
	case .upMirrored: return "upMirrored"
	case .down: return "down"
	case .downMirrored: return "downMirrored"
	case .leftMirrored: return "leftMifrored"
	case .right: return "right"
	case .rightMirrored: return "rightMirrored"
	case .left: return "left"
	@unknown default: return "unknown"
	}
  }

  public var debugDescription: String {
	return "\(description) (\(rawValue))"
  }
}

