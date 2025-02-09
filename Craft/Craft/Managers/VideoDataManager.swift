//
//  VideoDataManager.swift
//  Craft
//
//  Created by Alok Sahay on 09.02.2025.
//

import Foundation

class VideoDataManager {
    private let baseURL = "http://192.168.1.112:3000/api/v1"
    private let nillion: NillionWrapper
    
    init(nillionCluster: Any) {
        self.nillion = NillionWrapper()
    }
    
    func checkServerConnection() async throws -> Bool {
        print("Checking server connection...")
        print("Connecting to:", baseURL)
        
        let url = URL(string: "\(baseURL)/health")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 5
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("Error: Response is not HTTP")
                return false
            }
            
            if httpResponse.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let status = json["status"] as? String,
               status == "ok" {
                print("Successfully connected to server")
                return true
            }
            
            print("Server returned invalid status code:", httpResponse.statusCode)
            return false
        } catch {
            print("Server connection failed:", error.localizedDescription)
            return false
        }
    }
    
    func uploadVideoData(walletAddress: String, videoCID: String, recordingData: RecordingData) async throws {
        print("Starting video data upload:")
        print("- Wallet:", walletAddress)
        print("- Video CID:", videoCID)
        print("- Recording frames:", recordingData.frames.count)
        
        try await nillion.initialize()
        print("Nillion initialized")
        
        do {
            let success = try await nillion.uploadRecording(
                walletAddress: walletAddress,
                videoCID: videoCID,
                recordingData: recordingData
            )
            
            if success {
                print("Upload completed successfully")
            } else {
                throw NSError(domain: "UploadError", code: -1,
                             userInfo: [NSLocalizedDescriptionKey: "Not all chunks were uploaded successfully"])
            }
        } catch {
            print("Upload failed with error:", error)
            print("Error details:", error.localizedDescription)
            throw error
        }
    }
    
    func fetchVideoData(videoCID: String) async throws -> RecordingData? {
        try await nillion.initialize()
        
        let url = URL(string: "\(baseURL)/data/query?video_cid=\(videoCID)")!
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NSError(domain: "APIError", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Fetch failed"])
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let results = json?["data"] as? [[String: Any]],
              let firstResult = results.first,
              let encryptedData = firstResult["recording_data"] as? String else {
            return nil
        }
        
        return try await nillion.decrypt(encryptedData)
    }
    
    func fetchVideosForWallet(walletAddress: String) async throws -> [RecordingData] {
        try await nillion.initialize()
        
        let url = URL(string: "\(baseURL)/data/query?wallet_address=\(walletAddress)")!
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NSError(domain: "APIError", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Fetch failed"])
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let results = json?["data"] as? [[String: Any]] else {
            return []
        }
        
        var videos: [RecordingData] = []
        for result in results {
            if let encryptedData = result["recording_data"] as? String {
                let recordingData = try await nillion.decrypt(encryptedData)
                videos.append(recordingData)
            }
        }
        
        return videos
    }
}
