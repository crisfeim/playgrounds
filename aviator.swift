
// aviator-realitykit.swift

// AirplaneRealityKitEntity.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 25/11/25.


import RealityKit
import UIKit

final class AirplaneRealityKitEntity: Entity {
    var propeller: Entity!
    let scaleFactor: Float = 0.25
    
    required init() {
        super.init()
        self.name = "AirPlane"
        self.scale = SIMD3<Float>(repeating: scaleFactor)
        
        createCockpit()
        createEngine()
        createTailPlane()
        createSideWing()
        createPropellerAssembly()
    }
    
    private func createMaterial(color: UIColor) -> RealityKit.Material {
        let material = SimpleMaterial(color: color, isMetallic: false)
        return material
    }
    
    private func createCockpit() {
        let mesh = MeshResource.generateBox(width: 60, height: 50, depth: 50)
        let mat = createMaterial(color: AviatorApp.Colors.red)
        let cockpit = ModelEntity(mesh: mesh, materials: [mat])
        self.addChild(cockpit)
    }
    
    private func createEngine() {
        let mesh = MeshResource.generateBox(width: 20, height: 50, depth: 50)
        let mat = createMaterial(color: AviatorApp.Colors.white)
        let engine = ModelEntity(mesh: mesh, materials: [mat])
        engine.position = [40, 0, 0]
        self.addChild(engine)
    }
    
    private func createTailPlane() {
        let mesh = MeshResource.generateBox(width: 15, height: 20, depth: 5)
        let mat = createMaterial(color: AviatorApp.Colors.red)
        let tailPlane = ModelEntity(mesh: mesh, materials: [mat])
        tailPlane.position = [-35, 25, 0]
        self.addChild(tailPlane)
    }
    
    private func createSideWing() {
        let mesh = MeshResource.generateBox(width: 40, height: 8, depth: 150)
        let mat = createMaterial(color: AviatorApp.Colors.red)
        let sideWing = ModelEntity(mesh: mesh, materials: [mat])
        self.addChild(sideWing)
    }
    
    private func createPropellerAssembly() {
        let propMesh = MeshResource.generateBox(width: 20, height: 10, depth: 10)
        let propMat = createMaterial(color: AviatorApp.Colors.brown)
        propeller = ModelEntity(mesh: propMesh, materials: [propMat])
        propeller.position = [50, 0, 0]
        
        let bladeMesh = MeshResource.generateBox(width: 1, height: 100, depth: 20)
        let bladeMat = createMaterial(color: AviatorApp.Colors.brownDark)
        let blade = ModelEntity(mesh: bladeMesh, materials: [bladeMat])
        blade.position = [0, 0, 0]
        
        propeller.addChild(blade)
        self.addChild(propeller)
    }
}


// AviatorApp_RealityKit.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 25/11/25.


import RealityKit
import SwiftUI

struct AviatorApp_RealityKit: View {
    @State var x: Float = 0.0
    @State var y: Float = 100.0
    @State var z: Float = 200.0
    @State var fieldOfView: Float = 60.0
    let scene = AviatorRealityKitScene()

    var body: some View {
        RealityView { content in
            content.add(scene.rootAnchor)
        }
        .ignoresSafeArea()
        .onChange(of: x, updateCamera)
        .onChange(of: y, updateCamera)
        .onChange(of: z, updateCamera)
        .onChange(of: fieldOfView, updateFieldOfView)
        .overlay(slides)
    }
    
    var slides: some View {
        VStack {
            Slider(value: $x, in: 0...500) {
                Text("x")
            }
            Slider(value: $y, in: 0...500) {
                Text("y")
            }
            Slider(value: $z, in: 0...500) {
                Text("z")
            }
            
            Slider(value: $fieldOfView, in: 0...500) {
                Text("Field of view")
            }
        }
    }
    
    func updateCamera() {
        scene.cameraEntity.position = [x, y, z]
    }
    
    func updateFieldOfView() {
        scene.cameraEntity.camera.fieldOfViewInDegrees = fieldOfView
    }
}


#Preview {
    AviatorApp_RealityKit()
}


// AviatorRealityScene.swift
import RealityKit
import UIKit
import simd

final class AviatorRealityKitScene {
    
    let rootAnchor = AnchorEntity()
    var airPlane = AirplaneRealityKitEntity()
    var sea = Entity()
    var sky = Entity()
    
