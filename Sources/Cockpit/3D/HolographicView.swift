import SwiftUI
import RealityKit
import SceneKit

// MARK: - Holographic Reality Background

/// Live RealityKit 3D scene — wireframe hex-core, data streams, energy wisps,
/// orbiting elements, particle fields, and pulse waves.
/// Sits behind glass cards in the Overview tab.
struct HolographicRealityBackground: View {
    let rotation: CGPoint
    let isVisible: Bool

    var body: some View {
        if isVisible {
            ZStack {
                RealityView { content in
                    let scene = buildHolographicScene()
                    content.add(scene)
                } update: { content in
                    if let root = content.entities.first {
                        let target = simd_quatf(
                            from: [0, 1, 0],
                            to: simd_normalize([
                                Float(rotation.x) * 0.3,
                                Float(rotation.y) * 0.3,
                                1.0
                            ])
                        )
                        root.transform.rotation = simd_slerp(
                            root.transform.rotation,
                            target,
                            0.05
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)

                SceneKitParticleField()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)
                    .opacity(0.4)

                HolographicGrid()
                    .opacity(0.15)
                    .allowsHitTesting(false)
            }
            .ignoresSafeArea()
        } else {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.01, green: 0.015, blue: 0.03),
                        Color(red: 0.02, green: 0.02, blue: 0.06),
                        Color.black
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                HolographicGrid()
                    .opacity(0.18)
                    .ignoresSafeArea()
            }
        }
    }

    @MainActor
    private func buildHolographicScene() -> Entity {
        let root = Entity()
        root.name = "HolographicScene"

        // ── CENTRAL WIREFRAME HEX-CORE ──────────────────────────
        buildWireframeHexCore(parent: root)

        // ── ORBITING RINGS (3 axes) ──────────────────────────────
        buildRing(parent: root, radius: 0.38, yOffset: 0.0,
                  rotation: simd_quatf(angle: 0, axis: [0, 1, 0]),
                  name: "OrbitRingX", color: .cyan, thickness: 0.004)
        buildRing(parent: root, radius: 0.38, yOffset: 0.0,
                  rotation: simd_quatf(angle: .pi / 3, axis: [1, 0, 0]),
                  name: "OrbitRingY", color: .blue, thickness: 0.003)
        buildRing(parent: root, radius: 0.38, yOffset: 0.0,
                  rotation: simd_quatf(angle: .pi / 3, axis: [0, 0, 1]),
                  name: "OrbitRingZ", color: .purple, thickness: 0.003)

        // Outer elliptical ring
        buildRing(parent: root, radius: 0.55, yOffset: -0.05,
                  rotation: simd_quatf(angle: .pi / 6, axis: [0.5, 1, 0]),
                  name: "OuterEllipse", color: .cyan, thickness: 0.002)

        // ── ORBITING DATA NODES ──────────────────────────────────
        let nodeCount = 8
        for i in 0..<nodeCount {
            let angle = Float(i) * (2 * .pi / Float(nodeCount))
            let r: Float = 0.50
            let node = ModelEntity(
                mesh: .generateSphere(radius: 0.015),
                materials: [UnlitMaterial(color: .cyan.withAlphaComponent(0.8))]
            )
            node.position = [r * cos(angle), 0.0, r * sin(angle)]
            node.name = "DataNode\(i)"
            root.addChild(node)
        }

        // ── SECONDARY ORBIT RING (counter-rotating) ──────────────
        buildRing(parent: root, radius: 0.62, yOffset: 0.02,
                  rotation: simd_quatf(angle: .pi / 4, axis: [0.3, 0.7, 0.3]),
                  name: "CounterRing", color: .cyan, thickness: 0.002)

        // ── ENERGY WISP TRAILS ───────────────────────────────────
        for t in 0..<3 {
            let wisp = buildEnergyWisp(index: t)
            wisp.name = "EnergyWisp\(t)"
            root.addChild(wisp)
        }

        // ── GROUND GRID PLATFORM (perspective) ──────────────────
        buildPerspectiveGrid(parent: root)

        // ── PULSE WAVE RINGS ─────────────────────────────────────
        for p in 0..<4 {
            let pulse = buildPulseRing(index: p)
            pulse.name = "PulseRing\(p)"
            root.addChild(pulse)
        }

        // ── LIGHTING ─────────────────────────────────────────────
        let keyLight = DirectionalLight()
        keyLight.light.intensity = 1800
        keyLight.light.color = .cyan
        keyLight.position = [1.5, 2, 2]
        root.addChild(keyLight)

        let orbLight = PointLight()
        orbLight.light.intensity = 4000
        orbLight.light.color = .cyan
        orbLight.light.attenuationRadius = 3.0
        orbLight.position = [0, 0, 0]
        root.addChild(orbLight)

        let fillLight = DirectionalLight()
        fillLight.light.intensity = 500
        fillLight.light.color = .purple
        fillLight.position = [-1, 0, -1]
        root.addChild(fillLight)

        let rimLight = DirectionalLight()
        rimLight.light.intensity = 300
        rimLight.light.color = .blue
        rimLight.position = [0, -0.5, 2]
        root.addChild(rimLight)

        // ── PARTICLE EMITTER ─────────────────────────────────────
        var emitter = ParticleEmitterComponent()
        emitter.emitterShape = .box
        emitter.emitterShapeSize = [4, 0.3, 4]
        emitter.mainEmitter.birthRate = 80
        emitter.mainEmitter.lifeSpan = 10
        emitter.mainEmitter.lifeSpanVariation = 4
        emitter.mainEmitter.color = .constant(.single(.cyan.withAlphaComponent(0.45)))
        emitter.mainEmitter.size = 0.005
        emitter.speed = 0.08
        emitter.speedVariation = 0.04

        let particleEntity = Entity()
        particleEntity.position = [0, -0.3, 0]
        particleEntity.name = "ParticleEmitter"
        particleEntity.components.set(emitter)
        root.addChild(particleEntity)

        // ── ANIMATION SYSTEM ─────────────────────────────────────
        root.components.set(RealityKitAnimationComponent())

        return root
    }

    // MARK: - Wireframe Hex-Core

    private func buildWireframeHexCore(parent: Entity) {
        let mat = UnlitMaterial(color: .cyan.withAlphaComponent(0.7))
        let coreMat = UnlitMaterial(color: .cyan)

        // Build a double-tetrahedron wireframe (stellated octahedron look)
        struct Edge { let a: SIMD3<Float>; let b: SIMD3<Float> }

        let s: Float = 0.18
        // Vertices of an octahedron
        let top:    SIMD3<Float> = [0, s, 0]
        let bottom: SIMD3<Float> = [0, -s, 0]
        let front:  SIMD3<Float> = [0, 0, s]
        let back:   SIMD3<Float> = [0, 0, -s]
        let left:   SIMD3<Float> = [-s, 0, 0]
        let right:  SIMD3<Float> = [s, 0, 0]

        // Additional vertices for dodecahedral complexity
        let phi: Float = 1.618034
        let r: Float = s * 0.72
        let v: [SIMD3<Float>] = [
            SIMD3(r, 0, r * phi).normalized * s,
            SIMD3(-r, 0, r * phi).normalized * s,
            SIMD3(r, 0, -r * phi).normalized * s,
            SIMD3(-r, 0, -r * phi).normalized * s,
            SIMD3(r * phi, r, 0).normalized * s,
            SIMD3(-r * phi, r, 0).normalized * s,
            SIMD3(r * phi, -r, 0).normalized * s,
            SIMD3(-r * phi, -r, 0).normalized * s,
            SIMD3(0, r * phi, r).normalized * s,
            SIMD3(0, -r * phi, r).normalized * s,
            SIMD3(0, r * phi, -r).normalized * s,
            SIMD3(0, -r * phi, -r).normalized * s
        ]

        // Build icosahedral edges (simplified)
        let edges: [Edge] = [
            Edge(a: top, b: right), Edge(a: top, b: left),
            Edge(a: top, b: front), Edge(a: top, b: back),
            Edge(a: bottom, b: right), Edge(a: bottom, b: left),
            Edge(a: bottom, b: front), Edge(a: bottom, b: back),
            Edge(a: right, b: front), Edge(a: right, b: back),
            Edge(a: left, b: front), Edge(a: left, b: back),
            // Additional dodecahedral edges
            Edge(a: v[0], b: v[1]), Edge(a: v[0], b: v[4]),
            Edge(a: v[1], b: v[5]), Edge(a: v[4], b: v[5]),
            Edge(a: v[2], b: v[3]), Edge(a: v[2], b: v[6]),
            Edge(a: v[3], b: v[7]), Edge(a: v[6], b: v[7]),
            Edge(a: v[8], b: v[0]), Edge(a: v[8], b: v[4]),
            Edge(a: v[9], b: v[0]), Edge(a: v[9], b: v[6]),
            Edge(a: v[10], b: v[2]), Edge(a: v[10], b: v[5]),
            Edge(a: v[11], b: v[3]), Edge(a: v[11], b: v[7]),
        ]

        for edge in edges {
            let mid = (edge.a + edge.b) / 2
            let dir = edge.b - edge.a
            let length = simd_length(dir)
            let dirNorm = dir / length

            let segment = ModelEntity(
                mesh: .generateBox(size: [0.004, 0.004, length]),
                materials: [mat]
            )
            segment.position = mid

            // Orient the box to point from a → b
            let defaultDir = SIMD3<Float>(0, 0, 1)
            let rotationQuat = simd_quatf(from: defaultDir, to: dirNorm)
            segment.transform.rotation = rotationQuat

            segment.name = "WireEdge"
            parent.addChild(segment)
        }

        // Central glowing core
        let coreOrb = ModelEntity(
            mesh: .generateSphere(radius: 0.04),
            materials: [coreMat]
        )
        coreOrb.position = [0, 0, 0]
        coreOrb.name = "CentralOrb"
        parent.addChild(coreOrb)

        // Inner glow halo
        let haloMesh = MeshResource.generatePlane(width: 0.25, depth: 0.25)
        var haloMat = UnlitMaterial(color: .cyan.withAlphaComponent(0.12))
        haloMat.blending = .transparent(opacity: .init(floatLiteral: 0.12))
        let halo = ModelEntity(mesh: haloMesh, materials: [haloMat])
        halo.position = [0, 0, 0.001]
        halo.name = "CoreHalo"
        parent.addChild(halo)
    }

    // MARK: - Energy Wisps

    private func buildEnergyWisp(index: Int) -> Entity {
        let container = Entity()
        let segmentCount = 20
        let baseAngle = Float(index) * (2 * .pi / 3)

        for s in 0..<segmentCount {
            let t = Float(s) / Float(segmentCount - 1)
            let angle = baseAngle + t * .pi * 2
            let r: Float = 0.35 + sin(t * .pi * 3) * 0.15
            let y = (t - 0.5) * 0.5

            let segment = ModelEntity(
                mesh: .generateSphere(radius: 0.006 * (1 - t * 0.7)),
                materials: [UnlitMaterial(color: .cyan.withAlphaComponent(CGFloat(1 - t * 0.8)))]
            )
            segment.position = [r * cos(angle), y, r * sin(angle)]
            segment.name = "WispSeg\(s)"
            container.addChild(segment)
        }

        return container
    }

    // MARK: - Pulse Rings

    private func buildPulseRing(index: Int) -> Entity {
        let ring = ModelEntity(
            mesh: .generateTorus(ringRadius: 0.30, tubeRadius: 0.002),
            materials: [UnlitMaterial(color: .cyan.withAlphaComponent(0.0))]
        )
        ring.position = [0, 0, 0]
        ring.transform.rotation = simd_quatf(
            angle: Float(index) * .pi / 4,
            axis: simd_normalize([Float(index % 2), Float((index + 1) % 2), 0])
        )
        ring.name = "PulseBase\(index)"
        return ring
    }

    // MARK: - Perspective Grid Floor

    private func buildPerspectiveGrid(parent: Entity) {
        let gridSize: Float = 2.8
        let lineCount = 24
        let gridMat = UnlitMaterial(color: .cyan.withAlphaComponent(0.10))
        let thickMat = UnlitMaterial(color: .cyan.withAlphaComponent(0.18))
        let lineThickness: Float = 0.0015

        for i in 0...lineCount {
            let t = (Float(i) / Float(lineCount) - 0.5) * gridSize
            let isCenter = abs(t) < 0.1

            // Z-lines (receding into depth)
            let hLine = ModelEntity(
                mesh: .generateBox(size: [gridSize * 0.9, 0.0005, lineThickness * 1.5]),
                materials: [isCenter ? thickMat : gridMat]
            )
            hLine.position = [0, -0.6, t]
            parent.addChild(hLine)

            // X-lines
            let vLine = ModelEntity(
                mesh: .generateBox(size: [lineThickness * 1.5, 0.0005, gridSize * 0.9]),
                materials: [isCenter ? thickMat : gridMat]
            )
            vLine.position = [t, -0.6, 0]
            parent.addChild(vLine)
        }
    }

    // MARK: - Ring Builder

    private func buildRing(parent: Entity, radius: Float, yOffset: Float,
                           rotation: simd_quatf, name: String,
                           color: NSColor = .cyan, thickness: Float = 0.003) {
        let ringMat = UnlitMaterial(color: color.withAlphaComponent(0.5))
        let segmentCount = 48
        let segmentLength = 2 * .pi * radius / Float(segmentCount)

        let container = Entity()
        container.name = name
        container.transform.rotation = rotation

        for i in 0..<segmentCount {
            let angle = Float(i) * (2 * .pi / Float(segmentCount))
            let segment = ModelEntity(
                mesh: .generateBox(size: [segmentLength, thickness, thickness]),
                materials: [ringMat]
            )
            segment.position = [
                radius * cos(angle),
                yOffset,
                radius * sin(angle)
            ]
            segment.transform.rotation = simd_quatf(angle: angle + .pi / 2, axis: [0, 1, 0])
            container.addChild(segment)
        }

        parent.addChild(container)
    }
}

