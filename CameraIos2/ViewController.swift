//
//  ViewController.swift
//  CameraIos2
//
//  Created by Anish Kumar Dubey on 11/08/19.
//  Copyright © 2019 Anish Kumar Dubey. All rights reserved.
//

import UIKit
import Photos

class ViewController: UIViewController {
    
    @IBOutlet weak var toggleFlashButton: UIButton!
    @IBOutlet weak var switchCameraButton: UIButton!
    @IBOutlet weak var previewView: UIView!
    @IBOutlet weak var capturePhotoButton: UIButton!
    @IBOutlet weak var myImageView: UIImageView!
    
    let cameraController = CameraController()
    
    override var prefersStatusBarHidden: Bool { return true }
    
    @IBAction func toggleFlash(_ sender: UIButton) {
        if cameraController.flashMode == .on {
            cameraController.flashMode = .off
            toggleFlashButton.setImage(#imageLiteral(resourceName: "Flash Off Icon"), for: .normal)
        }else {
            cameraController.flashMode = .on
            toggleFlashButton.setImage(#imageLiteral(resourceName: "Flash On Icon"), for: .normal)
        }
    }
    
    @IBAction func switchCamera(_ sender: UIButton) {
        do {
            try cameraController.switchCameras()
        }
        catch {
            print(error)
        }
        
        switch cameraController.currentCameraPosition {
        case .some(.front):
            switchCameraButton.setImage(#imageLiteral(resourceName: "Front Camera Icon"), for: .normal)
            
        case .some(.rear):
            switchCameraButton.setImage(#imageLiteral(resourceName: "Rear Camera Icon"), for: .normal)
            
        case .none:
            return
        }
    }
    
    @IBAction func takePicture(_ sender: UIButton) {
        cameraController.captureImage {(image, error) in
            guard let image = image else {
                print(error ?? "Image capture error")
                return
            }
            
            try? PHPhotoLibrary.shared().performChangesAndWait {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
        }
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        cameraController.delegate = self
        styleCaptureButton()
        configureCameraController()
    }
    
    func styleCaptureButton() {
        capturePhotoButton.layer.borderColor = UIColor.black.cgColor
        capturePhotoButton.layer.borderWidth = 2
        capturePhotoButton.layer.cornerRadius = min(capturePhotoButton.frame.width, capturePhotoButton.frame.height) / 2
    }
    
    func configureCameraController() {
        cameraController.prepare {(error) in
            if let error = error {
                print(error)
            }
            
            try? self.cameraController.displayPreview(on: self.previewView)
        }
    }


}

extension ViewController: CameraControllerDelegate{
    func captured(image: UIImage) {
        //print("captured")
        
        //let imageFinal = wrapper.doWork(on: image)
        
        myImageView.image = image
    }
}

