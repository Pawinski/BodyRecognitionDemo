//
//  VisionBodyDetectionViewController.swift
//  BodyRecognitionDemo
//
//  Created by Alexander Pawinski on 2021-01-27.
//

import UIKit
import AVFoundation

protocol AVCaptureViewControllerProtocol {
    func drawPoints(points: [CGPoint])
    func setupLayers()
    func updateLayerGeometry()
    func createPointSublayerAtPoint(_ point: CGPoint) -> CALayer
}

class VisionBodyDetectionViewController: AVCaptureViewController, AVCaptureViewControllerProtocol {

    private var detectionOverlay: CALayer! = nil
    let presenter = VisionBodyDetectionPresenter()

    func drawPoints(points: [CGPoint]) {
        CATransaction.begin()
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        detectionOverlay.sublayers = nil // remove all the old recognized objects
        points.forEach { detectionOverlay.addSublayer(self.createPointSublayerAtPoint($0)) }
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

        // setup Vision parts
        setupLayers()
        updateLayerGeometry()
        presenter.setupVision(frameWidth: bufferSize.width,
                              frameHeight: bufferSize.height,
                              completion: { self.drawPoints(points: $0) })

        // start the capture
        startCaptureSession()
    }

    func setupLayers() {
        detectionOverlay = CALayer() // container layer that has all the renderings of the observations
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
        // rotate the layer into screen orientation and scale and mirror
        detectionOverlay.setAffineTransform(CGAffineTransform(rotationAngle: CGFloat(.pi / 2.0)).scaledBy(x: scale, y: -scale))
        // center the layer
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
