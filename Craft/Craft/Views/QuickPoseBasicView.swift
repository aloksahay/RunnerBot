//
//  Untitled.swift
//  Craft
//
//  Created by Alok Sahay on 05.02.2025.
//

import SwiftUI
import QuickPoseCore
import QuickPoseSwiftUI

struct QuickPoseBasicView: View {

    private var quickPose = QuickPose(sdkKey: CraftEnvironmentVariables.quickPoseSDKKey)
    @State private var overlayImage: UIImage?
    @State private var showOverlay = true
    
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
                    Button(action: { showOverlay.toggle() }) {
                        HStack {
                            Image(systemName: showOverlay ? "eye.fill" : "eye.slash.fill")
                            Text(showOverlay ? "Hide Overlay" : "Show Overlay")
                        }
                        .padding()
                        .background(Color.black.opacity(0.6))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .padding(.top, 40)
                    
                    Spacer()
                }
            }
            .frame(width: geometry.size.width)
            .edgesIgnoringSafeArea(.all)
            .onAppear {
                quickPose.start(features: [.overlay(.wholeBodyAndHead)], onFrame: { status, image, features, feedback, landmarks in
                    if showOverlay {
                        overlayImage = image
                    } else {
                        overlayImage = nil
                    }
                    if case .success = status {
                        
                        
                        
                        
                    } else {
                        print("Error")
                    }
                })
            }.onDisappear {
                quickPose.stop()
            }
        }
    }
}

#Preview {
    QuickPoseBasicView()
}
