//
//  TrackingClient.swift
//  BarcodeReaderforBook
//
//  Created by amamiya on 2023/02/24.
//

import Foundation
import Vision

final class TrackingClient: NSObject, ObservableObject {
    enum State {
        case stop
        case tracking(trackingRequests: [VNTrackObjectRequest])
    }
    
    @Published var visionObjectObservations: [VNDetectedObjectObservation] = []
    @Published var state: State = .stop
    @Published var info: [[String: String]] = [[:]]
    
    private lazy var sequenceRequestHandler = VNSequenceRequestHandler()
    
    func request(cvPixelBuffer pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation, options: [VNImageOption: Any] = [:]) {
        switch state {
        case .stop:
            initRequest(cvPixelBuffer: pixelBuffer, orientation: orientation, options: options)
        case .tracking(trackingRequests: let trackingRequests):
            if trackingRequests.isEmpty {
                initRequest(cvPixelBuffer: pixelBuffer, orientation: orientation, options: options)
                break
            }
            do {
                try sequenceRequestHandler.perform(trackingRequests, on: pixelBuffer, orientation: orientation)
            } catch {
                print(error.localizedDescription)
            }
            
            let newTrackingRequests = trackingRequests.compactMap { request -> VNTrackObjectRequest? in
                guard let results = request.results else { return nil }
                guard let observation = results[0] as? VNDetectedObjectObservation else { return nil }
                
                if !request.isLastFrame {
                    if observation.confidence > 0.99 {
                        request.inputObservation = observation
                    } else {
                        request.isLastFrame = true
                    }
                    return request
                } else {
                    return nil
                }
            }
            
            state = .tracking(trackingRequests: newTrackingRequests)
            if newTrackingRequests.isEmpty {
                self.visionObjectObservations = []
                return
            }
            
            newTrackingRequests.forEach { request in
                guard let result = request.results as? [VNDetectedObjectObservation] else { return }
                self.visionObjectObservations = result
            }
            
        }
    }
    private func initRequest(cvPixelBuffer pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation, options: [VNImageOption: Any] = [:] ){
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: options)
        
        do {
            let detectionRequest = prepareRequest() { [weak self] result in
                switch result {
                case .success(let trackingRequests):
                    self?.state = .tracking(trackingRequests: trackingRequests)
                case .failure(let error):
                    print("error: \(String(describing: error)).")
                }
            }
            try imageRequestHandler.perform([detectionRequest])
        } catch let error as NSError {
            NSLog("Failed to perform detectionRequest: %@", error)
        }
    }
    
    private func prepareRequest(completion: @escaping (Result<[VNTrackObjectRequest], Error>) -> Void) -> VNDetectBarcodesRequest {
        var requests = [VNTrackObjectRequest]()
        let barcodeRequest = VNDetectBarcodesRequest { request, error in
            if let error = error {
                completion(.failure(error))
            }
            
            guard let results = request.results as? [VNBarcodeObservation] else {
                return
            }
            
            let info = results.map { observation -> [String: String] in
                var detectedInfo: [String: String] = [:]
                detectedInfo["symbology"] = observation.symbology.rawValue
                detectedInfo["value"] = observation.payloadStringValue ?? ""
                return detectedInfo
            }
            self.info = info
            
            guard let detectBarcodeRequest = request as? VNDetectBarcodesRequest,
                  let results = detectBarcodeRequest.results else {
                return
            }
            
            for obj in results {
                let barcodeTrackingRequest = VNTrackObjectRequest(detectedObjectObservation: obj)
                requests.append(barcodeTrackingRequest)
            }
            completion(.success(requests))
        }
        
        if #available(iOS 15.0, *) {
            barcodeRequest.symbologies = [.qr, .codabar, .ean13]
        } else {
            // Fallback on earlier versions
            barcodeRequest.symbologies = [.qr, .ean13]
        }
        return barcodeRequest
        
    }
}
