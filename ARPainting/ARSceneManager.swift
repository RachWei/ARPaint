//
//  ARSceneManager.swift
//  ARPlaneDetector
//
//  Created by Ben Lambert on 2/8/18.
//  Copyright © 2018 collectiveidea. All rights reserved.
//

import Foundation
import ARKit

class ARSceneManager: NSObject {
    
    private var planes = [UUID: Plane]()
    
    var sceneView: ARSCNView?
    
    var showPlanes: Bool = true {
        didSet {
            if showPlanes == false {
                planes.values.forEach {
                    $0.runAction(SCNAction.fadeOut(duration: 0.5))
                }
            } else {
                planes.values.forEach {
                    $0.runAction(SCNAction.fadeIn(duration: 0.5))
                }
            }
        }
    }
    
    let configuration = ARWorldTrackingConfiguration()
    
    func attach(to sceneView: ARSCNView) {
        print("attach ARSceneManager")
        self.sceneView = sceneView
        self.sceneView?.autoenablesDefaultLighting = true
        
        self.sceneView!.delegate = self
        
        startPlaneDetection()
        configuration.isLightEstimationEnabled = true
        
        sceneView.scene.physicsWorld.gravity = SCNVector3(0, -3.0, 0)
    }
    
    func displayDebugInfo() {
        print("displayDebugInfo ARSceneManager")
        sceneView?.showsStatistics = true
        sceneView?.debugOptions = [ARSCNDebugOptions.showFeaturePoints, ARSCNDebugOptions.showWorldOrigin]
    }
    
    func startPlaneDetection() {
        print("startPlaneDetection ARSceneManager")
        configuration.planeDetection = [.vertical]
        sceneView?.session.run(configuration)
    }
    
    func stopPlaneDetection() {
        print("stopPlaneDetection ARSceneManager")
        configuration.planeDetection = []
        sceneView?.session.run(configuration)
    }
    
}

extension ARSceneManager: ARSCNViewDelegate {
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        print("renderer 1 ARSceneManager")
        // we only care about planes
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
        
        print("Found plane: \(planeAnchor)")
        
        let plane = Plane(anchor: planeAnchor)
        plane.opacity = showPlanes ? 1 : 0
        
        // store a local reference to the plane
        planes[anchor.identifier] = plane
        
        node.addChildNode(plane)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        print("renderer 2 ARSceneManager")
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
        
        if let plane = planes[planeAnchor.identifier] {
            plane.updateWith(anchor: planeAnchor)
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
        print("renderer 3 ARSceneManager")
        planes.removeValue(forKey: anchor.identifier)
    }
    
}
