import AVFoundation
import Vision
import CoreML
import Foundation

class ExerciseRecordingViewModel: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var hasRecordedVideo = false
    @Published var showReview = false
    @Published var formattedElapsedTime = "00:00"
    @Published var isProcessing = false
    @Published var currentCamera: AVCaptureDevice.Position = .front
    @Published var isWideAngle = false
    @Published var zoomLevel: CGFloat = 1.0
    @Published var availableDeviceTypes: [AVCaptureDevice.DeviceType] = []
    
    private(set) var videoURL: URL?
    private(set) var poseData: [VNHumanBodyPoseObservation] = []
    
    let captureSession = AVCaptureSession()
    private var videoOutput: AVCaptureMovieFileOutput?
    private var timer: Timer?
    private var startTime: Date?
    
    override init() {
        super.init()
        setupCamera()
    }
    
    private func setupCamera(position: AVCaptureDevice.Position = .front) {
        let deviceTypes: [AVCaptureDevice.DeviceType] = [
            .builtInWideAngleCamera,
            .builtInUltraWideCamera
        ]
        
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .video,
            position: position
        )
        
        // Update available device types
        availableDeviceTypes = discoverySession.devices.map { $0.deviceType }
        
        guard let camera = discoverySession.devices.first else { return }
        
        do {
            configureCamera(camera)
            let input = try AVCaptureDeviceInput(device: camera)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }
            
            let videoOutput = AVCaptureMovieFileOutput()
            if captureSession.canAddOutput(videoOutput) {
                captureSession.addOutput(videoOutput)
                self.videoOutput = videoOutput
            }
            
            DispatchQueue.global(qos: .userInitiated).async {
                self.captureSession.startRunning()
            }
        } catch {
            print("Camera setup error: \(error)")
        }
    }
    
    private func configureCamera(_ device: AVCaptureDevice) {
        try? device.lockForConfiguration()
        device.videoZoomFactor = zoomLevel
        device.unlockForConfiguration()
    }
    
    func startRecording() {
        guard let videoOutput = videoOutput else { return }
        
        // Clear previous pose data
        poseData.removeAll()
        
        let outputPath = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")
        
        videoOutput.startRecording(to: outputPath,
                                   recordingDelegate: self)
        
        isRecording = true
        startTime = Date()
        startTimer()
    }
    
    func stopRecording() {
        videoOutput?.stopRecording()
        isRecording = false
        timer?.invalidate()
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self,
                  let startTime = self.startTime else { return }
            
            let elapsed = Date().timeIntervalSince(startTime)
            if elapsed >= 30.0 {
                self.stopRecording()
            }
            
            self.formattedElapsedTime = String(format: "%02d:%02d",
                                               Int(elapsed) / 60,
                                               Int(elapsed) % 60)
        }
    }
    
    private func analyzePoses(in videoURL: URL) {
        let request = VNDetectHumanBodyPoseRequest { [weak self] request, error in
            guard let observations = request.results as? [VNHumanBodyPoseObservation],
                  !observations.isEmpty else { return }
            
            if let observation = observations.first {
                // Store body pose observation
                self?.poseData.append(observation)
            }
        }
        
        
        
        let videoAsset = AVURLAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: videoAsset)
        generator.appliesPreferredTrackTransform = true
        
        let duration = CMTimeGetSeconds(videoAsset.duration)
        let frameCount = Int(duration * 30) // 30 fps
        
        print("Starting hand pose analysis") // Debug
        
        for i in 0..<frameCount {
            let time = CMTime(seconds: Double(i) / 30.0,
                             preferredTimescale: 600)
            
            guard let cgImage = try? generator.copyCGImage(at: time,
                                                         actualTime: nil) else { continue }
            
            let handler = VNImageRequestHandler(cgImage: cgImage,
                                              orientation: .up,
                                              options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                print("Hand pose detection failed: \(error)")
            }
        }
        
        print("Finished hand pose analysis. Total poses: \(poseData.count)")
    }
    
    func switchCamera() {
        captureSession.beginConfiguration()
        
        // Remove existing input
        if let existingInput = captureSession.inputs.first {
            captureSession.removeInput(existingInput)
        }
        
        // Switch camera position
        let newPosition: AVCaptureDevice.Position = currentCamera == .front ? .back : .front
        let deviceTypes: [AVCaptureDevice.DeviceType] = [
            .builtInWideAngleCamera,
            .builtInUltraWideCamera
        ]
        
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .video,
            position: newPosition
        )
        
        if let camera = discoverySession.devices.first {
            do {
                let input = try AVCaptureDeviceInput(device: camera)
                if captureSession.canAddInput(input) {
                    captureSession.addInput(input)
                    currentCamera = newPosition
                }
            } catch {
                print("Camera switch error: \(error)")
            }
        }
        
        captureSession.commitConfiguration()
    }
    
    func toggleWideAngle() {
        isWideAngle.toggle()
        let deviceType: AVCaptureDevice.DeviceType = isWideAngle ? .builtInUltraWideCamera : .builtInWideAngleCamera
        
        if let device = AVCaptureDevice.default(deviceType, for: .video, position: currentCamera) {
            captureSession.beginConfiguration()
            
            // Remove existing input
            if let existingInput = captureSession.inputs.first {
                captureSession.removeInput(existingInput)
            }
            
            do {
                let input = try AVCaptureDeviceInput(device: device)
                if captureSession.canAddInput(input) {
                    captureSession.addInput(input)
                }
            } catch {
                print("Camera switch error: \(error)")
            }
            
            captureSession.commitConfiguration()
        }
    }
    
    func setZoom(_ factor: CGFloat) {
        zoomLevel = max(1.0, min(factor, 5.0)) // Limit zoom between 1x and 5x
        
        if let device = (captureSession.inputs.first as? AVCaptureDeviceInput)?.device {
            try? device.lockForConfiguration()
            device.videoZoomFactor = zoomLevel
            device.unlockForConfiguration()
        }
    }
}

extension ExerciseRecordingViewModel: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput,
                    didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection],
                    error: Error?) {
        if error == nil {
            videoURL = outputFileURL
            hasRecordedVideo = true
            isProcessing = true
            
            DispatchQueue.global(qos: .userInitiated).async {
                self.analyzePoses(in: outputFileURL)
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.showReview = true
                }
            }
        }
    }
    
    func fileOutput(_ output: AVCaptureFileOutput,
                    didStartRecordingTo fileURL: URL,
                    from connections: [AVCaptureConnection]) {}
}
