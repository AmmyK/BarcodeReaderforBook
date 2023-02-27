//
//  Book.swift
//  BarcodeReaderByGogleBooks
//
//  Created by amamiya on 2023/02/26.
//

import Foundation



struct Book: Codable {
    let kind: String
    let totalItems: Int
    let items: Items
}

struct Items: Codable{
    let kind: String
    let id: String
    let etag: String
    let selfLink: String
    let volumeInfo: VolumeInfo
    let saleInfo: SaleInfo
    let accessInfo: AccessInfo
    let searchInfo: SearchInfo
}

struct VolumeInfo: Codable {
    let title: String
    let authors: [String]
    let publisher: String
    let publishedDate: String
    let description: String
    
    let pageCount: Int
    let printType: String
}

struct SaleInfo: Codable {
    
}

struct AccessInfo: Codable {
    
}
struct SearchInfo: Codable {
    
}
