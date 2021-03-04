//
//  SkinClassifier.swift
//  MoleDetector
//
//  Created by Simpumind on 04/03/2021.
//
import Foundation
import CoreImage
import CoreML
import RxSwift
import RxCocoa

public class SkinClassifier {
	private let classifier: VisionClassifier
	
	public struct SkinType {
		public let skin: Float
		public let nonSkin: Float

	  public enum ObservationName: Float {
		case skin
		case nonSkin
	  }

	  public typealias Observation = (name: ObservationName, confidence: Float)

	  public var observations: [Observation] {
		return [
		  (name: .skin, confidence: skin),
		  (name: .nonSkin, confidence: nonSkin )
		]
	  }

	  public var dominant: Observation {
		return observations.reduce((name: .skin, confidence: skin)) { current, next in
		  next.confidence > current.confidence ? next : current
		}
	  }
	}
	
	public init() {
		let config = MLModelConfiguration()
	  guard let classifier = try? VisionClassifier(model: Skin_Classifier(configuration: config).model) else {
		fatalError("failed to initialise vision classifier")
	  }

	  self.classifier = classifier
	}

	public func classify(image: CIImage, handler: @escaping (Result<SkinType, Error>) -> Void) {
	  let resized = image.size(toFit: CGSize(width: 224, height: 224)) ?? image

	  classifier.classify(image: resized) { classification in
		let skinType = classification.map { classification -> SkinType in
		  let skin = confidence(observations: classification.observations, label: "1")
		  let nonSkin = confidence(observations: classification.observations, label: "0")
			print(skin)
			print(nonSkin)
		  return SkinType(skin: skin, nonSkin: nonSkin)
		}

		handler(skinType)
	  }
	}

	public func getSkin(image: CIImage, handler: @escaping (Result<Float, Error>) -> Void) {
	  classify(image: image) { result in
		let skinType = result.map { skinType -> Float in
		  (skinType.skin * 100).rounded() / 100
		}

		handler(skinType)
	  }
	}
  }

  extension SkinClassifier.SkinType: Equatable {}
  extension SkinClassifier.SkinType: Encodable {}


public extension CIImage {
  var height: CGFloat { return extent.height }
  var width: CGFloat { return extent.width }

  var aspectRatio: Double { return Double(height) / Double(width) }

  func size(toFit size: CGSize) -> CIImage? {
	guard let filter = CIFilter(name: "CILanczosScaleTransform") else {
	  fatalError("CILanczosScaleTransform unavailble")
	}

	let scale = min(size.height / height, size.width / width)

	filter.setValue(self, forKey: kCIInputImageKey)
	filter.setValue(aspectRatio, forKey: kCIInputAspectRatioKey)
	filter.setValue(scale, forKey: kCIInputScaleKey)

	return filter.outputImage
  }
}

private let queue = DispatchQueue(
  label: "afees.ai.skin-classifier",
  qos: .userInitiated,
  attributes: .concurrent
)

extension Reactive where Base: SkinClassifier {
  func skinType(image: CIImage) -> Single<Float> {
	return Single<Float>.create { observer in
	  queue.async {
		self.base.getSkin(image: image) { result in
		  switch result {
		  case let .success(value):
			observer(.success(value))
		  case .failure:
			observer(.success(0))
		  }
		}
	  }

	  return Disposables.create {}
	}.observe(on: MainScheduler())
  }

  func skinType(image: CIImage) -> Single<SkinClassifier.SkinType> {
	return Single<SkinClassifier.SkinType>.create { observer in
	  queue.async {
		self.base.classify(image: image) { result in
		  switch result {
		  case let .success(value):
			observer(.success(value))
		  case let .failure(error):
			observer(.failure(error))
		  }
		}
	  }
	  return Disposables.create {}
	}.observe(on: MainScheduler())
  }
}

extension SkinClassifier: ReactiveCompatible {}
