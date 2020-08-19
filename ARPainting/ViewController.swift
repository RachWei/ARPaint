//
//  ViewController.swift
//  ARPlaneDetector
//
//  Created by Ben Lambert on 2/8/18.
//  Copyright © 2018 collectiveidea. All rights reserved.
//

//learn about the angles + eulers, etc. 
import UIKit
import SceneKit
import ARKit
import Vision

class ViewController: UIViewController, ARSCNViewDelegate {
    let session = ARSession()
    let configuration = ARWorldTrackingConfiguration()
    var virtualObjectManager = VirtualObjectManager()
    var inDrawMode = false
    var textManager: TextManager!
    private var planes = [UUID: Plane]()
//    var planes = [ARPlaneAnchor: Plane]()
    var screenCenter: CGPoint?
    var restartExperienceButtonIsEnabled = true
    //var tracker = [[SCNNode]]()
    var selectedColor: UIColor?
    var colorPicker = SwiftHSVColorPicker()
    var currentPlane : ARAnchor?
    
    

    @IBOutlet weak var color: UIButton!
    @IBOutlet weak var restartExperienceButton: UIButton!
    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var drawButton: UIButton!
    @IBOutlet weak var messagePanel: UIVisualEffectView!
    @IBOutlet weak var messageLabel: UILabel!
    @IBAction func drawAction() {
        drawButton.isSelected = !drawButton.isSelected
        inDrawMode = drawButton.isSelected
    }
    @IBAction func colorButton(_ sender: Any) {
        self.color.backgroundColor = self.colorPicker.color
        if self.colorPicker.alpha == 1{
            self.colorPicker.alpha = 0
        } else {
            self.colorPicker.alpha = 1
        }
    }
    
    
    
    // MARK: - Queues
    //DispatchQueue: An object that manages the execution of tasks serially or concurrently on your app's main thread or on a background thread
    static let serialQueue = DispatchQueue(label: "com.apple.arkitexample.serialSceneKitQueue")
    // Create instance variable for more readable access inside class
    let serialQueue: DispatchQueue = ViewController.serialQueue
    
    func setupUIControls() {
        textManager = TextManager(viewController: self)
        // Set appearance of message output panel
        messagePanel.layer.cornerRadius = 3.0
        messagePanel.clipsToBounds = true
        messagePanel.isHidden = true
        messageLabel.text = ""
    }
    
