//
//  PreviewLayerView.swift
//  BarcodeReaderByGogleBooks
//
//  Created by amamiya on 2023/02/26.
//

import Foundation
import SwiftUI
import AVFoundation

struct PreviewLayerView: UIViewControllerRepresentable {
    typealias UIViewControllerType = UIViewController
    
    let previewLayer: AVCaptureVideoPreviewLayer
    let detectedRect: [CGRect]
    let pixelSize: CGSize
    
    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()
        viewController.view.layer.addSublayer(previewLayer)
        previewLayer.frame = viewController.view.layer.frame
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        previewLayer.frame = uiViewController.view.layer.frame
        drawObservations(detectedRect)
    }
    
    private func drawObservations(_ detectedRects: [CGRect]) {
        previewLayer.sublayers?.removeSubrange(1...)
        
        let captureDeviceBounds = CGRect(x: 0, y: 0, width: pixelSize.width, height: pixelSize.height)
        let overlayLayer = CALayer()
        
        overlayLayer.name = "DetectionOverlay"
        overlayLayer.bounds = captureDeviceBounds
        overlayLayer.position = CGPoint(x: captureDeviceBounds.midX, y: captureDeviceBounds.midY)
        
        print("overlay: before: \(overlayLayer.frame)")
        
        let videoPreviewRect = previewLayer.layerRectConverted(fromMetadataOutputRect: CGRect(x: 0, y: 0, width: 1, height: 1))
        
        let (rotation, scaleX, scaleY) = makeOrientationAndScale(videoPreviewRect: videoPreviewRect, pixelSize: pixelSize)
        
        let affineTransform = CGAffineTransform(rotationAngle: radiansForDegrees(rotation)).scaledBy(x: scaleX, y: -scaleY)
        overlayLayer.setAffineTransform(affineTransform)
        overlayLayer.position = CGPoint(x: previewLayer.bounds.midX, y: previewLayer.bounds.midY)
        
        previewLayer.addSublayer(overlayLayer)
        print("overlay: after: \(overlayLayer.frame)")
        
        let layers = detectedRects.compactMap { detectedRect -> CALayer in
            let xMin = detectedRect.minX
            let yMax = detectedRect.maxY
            
            let detectedX = xMin * overlayLayer.frame.size.width + overlayLayer.frame.minX
            let detectedY = (1 - yMax) * overlayLayer.frame.size.height
            let detectedWidth = detectedRect.width * overlayLayer.frame.size.width
            let detectedHeight = detectedRect.height * overlayLayer.frame.size.height
            
            let layer = CALayer()
            layer.frame = CGRect(x: detectedX, y: detectedY, width: detectedWidth, height: detectedHeight)
            layer.borderWidth = 2.0
            layer.borderColor = UIColor.green.cgColor
            return layer
        }
        
        layers.forEach { self.previewLayer.addSublayer($0) }
    }
    
    private func makeOrientationAndScale(videoPreviewRect: CGRect, pixelSize: CGSize) -> (rotation: CGFloat, scaleX: CGFloat, scaleY: CGFloat) {
        var rotation: CGFloat
        var scaleX: CGFloat
        var scaleY: CGFloat
        
        switch UIDevice.current.orientation {
        case .portraitUpsideDown:
            rotation = 180
            scaleX = videoPreviewRect.width / pixelSize.width
            scaleY = videoPreviewRect.height / pixelSize.height
        case .landscapeLeft:
            rotation = 90
            scaleX = videoPreviewRect.width / pixelSize.width
            scaleY = scaleX
        case .landscapeRight:
            rotation = -90
            scaleX = videoPreviewRect.width / pixelSize.width
            scaleY = scaleX
        default:
            rotation = 0
            scaleX = videoPreviewRect.width / pixelSize.width
            scaleY = videoPreviewRect.height / pixelSize.height
        }
        return (rotation, scaleX, scaleY)
    }
    
    private func radiansForDegrees(_ degrees: CGFloat) -> CGFloat {
        return CGFloat(Double(degrees) * Double.pi / 180.0)
    }

}
