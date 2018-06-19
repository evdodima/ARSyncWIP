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

class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {

    @IBOutlet var sceneView: ARSCNView!
    
    @IBOutlet weak var pricel: UIImageView!
    @IBOutlet weak var connectedDevicesLabel: UILabel!
    
    let connection = ConnectionManager()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        connection.delegate = self
        sceneView.session.delegate = self
        
        sceneView.delegate = self
        sceneView.showsStatistics = true
        
        sceneView.debugOptions = [ARSCNDebugOptions.showWorldOrigin]
    
        sceneView.scene = SCNScene(named: "art.scnassets/ship.scn")!
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(tap))
        view.addGestureRecognizer(tapGesture)
    }
    
    @objc func tap(tapGesture: UITapGestureRecognizer) {
        pricel.isHidden = !pricel.isHidden
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        guard var referenceImages = ARReferenceImage.referenceImages(inGroupNamed: "AR Resources", bundle: nil) else {
            fatalError("Missing expected asset catalog resources.")
        }
        
        
        configuration.detectionImages = referenceImages
        

        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        if let anchor = anchor as? ARPlaneAnchor {
            node.name = connection.myPeerId.displayName + UUID().uuidString
            let event = Event(type: .added, node: ARSyncNode(id: node.name!,
                                                             geo:
                                                                ARSyncGeo(
                                                                    type: .horPlane,
                                                                    width: anchor.extent.x,
                                                                    height: anchor.extent.z),
                                                             position: node.position,
                                                             rotation: node.eulerAngles
            ))
            connection.sendEvent(event: event)
        } else if let anchor = anchor as? ARImageAnchor,
            let name = connection.session.connectedPeers.first?.displayName,
            let red = sceneView.scene.rootNode.childNode(withName: name, recursively: false) {
            
            let qr = SCNNode()
            qr.transform = SCNMatrix4(anchor.transform)
            
//            let rotation = SCNMatrix4MakeRotation(red.eulerAngles.y + qr.eulerAngles.y,
//                                                  0, 1, 0)
            let rotnod = SCNNode()
            rotnod.eulerAngles.y = qr.eulerAngles.y - red.eulerAngles.y
            print(qr.eulerAngles.y / Float.pi * 180)
            print(red.eulerAngles.y / Float.pi * 180, "\n")

//            sceneView.session.setWorldOrigin(relativeTransform: matrix_float4x4(rotnod.transform))
            
            let translation = SCNMatrix4MakeTranslation(qr.position.x - red.position.x,
                                                        qr.position.y - red.position.y,
                                                        qr.position.z - red.position.z)
            
//            sceneView.session.setWorldOrigin(relativeTransform: matrix_float4x4(translation))
            
            sceneView.session.remove(anchor: anchor)
            
         //   connection.sendEvent(event: <#T##Event#>)
        }

    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {

    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        counter += 1
        connection.broadcastMyLocation(pov: sceneView.pointOfView!)
    }
    
    
    
    var counter = 0
}



extension ViewController: ConnectionManagerDelegate {
    
    func didSyncWorld(manager: ConnectionManager) {
        DispatchQueue.main.async {
            self.pricel.isHidden = true
        }
    }
    
    
    func connectedDevicesChanged(manager: ConnectionManager, connectedDevices: [String]) {
//        print(connectedDevices)
        connectedDevicesLabel.text = connectedDevices.description
        
        for device in connectedDevices {
            if sceneView.scene.rootNode.childNode(withName: device,
                                                  recursively: false) == nil {
                addNodeForDevice(device)
            }
        }
    }
    
    func dataChanged(manager: ConnectionManager, data: [Int : Any], fromPeer: String) {
        
    }
    
    func updateFromStream(manager: ConnectionManager, data: [Message : Any], fromPeer: String) {
        if let location = data[.location] as? SCNVector3,
            let eulers = data[.eulers] as? SCNVector3 {
            if let node = sceneView.scene.rootNode.childNode(withName: fromPeer,
                                                             recursively: false) {
                node.position = location
                node.eulerAngles = eulers
            } else {
                addNodeForDevice(fromPeer, position: location)
            }
        }
    }
    
    func eventRecieved(manager: ConnectionManager, event: Event, fromPeer: String) {
        
    }
    
    
    func addNodeForDevice(_ device: String, position: SCNVector3? = nil) {
        let node = SCNNode()
        node.name = device
        node.geometry = SCNBox(width: 0.1, height: 0.3, length: 0.03, chamferRadius: 0)
        node.geometry?.firstMaterial?.diffuse.contents = UIColor.red.withAlphaComponent(0.7)
        node.geometry?.firstMaterial?.isDoubleSided = true
        node.position = position ?? SCNVector3Zero
        sceneView.scene.rootNode.addChildNode(node)
    }
}
