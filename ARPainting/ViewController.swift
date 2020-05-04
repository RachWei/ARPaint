//
//  ViewController.swift
//  ARPlaneDetector
//
//  Created by Ben Lambert on 2/8/18.
//  Copyright © 2018 collectiveidea. All rights reserved.
//

//today: detect the finger and put a point there that follows the finger
import UIKit
import SceneKit
import ARKit
import Vision

class ViewController: UIViewController, ARSCNViewDelegate {
    let session = ARSession()

    @IBOutlet var sceneView: ARSCNView!
    let sceneManager = ARSceneManager()
    //implement
//    @IBOutlet weak var drawButton: UIButton!
//    @IBAction func drawAction() {
//        drawButton.isSelected = !drawButton.isSelected
//        inDrawMode = drawButton.isSelected
//        in3DMode = false
//    }
    
    // MARK: - Queues
    //don't know if we need
    //DispatchQueue: An object that manages the execution of tasks serially or concurrently on your app's main thread or on a background thread
    static let serialQueue = DispatchQueue(label: "com.apple.arkitexample.serialSceneKitQueue")
    // Create instance variable for more readable access inside class
    let serialQueue: DispatchQueue = ViewController.serialQueue
    
    
    
    
    
    
    
    // MARK: - ViewDidLoad
    override func viewDidLoad() {
        print("viewDidLoad")
        super.viewDidLoad()
        
        sceneManager.attach(to: sceneView)
        sceneManager.displayDebugInfo()
        UIApplication.shared.isIdleTimerDisabled = true
        
        //arpaint:
//        setupUIControls()
//        setupScene()
        
        //setting up gesture
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(didTapScene(_:)))
        view.addGestureRecognizer(tapGesture)
    }
    
    
    //arpaint
    override func viewDidAppear(_ animated: Bool){
        print("viewDidAppear")
        if ARWorldTrackingConfiguration.isSupported {
            // Start the ARSession.
//            resetTracking()
            print("hi")
        } else {
            // This device does not support 6DOF world tracking.
            let sessionErrorMsg = "This app requires world tracking. World tracking is only available on iOS devices with A9 processor or newer. " +
            "Please quit the application."
//            displayErrorMessage(title: "Unsupported platform", message: sessionErrorMsg, allowRestart: false)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        print("viewWillDisappear")
        super.viewWillDisappear(animated)
        session.pause()
    }
    
    
    
    // MARK: - Functions
    
    
    @objc func didTapScene(_ gesture: UITapGestureRecognizer) {
        print("didTapScene")
        switch gesture.state {
        case .ended:
            let location = gesture.location(ofTouch: 0,
                                            in: sceneView)
            let hit = sceneView.hitTest(location,
                                        types: .existingPlaneUsingGeometry)
            
            if let hit = hit.first {
                placeBlockOnPlaneAt(hit)
            }
        default:
            print("tapped default")
        }
    }
    
    func placeBlockOnPlaneAt(_ hit: ARHitTestResult) {
        print("placeBlockOnPlaneAt")
        let box = createBox()
        position(node: box, atHit: hit)
        
        sceneView?.scene.rootNode.addChildNode(box)
    }
    
    private func createBox() -> SCNNode {
        print("createBox")
        let box = SCNBox(width: 0.2, height: 0.2, length: 0.08, chamferRadius: 0.02)
        let boxNode = SCNNode(geometry: box)
        boxNode.physicsBody = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(geometry: box, options: nil))
        
        return boxNode
    }
    
    private func position(node: SCNNode, atHit hit: ARHitTestResult) {
        print("position")
        node.transform = SCNMatrix4(hit.anchor!.transform)
        node.eulerAngles = SCNVector3Make(node.eulerAngles.x + (Float.pi / 2), node.eulerAngles.y, node.eulerAngles.z)
        
        let position = SCNVector3Make(hit.worldTransform.columns.3.x + node.geometry!.boundingBox.min.z, hit.worldTransform.columns.3.y, hit.worldTransform.columns.3.z + 0.1)
        node.position = position
    }

    @IBAction func tappedShoot(_ sender: Any) {
        print("tappedShoot")
        let camera = sceneView.session.currentFrame!.camera
        let projectile = Projectile()
        
        // transform to location of camera
        var translation = matrix_float4x4(projectile.transform)
        translation.columns.3.z = -0.1
        translation.columns.3.x = 0.03
        
        projectile.simdTransform = matrix_multiply(camera.transform, translation)
        
        let force = simd_make_float4(-1, 0, -3, 0)
        let rotatedForce = simd_mul(camera.transform, force)
        
        let impulse = SCNVector3(rotatedForce.x, rotatedForce.y, rotatedForce.z)

        sceneView?.scene.rootNode.addChildNode(projectile)
        
        projectile.launch(inDirection: impulse)
    }
    
    @IBAction func tappedShowPlanes(_ sender: Any) {
        print("tappedShowPlanes")
        sceneManager.showPlanes = true
    }
    
    @IBAction func tappedHidePlanes(_ sender: Any) {
        print("tappedHidePlanes")
        sceneManager.showPlanes = false
    }
    
    @IBAction func tappedStop(_ sender: Any) {
        print("tappedStop")
        sceneManager.stopPlaneDetection()
    }
    
    @IBAction func tappedStart(_ sender: Any) {
        print("tappedStart")
        sceneManager.startPlaneDetection()
    }
    
    
    
    
    
    
    //arpaint functions: setting up scene