    var cameraEntity: PerspectiveCamera!
    
    
    init() {
        rootAnchor.name = "RootScene"
        setupScene()
    }
    
    private func setupScene() {
        
        cameraEntity = PerspectiveCamera()
        cameraEntity.camera.fieldOfViewInDegrees = 60
        cameraEntity.position = [0, 100, 200]
        cameraEntity.look(
            at: [0, 0, 0],
            from: cameraEntity.position,
            relativeTo: rootAnchor
        )
        rootAnchor.addChild(cameraEntity)
        
        createLights()
        createSea()
        createSky()
        createPlane()
    }
    
    private func createLights() {
        let shadowLight = DirectionalLight()
        shadowLight.light.intensity = 1500
        shadowLight.light.color = .white
        shadowLight.look(at: [0, 0, 0], from: [150, 350, 350], relativeTo: rootAnchor)
        rootAnchor.addChild(shadowLight)
        
        let ambientLight = PointLight()
        ambientLight.light.intensity = 800
        ambientLight.light.color = AviatorApp.Colors.ambientSky
        ambientLight.position = [0, 200, 0]
        rootAnchor.addChild(ambientLight)
    }
    
    private func createSea() {
        let mesh = MeshResource.generateCylinder(height: 800, radius: 600)
        let material = SimpleMaterial(color: AviatorApp.Colors.blue, isMetallic: false)
        sea = ModelEntity(mesh: mesh, materials: [material])
        sea.orientation = simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])
        sea.position = [0, -600, 0]
        rootAnchor.addChild(sea)
    }
    
    private func createSky() {
        sky = Entity()
        sky.position = [0, -600, 0]
        rootAnchor.addChild(sky)
    }
    
    private func createPlane() {
        airPlane.position = [0, 100, 0]
        rootAnchor.addChild(airPlane)
    }
}


import SwiftUI
#Preview {
    AviatorApp_RealityKit()
}



// aviator-scenekit.swift

// AirPlane.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 25/11/25.

import SceneKit

class AirPlane: SCNNode {
    
    var propeller: SCNNode!
    let scaleFactor: Float = 0.25
    
    override init() {
        super.init()
        self.name = "AirPlane"
        self.scale = SCNVector3(scaleFactor, scaleFactor, scaleFactor)
        
        createCockpit()
        createEngine()
        createTailPlane()
        createSideWing()
        createPropellerAssembly()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func createMaterial(color: UIColor) -> SCNMaterial {
        let material = SCNMaterial()
        material.diffuse.contents = color
        material.lightingModel = .phong // Usar Phong para un look low-poly con sombreado plano (flat shading)
        return material
    }
    
    // El tutorial original modifica los vértices, aquí usaremos una forma simple de caja
    private func createCockpit() {
        let geom = SCNBox(width: 60, height: 50, length: 50, chamferRadius: 0)
        geom.materials = [createMaterial(color: AviatorApp.Colors.red)]
        let cockpit = SCNNode(geometry: geom)
        cockpit.castsShadow = true
        self.addChildNode(cockpit)
    }
    
    private func createEngine() {
        let geom = SCNBox(width: 20, height: 50, length: 50, chamferRadius: 0)
        geom.materials = [createMaterial(color: AviatorApp.Colors.white)]
        let engine = SCNNode(geometry: geom)
        engine.position = SCNVector3(40, 0, 0)
        engine.castsShadow = true
        self.addChildNode(engine)
    }
    
    private func createTailPlane() {
        let geom = SCNBox(width: 15, height: 20, length: 5, chamferRadius: 0)
        geom.materials = [createMaterial(color: AviatorApp.Colors.red)]
        let tailPlane = SCNNode(geometry: geom)
        tailPlane.position = SCNVector3(-35, 25, 0)
        tailPlane.castsShadow = true
        self.addChildNode(tailPlane)
    }
    
    private func createSideWing() {
        let geom = SCNBox(width: 40, height: 8, length: 150, chamferRadius: 0)
        geom.materials = [createMaterial(color: AviatorApp.Colors.red)]
        let sideWing = SCNNode(geometry: geom)
        sideWing.castsShadow = true
        self.addChildNode(sideWing)
    }
    
    private func createPropellerAssembly() {
        let propGeom = SCNBox(width: 20, height: 10, length: 10, chamferRadius: 0)
        propGeom.materials = [createMaterial(color: AviatorApp.Colors.brown)]
        propeller = SCNNode(geometry: propGeom)
        propeller.castsShadow = true
        propeller.position = SCNVector3(50, 0, 0)
        
        // Aspa de la hélice
        let bladeGeom = SCNBox(width: 1, height: 100, length: 20, chamferRadius: 0)
        bladeGeom.materials = [createMaterial(color: AviatorApp.Colors.brownDark)]
        let blade = SCNNode(geometry: bladeGeom)
        blade.castsShadow = true
        // El tutorial original lo posiciona en 8,0,0, aquí lo centralizamos
        blade.position = SCNVector3(0, 0, 0)
        
        propeller.addChildNode(blade)
        self.addChildNode(propeller)
    }
    
    func updatePropeller() {
        propeller.rotation = SCNVector4(1, 0, 0, propeller.rotation.w + 0.3)
    }
}


// AviatorApp.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 22/11/25.

import SceneKit
import SwiftUI

// https://medium.com/@medkalech/getting-started-with-scenekit-in-swiftui-ad4082a27446
// https://developer.apple.com/documentation/realitykit/model3d/
// https://developer.apple.com/documentation/RealityKit/RealityView
struct AviatorApp: View {
    private let scene = AviatorScene()
    private var airPlane: AirPlane { scene.airPlane }
    private var sea: SCNNode { scene.sea }
    private var sky: SCNNode { scene.sky }
    
