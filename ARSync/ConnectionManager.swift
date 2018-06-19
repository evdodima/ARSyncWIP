//
//  ColorServiceManager.swift
//  multipeer
//
//  Created by evdodima on 23/11/2017.
//  Copyright © 2017 Evdodima. All rights reserved.
//

import Foundation
import ARKit
import MultipeerConnectivity

class ConnectionManager : NSObject {
    
    // Service type must be a unique string, at most 15 characters long
    // and can contain only ASCII lowercase letters, numbers and hyphens.
    private let serviceType = "arsync"
    
    public let myPeerId = MCPeerID(displayName: UIDevice.current.name) 
    private let serviceAdvertiser : MCNearbyServiceAdvertiser
    private let serviceBrowser : MCNearbyServiceBrowser
    
    var delegate : ConnectionManagerDelegate?
    
    lazy var session : MCSession = {
        let session = MCSession(peer: self.myPeerId,
                                securityIdentity: nil,
                                encryptionPreference: .none)
        session.delegate = self
        return session
    }()
    
    var queues: [MCPeerID : OperationQueue] = [:]
    var outputStreams: [MCPeerID : OutputStream] = [:]
    var inputStreams: [MCPeerID : InputStream] = [:]
    var synced: Bool = false {
        didSet {
            if synced {
                self.delegate?.didSyncWorld(manager: self)
            } else {
                // invalidate (show QR code again)
            }
        }
    }
    
    override init() {
        self.serviceAdvertiser = MCNearbyServiceAdvertiser(peer: myPeerId, discoveryInfo: nil, serviceType: serviceType)
        self.serviceBrowser = MCNearbyServiceBrowser(peer: myPeerId, serviceType: serviceType)
        super.init()
        self.serviceAdvertiser.delegate = self
        self.serviceAdvertiser.startAdvertisingPeer()
        
        self.serviceBrowser.delegate = self
        self.serviceBrowser.startBrowsingForPeers()
    }
    
    deinit {
        self.serviceAdvertiser.stopAdvertisingPeer()
        self.serviceBrowser.stopBrowsingForPeers()
    }
    func sendToStreams(data: [Message:Any]) {
//        
//        NSLog("%@", "sending data: \(data) to \(session.connectedPeers.count) peers")
        
        for (id, stream) in outputStreams {
            if let location = data[.location] as? SCNVector3,
                let eulers = data[.eulers] as? SCNVector3,
                let queue = queues[id] {
                do {
                    let bytes = location.toBytes() + eulers.toBytes()
                    stream.write(bytes, maxLength: 24)
                }
            }
        }
    }
    
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()
    
    func sendEvent(event: Event) {
//        NSLog("%@", "sending data: \(event) to \(session.connectedPeers.count) peers")
        
        if session.connectedPeers.count > 0 {
            do {
                try self.session.send(try encoder.encode(event),
                                      toPeers: session.connectedPeers,
                                      with: .unreliable)
            } catch let error {
                NSLog("%@", "Error for sending: \(error)")
            }
        }
        
    }
    func broadcastMyLocation(pov: SCNNode) {
            sendToStreams(data: [.location : pov.position,
                                            .eulers : pov.eulerAngles])
    }
}

extension ConnectionManager : MCSessionDelegate {
    
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        NSLog("%@", "peer \(peerID) didChangeState: \(state)")
        
        if state == .connected {
            if peerID.displayName > myPeerId.displayName {
                synced = true
            }
            
                
            let id = "\(myPeerId.displayName)-\(peerID.displayName)"
            if let stream = try? session.startStream(withName: id, toPeer: peerID) {
                stream.schedule(in: RunLoop.main, forMode: .defaultRunLoopMode)
                outputStreams[peerID] = stream
                stream.open()
                
                queues[peerID] = OperationQueue()
            }
        } else if state == .notConnected {
            outputStreams[peerID]?.close()
            outputStreams[peerID] = nil
            queues[peerID] = nil
        }
        
        OperationQueue.main.addOperation {
            self.delegate?.connectedDevicesChanged(manager: self, connectedDevices:
                session.connectedPeers.map{$0.displayName})
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        do {
            let event = try decoder.decode(Event.self, from: data)
            NSLog("%@", "unarchived: \(event)")
            OperationQueue.main.addOperation {
//                debugPrint(event)
                self.delegate?.eventRecieved(manager: self, event: event, fromPeer: peerID.displayName)
            }
        } catch let error {
            print("Can't unarchive data \(data) \(error)")
        }
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        NSLog("%@", "didReceiveStream")
        inputStreams[peerID] = stream
        stream.schedule(in: RunLoop.main, forMode: .defaultRunLoopMode)
        stream.delegate = self
        stream.open()
    }
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        NSLog("%@", "didStartReceivingResourceWithName")
    }
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        NSLog("%@", "didFinishReceivingResourceWithName")
    }
}

extension ConnectionManager : StreamDelegate {
    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        do {
            if let input = aStream as? InputStream, let sender = self.inputStreams.first(where: { $1 == input })?.0,
                eventCode == .hasBytesAvailable {
                
                do {
                    
                    
                    
                        var bytes = [UInt8](repeating: 0, count: 256)
                        let len = input.read(&bytes, maxLength: 256)
                    
                        if len < 24 { return }
                    
                        bytes = Array(bytes[len-24..<len])
                    
                        let position = SCNVector3(fromBytes: Array(bytes[0..<12]))
                        let eulers = SCNVector3(fromBytes: Array(bytes[12..<24]))
                    
                        self.delegate?.updateFromStream(manager: self,
                                                   data: [.location: position,
                                                          .eulers : eulers],
                                                   fromPeer: sender.displayName)
                }
            }
        }
    }
}

extension ConnectionManager : MCNearbyServiceAdvertiserDelegate {
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        NSLog("%@", "didNotStartAdvertisingPeer: \(error)")
    }
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        NSLog("%@", "didReceiveInvitationFromPeer \(peerID)")
        
        invitationHandler(true, self.session)
    }
    
}

extension ConnectionManager : MCNearbyServiceBrowserDelegate {
    
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        NSLog("%@", "didNotStartBrowsingForPeers: \(error)")
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        NSLog("%@", "foundPeer: \(peerID)")
        NSLog("%@", "invitePeer: \(peerID)")
        browser.invitePeer(peerID, to: self.session, withContext: nil, timeout: 10)
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        NSLog("%@", "lostPeer: \(peerID)")
    }
    
}