// MARK: - Mesh Helpers

extension MeshResource {
    /// Generate a torus (ring) mesh
    static func generateTorus(ringRadius: Float, tubeRadius: Float, segments: Int = 64) -> MeshResource {
        var desc = MeshDescriptor(name: "torus")
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var indices: [UInt32] = []

        for i in 0..<segments {
            let phi = Float(i) * 2 * .pi / Float(segments)
            let cosPhi = cos(phi)
            let sinPhi = sin(phi)

            for j in 0..<segments {
                let theta = Float(j) * 2 * .pi / Float(segments)
                let cosTheta = cos(theta)
                let sinTheta = sin(theta)

                let x = (ringRadius + tubeRadius * cosTheta) * cosPhi
                let y = tubeRadius * sinTheta
                let z = (ringRadius + tubeRadius * cosTheta) * sinPhi

                positions.append([x, y, z])

                let nx = cosTheta * cosPhi
                let ny = sinTheta
                let nz = cosTheta * sinPhi
                normals.append(simd_normalize([nx, ny, nz]))
            }
        }

        for i in 0..<segments {
            for j in 0..<segments {
                let a = UInt32(i * segments + j)
                let b = UInt32(((i + 1) % segments) * segments + j)
                let c = UInt32(i * segments + (j + 1) % segments)
                let d = UInt32(((i + 1) % segments) * segments + (j + 1) % segments)

                indices.append(contentsOf: [a, b, c, b, d, c])
            }
        }

        desc.positions = MeshBuffers.Positions(positions)
        desc.normals = MeshBuffers.Normals(normals)
        desc.primitives = .triangles(indices)

        return try! MeshResource.generate(from: [desc])
    }
}

