//
//  ViewController.swift
//  ARSync
//
//  Created by Rinat Khanov on 02/12/2017.
//  Copyright © 2017 Rinat Khanov. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

typealias Message = String
extension Message {
    static let location = "location"
}

class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {

    @IBOutlet var sceneView: ARSCNView!
    
    @IBOutlet weak var connectedDevicesLabel: UILabel!
    
    let connection = ConnectionManager()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        connection.delegate = self
        sceneView.session.delegate = self
        
        sceneView.delegate = self
        sceneView.showsStatistics = true
    
        sceneView.scene = SCNScene(named: "art.scnassets/ship.scn")!
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()

        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {

    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        broadcastMyLocation()
    }
    
    func broadcastMyLocation() {
        if let location = sceneView.pointOfView?.position {
            connection.send(data: [.location : location])
        }
    }
}

extension ViewController: ConnectionManagerDelegate {
    func connectedDevicesChanged(manager: ConnectionManager, connectedDevices: [String]) {
        print(connectedDevices)
        connectedDevicesLabel.text = connectedDevices.description
        
        for device in connectedDevices {
            if sceneView.scene.rootNode.childNode(withName: device,
                                                  recursively: false) == nil {
                addNodeForDevice(device)
            }
        }
    }
    
    func dataChanged(manager: ConnectionManager, data: [String : Any], fromPeer: String) {
        if let location = data[.location] as? SCNVector3 {
            if let node = sceneView.scene.rootNode.childNode(withName: fromPeer,
                                                             recursively: false) {
                node.position = location
            } else {
                addNodeForDevice(fromPeer, position: location)
            }
        }
    }
    
    func addNodeForDevice(_ device: String, position: SCNVector3? = nil) {
        let node = SCNNode()
        node.name = device
        node.geometry = SCNSphere(radius: 0.02)
        node.geometry?.firstMaterial?.diffuse.contents = UIColor.red.withAlphaComponent(0.7)
        node.geometry?.firstMaterial?.isDoubleSided = true
        node.position = position ?? SCNVector3Zero
        sceneView.scene.rootNode.addChildNode(node)
    }
}
