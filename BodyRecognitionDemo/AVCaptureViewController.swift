//
//  AVCaptureViewController.swift
//  BodyRecognitionDemo
//
//  Created by Alexander Pawinski on 2021-01-27.
//

import UIKit
import AVFoundation

protocol AVCaptureViewProtocol {
    func setupAVCapture()
}

enum AVCaptureError: Swift.Error {
    case cameraInputUnavailable
    case cameraUnavailable
    case cameraUnableToLockConfiguration
    case sessionUnableToAddInput
    case sessionUnableToAddOutput
    case videoOutputMissingConnection
    case unknown
}

class AVCaptureViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {

    var bufferSize: CGSize = .zero
    var rootLayer: CALayer! = nil

    @IBOutlet weak private var previewView: UIView!
    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer! = nil
    private let videoDataOutput = AVCaptureVideoDataOutput()

    private let videoDataOutputQueue = DispatchQueue(label: "VideoDataOutput",
                                                     qos: .userInitiated,
                                                     attributes: [],
                                                     autoreleaseFrequency: .workItem)

    override func viewDidLoad() {
        super.viewDidLoad()
        setupAVCapture()
    }

    func setupAVCapture() {
        do {
            let session = try getAVCaptureSession()
            setupRootLayerFor(session)
        } catch let error as AVCaptureError {
            handleAVCaptureError(error)
        } catch {
            print(error)
        }
    }

    func handleAVCaptureError(_ error: AVCaptureError) {
        print(error)
    }

    func getAVCaptureSession() throws -> AVCaptureSession {
        var deviceInput: AVCaptureDeviceInput!
        guard let videoDevice = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .back).devices.first else {
            throw AVCaptureError.cameraUnavailable
        }
        do {
            deviceInput = try AVCaptureDeviceInput(device: videoDevice)
        } catch {
            throw AVCaptureError.cameraInputUnavailable
        }
        session.beginConfiguration()
        session.sessionPreset = .vga640x480 // Model image size is smaller.
        guard session.canAddInput(deviceInput) else {
            print("Could not add video device input to the session")
            session.commitConfiguration()
            throw AVCaptureError.sessionUnableToAddInput
        }
        session.addInput(deviceInput)
        guard session.canAddOutput(videoDataOutput) else {
            print("Could not add video data output to the session")
            session.commitConfiguration()
            throw AVCaptureError.sessionUnableToAddOutput
        }
        session.addOutput(videoDataOutput)
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
        videoDataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        guard let captureConnection = videoDataOutput.connection(with: .video) else {
            throw AVCaptureError.videoOutputMissingConnection
        }
        captureConnection.isEnabled = true
        do {
            try videoDevice.lockForConfiguration()
            let dimensions = CMVideoFormatDescriptionGetDimensions((videoDevice.activeFormat.formatDescription))
            bufferSize.width = CGFloat(dimensions.width)
            bufferSize.height = CGFloat(dimensions.height)
            videoDevice.unlockForConfiguration()
        } catch {
            throw AVCaptureError.cameraUnableToLockConfiguration
        }
        session.commitConfiguration()
        return session
    }

    func setupRootLayerFor(_ session: AVCaptureSession) {
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        rootLayer = previewView.layer
        previewLayer.frame = rootLayer.bounds
        rootLayer.addSublayer(previewLayer)
    }

    func startCaptureSession() {
        session.startRunning()
    }

    func teardownAVCapture() {
        previewLayer.removeFromSuperlayer()
        previewLayer = nil
    }

    // DEV NOTE: To be implemented in subclass

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // print("did output")
    }

    func captureOutput(_ captureOutput: AVCaptureOutput, didDrop didDropSampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // print("frame dropped")
    }

    public func exifOrientationFromDeviceOrientation() -> CGImagePropertyOrientation {
        let curDeviceOrientation = UIDevice.current.orientation
        let exifOrientation: CGImagePropertyOrientation
        switch curDeviceOrientation {
        case UIDeviceOrientation.portraitUpsideDown:  // Device oriented vertically, home button on the top
            exifOrientation = .left
        case UIDeviceOrientation.landscapeLeft:       // Device oriented horizontally, home button on the right
            exifOrientation = .upMirrored
        case UIDeviceOrientation.landscapeRight:      // Device oriented horizontally, home button on the left
            exifOrientation = .down
        case UIDeviceOrientation.portrait:            // Device oriented vertically, home button on the bottom
            exifOrientation = .up
        default:
            exifOrientation = .up
        }
        return exifOrientation
    }
}

