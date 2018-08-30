//
//  ViewController.swift
//  Screen-Sharing
//
//  Created by Roberto Perez Cubero on 11/08/16.
//  Copyright © 2016 tokbox. All rights reserved.
//

import UIKit
import OpenTok

let kWidgetHeight = 240
let kWidgetWidth = 320

// *** Fill the following variables using your own Project info  ***
// ***            https://tokbox.com/account/#/                  ***
// Replace with your OpenTok API key
let kApiKey = "45898942"
// Replace with your generated session ID
let kSessionId = "2_MX40NTg5ODk0Mn5-MTUzNDk0NDExMzE5N35ybVlEekZobUVYQlAxaXNWOGtxSDhJY29-fg"
// Replace with your generated token
let kToken = "T1==cGFydG5lcl9pZD00NTg5ODk0MiZzaWc9MjliZjJhOTk3ZDIwYmMyMDhjMWQyMjdkMmJhMzdkYjAxYWQ4ZDQzYTpzZXNzaW9uX2lkPTJfTVg0ME5UZzVPRGswTW41LU1UVXpORGswTkRFeE16RTVOMzV5YlZsRWVrWm9iVVZZUWxBeGFYTldPR3R4U0RoSlkyOS1mZyZjcmVhdGVfdGltZT0xNTM1MzY0MDkyJm5vbmNlPTAuNjY4NDc1MTAyMzY5NzEwMiZyb2xlPXB1Ymxpc2hlciZleHBpcmVfdGltZT0xNTM3OTU2MDkyJmNvbm5lY3Rpb25fZGF0YT0lN0IlMjJ1c2VySWQlMjIlM0ElMjI1YjdiZGMwNTgzZjA4YTNmZTIyNmUzYjclMjIlMkMlMjJyb29tJTIyJTNBJTIyc3RyZWFtaW5nLW9wZW4tcm9vbSUyMiUyQyUyMnJvbGUlMjIlM0ElMjJwYXJ0aWNpcGFudCUyMiUyQyUyMnZva2xGb3JtYXQlMjIlM0ElMjJvcGVucm9vbSUyMiUyQyUyMnRpbWVzdGFtcCUyMiUzQTE1MzUzNjQwOTIxOTMlN0Q="


class OpenRoomVC: UIViewController {
    lazy var session: OTSession = {
        return OTSession(apiKey: kApiKey, sessionId: kSessionId, delegate: self)!
    }()
    
    var publisher: OTPublisher?
    var subscriber: OTSubscriber?
    var capturer: ScreenCapturer?
    
    private var recorder : VRecorder?
    var completion : VRecorder.Completion?


    override func viewDidLoad() {
        super.viewDidLoad()
        checkPermissions()
        doConnect()
    }
    
    /**
     * Asynchronously begins the session connect process. Some time later, we will
     * expect a delegate method to call us back with the results of this action.
     */
    private func doConnect() {
        var error: OTError?
        defer {
            process(error: error)
        }
        session.connect(withToken: kToken, error: &error)
    }
    
    /**
     * Sets up an instance of OTPublisher to use with this session. OTPubilsher
     * binds to the device camera and microphone, and will provide A/V streams
     * to the OpenTok session.
     */
    fileprivate func doPublish() {
        var error: OTError? = nil
        defer {
            process(error: error)
        }
        let settings = OTPublisherSettings()
        settings.name = UIDevice.current.name
        publisher = OTPublisher(delegate: self, settings: settings)
        publisher?.videoType = .screen
        publisher?.audioFallbackEnabled = false
        
        let capture = TBScreenCapture(view: view)
        //capturer = ScreenCapturer(withView: view)
        publisher?.videoCapture = capture
        
        session.publish(publisher!, error: &error)
        
        if let pubView = publisher?.view {
            pubView.frame = CGRect(x: 0, y: 0, width: kWidgetWidth, height: kWidgetHeight)
            //view.addSubview(pubView)
        }
    }
    
