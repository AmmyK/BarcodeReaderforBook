//
//  CaptureSession.swift
//  BarcodeReaderforBook
//
//  Created by amamiya on 2023/02/20.
//

import Foundation
import AVKit
import Combine

final class CaptureSession: NSObject, ObservableObject {
    
    struct Outputs {
        let cameraIntrinsicData: CFTypeRef
        let pixelBuffer: CVImageBuffer
        let pixelBufferSize: CGSize
    }
    
    private let captureSession = AVCaptureSession()
    private var captureDevice: AVCaptureDevice?
    
    private var videoDataOutput: AVCaptureVideoDataOutput?
    private var videoDataOutputQueue: DispatchQueue?
    private(set) var previewLayer = AVCaptureVideoPreviewLayer()
    
    var outputs = PassthroughSubject<Outputs, Never>()
    private var cancellable: AnyCancellable?
    
    override init() {
        super.init()
        setupCaptureSession()
    }
    
    func startSession() {
        if captureSession.isRunning {
            return
        }
        DispatchQueue.global(qos: .default).async {
            self.captureSession.startRunning()
        }
    }
    
    func stopSession() {
        if !captureSession.isRunning { return }
        captureSession.stopRunning()
    }
    
    private func setupCaptureSession() {
        captureSession.sessionPreset = .photo
        
        if let availableDevice = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera],
                                                                  mediaType: .video,
                                                                  position: .back).devices.first {
            availableDevice.activeVideoMaxFrameDuration = CMTimeMake(value: 1, timescale: 30)
            captureDevice = availableDevice
            do {
                let captureDeviceInput = try AVCaptureDeviceInput(device: availableDevice)
                captureSession.addInput(captureDeviceInput)
            } catch {
                print(error.localizedDescription)
            }
        }
        makePreviewLayer(session: captureSession)
        
        cancellable = NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)
            .map{ _ in () }
            .prepend(())
            .sink{ [previewLayer] in
                let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
                let window = windowScene?.windows.first
                let interfaceOrientation = window?.windowScene?.interfaceOrientation
                
                if let interfaceOrientation = interfaceOrientation,
                   let orientation = AVCaptureVideoOrientation(interfaceOrientation: interfaceOrientation) {
                    previewLayer.connection?.videoOrientation = orientation
                }
            }
        makeDataOutput()
    }
    
    private func makePreviewLayer(session: AVCaptureSession) {
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.name = "CameraPreview"
        previewLayer.videoGravity = .resizeAspectFill
        
        self.previewLayer = previewLayer
    }
    
    private func makeDataOutput() {
        let videoDataOutput = AVCaptureVideoDataOutput()
        
        videoDataOutput.videoSettings = [
            (kCVPixelBufferPixelFormatTypeKey as String): kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        ]
        
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        let videoDataOutputQueue = DispatchQueue(label: "com.amamamam")
        videoDataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        
        captureSession.beginConfiguration()
        
        if captureSession.canAddOutput(videoDataOutput) {
            captureSession.addOutput(videoDataOutput)
        }
        
        if let captureConnection = videoDataOutput.connection(with: .video) {
            if captureConnection.isCameraIntrinsicMatrixDeliverySupported {
                captureConnection.isCameraIntrinsicMatrixDeliveryEnabled = true
            }
        }
        
        self.videoDataOutput = videoDataOutput
        self.videoDataOutputQueue = videoDataOutputQueue
        
        captureSession.commitConfiguration()
    }
}

extension CaptureSession: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let cameraIntrinsicData = CMGetAttachment(sampleBuffer, key: kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, attachmentModeOut: nil) else {
            return  }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("Failed to obtain a CVPixelBuffer for the current output frame.")
            return
        }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        self.outputs.send(.init(cameraIntrinsicData: cameraIntrinsicData,
                                pixelBuffer: pixelBuffer,
                                pixelBufferSize: CGSize(width: width, height: height)))
    }
}

// MARK: - AVCaptureVideoOrientation
extension AVCaptureVideoOrientation: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case .portrait:
            return "portrait"
        case .portraitUpsideDown:
            return "portraitUpsideDown"
        case .landscapeRight:
            return "landscapeRight"
        case .landscapeLeft:
            return "landscapeLeft"
        
        @unknown default:
            return "unknown"
        }
    }
    
    public init?(deviceOrientation: UIDeviceOrientation) {
        switch deviceOrientation {
        case .portrait:
            self = .portrait
        case .portraitUpsideDown:
            self = .portraitUpsideDown
        case .landscapeLeft:
            self = .landscapeLeft
        case .landscapeRight:
            self = .landscapeRight
        case .faceUp, .faceDown, .unknown:
            return nil
        @unknown default:
            return nil
        }
    }
    
    public init?(interfaceOrientation: UIInterfaceOrientation) {
        switch interfaceOrientation {
        case .unknown:
            return nil
        case .portrait:
            self = .portrait
        case .portraitUpsideDown:
            self = .portraitUpsideDown
        case .landscapeLeft:
            self = .landscapeLeft
        case .landscapeRight:
            self = .landscapeRight
        @unknown default:
            return nil
        }
    }
}
