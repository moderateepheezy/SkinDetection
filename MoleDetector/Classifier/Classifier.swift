//
//  Classifier.swift
//  MoleDetector
//
//  Created by Simpumind on 04/03/2021.
//

import CoreImage
import Vision

public struct Classification {
  let image: CIImage
  let observations: [Observation]

  public struct Observation: Equatable {
	let label: String
	let confidence: Float
  }
}

public protocol Classifier {
  func classify(image: CIImage, handler: @escaping (Result<Classification, Error>) -> Void)
}

public class VisionClassifier: Classifier {
  private let model: VNCoreMLModel

  public init(model: MLModel) throws {
	self.model = try VNCoreMLModel(for: model)
  }

  public func classify(image: CIImage, handler: @escaping (Result<Classification, Error>) -> Void) {
	#if TIME_CLASSIFIER
	  let startTime = CACurrentMediaTime()
	#endif

	let classify = VNCoreMLRequest(model: model) { result, _ in
	  if let observations = result.results as? [VNClassificationObservation] {
		#if TIME_CLASSIFIER
		  let timeElapsed = CACurrentMediaTime() - startTime
		  print("Time to classify - \(timeElapsed)")
		#endif

		handler(.success(Classification(
		  image: image,
		  observations: observations.map { Classification.Observation(label: $0.identifier, confidence: $0.confidence) }
		)))
	  }
	}

	do {
	  try VNImageRequestHandler(ciImage: image, options: [:]).perform([classify])
	} catch {
	  handler(.failure(error))
	}
  }
}

extension Classification: Sequence {
  public typealias Iterator = IndexingIterator<Array<Classification.Observation>>

  public func makeIterator() -> Iterator {
	return observations.makeIterator()
  }
}

extension Classification: Collection {
  public typealias Index = Int

  public var startIndex: Index {
	return observations.startIndex
  }

  public var endIndex: Index {
	return observations.endIndex
  }

  public subscript(position: Index) -> Iterator.Element {
	precondition(indices.contains(position), "out of bounds")
	return observations[position]
  }

  public func index(after i: Index) -> Index {
	return observations.index(after: i)
  }
}

func confidence(observations: [Classification.Observation], label: String) -> Float {
  return observations.first(where: { $0.label == label }).map { $0.confidence } ?? 0.0
}

