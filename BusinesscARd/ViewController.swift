//
//  ViewController.swift
//  BusinesscARd
//
//  Created by Peter Bødskov on 22/10/2018.
//  Copyright © 2018 Nodes. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import CoreLocation
import MapKit

enum CardOrientation: String {
    case front
    case back
}

class ViewController: UIViewController {

    @IBOutlet var sceneView: ARSCNView!
    var locationManager: CLLocationManager!
    //    56.155146, 10.205094
    let nodesAARLocation = CLLocation(latitude: 56.155146, longitude: 10.205094)
    var currentDistance: CLLocationDistance?
    
    var distanceFormatter: MKDistanceFormatter = {
        var formatter = MKDistanceFormatter()
        return formatter
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupLocation()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
    }
    
    private func setupLocation() {
        locationManager = CLLocationManager()
        locationManager.requestWhenInUseAuthorization()
        
        if CLLocationManager.locationServicesEnabled() {
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
            locationManager.startUpdatingLocation()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARImageTrackingConfiguration()
        
        
        guard let arResources = ARReferenceImage.referenceImages(inGroupNamed: "BusinessCard", bundle: nil) else { return }
        configuration.trackingImages = arResources
        // Run the view's session
        sceneView.session.run(configuration)
//        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
}

extension ViewController: ARSCNViewDelegate {
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard
            let imageAnchor = anchor as? ARImageAnchor,
            let anchorName = anchor.name,
            let cardOrientation = CardOrientation(rawValue: anchorName)
        else { return }
        
        let imageSize = imageAnchor.referenceImage.physicalSize
        
        switch cardOrientation {
        case .front:
            decorateFront(node, imageSize: imageSize)
        case .back:
            decorateBack(node, imageSize: imageSize)
        }
    }
    
    private func decorateFront(_ node: SCNNode, imageSize: CGSize) {
        let geometry = makeGeometry(from: imageSize)
        
        let imageAnimationNode = SCNNode(geometry: geometry)
        imageAnimationNode.eulerAngles.x = -.pi / 2
        imageAnimationNode.opacity = 0.0
        node.addChildNode(imageAnimationNode)
        
        let fadeAction = SCNAction.sequence([
            .fadeOpacity(to: 1.0, duration: 0.1),
            .fadeOpacity(to: 0.0, duration: 0.1),
            .removeFromParentNode()
            ])
        
        
        imageAnimationNode.runAction(fadeAction) {
            let frontSpriteKitScene = SKScene(fileNamed: "Front")
            frontSpriteKitScene?.isPaused = false
            //SCNPlane with sprite kit node as content (yes, a 2d scene attached to a 3d node...there is no spoon!)
            let frontGeometry = SCNPlane(width: imageSize.width, height: imageSize.height)
            frontGeometry.firstMaterial?.diffuse.contents = frontSpriteKitScene
            frontGeometry.firstMaterial?.diffuse.contentsTransform = SCNMatrix4Translate(
                SCNMatrix4MakeScale(1.0, -1.0, 1.0),
                0.0, 1.0, 0.0)
            
            let frontNode = SCNNode(geometry: frontGeometry)
            frontNode.eulerAngles.x = -.pi / 2
            frontNode.position = SCNVector3Zero
            
            node.addChildNode(frontNode)
            
            let frontAction = SCNAction.sequence([
                .move(by: SCNVector3(0.06, 0, 0), duration: 0.2)
                ])
            frontNode.runAction(frontAction) {
                let textNode = frontSpriteKitScene?.childNode(withName: "Text")
                textNode?.run(SKAction.fadeAlpha(to: 1.0, duration: 0.5))
                
                if let imageNode = frontSpriteKitScene?.childNode(withName: "Image") as? SKSpriteNode {
                    let image = UIImage(named: "Jacob")!
                    let texture = SKTexture(image: image)
                    imageNode.texture = texture
                    imageNode.run(SKAction.moveTo(y: 150, duration: 0.5))
                }
            }
        }
    }
    
    private func decorateBack(_ node: SCNNode, imageSize: CGSize) {
        let geometry = makeGeometry(from: imageSize)
        
        let imageAnimationNode = SCNNode(geometry: geometry)
        imageAnimationNode.eulerAngles.x = -.pi / 2
        imageAnimationNode.opacity = 0.0
        node.addChildNode(imageAnimationNode)
        
        let fadeAction = SCNAction.sequence([
            .fadeOpacity(to: 1.0, duration: 0.1),
            .fadeOpacity(to: 0.0, duration: 0.1),
            .removeFromParentNode()
        ])
        
        
        imageAnimationNode.runAction(fadeAction) { [weak self] in
            guard let strongSelf = self else { return }
            guard let currentDistance = strongSelf.currentDistance else { return }
            //Load SpriteKit scene, add it to  new SCNNode and add that node to the "back" node
            let spriteKitBackScene = SKScene(fileNamed: "Back")
            spriteKitBackScene?.isPaused = false
            
            let backGeometry = SCNPlane(width: imageSize.width, height: imageSize.height)
            backGeometry.firstMaterial?.diffuse.contents = spriteKitBackScene
            backGeometry.firstMaterial?.diffuse.contentsTransform = SCNMatrix4Translate(
                SCNMatrix4MakeScale(1.0, -1.0, 1.0),
                0.0, 1.0, 0.0)
            
            let backNode = SCNNode(geometry: backGeometry)
            backNode.eulerAngles.x = -.pi / 2
            backNode.position = SCNVector3Zero
            
            node.addChildNode(backNode)
            
            if let distanceNode = spriteKitBackScene?.childNode(withName: "Distance") as? SKLabelNode {
                let distanceString = strongSelf.distanceFormatter.string(fromDistance: currentDistance)
                distanceNode.text = distanceString
            }
        }
    }
    
    private func makeGeometry(from size: CGSize) -> SCNPlane {
        let plane = SCNPlane(width: size.width, height: size.height)
        plane.firstMaterial?.diffuse.contentsTransform = SCNMatrix4Translate(
            SCNMatrix4MakeScale(1.0, -1.0, 1.0),
            0.0, 1.0, 0.0)
        return plane
    }
}

extension ViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentDistance = manager.location?.distance(from: nodesAARLocation)
    }
}