// MARK: - Per-Frame Animation Component

struct RealityKitAnimationComponent: Component {
    var elapsed: Float = 0
}

struct RealityKitAnimationSystem: System {
    static let query = EntityQuery(where: .has(RealityKitAnimationComponent.self))

    init(scene: RealityKit.Scene) {}

    func update(context: SceneUpdateContext) {
        let delta = Float(context.deltaTime)
        for entity in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
            guard var anim = entity.components[RealityKitAnimationComponent.self] else { continue }
            anim.elapsed += delta

            // Rotate orbital rings
            let ringSpeeds: [(String, Float, SIMD3<Float>)] = [
                ("OrbitRingX", 0.45, [0, 1, 0]),
                ("OrbitRingY", -0.35, [1, 0, 0]),
                ("OrbitRingZ", 0.30, [0, 0, 1]),
                ("OuterEllipse", -0.25, [0.3, 0.7, 0.3]),
                ("CounterRing", 0.55, [0.2, 0.6, 0.2]),
            ]

            for (name, speed, axis) in ringSpeeds {
                if let ring = entity.findEntity(named: name) {
                    ring.transform.rotation *= simd_quatf(angle: delta * speed, axis: axis)
                }
            }

            // Orbit data nodes
            for i in 0..<8 {
                if let node = entity.findEntity(named: "DataNode\(i)") {
                    let baseAngle = Float(i) * (2 * .pi / 8)
                    let currentAngle = baseAngle + anim.elapsed * 0.35
                    let r: Float = 0.50 + sin(anim.elapsed * 1.5 + Float(i)) * 0.04
                    node.position.x = r * cos(currentAngle)
                    node.position.z = r * sin(currentAngle)
                    node.position.y = sin(anim.elapsed * 2.0 + Float(i)) * 0.06
                }
            }

            // Pulse the central core
            if let orb = entity.findEntity(named: "CentralOrb") {
                let s = 1.0 + sin(anim.elapsed * 1.8) * 0.12
                orb.scale = [s, s, s]
            }

            // Rotate core halo
            if let halo = entity.findEntity(named: "CoreHalo") {
                halo.transform.rotation = simd_quatf(
                    angle: anim.elapsed * 0.6,
                    axis: [0, 1, 0]
                )
                let haloAlpha = 0.08 + sin(anim.elapsed * 2.0) * 0.04
                if var mat = halo.components[ModelComponent.self]?.materials.first as? UnlitMaterial {
                    mat.color = .init(tint: .cyan.withAlphaComponent(CGFloat(haloAlpha)))
                    halo.components[ModelComponent.self]?.materials = [mat]
                }
            }

            // Animate wireframe edges (subtle glow pulse)
            let wireGlow = 0.5 + sin(anim.elapsed * 2.5) * 0.2
            for child in entity.children {
                if child.name == "WireEdge" {
                    if var mat = child.components[ModelComponent.self]?.materials.first as? UnlitMaterial {
                        mat.color = .init(tint: .cyan.withAlphaComponent(CGFloat(wireGlow)))
                        child.components[ModelComponent.self]?.materials = [mat]
                        break // Just update one to pulse the whole set together via scale
                    }
                }
            }

            // Animate energy wisps
            for t in 0..<3 {
                if let wisp = entity.findEntity(named: "EnergyWisp\(t)") {
                    wisp.transform.rotation = simd_quatf(
                        angle: anim.elapsed * (0.3 + Float(t) * 0.15),
                        axis: simd_normalize([Float(t % 2), Float((t + 1) % 2), 0.3])
                    )
                    // Pulsing opacity via scale
                    let wispPulse = 0.9 + sin(anim.elapsed * 3.0 + Float(t)) * 0.1
                    wisp.scale = [wispPulse, wispPulse, wispPulse]
                }
            }

            // Animate pulse rings (expand and fade)
            for p in 0..<4 {
                if let ring = entity.findEntity(named: "PulseRing\(p)") {
                    let phase = (anim.elapsed * 0.6 + Float(p) * 0.25).truncatingRemainder(dividingBy: 2.4)
                    let progress = phase / 2.4 // 0 → 1 over the cycle
                    let expandScale: Float = 0.4 + progress * 2.5
                    ring.scale = [expandScale, expandScale, expandScale]

                    let alpha = CGFloat(max(0, 1.0 - progress) * 0.25)
                    if var mat = ring.components[ModelComponent.self]?.materials.first as? UnlitMaterial {
                        mat.color = .init(tint: .cyan.withAlphaComponent(alpha))
                        ring.components[ModelComponent.self]?.materials = [mat]
                    }
                }
            }

            entity.components[RealityKitAnimationComponent.self] = anim
        }
    }
}

