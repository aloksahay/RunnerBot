//
//  VideoDataManager.swift
//  Craft
//
//  Created by Alok Sahay on 09.02.2025.
//

import Foundation

class VideoDataManager {
    private let baseURL = "http://localhost:3000/api/v1"
    private let nillion: NillionWrapper
    
    init(nillionCluster: Any) {
        self.nillion = NillionWrapper()
    }
    
    func uploadVideoData(walletAddress: String, videoCID: String, recordingData: RecordingData) async throws {
        try await nillion.initialize()
        
        let url = URL(string: "\(baseURL)/data/create")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "wallet_address": walletAddress,
            "video_cid": videoCID,
            "recording_data": try await nillion.encrypt(recordingData)
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NSError(domain: "APIError", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Upload failed"])
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