    // MARK: - ViewDidLoad
    override func viewDidLoad() {
//        print("viewDidLoad")
        self.drawButton.layer.cornerRadius = self.drawButton.frame.width / 3
        self.color.layer.shadowColor = UIColor.black.cgColor
        self.color.layer.shadowOffset = CGSize(width: 0.0, height: 2.0)
        self.color.layer.masksToBounds = false
        self.color.layer.shadowRadius = 1.0
        self.color.layer.shadowOpacity = 0.5
        self.color.layer.cornerRadius = self.color.frame.width / 2
        selectedColor = UIColor.white
        super.viewDidLoad()
        self.colorPicker = SwiftHSVColorPicker(frame: CGRect(x: 10, y: 150, width: 210, height: 280))
        self.colorPicker.frame.origin.x = 80
        self.colorPicker.frame.origin.y = 450
        self.colorPicker.alpha = 0
        self.view.addSubview(colorPicker)
        self.colorPicker.setViewColor(selectedColor!)
        setupUIControls()
        sceneView.delegate = self
        sceneView.session = session
        self.color.backgroundColor = selectedColor!
        self.displayDebugInfo()
        sceneView.scene.enableEnvironmentMapWithIntensity(25, queue: serialQueue)
        
        UIApplication.shared.isIdleTimerDisabled = true
        self.attach(to: sceneView)
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(tapAction))
        view.addGestureRecognizer(tapGesture)
        self.textManager.showMessage("Welcome!")
    }
    
    override func viewDidAppear(_ animated: Bool){
//        print("viewDidAppear")
        if ARWorldTrackingConfiguration.isSupported { 
            resetTracking()
        } else {
            let sessionErrorMsg = "This app requires world tracking. World tracking is only available on iOS devices with A9 processor or newer. " +
            "Please quit the application."
            displayErrorMessage(title: "Unsupported platform", message: sessionErrorMsg, allowRestart: false)
        }
        configuration.isLightEstimationEnabled = true
//        sceneView.scene.physicsWorld.gravity = SCNVector3(0, -3.0, 0)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        print("viewWillDisappear")
        super.viewWillDisappear(animated)
        session.pause()
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        print("sessionWasInterrupted")
        textManager.blurBackground()
        textManager.showAlert(title: "Session Interrupted", message: "The session will be reset after the interruption has ended.")
    }

    func sessionInterruptionEnded(_ session: ARSession) {
        print("sessionInterruptionEnded")
        textManager.unblurBackground()
        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        restartExperience(self)
        textManager.showMessage("RESETTING SESSION")
    }
    
    
    // MARK: - ARPlaneDetector
    
    private func position(node: SCNNode, atHit hit: ARHitTestResult) {
        print("position")
        node.transform = SCNMatrix4(hit.anchor!.transform)
        node.eulerAngles = SCNVector3Make(node.eulerAngles.x + (Float.pi / 2), node.eulerAngles.y, node.eulerAngles.z)
        
        let position = SCNVector3Make(hit.worldTransform.columns.3.x + node.geometry!.boundingBox.min.z, hit.worldTransform.columns.3.y, hit.worldTransform.columns.3.z + 0.1)
        node.position = position
    }


        // MARK: Object tracking
    var lastFingerWorldPos: float3?
    var virtualPenTip: PointNode?
    private var handler = VNSequenceRequestHandler()
    fileprivate var lastObservation: VNDetectedObjectObservation?
    var trackImageBoundingBox: CGRect?
    var trackImageInitialOrigin: CGPoint?
    let trackImageSize = CGFloat(20)
    
    
    func resetTracking() {
        print("resetTracking")
        session.run(self.configuration, options: [.resetTracking, .removeExistingAnchors])
        trackImageInitialOrigin = nil
        inDrawMode = false
        lastFingerWorldPos = nil
        drawButton.isSelected = false
        self.virtualPenTip?.isHidden = true
        
    }
    // MARK: Tap Action
    @objc private func tapAction(recognizer: UITapGestureRecognizer) {
        print("tapped!")
        handler = VNSequenceRequestHandler()
        lastObservation = nil
        let tapLocation = recognizer.location(in: view)
//        var hitFeature : ARHitTestResult

        //find the distance away from the screen the object is at/
        //right now, hitting a feature point
        //put feature point on the tracked object/tracking box
        //lastObservation.boundingBox is a CGRect
        
        
//        let featureHitTestResult = self.sceneView.hitTest(tapLocation, types: .featurePoint)
//        if !featureHitTestResult.isEmpty {
//            hitFeature = featureHitTestResult.first!
//            hitFeature.distance
//
//
//
//            let anchor = ARAnchor(transform:hitFeature.worldTransform)
//            sceneView.session.add(anchor: anchor)
//
//        }
        
        // Set up the rect in the image in view coordinate space that we will track
        let trackImageBoundingBoxOrigin = CGPoint(x: tapLocation.x - trackImageSize / 2, y: tapLocation.y - trackImageSize / 2)
        trackImageBoundingBox = CGRect(origin: trackImageBoundingBoxOrigin, size: CGSize(width: trackImageSize, height: trackImageSize))
        
        let t = CGAffineTransform(scaleX: 1.0 / self.view.frame.size.width, y: 1.0 / self.view.frame.size.height)
        let normalizedTrackImageBoundingBox = trackImageBoundingBox!.applying(t)
        
        // Transfrom the rect from view space to image space
        guard let fromViewToCameraImageTransform = self.sceneView.session.currentFrame?.displayTransform(for: UIInterfaceOrientation.portrait, viewportSize: self.sceneView.frame.size).inverted() else {
            return
        }
        var trackImageBoundingBoxInImage =  normalizedTrackImageBoundingBox.applying(fromViewToCameraImageTransform)
        trackImageBoundingBoxInImage.origin.y = 1 - trackImageBoundingBoxInImage.origin.y   // Image space uses bottom left as origin while view space uses top left
        
        lastObservation = VNDetectedObjectObservation(boundingBox: trackImageBoundingBoxInImage)
        print("lastObservation: \(lastObservation)")
        
    }
    
    //Once object tracking is completed, it will call a callback function in which we will update the thumbnail location. It is typically the inverse of the code written in the tap recognizer:
    fileprivate func handle(_ request: VNRequest, error: Error?) {
//        print("handle")
        DispatchQueue.main.async {
            guard let newObservation = request.results?.first as? VNDetectedObjectObservation else {
                return
            }
            self.lastObservation = newObservation
            
            // check the confidence level before updating the UI
            guard newObservation.confidence >= 0.3 else {
                // hide the pen when we lose accuracy so the user knows something is wrong
                self.virtualPenTip?.isHidden = true
                self.lastObservation = nil
                return
            }
            
            var trackImageBoundingBoxInImage = newObservation.boundingBox
            
            // Transfrom the rect from image space to view space
            trackImageBoundingBoxInImage.origin.y = 1 - trackImageBoundingBoxInImage.origin.y
            guard let fromCameraImageToViewTransform = self.sceneView.session.currentFrame?.displayTransform(for: UIInterfaceOrientation.portrait, viewportSize: self.sceneView.frame.size) else {
                return
            }
            let normalizedTrackImageBoundingBox = trackImageBoundingBoxInImage.applying(fromCameraImageToViewTransform)
            let t = CGAffineTransform(scaleX: self.view.frame.size.width, y: self.view.frame.size.height)
            let unnormalizedTrackImageBoundingBox = normalizedTrackImageBoundingBox.applying(t)
            self.trackImageBoundingBox = unnormalizedTrackImageBoundingBox
            
            // Get the projection of the location of the tracked image from image space to the nearest detected plane
            if let trackImageOrigin = self.trackImageBoundingBox?.origin {
                (self.lastFingerWorldPos, _, _) = self.virtualObjectManager.worldPositionFromScreenPosition(CGPoint(x: trackImageOrigin.x /* - 20.0*/, y: trackImageOrigin.y /*+ 40.0*/), in: self.sceneView, objectPos: nil, infinitePlane: false)
                self.currentPlane = self.virtualObjectManager.worldPositionFromScreenPosition(CGPoint(x: trackImageOrigin.x /* - 20.0*/, y: trackImageOrigin.y /*+ 40.0*/), in: self.sceneView, objectPos: nil, infinitePlane: false).planeAnchor
//                print("lastFingerWorldPos \(self.lastFingerWorldPos)")
            }
        }
    }
    
    // MARK: Renderer + Planes
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
//        print("renderer 1")
        //updateFocusSquare()

        // If light estimation is enabled, update the intensity of the model's lights and the environment map
        
        if let lightEstimate = self.session.currentFrame?.lightEstimate {
            self.sceneView.scene.enableEnvironmentMapWithIntensity(lightEstimate.ambientIntensity / 40, queue: serialQueue)
        } else {
            self.sceneView.scene.enableEnvironmentMapWithIntensity(40, queue: serialQueue)
        }
        // Setup a dot that represents the virtual pen's tippoint
        if (self.virtualPenTip == nil) {
            self.virtualPenTip = PointNode(color: UIColor.red)
//            print("position: \(self.virtualPenTip!.position)")
//            let boxGeometry = SCNBox(width: 0.5, height: 0.5, length: 0.5, chamferRadius: 0.01)
//            let node = SCNNode(geometry: boxGeometry)
//            node.position = self.virtualPenTip!.position
//            self.sceneView.scene.rootNode.addChildNode(node)
            self.sceneView.scene.rootNode.addChildNode(self.virtualPenTip!)
        }

        // Track the thumbnail
        //The trickiest part above is how to convert the tap location from UIView coordinate space to the image coordinate space. ARKit provides us with the displayTransform matrix that converts from image coordinate space to a viewport coordinate space, but not the other way around. So how can we do the inverse? By using the inverse of the matrix. I really tried to minimize use of math in this post, but it is sometimes unavoidable in the 3D world.
        guard let pixelBuffer = self.sceneView.session.currentFrame?.capturedImage,
            let observation = self.lastObservation else {
                return
        }
        let request = VNTrackObjectRequest(detectedObjectObservation: observation) { [unowned self] request, error in
            self.handle(request, error: error)
        }
        request.trackingLevel = .accurate
        do {
            try self.handler.perform([request], on: pixelBuffer)
        }
        catch {
            print(error)
        }

        // Draw
        
        if let lastFingerWorldPos = self.lastFingerWorldPos {
            // Update virtual pen position
            self.virtualPenTip?.isHidden = false
            self.virtualPenTip?.simdPosition = lastFingerWorldPos
//
//            print("renderer 1 lastFingerWorldPos z \(self.lastFingerWorldPos?.z as Any)")
            // Draw new point
            if (self.inDrawMode && !self.virtualObjectManager.pointNodeExistAt(pos: lastFingerWorldPos)){
                let boxGeometry = SCNBox(width: 0.02, height: 0.02, length: 0.02, chamferRadius: 0.008)
//                print("selectedColor: \(selectedColor)")
                boxGeometry.firstMaterial?.diffuse.contents = colorPicker.color
                let node = SCNNode(geometry: boxGeometry)
                let distance = simd_distance(node.simdTransform.columns.3, (sceneView.session.currentFrame?.camera.transform.columns.3)!)
//                print("distance: \(distance)")
                let anchorPosition = currentPlane!.transform.columns.3
                let cameraPosition = sceneView.session.currentFrame!.camera.transform.columns.3
                let cameraToAnchor = cameraPosition - anchorPosition
                let distancePlane = length(cameraToAnchor)
//                print("distance: \(distance2)")2
                print(distancePlane)
                node.simdPosition = [lastFingerWorldPos.x + 0.1, lastFingerWorldPos.y + 0.05, lastFingerWorldPos.z + (distancePlane/2)]
                self.sceneView.scene.rootNode.addChildNode(node)
            }

            // Convert drawing to 3D
//            if (self.in3DMode ) {
//                if self.trackImageInitialOrigin != nil {
//                    DispatchQueue.main.async {
//                        let newH = 0.4 *  (self.trackImageInitialOrigin!.y - self.trackImageBoundingBox!.origin.y) / self.sceneView.frame.height
//                        self.virtualObjectManager.setNewHeight(newHeight: newH)
//                    }
//                }
//                else {
//                    self.trackImageInitialOrigin = self.trackImageBoundingBox?.origin
//                }
            //}

        }

    }
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        self.textManager.showMessage("Plane detected!")
//            print("renderer 2")
            
