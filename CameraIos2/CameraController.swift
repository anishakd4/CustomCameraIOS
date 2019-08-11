//
//  CameraController.swift
//  CameraIos2
//
//  Created by Anish Kumar Dubey on 11/08/19.
//  Copyright © 2019 Anish Kumar Dubey. All rights reserved.
//

import UIKit
import AVFoundation

class CameraController: NSObject {
    
    var captureSession: AVCaptureSession?
    
    var frontCamera: AVCaptureDevice?
    var rearCamera: AVCaptureDevice?
    
    var currentCameraPosition: CameraPosition?
    var frontCameraInput: AVCaptureDeviceInput?
    var rearCameraInput: AVCaptureDeviceInput?
    
    var photoOutput: AVCapturePhotoOutput?
    
    var previewLayer: AVCaptureVideoPreviewLayer?
    
    var flashMode = AVCaptureDevice.FlashMode.off
    
    var photoCaptureCompletionBlock: ((UIImage?, Error?) -> Void)?
    
}

extension CameraController: AVCapturePhotoCaptureDelegate {
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            self.photoCaptureCompletionBlock?(nil, error)
        }else if let data = photo.fileDataRepresentation(),
            let image = UIImage(data: data) {
            self.photoCaptureCompletionBlock?(image, nil)
        }else {
            self.photoCaptureCompletionBlock?(nil, CameraControllerError.unknown)
        }
    }
    
    func createCaptureSession() {
        self.captureSession = AVCaptureSession()
    }
    
    func configureCaptureDevices() throws {
        
        let session = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: AVMediaType.video, position: .unspecified)
        
        let cameras = (session.devices.compactMap { $0 })
        if cameras.isEmpty { throw CameraControllerError.noCamerasAvailable }
        
        for camera in cameras {
            if camera.position == .front {
                self.frontCamera = camera
            }
            if camera.position == .back {
                self.rearCamera = camera
                
                try camera.lockForConfiguration()
                camera.focusMode = .continuousAutoFocus
                camera.unlockForConfiguration()
            }
        }
        
    }
    
    func configureDeviceInputs() throws {
        guard let captureSession = self.captureSession else { throw CameraControllerError.captureSessionIsMissing }
        
        if let rearCamera = self.rearCamera {
            self.rearCameraInput = try AVCaptureDeviceInput(device: rearCamera)
            if captureSession.canAddInput(self.rearCameraInput!) {
                captureSession.addInput(self.rearCameraInput!)
            }
            self.currentCameraPosition = .rear
        } else if let frontCamera = self.frontCamera {
            self.frontCameraInput = try AVCaptureDeviceInput(device: frontCamera)
            if captureSession.canAddInput(self.frontCameraInput!) {
                captureSession.addInput(self.frontCameraInput!)
            }else {
                throw CameraControllerError.inputsAreInvalid
            }
            self.currentCameraPosition = .front
        }else {
            throw CameraControllerError.noCamerasAvailable
        }
        
    }
    
    func configurePhotoOutput() throws {
        guard let captureSession = self.captureSession else { throw CameraControllerError.captureSessionIsMissing }
        
        self.photoOutput = AVCapturePhotoOutput()
        self.photoOutput!.setPreparedPhotoSettingsArray([AVCapturePhotoSettings(format: [AVVideoCodecKey : AVVideoCodecType.jpeg])], completionHandler: nil)
        
        if captureSession.canAddOutput(self.photoOutput!) {
            captureSession.addOutput(self.photoOutput!)
        }
        
        captureSession.startRunning()
    }
    
    func prepare(completionHandler: @escaping (Error?) -> Void) {
        
        DispatchQueue(label: "prepare").async {
            do {
                self.createCaptureSession()
                try self.configureCaptureDevices()
                try self.configureDeviceInputs()
                try self.configurePhotoOutput()
            }
                
            catch {
                DispatchQueue.main.async {
                    completionHandler(error)
                }
                
                return
            }
            
            DispatchQueue.main.async {
                completionHandler(nil)
            }
        }
    }
    
    func displayPreview(on view: UIView) throws {
        guard let captureSession = self.captureSession, captureSession.isRunning else { throw CameraControllerError.captureSessionIsMissing }
        
        self.previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        self.previewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
        self.previewLayer?.connection?.videoOrientation = .portrait
        
        view.layer.insertSublayer(self.previewLayer!, at: 0)
        self.previewLayer?.frame = view.frame
    }
    
    func switchCameras() throws {
        guard let currentCameraPosition = currentCameraPosition, let captureSession = self.captureSession, captureSession.isRunning else { throw CameraControllerError.captureSessionIsMissing }
        
        captureSession.beginConfiguration()
        
        switch currentCameraPosition {
        case .front:
            try switchToRearCamera()
            
        case .rear:
            try switchToFrontCamera()
        }
        
        captureSession.commitConfiguration()
    }
    
    func switchToFrontCamera() throws {
        guard let captureSession = self.captureSession, captureSession.isRunning else { throw CameraControllerError.captureSessionIsMissing }
        
        let inputs = captureSession.inputs as [AVCaptureInput]
        
        guard let rearCameraInput = self.rearCameraInput,
            inputs.contains(rearCameraInput),
            let frontCamera = self.frontCamera
            else { throw CameraControllerError.invalidOperation }
        
        self.frontCameraInput = try AVCaptureDeviceInput(device: frontCamera)
        
        captureSession.removeInput(rearCameraInput)
        
        if captureSession.canAddInput(self.frontCameraInput!) {
            captureSession.addInput(self.frontCameraInput!)
            self.currentCameraPosition = .front
        }else {
            throw CameraControllerError.invalidOperation
        }
    }
    
    func switchToRearCamera() throws {
        guard let captureSession = self.captureSession, captureSession.isRunning else { throw CameraControllerError.captureSessionIsMissing }
        
        let inputs = captureSession.inputs
        
        guard  let frontCameraInput = self.frontCameraInput,
            inputs.contains(frontCameraInput),
            let rearCamera = self.rearCamera
            else { throw CameraControllerError.invalidOperation }
        
        self.rearCameraInput = try AVCaptureDeviceInput(device: rearCamera)
        
        captureSession.removeInput(frontCameraInput)
        
        if captureSession.canAddInput(self.rearCameraInput!) {
            captureSession.addInput(self.rearCameraInput!)
            self.currentCameraPosition = .rear
        }else {
            throw CameraControllerError.invalidOperation
        }
    }
    
    func captureImage(completion: @escaping (UIImage?, Error?) -> Void) {
        guard let captureSession = captureSession,
            captureSession.isRunning
            else { completion(nil, CameraControllerError.captureSessionIsMissing); return }
        
        let settings = AVCapturePhotoSettings()
        settings.flashMode = self.flashMode
        
        self.photoOutput?.capturePhoto(with: settings, delegate: self)
        self.photoCaptureCompletionBlock = completion
    }
    
}

extension CameraController{
    enum CameraControllerError: Swift.Error {
        case captureSessionAlreadyRunning
        case captureSessionIsMissing
        case inputsAreInvalid
        case invalidOperation
        case noCamerasAvailable
        case unknown
    }
    
    public enum CameraPosition {
        case front
        case rear
    }
}

