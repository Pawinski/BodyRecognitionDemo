//
//  VisionBodyDetectionViewController.swift
//  BodyRecognitionDemo
//
//  Created by Alexander Pawinski on 2021-01-27.
//

import UIKit
import AVFoundation

protocol AVCaptureViewControllerProtocol {
    func drawPoints(pointViewModels: [PointViewModel])
    func setupLayers()
    func updateLayerGeometry()
    func createPointSublayerAtPoint(_ point: CGPoint) -> CALayer
}

struct PointViewModel: Hashable {
    let x: CGFloat
    let y: CGFloat
}

class VisionBodyDetectionViewController: AVCaptureViewController, AVCaptureViewControllerProtocol {

    private var detectionOverlay: CALayer! = nil
    let presenter = VisionBodyDetectionPresenter()

    func drawPoints(pointViewModels: [PointViewModel]) {
        CATransaction.begin()
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        detectionOverlay.sublayers = nil
        let cgPoints = pointViewModels.compactMap { CGPoint(x: $0.x, y: $0.y) }
        cgPoints.forEach { detectionOverlay.addSublayer(createPointSublayerAtPoint($0)) }
        CATransaction.commit()
    }

    override func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        let exifOrientation = exifOrientationFromDeviceOrientation()
        presenter.processBuffer(pixelBuffer, orientation: exifOrientation)
    }

    override func setupAVCapture() {
        super.setupAVCapture()
        setupLayers()
        updateLayerGeometry()
        presenter.setupVision(frameWidth: bufferSize.width,
                              frameHeight: bufferSize.height) {
                                let pointViewModels = $0.compactMap { PointViewModel(x: $0.x, y: $0.y) }
                                self.drawPoints(pointViewModels: pointViewModels)
                              }
        startCaptureSession()
    }

    func setupLayers() {
        detectionOverlay = CALayer()
        detectionOverlay.name = "DetectionOverlay"
        detectionOverlay.bounds = CGRect(x: 0.0,
                                         y: 0.0,
                                         width: bufferSize.width,
                                         height: bufferSize.height)
        detectionOverlay.position = CGPoint(x: rootLayer.bounds.midX, y: rootLayer.bounds.midY)
        rootLayer.addSublayer(detectionOverlay)
    }

    func updateLayerGeometry() {
        let bounds = rootLayer.bounds
        var scale: CGFloat
        let xScale: CGFloat = bounds.size.width / bufferSize.height
        let yScale: CGFloat = bounds.size.height / bufferSize.width
        scale = fmax(xScale, yScale)
        if scale.isInfinite {
            scale = 1.0
        }
        CATransaction.begin()
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        detectionOverlay.setAffineTransform(CGAffineTransform(rotationAngle: CGFloat(.pi / 2.0)).scaledBy(x: scale, y: -scale))
        detectionOverlay.position = CGPoint(x: bounds.midX, y: bounds.midY)
        CATransaction.commit()
    }

    func createPointSublayerAtPoint(_ point: CGPoint) -> CALayer {
        let circleLayer = CAShapeLayer()
        let radius: CGFloat = 6.0
        circleLayer.path = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 2.0 * radius, height: 2.0 * radius), cornerRadius: radius).cgPath
        circleLayer.position = CGPoint(x: point.x - radius, y: point.y - radius)
        circleLayer.fillColor = UIColor.blue.cgColor
        return circleLayer
    }
}
