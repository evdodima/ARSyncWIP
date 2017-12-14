//
//  Event.swift
//  ARSync
//
//  Created by evdodima on 14/12/2017.
//  Copyright © 2017 Rinat Khanov. All rights reserved.
//

import Foundation
import SceneKit


struct Event: Codable {
    let type: ARSyncEventType
    let node: ARSyncNode
}

enum ARSyncEventType: Int, Codable {
    case added
    case updated
    case removed
}

enum ARSyncGeoType: Int, Codable {
    case horPlane
}

struct ARSyncGeo: Codable {
    let type: ARSyncGeoType
    let width: Float
    let height: Float
}

struct ARSyncNode: Codable {
    let id: Int
    let geo: ARSyncGeo
    let position: SCNVector3
    let rotation: SCNVector3
}



