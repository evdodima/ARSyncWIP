//
//  Utils.swift
//  ARSync
//
//  Created by Rinat Khanov on 02/12/2017.
//  Copyright © 2017 Rinat Khanov. All rights reserved.
//

import Foundation
import ARKit

func fromByteArray<T>(_ value: [UInt8], _: T.Type) -> T {
    return value.withUnsafeBufferPointer {
        $0.baseAddress!.withMemoryRebound(to: T.self, capacity: 1) {
            $0.pointee
        }
    }
}

func toByteArray<T>(_ value: T) -> [UInt8] {
    var value = value
    return withUnsafePointer(to: &value) {
        $0.withMemoryRebound(to: UInt8.self, capacity: MemoryLayout<T>.size) {
           Array(UnsafeBufferPointer(start: UnsafePointer<UInt8>($0), count: MemoryLayout<T>.size))
        }
    }
}

extension SCNVector3 {
    init(fromBytes: [UInt8]) {
        x = fromByteArray(Array(fromBytes[0...3]), Float.self)
        y = fromByteArray(Array(fromBytes[4...7]), Float.self)
        z = fromByteArray(Array(fromBytes[8...11]), Float.self)
    }
    
    func toBytes() -> [UInt8] {
        return [x,y,z].flatMap() { toByteArray($0) }
    }
}