    @State private var normalizedMousePos = CGPoint.zero
    @State private var viewSize: CGSize = .zero
    
    var body: some View {
        GeometryReader { geometry in
            SceneView(
                scene: scene,
                options: [.autoenablesDefaultLighting]
            )
            .onAppear { viewSize = geometry.size }
            .gesture(dragGesture)
            .onReceive(Timer.publish(every: 1.0/60.0, on: .main, in: .common).autoconnect()) { _ in
                update(time: Date().timeIntervalSince1970)
            }
        }
        .ignoresSafeArea()
    }
    
    var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                
                guard self.viewSize != .zero else { return }
                
                let screenWidth = self.viewSize.width
                let screenHeight = self.viewSize.height
                
                let tx = -1 + (value.location.x / screenWidth) * 2
                let ty = 1 - (value.location.y / screenHeight) * 2
                
                normalizedMousePos = CGPoint(x: tx, y: ty)
            }
    }
}

extension AviatorApp {
    private func normalize(_ v: CGFloat, vmin: CGFloat, vmax: CGFloat, tmin: CGFloat, tmax: CGFloat) -> CGFloat {
        let nv = max(min(v, vmax), vmin)
        let dv = vmax - vmin
        let pc = (nv - vmin) / dv
        let dt = tmax - tmin
        let tv = tmin + (pc * dt)
        return tv
    }
    
    private func update(time: TimeInterval) {
        
        airPlane.updatePropeller()
        sea.rotation = SCNVector4(0, 1, 0, sea.rotation.w + Float(0.005))
        sky.rotation = SCNVector4(0, 1, 0, sky.rotation.w + Float(0.01))
        
        updatePlaneMovement()
    }
    
    private func updatePlaneMovement() {
        let targetX = normalize(normalizedMousePos.x, vmin: -1, vmax: 1, tmin: -100, tmax: 100)
        let targetY = normalize(normalizedMousePos.y, vmin: -1, vmax: 1, tmin: 25, tmax: 175)
        
        let currentX = CGFloat(airPlane.position.x)
        let currentY = CGFloat(airPlane.position.y)
        
        let newX = currentX + (targetX - currentX) * 0.1
        let newY = currentY + (targetY - currentY) * 0.1
        
        let diffY = targetY - currentY
        
        // Rotación suavizada (z e x)
        airPlane.rotation = SCNVector4(0, 0, 1, Float(diffY) * 0.0128)
        
        airPlane.position.x = Float(newX)
        airPlane.position.y = Float(newY)
    }
}

#Preview {
    AviatorApp()
}


// AviatorScene.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 25/11/25.


import SceneKit
import SwiftUI

class AviatorScene: SCNScene {
    
    var airPlane = AirPlane()
    var sea = SCNNode()
    var sky = SCNNode()
    
    override init() {
        super.init()
        setupScene()
    }
    