//            if let planeAnchor = anchor as? ARPlaneAnchor {
//                serialQueue.async {
//                    self.addPlane(node: node, anchor: planeAnchor)
//                    self.virtualObjectManager.checkIfObjectShouldMoveOntoPlane(anchor: planeAnchor, planeAnchorNode: node)
//                }
//            }
            
    //             we only care about planes
            guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
            self.virtualObjectManager.checkIfObjectShouldMoveOntoPlane(anchor: planeAnchor, planeAnchorNode: node)

            let plane = Plane(anchor: planeAnchor)
    //        plane.opacity = showPlanes ? 1 : 0

            // store a local reference to the plane
            planes[anchor.identifier] = plane

            node.addChildNode(plane)
            }
        
        func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
//            print("renderer 3")
//            if let planeAnchor = anchor as? ARPlaneAnchor {
//                serialQueue.async {
//                    self.updatePlane(anchor: planeAnchor)
//                    self.virtualObjectManager.checkIfObjectShouldMoveOntoPlane(anchor: planeAnchor, planeAnchorNode: node)
//                }
//            }
            guard let planeAnchor = anchor as? ARPlaneAnchor else { return }

            if let plane = planes[planeAnchor.identifier] {
                plane.updateWith(anchor: planeAnchor)
            }

        }

        
    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
