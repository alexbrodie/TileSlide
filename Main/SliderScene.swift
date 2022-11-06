//
//  SliderScene.swift
//  TileSlide
//
//  Created by Alexander Brodie on 4/23/19.
//  Copyright © 2019 Alex Brodie. All rights reserved.
//

import Combine
import CoreMotion
import GameplayKit
import SpriteKit
import SwiftUI

class SliderScene: SKScene, ObservableObject, BoardNodeDelegate {
    
    private func lerp(from: Double, to: Double, ratio: Double) -> Double {
        return (from * (1 - ratio)) + (to * ratio)
    }
    
    @ObservedObject var settings = SliderSettings() {
        didSet { onSettingsReplaced() }
    }

    // Last time that tilting the device slid a tile
    private var lastTiltShift: Date = Date()
    // Object to fetch accelerometer/gyro data
    private var motionManager: CMMotionManager? = nil
    // The current board
    private var currentBoard: BoardNode? = nil
    // Place to show text for debugging
    private var debugText: SKLabelNode? = nil
    
    //MARK: - Initialization
    
    override init() {
        super.init(size: CGSize(width: 0, height: 0))
        backgroundColor = .black
        scaleMode = .resizeFill
        onSettingsReplaced()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    //MARK: - SKScene
    
    override func didMove(to view: SKView) {
        //setEnableTiltToSlide(true)
        //makeDebugText()
        newBoard()
    }
    
    override func update(_ currentTime: TimeInterval) {
        let tiltDelay = 0.5
        let pitchOffset = -0.75
        let tiltThreshold = 0.25

        if settings.enableTiltToSlide {
            if let data = motionManager!.deviceMotion, let board = currentBoard {
                // Wait this long between processing tilt slides
                let now = Date()
                if lastTiltShift + tiltDelay < now {
                    let yaw = data.attitude.yaw
                    let pitch = data.attitude.pitch + pitchOffset
                    let roll = data.attitude.roll
                    debugText?.text = String(format: "Y = %.02f P = %.02f R = %.02f", yaw, pitch, roll)
                    
                    var slid = false
                   
                    // Only process one direction whichever is greatest
                    if abs(pitch) > abs(roll) {
                        if pitch < -tiltThreshold {
                            // Negative pitch == tilt forward
                            slid = board.slideUp()
                        } else if pitch > tiltThreshold {
                            // Positive pitch == tilt backward
                            slid = board.slideDown()
                        }
                    }
                    
                    if !slid {
                        if roll < -tiltThreshold {
                            // Negative roll == tilt left
                            slid = board.slideLeft()
                        } else if roll > tiltThreshold {
                            // Positive roll == tilt right
                            slid = board.slideRight()
                        }
                    }
                    
                    if slid {
                        lastTiltShift = now
                    }
                }
            }
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches {
            _ = handleTouch(atPoint(t.location(in: self)))
        }
    }
    
    private func handleTouch(_ node: SKNode) -> Bool {
        // First chance processing - this happens on the descendants first, i.e. the bubble phase
        if let tile = node as? TileNode {
            // Move the tile the touch was in
            if tile.slide() {
                return true
            }
        }
        
        // Let parents try
        if let parent = node.parent {
            if handleTouch(parent) {
                return true
            }
        }
        
        // Fallback handling - this happens on ancestors first, i.e. the routing phase
        if let tile = node as? TileNode {
            subShuffleTile(tile)
            return true
        }
        
        return false
    }
    
    // Called when the settings property is set so that we can
    // reset sinks for our manual bindings
    private func onSettingsReplaced() {
        enumerateChildNodes(withName: BoardNode.nodeName) { (board, stop) in
            (board as! BoardNode).settings = self.settings
        }
    }
    
    private func setEnableTiltToSlide(_ enable: Bool) {
        settings.enableTiltToSlide = enable
        if enable {
            startDeviceMotionUpdates()
        } else {
            stopDeviceMotionUpdates()
        }
    }
    
    private func startDeviceMotionUpdates() {
        if motionManager == nil {
            motionManager = CMMotionManager()
        }
        if motionManager!.isDeviceMotionAvailable {
            motionManager!.startDeviceMotionUpdates(using: .xMagneticNorthZVertical)
        }
    }
    
    private func stopDeviceMotionUpdates() {
        motionManager?.stopDeviceMotionUpdates()
    }
    
    private func makeDebugText() {
        let size = CGSize(width: frame.width, height: frame.height * 0.03)
        
        let label = SKLabelNode(text: "Debug\nText")
        label.fontSize = size.height * 0.75
        label.horizontalAlignmentMode = .left
        label.verticalAlignmentMode = .center
        label.fontColor = .black
        label.position = CGPoint(x: size.width * -0.45, y: 0)
        
        let parent = SKSpriteNode(color: UIColor(red: 1, green: 1, blue: 1, alpha: 0.5), size: size)
        parent.position = CGPoint(x: 0, y: frame.minY + size.height)
        parent.zPosition = 1000
        
        parent.addChild(label)
        addChild(parent)
        
        debugText = label
    }
    
    //MARK: - Board management
    
    public func newBoard() {
        cleanupBoard()

        // Pick a board and config magic numbers
        let textureName = String(format: "Doguillo-%d", Int.random(in: 1...19))
        let model = SliderBoard(columns: 3, rows: 3, emptyOrdinal: 8)

        // Construct board from the asset name and model definition
        let texture = SKTexture(imageNamed: textureName)
        let rect = frame.middleWithAspect(texture.size().aspect)
        let board = BoardNode(settings: settings, model: model, texture: texture, rect: rect)
        board.shuffle()
        
//        var subBoard = board;
//        for i in stride(from: 3, to: 1, by: -1) {
//            let subModel = SliderBoard(columns: columns, rows: rows, emptyOrdinal: emptyOrdinal)
//            subBoard = subBoard.tiles[i].createSubBoard(model: subModel)
//            subBoard.shuffle()
//        }

        addChild(board)
        board.revealTiles()
        setCurrentBoard(board)
    }
    
    private func cleanupBoard() {
        enumerateChildNodes(withName: BoardNode.nodeName) { (board, stop) in
            (board as! BoardNode).cleanup()
        }
        setCurrentBoard(nil)
    }
    
    private func setCurrentBoard(_ board: BoardNode?) {
        currentBoard = board
    }
    
    // Turns a tile into a sub-board if it's not already and then shuffles it
    private func subShuffleTile(_ tile: TileNode) {
        var subBoard = tile.childBoard
        if subBoard == nil {
            let parentModel = tile.parentBoard.model
            let model = SliderBoard(columns: parentModel.columns,
                                    rows: parentModel.rows,
                                    emptyOrdinal: tile.ordinal)
            subBoard = tile.createChildBoard(model: model)
        }
        setCurrentBoard(subBoard)
        subBoard!.shuffle(3)
    }
    
    //MARK: - BoardNodeDelegate
    
    // Called when the board enters the solved state
    func boardSolved(_ board: BoardNode) {
        let rootBoard: BoardNode = board.lastAncestorOfType()!
        if rootBoard.isRecursivelySolved() {
            for _ in 0...17 {
                run(.wait(forDuration: Double.random(in: 0...1))) {
                    self.firework()
                }
            }
        }
    }
    
    private func firework() {
        // Define the magic numbers that will create a
        //  'duration' second animation of
        //  'particleCount' little sprites of size
        //  'particleSize' forming a blast extending
        //  'blastRadius' from a point in the
        //  'blastZone'
        let duration: Double = 1.0
        let particleCount: Int = 23
        let particleSize = CGSize(width: 3, height: 3)
        let blastRadius: Double = min(frame.width, frame.height) * Double.random(in: 0.4...0.6)
        let particleColor = UIColor(hue: Double.random(in: 0...1),
                                    saturation: Double.random(in: 0.8...1),
                                    brightness: Double.random(in: 0.5...0.9),
                                    alpha: 0.75)
        let blastZone = CGRect(x: frame.minX + frame.width * 0.2,
                               y: frame.minY + frame.height * 0.3,
                               width: frame.width * 0.6,
                               height: frame.height * 0.4)

        let from = CGPoint(x: Double.random(in: blastZone.minX...blastZone.maxX),
                           y: Double.random(in: blastZone.minY...blastZone.maxY))
        let initialAngle = Double.random(in: 0..<360)
        let scatterMin: Double = -90 / Double(particleCount)
        let scatterMax: Double = 90 / Double(particleCount)
        for i in 1...particleCount {
            var angle = initialAngle
            angle += Double(i * 360) / Double(particleCount)
            angle += Double.random(in: scatterMin...scatterMax)
            let to = CGPoint(x: from.x + blastRadius * sin(angle * Double.pi / 180),
                             y: from.y + blastRadius * cos(angle * Double.pi / 180))
            
            let node = SKSpriteNode(color: particleColor, size: particleSize)
            node.position = from
            addChild(node)
            
            node.run(.group([
                .fadeOut(withDuration: duration),
                .move(to: to, duration: duration)
            ])) {
                node.removeFromParent()
            }
        }
    }
}