//    func setupUIControls() {
//        textManager = TextManager(viewController: self)
//
//        // Set appearance of message output panel
//        messagePanel.layer.cornerRadius = 3.0
//        messagePanel.clipsToBounds = true
//        messagePanel.isHidden = true
//        messageLabel.text = ""
//    }
    
//    func setupScene() {
//        virtualObjectManager = VirtualObjectManager()
//
//        // set up scene view
//        sceneView.setup()
//        sceneView.delegate = self
//        sceneView.session = session
//        // sceneView.showsStatistics = true
//
//        sceneView.scene.enableEnvironmentMapWithIntensity(25, queue: serialQueue)
//
//        setupFocusSquare()
//
//        DispatchQueue.main.async {
//            self.screenCenter = self.sceneView.bounds.mid
//        }
//    }
    

        // MARK: Object tracking
    var lastFingerWorldPos: float3?
    var virtualPenTip: PointNode?
    var virtualObjectManager: VirtualObjectManager!
    private var handler = VNSequenceRequestHandler()
    fileprivate var lastObservation: VNDetectedObjectObservation?
    var trackImageBoundingBox: CGRect?
    var trackImageInitialOrigin: CGPoint?
    let trackImageSize = CGFloat(20)
    
    @objc private func tapAction(recognizer: UITapGestureRecognizer) {
        handler = VNSequenceRequestHandler()
        lastObservation = nil
        let tapLocation = recognizer.location(in: view)
        
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
        
    }
    
    //Once object tracking is completed, it will call a callback function in which we will update the thumbnail location. It is typically the inverse of the code written in the tap recognizer:
    fileprivate func handle(_ request: VNRequest, error: Error?) {
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
            
            // Get the projection if the location of the tracked image from image space to the nearest detected plane
            print(self.lastFingerWorldPos)
            if let trackImageOrigin = self.trackImageBoundingBox?.origin {
                (self.lastFingerWorldPos, _, _) = self.virtualObjectManager.worldPositionFromScreenPosition(CGPoint(x: trackImageOrigin.x - 20.0, y: trackImageOrigin.y + 40.0), in: self.sceneView, objectPos: nil, infinitePlane: false)
            }
            
        }
    }
    
    
    
}


class Projectile: SCNNode {
    
    override init() {
        super.init()
        
        let capsule = SCNCapsule(capRadius: 0.006, height: 0.06)
        
        geometry = capsule
        
        eulerAngles = SCNVector3(CGFloat.pi / 2, (CGFloat.pi * 0.25), 0)
        
        physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func launch(inDirection direction: SCNVector3) {
        physicsBody?.applyForce(direction, asImpulse: true)
    }
    
}