    private func setupScene() {
        background.contents = AviatorApp.Colors.fogColor
        
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 60
        cameraNode.camera?.zNear = 1
        cameraNode.camera?.zFar = 10000
        cameraNode.position = SCNVector3(0, 100, 200)
        rootNode.addChildNode(cameraNode)
        
        createLights()
        
        createSea()
        createSky()
        createPlane()
    }
    
    private func createLights() {
        // 1. Luz Hemisférica (HemisphereLight)
        // En SceneKit, se usa una luz ambiente con un color para simular el skyColor
        let hemiLight = SCNLight()
        hemiLight.type = .ambient // Tipo ambiente para luz general
        // CORRECCIÓN: Usar 'color' directamente. Se simula el skyColor (0xaaaaaa)
        hemiLight.color = AviatorApp.Colors.ambientSky
        hemiLight.intensity = 900 // Intensidad base del tutorial (0.9) ajustada a SceneKit
        let hemiNode = SCNNode()
        hemiNode.light = hemiLight
        rootNode.addChildNode(hemiNode)
        
        // 2. Luz Direccional (DirectionalLight)
        let shadowLight = SCNLight()
        shadowLight.type = .directional
        shadowLight.color = UIColor.white
        shadowLight.intensity = 1500
        shadowLight.castsShadow = true
        
        let shadowNode = SCNNode()
        shadowNode.light = shadowLight
        shadowNode.position = SCNVector3(150, 350, 350)
        // CORRECCIÓN: Usar SCNVector3(0, 0, 0) o SCNVector3Zero
        shadowNode.look(at: SCNVector3(0, 0, 0))
        rootNode.addChildNode(shadowNode)
        
        // 3. Luz Ambiental Adicional (AmbientLight)
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.color = UIColor(white: 0.5, alpha: 1.0)
        ambientLight.intensity = 500
        let ambientNode = SCNNode()
        ambientNode.light = ambientLight
        rootNode.addChildNode(ambientNode)
    }
    
    private func createSea() {
        let geom = SCNCylinder(radius: 600, height: 800)
        let mat = SCNMaterial()
        mat.diffuse.contents = AviatorApp.Colors.blue
        mat.transparency = 0.8
        mat.lightingModel = .phong
        geom.materials = [mat]
        
        sea = SCNNode(geometry: geom)
        sea.rotation = SCNVector4(1, 0, 0, -Float.pi / 2)
        sea.position = SCNVector3(0, -600, 0)
        rootNode.addChildNode(sea)
    }
    
    private func createSky() {
        sky.position = SCNVector3(0, -600, 0)
        rootNode.addChildNode(sky)
    }
    
    private func createPlane() {
        airPlane.position = SCNVector3(0, 100, 0)
        rootNode.addChildNode(airPlane)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

#Preview {
    SceneView(scene: AviatorScene()).ignoresSafeArea()
}


// Colors.swift
// © 2025  Cristian Felipe Patiño Rojas. Created on 25/11/25.


import UIKit
import SceneKit
import SwiftUI

extension AviatorApp {
    struct Colors {
        static let red = UIColor(red: 0xF2/255.0, green: 0x53/255.0, blue: 0x46/255.0, alpha: 1.0)
        static let white = UIColor(red: 0xD8/255.0, green: 0xD0/255.0, blue: 0xD1/255.0, alpha: 1.0)
        static let brown = UIColor(red: 0x59/255.0, green: 0x33/255.0, blue: 0x2E/255.0, alpha: 1.0)
        static let pink = UIColor(red: 0xF5/255.0, green: 0x98/255.0, blue: 0x6E/255.0, alpha: 1.0)
        static let brownDark = UIColor(red: 0x23/255.0, green: 0x19/255.0, blue: 0x0F/255.0, alpha: 1.0)
        static let blue = UIColor(red: 0x68/255.0, green: 0xC3/255.0, blue: 0xC0/255.0, alpha: 1.0)
        static let ambientSky = UIColor(red: 0xAA/255.0, green: 0xAA/255.0, blue: 0xAA/255.0, alpha: 1.0) // 0xaaaaaa
        static let ambientGround = UIColor(red: 0x00/255.0, green: 0x00/255.0, blue: 0x00/255.0, alpha: 1.0) // 0x000000
        static let fogColor = UIColor(red: 0xF7/255.0, green: 0xD9/255.0, blue: 0xAA/255.0, alpha: 1.0) // 0xf7d9aa
    }
}