//        print("renderer 4")
//        if let planeAnchor = anchor as? ARPlaneAnchor {
//            serialQueue.async {
//                self.removePlane(anchor: planeAnchor)
//            }
//        }
        planes.removeValue(forKey: anchor.identifier)
    }
    
    func attach(to sceneView: ARSCNView) {
        print("attach ARSceneManager")
        self.sceneView = sceneView
        self.sceneView?.autoenablesDefaultLighting = true

        self.sceneView!.delegate = self

        startPlaneDetection()
        configuration.isLightEstimationEnabled = true

        sceneView.scene.physicsWorld.gravity = SCNVector3(0, -3.0, 0)
    }
    
    func startPlaneDetection() {
        print("startPlaneDetection ARSceneManager")
        self.textManager.showMessage("Detecting Plane...")
        configuration.planeDetection = [.vertical]
        self.session.run(configuration)
    }
    
    func stopPlaneDetection() {
        configuration.planeDetection = []
        self.session.run(configuration)
    }

    
//    func addPlane(node: SCNNode, anchor: ARPlaneAnchor) {
//        print("addPlane")
//        let plane = Plane(anchor: anchor)
//        planes[anchor] = plane
//        node.addChildNode(plane)
//
//        //TEXT MANAGER?
//        textManager.cancelScheduledMessage(forType: .planeEstimation)
//        textManager.showMessage("SURFACE DETECTED")
//        if virtualObjectManager.pointNodes.isEmpty {
//            textManager.scheduleMessage("TAP + TO PLACE AN OBJECT", inSeconds: 7.5, messageType: .contentPlacement)
//        }
//    }
        
