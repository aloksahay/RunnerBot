//
//  CraftAgentModel.swift
//  Craft
//
//  Created by Alok Sahay on 08.02.2025.
//

import SwiftUI
import QuickPoseCore
import QuickPoseSwiftUI

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

struct FrameData: Codable {
    let timestamp: TimeInterval
        
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
                
        var convertedFeatures: [String: Feature] = [:]
        for (key, value) in features {
            convertedFeatures[key.displayString] = Feature(
                value: value.value,
                stringValue: value.stringValue
            )
        }
        self.features = convertedFeatures
                
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

struct Landmark: Codable {
    let location: Point3D
    let type: String
}

struct Point3D: Codable {
    let x: Double
    let y: Double
    let cameraAspectY: Double
    let z: Double
    let visibility: Double
    let presence: Double
}
