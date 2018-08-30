//
//  AVRecorder.swift
//  GetVokl
//
//  Created by MDS on 19/09/17.
//  Copyright © 2017 Vikas Soni. All rights reserved.
//

import UIKit
import AVFoundation
import Photos

class VRecorder: NSObject {

    internal typealias Completion = (_ url : URL? , _ thumb : UIImage) -> Void

    var output : AVCaptureMovieFileOutput?
    var completion : Completion?
    
    lazy var videoSession: AVCaptureSession = {
        let s = AVCaptureSession()
        return s
    }()
    
    lazy var previewLayer: AVCaptureVideoPreviewLayer = {
        let preview =  AVCaptureVideoPreviewLayer(session: self.videoSession)
        preview.bounds = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
        preview.position = CGPoint(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY)
        preview.videoGravity = AVLayerVideoGravity.resizeAspectFill
        return preview
    }()
    
    init(vc : UIViewController , maxTime: Double , completionBlock : @escaping Completion ) {
        super.init()
        completion = completionBlock
        showVideoCapture(onVC: vc, maxTime: maxTime)
    }
    
    deinit {
        output = nil
        completion = nil
    }
    
    func getDevice(position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let devices: NSArray = AVCaptureDevice.devices() as NSArray
        for de in devices {
            let deviceConverted = de as! AVCaptureDevice
            if(deviceConverted.position == position){
                return deviceConverted
            }
        }
        return nil
    }
    
    func showVideoCapture(onVC vc : UIViewController , maxTime : Double) {
        
        let captureDevice = getDevice(position: .front)
        let audioCaptureDevice = AVCaptureDevice.default(for: AVMediaType.audio)
        
        do {
            let deviceInput = try AVCaptureDeviceInput(device: captureDevice!)
            
            videoSession.beginConfiguration() // 1
            videoSession.sessionPreset = AVCaptureSession.Preset.vga640x480
            if (videoSession.canAddInput(deviceInput) == true) {
                videoSession.addInput(deviceInput)
            }
            
            let dataOutput = AVCaptureVideoDataOutput() // 2
            
            dataOutput.videoSettings = [((kCVPixelBufferPixelFormatTypeKey as NSString) as String) : NSNumber(value: kCVPixelFormatType_32BGRA as UInt32)] // 3
            dataOutput.alwaysDiscardsLateVideoFrames = true
            
            if (videoSession.canAddOutput(dataOutput) == true) {
                videoSession.addOutput(dataOutput)
            }
            
            videoSession.commitConfiguration() //5
            
            let queue = DispatchQueue(label: "com.invasivecode.videoQueue") // 6
            dataOutput.setSampleBufferDelegate(self, queue: queue) // 7
            
        }
        catch let error as NSError {
            NSLog("\(error), \(error.localizedDescription)")
        }
        
        output = AVCaptureMovieFileOutput.init()
        let fps = 30
        output!.maxRecordedDuration = CMTime.init(seconds: maxTime, preferredTimescale: CMTimeScale(fps))
        
        if videoSession.canAddOutput(output!){
            videoSession.addOutput(output!)
        }
        
        do {
            let audioDeviceInput = try AVCaptureDeviceInput.init(device: audioCaptureDevice!)
            
            if videoSession.canAddInput(audioDeviceInput){
                videoSession.addInput(audioDeviceInput)
            }
        } catch let error {
            debugPrint(error)
        }
        
        vc.view.layer.addSublayer(previewLayer)
        videoSession.sessionPreset = AVCaptureSession.Preset.vga640x480
        videoSession.startRunning()
    }
    
    func start(){
        self.videoSession.sessionPreset = AVCaptureSession.Preset.vga640x480
        let fileManager = FileManager.init()
        if fileManager.fileExists(atPath: VRecorder.outputURL().absoluteString){
            do {
                let _ = try fileManager.removeItem(atPath: VRecorder.outputURL().absoluteString)
            } catch let error {
                debugPrint(error)
            }
        }
        output?.startRecording(to: VRecorder.outputURL(), recordingDelegate: self)
        debugPrint(self.videoSession.sessionPreset)
    }
    
    func stop()  {
        output?.stopRecording()
        videoSession.stopRunning()
    }
    
    func switchCamera(){
        // Get current input
        
    let inputDevice = videoSession.inputs.filter({ (captureDevice) -> Bool in
            if captureDevice.ports[0].mediaType == .audio{
                return false
            } else {
                return true
            }
       })
        
        guard let input = inputDevice as? [AVCaptureDeviceInput] else {return}
        videoSession.removeInput(input[0])

        // Begin new session configuration and defer commit
        videoSession.beginConfiguration()
        
        // Create new capture device
        var newDevice: AVCaptureDevice?
        if input[0].device.position == .back {
            newDevice = getDevice(position: .front)
        } else {
            newDevice = getDevice(position: .back)
        }
        
        // Create new capture input
        var deviceInput: AVCaptureDeviceInput!
        do {
            deviceInput = try AVCaptureDeviceInput(device: newDevice!)
        } catch let error {
            debugPrint(error.localizedDescription)
            return
        }
        
        // Swap capture device inputs
        videoSession.addInput(deviceInput)
        videoSession.commitConfiguration()
    }
    
    class func outputURL() -> URL {
        do {
            let url = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            return URL.init(string: "\(url.absoluteString)output.mov")!
        } catch let error {
            debugPrint(error.localizedDescription)

        }
        return URL.init(string: "")!
    }
}

extension VRecorder : AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ captureOutput: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
    }
    
    func captureOutput(_ captureOutput: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
    }
}

extension VRecorder : AVCaptureFileOutputRecordingDelegate {
    
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        
        do {
            let asset = AVURLAsset(url: outputFileURL, options: nil)
            let imgGenerator = AVAssetImageGenerator(asset: asset)
            imgGenerator.appliesPreferredTrackTransform = true
            let cgImage = try imgGenerator.copyCGImage(at: CMTimeMake(0, 1), actualTime: nil)
            let thumbnailImage = UIImage(cgImage: cgImage)
            
            completion!(outputFileURL ,thumbnailImage )
            
        } catch let error as NSError {
            debugPrint("Error generating thumbnail: \(error)")
        }
    }

}
