//
//  ViewController.swift
//  Speech recognition
//
//  Created by Rplay on 19/09/16.
//  Copyright © 2016 rplay. All rights reserved.
//

import UIKit
import AVFoundation
import Speech

class ViewController: UIViewController {
    
    //-- Variables
    var previewLayer: AVCaptureVideoPreviewLayer?
    var session: AVCaptureSession?
    var sessionQueue: DispatchQueue?
    
    var inputVideo: AVCaptureDeviceInput?
    var inputAudio: AVCaptureDeviceInput?
    var outputVideo: AVCaptureVideoDataOutput?
    var outputAudio: AVCaptureAudioDataOutput?
    
    var speechRecognizer: SFSpeechRecognizer?
    var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    var recognitionTask: SFSpeechRecognitionTask?
    
    //-- Outlets
    @IBOutlet var preview: UIView!
    @IBOutlet var textView: UITextView!

    //-- View Did Load method
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        let sessionAudioVideo = createSession()
        let previewSize = self.view.frame.size
        let previewAudioVideo = createPreview(size: previewSize, session: sessionAudioVideo)
        
        preview.layer.addSublayer(previewAudioVideo!)
        sessionAudioVideo.startRunning()
        
        initSpeechRecognizer()
        requestAuthorization()
        startRecording()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    //-- Create session methods
    func createSession() -> AVCaptureSession {
        sessionQueue = DispatchQueue(label: "CameraQueue")
        session = AVCaptureSession()
        session?.sessionPreset = AVCaptureSessionPresetMedium
        
        addVideoInput()
        addAudioInput()
        
        addVideoOutput()
        addAudioOutput()
        
        return session!
    }
    
    //-- Create preview methods
    func createPreview(size: CGSize, session: AVCaptureSession) -> AVCaptureVideoPreviewLayer? {
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer?.frame.size = size
        previewLayer?.videoGravity = AVLayerVideoGravityResizeAspectFill
        previewLayer?.connection.videoOrientation = AVCaptureVideoOrientation.portrait
        
        return previewLayer
    }
    
    //-- Get audio and video device methods
    func getAudioDevice() -> AVCaptureDevice {
        
        let audioDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeAudio)
        return audioDevice!
    }
    
    func getVideoDevice() -> AVCaptureDevice {
        
        var videoDevice: AVCaptureDevice?
        
        guard  let discoverySession: AVCaptureDeviceDiscoverySession? = AVCaptureDeviceDiscoverySession(deviceTypes: [.builtInMicrophone, .builtInWideAngleCamera, .builtInTelephotoCamera, .builtInDuoCamera], mediaType: AVMediaTypeVideo, position: .front) else {
            videoDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)
            return videoDevice!
        }
        
        let devices: Array<AVCaptureDevice>? = discoverySession?.devices
        
        for device in devices! {
            let device = device as AVCaptureDevice
            if device.position == AVCaptureDevicePosition.front {
                videoDevice = device
                break
            }
        }
        
        return videoDevice!
    }
    
    //-- Add video and audio input/output methods
    func addVideoInput() {
        
        let deviceVideo = getVideoDevice()
        var addInputVideoError: NSError?
        
        do {
            try inputVideo = AVCaptureDeviceInput(device: deviceVideo)
        } catch let err as NSError {
            addInputVideoError = err
        }
        
        if addInputVideoError == nil {
            session?.addInput(inputVideo)
        } else {
            print("camera input error: \(addInputVideoError)")
        }
        
    }
    
    func addAudioInput() {
        
        let deviceAudio = getAudioDevice()
        var addInputAudioError: NSError?
        
        do {
            let inputAudio = try AVCaptureDeviceInput(device: deviceAudio)
            session?.addInput(inputAudio)
        } catch let err as NSError {
            addInputAudioError = err
            print(addInputAudioError)
        }
    }
    
    func addVideoOutput() {
        outputVideo = AVCaptureVideoDataOutput()
        outputVideo?.alwaysDiscardsLateVideoFrames = true
        outputVideo?.setSampleBufferDelegate(self, queue: sessionQueue)
        
        let videoSettings = [kCVPixelBufferPixelFormatTypeKey as NSString:Int(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)] as [AnyHashable : Any]
        
        outputVideo?.videoSettings = videoSettings
        
        if session!.canAddOutput(outputVideo) {
            session!.addOutput(outputVideo)
        }
    }
    
    
    func addAudioOutput() {
        outputAudio = AVCaptureAudioDataOutput()
        outputAudio?.setSampleBufferDelegate(self, queue: sessionQueue)
        
        if session!.canAddOutput(outputAudio) {
            session!.addOutput(outputAudio)
        }
    }
    
    //-- Speech recognition methods
    func initSpeechRecognizer() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale.init(identifier: "fr-FR"))
    }
    
    func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            
            switch authStatus {
            case .authorized:
                print("User access to speech recognition")
                
            case .denied:
                print("User denied access to speech recognition")
                
            case .restricted:
                print("Speech recognition restricted on this device")
                
            case .notDetermined:
                print("Speech recognition not yet authorized")
            }
        }
    }
    
    func startRecording() {
        
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let recognitionRequest = recognitionRequest else {
            fatalError("Unable to create an SFSpeechAudioBufferRecognitionRequest object")
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest, resultHandler: { (result, error) in
            
            if result != nil {
                self.textView.text = result?.bestTranscription.formattedString
            }
            
            if error != nil {
                self.recognitionRequest = nil
                self.recognitionTask = nil
            }
        })
        
        textView.text = "Say something, I'm listening!"
    }
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    
    //-- Capture output delegate method
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        
        if CMSampleBufferGetImageBuffer(sampleBuffer) != nil {
            
            //-- Image
        } else {
            
            //-- Audio
            self.recognitionRequest?.appendAudioSampleBuffer(sampleBuffer)
        }
    }
}

