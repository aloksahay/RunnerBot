//
//  Untitled.swift
//  Craft
//
//  Created by Alok Sahay on 05.02.2025.
//

import SwiftUI
import QuickPoseCore
import QuickPoseSwiftUI

// Update Point3D structure to match QuickPose.Point3d

struct QuickPoseBasicView: View {

    private var quickPose = QuickPose(sdkKey: CraftEnvironmentVariables.quickPoseSDKKey)
    private let videoDataManager = VideoDataManager(nillionCluster: [:]) // Empty dictionary as placeholder for now
    
    @State private var overlayImage: UIImage?
    @State private var showOverlay = true
    @State private var isRecording = false
    @State private var recordedFramesData: [FrameData] = [] // Store AI data during recording
    @State private var isUploading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    // Define a struct to store frame data
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                if ProcessInfo.processInfo.isiOSAppOnMac, let url = Bundle.main.url(forResource: "happy-dance", withExtension: "mov") {
                    QuickPoseSimulatedCameraView(useFrontCamera: false, delegate: quickPose, video: url)
                } else {
                    QuickPoseCameraView(useFrontCamera: true, delegate: quickPose)
                }
                if showOverlay {
                    QuickPoseOverlayView(overlayImage: $overlayImage)
                }
                VStack {
                    HStack {
                        Button(action: { showOverlay.toggle() }) {
                            Image(systemName: showOverlay ? "eye.fill" : "eye.slash.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                                .frame(width: 50, height: 50)
                                .background(Circle().fill(Color.black.opacity(0.6)))
                        }
                        .padding(.top, 40)
                        .padding(.trailing, 20)
                        
                        Spacer()
                        
                        Button(action: { 
                            isRecording.toggle()
                            if isRecording {
                                startRecording()
                            } else {
                                stopRecording()
                            }
                        }) {
                            Circle()
                                .fill(isRecording ? Color.red : Color.white)
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: 4)
                                )
                        }
                    }
                    .padding(.top, 40)
                    .padding(.horizontal, 20)
                    
                    Spacer()
                }
                uploadingOverlay
            }
            .frame(width: geometry.size.width)
            .edgesIgnoringSafeArea(.all)
            .onAppear {
                quickPose.start(features: [.overlay(.wholeBodyAndHead)], onFrame: { status, image, features, feedback, landmarks in
                    if showOverlay {
                        overlayImage = image
                    }
                    
                    if case .success = status {
                        if isRecording {
                            let frameData = FrameData(
                                timestamp: Date().timeIntervalSince1970,
                                features: features,
                                landmarks: landmarks
                            )
                            recordedFramesData.append(frameData)
                        }
                    } else {
                        print("Error")
                    }
                })
            }.onDisappear {
                quickPose.stop()
            }
        }
        .alert("Recording Status", isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func startRecording() {
        recordedFramesData.removeAll()
    }
    
    private func stopRecording() {
        saveRecordingData()
    }
    
    private func saveRecordingData() {
        let recordingData = RecordingData(
            id: UUID().uuidString,
            timestamp: Date(),
            frames: recordedFramesData
        )
        
        // First save locally
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(recordingData)
            
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileURL = documentsDirectory.appendingPathComponent("\(recordingData.id).json")
            
            try data.write(to: fileURL)
            print("Saved recording data locally to: \(fileURL)")
            
            // Then upload to Nillion
            Task {
                await uploadToNillion(recordingData)
            }
        } catch {
            showAlert(message: "Failed to save recording: \(error.localizedDescription)")
        }
    }
    
    private func uploadToNillion(_ recordingData: RecordingData) async {
        do {
            isUploading = true
            // TODO: Get these values from your app's state/environment
            let walletAddress = "YOUR_WALLET_ADDRESS" // Replace with actual wallet address
            let videoCID = "YOUR_VIDEO_CID" // Replace with actual video CID or generate one
            
            try await videoDataManager.uploadVideoData(
                walletAddress: walletAddress,
                videoCID: videoCID,
                recordingData: recordingData
            )
            
            await MainActor.run {
                showAlert(message: "Recording uploaded successfully!")
            }
        } catch {
            await MainActor.run {
                showAlert(message: "Failed to upload: \(error.localizedDescription)")
            }
        }
        await MainActor.run {
            isUploading = false
        }
    }
    
    private func showAlert(message: String) {
        alertMessage = message
        showAlert = true
    }
    
    // Add this to your view's body
    var uploadingOverlay: some View {
        Group {
            if isUploading {
                Color.black.opacity(0.5)
                    .edgesIgnoringSafeArea(.all)
                    .overlay(
                        ProgressView("Uploading...")
                            .foregroundColor(.white)
                    )
            }
        }
    }
    
    // Add a function to load recording data
    func loadRecordingData(id: String) -> RecordingData? {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsDirectory.appendingPathComponent("\(id).json")
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            let recordingData = try decoder.decode(RecordingData.self, from: data)
            return recordingData
        } catch {
            print("Failed to load recording data: \(error)")
            return nil
        }
    }
    
    // Function to fetch recordings for a wallet
    func fetchRecordings(walletAddress: String) async {
        do {
            let recordings = try await videoDataManager.fetchVideosForWallet(walletAddress: walletAddress)
            print("Retrieved \(recordings.count) recordings")
            // Handle the retrieved recordings (e.g., display them in a list)
        } catch {
            showAlert(message: "Failed to fetch recordings: \(error.localizedDescription)")
        }
    }
    
    // Function to fetch a specific recording
    func fetchRecording(videoCID: String) async {
        do {
            if let recording = try await videoDataManager.fetchVideoData(videoCID: videoCID) {
                print("Retrieved recording with ID: \(recording.id)")
                // Handle the retrieved recording
            }
        } catch {
            showAlert(message: "Failed to fetch recording: \(error.localizedDescription)")
        }
    }
}