// MARK: - SIMD Extensions

extension SIMD3 where Scalar == Float {
    var normalized: SIMD3<Float> {
        let len = simd_length(self)
        return len > 0 ? self / len : self
    }
}

// MARK: - SceneKit Particle Field (NSViewRepresentable)

struct SceneKitParticleField: NSViewRepresentable {
    func makeNSView(context: Context) -> SCNView {
        let sceneView = SCNView()
        sceneView.scene = buildParticleScene()
        sceneView.backgroundColor = .clear
        sceneView.antialiasingMode = .multisampling4X
        sceneView.rendersContinuously = true
        sceneView.setValue(false, forKey: "acceptsTouchEvents")
        return sceneView
    }

    func updateNSView(_ nsView: SCNView, context: Context) {}

    private func buildParticleScene() -> SCNScene {
        let scene = SCNScene()

        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(0, 0.5, 3)
        scene.rootNode.addChildNode(cameraNode)

        // Primary rising particle system
        let ps = SCNParticleSystem()
        ps.birthRate = 150
        ps.birthRateVariation = 40
        ps.emissionDuration = .greatestFiniteMagnitude
        ps.loops = true

        ps.emitterShape = SCNBox(width: 5, height: 0.01, length: 5, chamferRadius: 0)
        ps.birthLocation = .surface
        ps.birthDirection = .surfaceNormal

        ps.emittingDirection = SCNVector3(0, 1, 0)
        ps.spreadingAngle = 35

        ps.particleLifeSpan = 12
        ps.particleLifeSpanVariation = 5

        ps.particleVelocity = 0.25
        ps.particleVelocityVariation = 0.12

        ps.particleSize = 0.005
        ps.particleSizeVariation = 0.004
        ps.particleColor = NSColor.cyan.withAlphaComponent(0.5)

        let colorAnim = CAKeyframeAnimation(keyPath: "color")
        colorAnim.values = [
            NSColor.cyan.withAlphaComponent(0.0).cgColor,
            NSColor.cyan.withAlphaComponent(0.7).cgColor,
            NSColor(red: 0.3, green: 0.5, blue: 1.0, alpha: 0.4).cgColor,
            NSColor.purple.withAlphaComponent(0.0).cgColor
        ]
        colorAnim.keyTimes = [0, 0.25, 0.6, 1.0]
        colorAnim.duration = 12

        ps.propertyControllers = [
            .color: SCNParticlePropertyController(animation: colorAnim)
        ]

        ps.blendMode = .additive
        ps.isBlackPassEnabled = false
        ps.isLightingEnabled = false
        ps.sortingMode = .none

        let particleNode = SCNNode()
        particleNode.addParticleSystem(ps)
        particleNode.position = SCNVector3(0, -0.6, 0)
        scene.rootNode.addChildNode(particleNode)

        // Secondary floating particle system (higher, sparser)
        let floatPS = SCNParticleSystem()
        floatPS.birthRate = 40
        floatPS.birthRateVariation = 15
        floatPS.emissionDuration = .greatestFiniteMagnitude
        floatPS.loops = true

        floatPS.emitterShape = SCNSphere(radius: 1.5)
        floatPS.birthLocation = .volume
        floatPS.birthDirection = .random

        floatPS.particleLifeSpan = 8
        floatPS.particleLifeSpanVariation = 3
        floatPS.particleVelocity = 0.08
        floatPS.particleVelocityVariation = 0.04
        floatPS.particleSize = 0.003
        floatPS.particleSizeVariation = 0.002
        floatPS.particleColor = NSColor.cyan.withAlphaComponent(0.3)

        let floatColorAnim = CAKeyframeAnimation(keyPath: "color")
        floatColorAnim.values = [
            NSColor.cyan.withAlphaComponent(0.0).cgColor,
            NSColor.cyan.withAlphaComponent(0.4).cgColor,
            NSColor.cyan.withAlphaComponent(0.0).cgColor
        ]
        floatColorAnim.keyTimes = [0, 0.5, 1.0]
        floatColorAnim.duration = 8

        floatPS.propertyControllers = [
            .color: SCNParticlePropertyController(animation: floatColorAnim)
        ]
        floatPS.blendMode = .additive
        floatPS.isBlackPassEnabled = false
        floatPS.isLightingEnabled = false

        let floatNode = SCNNode()
        floatNode.addParticleSystem(floatPS)
        floatNode.position = SCNVector3(0, 0.1, 0)
        scene.rootNode.addChildNode(floatNode)

        return scene
    }
}

