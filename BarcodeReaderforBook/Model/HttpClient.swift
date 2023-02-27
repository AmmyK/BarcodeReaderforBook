//
//  HttpClient.swift
//  BarcodeReaderByGogleBooks
//
//  Created by amamiya on 2023/02/26.
//

import Foundation

enum HttpError: Error {
    case badURL, badResponse, errorDecodingData, invalidURL
}

final class HttpClient {
    func fetch<T: Codable>(url: URL) async throws -> [T] {
        
        let (data, respone) = try await URLSession.shared.data(from: url)
        
        guard (respone as? HTTPURLResponse)?.statusCode == 200 else {
            throw HttpError.badResponse
        }
        
        guard let object = try? JSONDecoder().decode([T].self, from: data) else {
            throw HttpError.errorDecodingData
        }
        return object
    }
}
