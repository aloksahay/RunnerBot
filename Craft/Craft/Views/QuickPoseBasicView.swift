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
struct Point3D: Codable {
    let x: Double
    let y: Double
    let cameraAspectY: Double
    let z: Double
    let visibility: Double
    let presence: Double
}

// Update Landmark structure
struct Landmark: Codable {
    let location: Point3D
    let type: String
}

struct FrameData: Codable {
    let timestamp: TimeInterval
    
    // Update Feature structure to match QuickPose.FeatureResult
    struct Feature: Codable {
        let value: Double
        let stringValue: String
    }
    
    // Store the feature type as string and its result
    let features: [String: Feature]
    let landmarks: [Landmark]?
    
    init(timestamp: TimeInterval, 
         features: [QuickPose.Feature: QuickPose.FeatureResult],
         landmarks: QuickPose.Landmarks?) {
        self.timestamp = timestamp
        
        // Convert features
        var convertedFeatures: [String: Feature] = [:]
        for (key, value) in features {
            convertedFeatures[key.displayString] = Feature(
                value: value.value,
                stringValue: value.stringValue
            )
        }
        self.features = convertedFeatures
        
        // Update landmarks conversion
        if let landmarks = landmarks {
            self.landmarks = landmarks.allLandmarksForBody().map { point3d in
                Landmark(
                    location: Point3D(
                        x: point3d.x,
                        y: point3d.y,
                        cameraAspectY: point3d.cameraAspectY,
                        z: point3d.z,
                        visibility: point3d.visibility,
                        presence: point3d.presence
                    ),
                    type: "body"
                )
            }
        } else {
            self.landmarks = nil
        }
    }
}

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

// Data structure for saving recording data
struct RecordingData: Codable {
    let id: String
    let timestamp: Date
    let frames: [FrameData]
    
    enum CodingKeys: String, CodingKey {
        case id
        case timestamp
        case frames
    }
}

#Preview {
    QuickPoseBasicView()
}