//    func updatePlane(anchor: ARPlaneAnchor) {
//        print("updatePlane")
//        if let plane = planes[anchor] {
//            plane.update(anchor)
//        }
//    }
            
//    func removePlane(anchor: ARPlaneAnchor) {
//        print("removePlane")
//        if let plane = planes.removeValue(forKey: anchor) {
//            plane.removeFromParentNode()
//        }
//    }
    
    func displayErrorMessage(title: String, message: String, allowRestart: Bool = false) {
        print("displayErrorMessage")
        // Blur the background.
        textManager.blurBackground()
        
        if allowRestart {
            // Present an alert informing about the error that has occurred.
            let restartAction = UIAlertAction(title: "Reset", style: .default) { _ in
                self.textManager.unblurBackground()
            }
            textManager.showAlert(title: title, message: message, actions: [restartAction])
        } else {
            textManager.showAlert(title: title, message: message, actions: [])
        }
    }
    
    
    func displayDebugInfo() {
        print("displayDebugInfo ARSceneManager")
        self.sceneView.showsStatistics = true
//        sceneView?.debugOptions = [ARSCNDebugOptions.showFeaturePoints]
        //ARSCNDebugOptions.showWorldOrigin
    }
    
    @IBAction func getSelectedColor(_ sender: UIButton) {
       // Get the selected color from the Color Picker.
        let selectedColor = colorPicker.color
    }
    
    
    @IBAction func restartExperience(_ sender: Any) {
        print("restartExperience")
        guard restartExperienceButtonIsEnabled else { return }
        
        DispatchQueue.main.async {
            self.restartExperienceButtonIsEnabled = false
            
            self.textManager.cancelAllScheduledMessages()
            self.textManager.dismissPresentedAlert()
            self.textManager.showMessage("STARTING A NEW SESSION")
            
            self.sceneView.scene.rootNode.enumerateChildNodes { (node, stop) in
            node.removeFromParentNode() }
            self.resetTracking()
            
            self.restartExperienceButton.setImage(#imageLiteral(resourceName: "restart"), for: [])
            
            // Disable Restart button for a while in order to give the session enough time to restart.
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0, execute: {
                self.restartExperienceButtonIsEnabled = true
            })
        }
    }
    
    func calculateAngleBetween3Positions(pos1:SCNVector3, pos2:SCNVector3, pos3:SCNVector3) -> Float {
        let v1 = SCNVector3(x: pos2.x-pos1.x, y: pos2.y-pos1.y, z: pos2.z-pos1.z)
        let v2 = SCNVector3(x: pos3.x-pos1.x, y: pos3.y-pos1.y, z: pos3.z-pos1.z)

        let v1Magnitude = sqrt(v1.x * v1.x + v1.y * v1.y + v1.z * v1.z)
        let v1Normal = SCNVector3(x: v1.x/v1Magnitude, y: v1.y/v1Magnitude, z: v1.z/v1Magnitude)

        let v2Magnitude = sqrt(v2.x * v2.x + v2.y * v2.y + v2.z * v2.z)
        let v2Normal = SCNVector3(x: v2.x/v2Magnitude, y: v2.y/v2Magnitude, z: v2.z/v2Magnitude)

        let result = v1Normal.x * v2Normal.x + v1Normal.y * v2Normal.y + v1Normal.z * v2Normal.z
        let angle = acos(result)

        return angle
    }
    
}
