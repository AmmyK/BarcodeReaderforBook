//
//  TrackingViewModel.swift
//  BarcodeReaderforBook
//
//  Created by amamiya on 2023/02/24.
//

import Foundation
import Combine
import AVKit
import Vision


final class TrackingViewModel: ObservableObject {
    let captureSession = CaptureSession()
    let trackingClient = TrackingClient()
    
    var previewLayer: AVCaptureVideoPreviewLayer {
        return captureSession.previewLayer
    }
    
    @Published var pixelSize: CGSize = .zero
    @Published var isAdded: Bool = false
    
    @Published var detectedRects: [CGRect] = []
    @Published var info: [[String:String]] = [[:]]
    
    @Published var isTracking: Bool = false
    
    private var cancellables: Set<AnyCancellable> = []
    
    init() {
        bind()
    }
    
    func bind() {
        captureSession.outputs
            .receive(on: RunLoop.main)
            .sink { [weak self] output in
                guard let self = self else { return }
                
                var requestHandlerOptions: [VNImageOption: AnyObject] = [:]
                requestHandlerOptions[VNImageOption.cameraIntrinsics] = output.cameraIntrinsicData
                self.pixelSize = output.pixelBufferSize
                
                if !self.isAdded {
                    self.trackingClient.request	(cvPixelBuffer: output.pixelBuffer,
                                                 orientation: self.makeOrientation(with: UIDevice.current.orientation),
                                                 options: requestHandlerOptions)
                }
            }
            .store(in: &cancellables)
        
        trackingClient.$visionObjectObservations
            .receive(on: RunLoop.main)
            .map { observations -> [CGRect] in
                return observations.map { $0.boundingBox }
            }
            .assign(to: &$detectedRects)
        
        trackingClient.$info
            .receive(on: RunLoop.main)
            .assign(to: &$info)
        
        trackingClient.$info
            .receive(on: RunLoop.main)
            .compactMap {
                var data: [String:String] = [:]
                for i in $0.indices {
                    if !$0[i].isEmpty {
                        data = $0[i]
                        self.isTracking = true
                        self.previewLayer.borderWidth = 2
                        self.previewLayer.borderColor = UIColor.green.cgColor
                    }
                }
                return data
            }
            .assign(to: &$barcode)
        
        $isTracking.sink {
            if $0 == true {
                Task {
                    do {
                        try await self.fetchBook()
                    } catch {
                        print(error.localizedDescription)
                    }
                }
            }
        }
        .store(in: &cancellables)
        
    }
    
    func startSession() {
        captureSession.startSession()
    }
    
    private func makeOrientation(with deviceOrientation: UIDeviceOrientation) -> CGImagePropertyOrientation {
        switch deviceOrientation{
        case .portraitUpsideDown:
            return .rightMirrored
        case .landscapeLeft:
            return .downMirrored
        case .landscapeRight:
            return .upMirrored
        default:
            return .leftMirrored
        }
    }

    @Published var book: [Item] = []
    @Published var barcode: [String:String] = [:]
    
    func fetchBook() async throws {
        let urlString = Constants.baseURL
        guard let url = URL(string: urlString) else {
            throw HttpError.badURL
        }

        var component = URLComponents(url: url, resolvingAgainstBaseURL: true)
        component?.queryItems = [URLQueryItem(name: EndPoints.q, value: barcode["value"])]
        
        guard let addedQueryUrl = component?.url else { return }
        print(addedQueryUrl.absoluteURL)
        let items: [Item] = try await HttpClient().fetch(url: addedQueryUrl)
        sleep(1)
        DispatchQueue.main.async {
            if !items.isEmpty {
                self.book = items
                self.isAdded = true
            }
        }
    }
    
    func resetParameter() {
        self.previewLayer.borderColor = UIColor.clear.cgColor
        self.detectedRects = []
        self.pixelSize = .zero
        self.book = []
        self.info = [[:]]
        self.isAdded = false
        self.isTracking = false
        self.barcode = [:]
    }
    
}

