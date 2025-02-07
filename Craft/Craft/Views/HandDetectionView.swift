//
//  HandDetectionView.swift
//  Craft
//
//  Created by Alok Sahay on 05.02.2025.
//

import UIKit
import AVFoundation
import SwiftUI
import Vision


final class CameraViewController : UIViewController{
    
    private var cameraFeedSession: AVCaptureSession?
    
    override func loadView() {
        view = CameraPreview()
    }
    
    private var cameraView: CameraPreview{ view as! CameraPreview}
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        do{
            
            if cameraFeedSession == nil{
                try setupAVSession()
                
                cameraView.previewLayer.session = cameraFeedSession
                //MARK: Commented out cause it cropped out our View Finder
             //   cameraView.previewLayer.videoGravity = .resizeAspectFill
            }
            
            //MARK: Surronded the code into a DispatchQueue cause it may cause a crash
            DispatchQueue.global(qos: .userInteractive).async {
                self.cameraFeedSession?.startRunning()
               }
            
        }catch{
            print(error.localizedDescription)
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        cameraFeedSession?.stopRunning()
        super.viewDidDisappear(animated)
    }
    
    private let videoDataOutputQueue =
        DispatchQueue(label: "CameraFeedOutput", qos: .userInteractive)
    
    
    func setupAVSession() throws {
        //Start of Camera setup
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            throw CameraError.deviceNotFound
        }
        
        guard let deviceInput = try? AVCaptureDeviceInput(device: videoDevice) else{
            throw CameraError.inputError
        }
        
        let session = AVCaptureSession()
        session.beginConfiguration()
        //You can change the quality of the media from view finder from this line
        session.sessionPreset = AVCaptureSession.Preset.high
        
        guard session.canAddInput(deviceInput) else{
            throw CameraError.inputError
        }
        
        session.addInput(deviceInput)
        
        let dataOutput = AVCaptureVideoDataOutput()
        if session.canAddOutput(dataOutput){
            session.addOutput(dataOutput)
            dataOutput.alwaysDiscardsLateVideoFrames = true
            dataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        }else{
            throw CameraError.outputError
        }
        
        session.commitConfiguration()
        cameraFeedSession = session
    }
    
    
    //MARK: Vision Init Below
    
    private let handPoseRequest : VNDetectHumanHandPoseRequest = {
            let request = VNDetectHumanHandPoseRequest()
             // Here is where we limit the number of hands Vision can detect at a single given moment
            request.maximumHandCount = 1
            return request
        }()
        
     
        var pointsProcessorHandler: (([CGPoint]) -> Void)?

        func processPoints(_ fingerTips: [CGPoint]) {
          
          let convertedPoints = fingerTips.map {
            cameraView.previewLayer.layerPointConverted(fromCaptureDevicePoint: $0)
          }

          pointsProcessorHandler?(convertedPoints)
        }
    }

extension CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate{
        //Handler and Observation
        
        func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
            
            var fingerTips: [CGPoint] = []
            defer {
              DispatchQueue.main.sync {
                self.processPoints(fingerTips)
              }
            }

            
            let handler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer,   orientation: .up,   options: [:])
            
            do{
                try handler.perform([handPoseRequest])
                
                guard let results = handPoseRequest.results?.prefix(2),     !results.isEmpty  else{
                    return
                }
                
                var recognizedPoints: [VNRecognizedPoint] = []
                
                try results.forEach { observation in
                    
                    let fingers = try observation.recognizedPoints(.all)
                    
                    
                    if fingers[.thumbTip]?.confidence ?? 0.0 > 0.7{
                        recognizedPoints.append(fingers[.thumbTip]!)
                    }
                    
                    
                    if fingers[.indexTip]?.confidence ?? 0.0 > 0.7  {
                            recognizedPoints.append(fingers[.indexTip]!)
                        }
                    
                    
                    if fingers[.middleTip]?.confidence ?? 0.0 > 0.7 {
                        recognizedPoints.append(fingers[.middleTip]!)
                    }
                    
                    
                    if fingers[.ringTip]?.confidence ?? 0.0 > 0.7 {
                        recognizedPoints.append(fingers[.ringTip]!)
                    }
                    
                    if fingers[.littleTip]?.confidence ?? 0.0 > 0.7 {
                        recognizedPoints.append(fingers[.littleTip]!)
                    }
                    
                }
                
                fingerTips = recognizedPoints.filter {
                  $0.confidence > 0.9
                }
                .map {
                  CGPoint(x: $0.location.x, y: 1 - $0.location.y)
                }
                
                
            }catch{
                cameraFeedSession?.stopRunning()
            }
            
        }
        
    }

struct HandDetectionView: View {
    @StateObject private var viewModel = HandDetectionViewModel()
    
    var body: some View {
        ZStack {
            // Camera Preview
            CameraPreviewView(session: viewModel.session)
                .edgesIgnoringSafeArea(.all)
            
            // Finger dots overlay
            ForEach(viewModel.fingerLocations, id: \.self) { point in
                Circle()
                    .fill(Color.green)
                    .frame(width: 20, height: 20)
                    .position(
                        x: point.x * UIScreen.main.bounds.width,
                        y: point.y * UIScreen.main.bounds.height
                    )
            }
        }
        .onAppear {
            viewModel.startSession()
        }
        .onDisappear {
            viewModel.stopSession()
        }
    }
}

#Preview {
    HandDetectionView()
}