    fileprivate func doSubscribe(_ stream: OTStream) {
        var error: OTError?
        defer {
            process(error: error)
        }
        subscriber = OTSubscriber(stream: stream, delegate: self)
        
        session.subscribe(subscriber!, error: &error)
    }
    
    fileprivate func process(error err: OTError?) {
        if let e = err {
            showAlert(errorStr: e.localizedDescription)
        }
    }
    
    fileprivate func showAlert(errorStr err: String) {
        DispatchQueue.main.async {
            let controller = UIAlertController(title: "Error", message: err, preferredStyle: .alert)
            controller.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
            self.present(controller, animated: true, completion: nil)
        }
    }
    
    private func checkPermissions()
    {
        if !Permissions.checkForPermission(permissionType: AVMediaType.video) || !Permissions.checkForPermission(permissionType: AVMediaType.audio)
        {
            AVCaptureDevice.requestAccess(for: AVMediaType.video) {[weak self] response in
                if response {
                    
                    if Permissions.checkForPermission(permissionType: AVMediaType.audio) == false
                    {
                        AVCaptureDevice.requestAccess(for: AVMediaType.audio) {[weak self] response in
                            DispatchQueue.main.async {
                                if response {
                                    
                                    self?.initialiseRecorder()
                                } else {
                                    debugPrint("error")

                                }
                            }
                            
                        }
                    }
                } else {
                    debugPrint("error")

                }
            }
        }
        else
        {
            self.initialiseRecorder()
            
        }
        
    }
    
    
    func initialiseRecorder(){
       
        if recorder != nil {
            recorder = nil
        }
        recorder = VRecorder.init(vc: self, maxTime: 10.0, completionBlock: {(url , thumb) in
            
        })
    
    }
}

// MARK: - OTSession delegate callbacks
extension OpenRoomVC: OTSessionDelegate {
    func sessionDidConnect(_ session: OTSession) {
        print("Session connected")
        doPublish()
    }
    
    func sessionDidDisconnect(_ session: OTSession) {
        print("Session disconnected")
    }
    
    func session(_ session: OTSession, streamCreated stream: OTStream) {
        print("Session streamCreated: \(stream.streamId)")
        doSubscribe(stream)
    }
    
    func session(_ session: OTSession, streamDestroyed stream: OTStream) {
        print("Session streamDestroyed: \(stream.streamId)")
    }
    
    func session(_ session: OTSession, didFailWithError error: OTError) {
        print("session Failed to connect: \(error.localizedDescription)")
    }
    
}

// MARK: - OTPublisher delegate callbacks
extension OpenRoomVC: OTPublisherDelegate {
    func publisher(_ publisher: OTPublisherKit, streamCreated stream: OTStream) {
    }
    
    func publisher(_ publisher: OTPublisherKit, streamDestroyed stream: OTStream) {
    }
    
    func publisher(_ publisher: OTPublisherKit, didFailWithError error: OTError) {
        print("Publisher failed: \(error.localizedDescription)")
    }
}

// MARK: - OTSubscriber delegate callbacks
extension OpenRoomVC: OTSubscriberDelegate {
    func subscriberDidConnect(toStream subscriberKit: OTSubscriberKit) {
        print("Subscriber connected")
        if let subsView = subscriber?.view {
            subsView.frame = CGRect(x: 0, y: kWidgetHeight, width: kWidgetWidth, height: kWidgetHeight)
            view.addSubview(subsView)
        }

    }
    
    func subscriber(_ subscriber: OTSubscriberKit, didFailWithError error: OTError) {
        print("Subscriber failed: \(error.localizedDescription)")
    }
    
    func subscriberVideoDataReceived(_ subscriber: OTSubscriber) {
    }
}

class Permissions: NSObject {
    
    class func checkForPermission(permissionType:AVMediaType) -> Bool
    {
        let authStatus = AVCaptureDevice.authorizationStatus(for: permissionType)
        switch authStatus {
        case .authorized:
            return true
        default:
            return false
        }
    }
    
}


