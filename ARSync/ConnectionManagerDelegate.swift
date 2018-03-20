//
//  ColorServiceManagerDelegate.swift
//  multipeer
//
//  Created by evdodima on 23/11/2017.
//  Copyright © 2017 Evdodima. All rights reserved.
//

protocol ConnectionManagerDelegate {
    
    func connectedDevicesChanged(manager : ConnectionManager, connectedDevices: [String])
    
    func eventRecieved(manager : ConnectionManager, event: Event, fromPeer: String)
    
    func updateFromStream(manager : ConnectionManager, data: [Message: Any], fromPeer: String)
    
    func didSyncWorld(manager : ConnectionManager)
}