// MARK: - Holographic Grid (SwiftUI Canvas with scanning line)

struct HolographicGrid: View {
    @State private var scanOffset: CGFloat = -100
    let scanTimer = Timer.publish(every: 0.04, on: .main, in: .common).autoconnect()

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let spacing: CGFloat = 40
                let date = timeline.date.timeIntervalSinceReferenceDate
                let scanY = size.height * 0.5 + sin(date * 0.3) * size.height * 0.3

                // Grid lines
                var path = Path()
                var x: CGFloat = 0
                while x <= size.width {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                    x += spacing
                }
                var y: CGFloat = 0
                while y <= size.height {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    y += spacing
                }
                context.stroke(path, with: .color(.cyan.opacity(0.10)), lineWidth: 0.5)

                // Scanning line
                let scanRect = CGRect(x: 0, y: scanY, width: size.width, height: 3)
                context.fill(
                    Path(scanRect),
                    with: .color(.cyan.opacity(0.08))
                )
                context.fill(
                    Path(CGRect(x: 0, y: scanY + 1, width: size.width, height: 1)),
                    with: .color(.cyan.opacity(0.15))
                )
            }
        }
    }
}

// MARK: - Legacy Compatibility

struct HolographicBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.01, green: 0.015, blue: 0.03),
                    Color(red: 0.02, green: 0.02, blue: 0.06),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [Color.cyan.opacity(0.20), Color.clear],
                center: .topLeading,
                startRadius: 10,
                endRadius: 520
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [Color.purple.opacity(0.14), Color.clear],
                center: .bottomTrailing,
                startRadius: 10,
                endRadius: 620
            )
            .ignoresSafeArea()

            HolographicGrid()
                .opacity(0.28)
                .ignoresSafeArea()
        }
    }
}

struct HolographicView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            RealityView { content in
                let platform = ModelEntity(
                    mesh: .generateCylinder(height: 0.02, radius: 0.8),
                    materials: [SimpleMaterial(color: .cyan.withAlphaComponent(0.3), isMetallic: true)]
                )
                platform.position = [0, -0.3, 0]
                content.add(platform)

                let orb = ModelEntity(
                    mesh: .generateSphere(radius: 0.15),
                    materials: [SimpleMaterial(color: .white.withAlphaComponent(0.8), isMetallic: false)]
                )
                orb.position = [0, 0.1, 0]
                content.add(orb)

                let light = DirectionalLight()
                light.light.intensity = 2000
                light.light.color = .cyan
                light.position = [0, 2, 2]
                content.add(light)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}