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
    @State private var overlayImage: UIImage?
    @State private var showOverlay = true
    @State private var isRecording = false
    @State private var recordedFramesData: [FrameData] = [] // Store AI data during recording
    
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
    }
    
    private func startRecording() {
        recordedFramesData.removeAll()
        // Start video recording without overlay
        // You'll need to implement actual video recording using AVFoundation
    }
    
    private func stopRecording() {
        // Stop video recording
        // Save video file and AI data separately
        saveRecordingData()
    }
    
    private func saveRecordingData() {
        let recordingData = RecordingData(
            id: UUID().uuidString,
            timestamp: Date(),
            frames: recordedFramesData
        )
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(recordingData)
            
            // Save to documents directory
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileURL = documentsDirectory.appendingPathComponent("\(recordingData.id).json")
            
            try data.write(to: fileURL)
            print("Saved recording data to: \(fileURL)")
            
            // Optional: Print the JSON for debugging
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Recording data JSON:\n\(jsonString)")
            }
        } catch {
            print("Failed to save recording data: \(error)")
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
}

