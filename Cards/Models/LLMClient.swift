//
//  LLMClient.swift
//  Cards
//
//  Created by Julien Coquet on [Date].
//

import Foundation
import UIKit

class LLMClient {
    static let shared = LLMClient()

    private let apiKey = "YOUR_API_KEY" // Replace with your actual API key
    private let ocrApiURL = URL(string: "https://api.anthropic.com/v1/claude/ocr")! // Replace with the actual OCR endpoint
    private let processingApiURL = URL(string: "https://api.anthropic.com/v1/claude/llm")! // Replace with the actual LLM endpoint

    private init() {}

    func processImage(_ image: UIImage, completion: @escaping ([Flashcard]?) -> Void) {
        // Convert image to JPEG data
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            completion(nil)
            return
        }

        // Encode image data to base64 string
        let base64ImageString = imageData.base64EncodedString()

        // Prepare the OCR request
        var request = URLRequest(url: ocrApiURL)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "image_data": base64ImageString
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        // Send the OCR request
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error during OCR request: \(error.localizedDescription)")
                completion(nil)
                return
            }

            guard let data = data else {
                print("No data received from OCR request.")
                completion(nil)
                return
            }

            // Parse the OCR response
            if let ocrResponse = try? JSONDecoder().decode(OCRResponse.self, from: data) {
                // Proceed to process the extracted text
                self.processTextForFlashcards(ocrResponse.text, completion: completion)
            } else {
                print("Failed to decode OCR response.")
                completion(nil)
            }
        }

        task.resume()
    }

    private func processTextForFlashcards(_ extractedText: String, completion: @escaping ([Flashcard]?) -> Void) {
        // Prepare the LLM request
        var request = URLRequest(url: processingApiURL)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let prompt = "Create flashcards from the following text:\n\(extractedText)\n\nProvide the flashcards in JSON format as an array of objects with 'front' and 'back' fields."

        let body: [String: Any] = [
            "prompt": prompt,
            "max_tokens": 1000
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        // Send the LLM request
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error during LLM request: \(error.localizedDescription)")
                completion(nil)
                return
            }

            guard let data = data else {
                print("No data received from LLM request.")
                completion(nil)
                return
            }

            // Parse the LLM response
            if let flashcardsResponse = try? JSONDecoder().decode([Flashcard].self, from: data) {
                completion(flashcardsResponse)
            } else {
                print("Failed to decode LLM response.")
                completion(nil)
            }
        }

        task.resume()
    }
}

// MARK: - Response Models

struct OCRResponse: Decodable {
    let text: String
}

struct Flashcard: Decodable {
    let front: String
    let back: String
}
