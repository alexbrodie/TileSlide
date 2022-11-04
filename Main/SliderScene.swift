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

class SliderScene: SKScene, ObservableObject {
    
    private func lerp(from: Double, to: Double, ratio: Double) -> Double {
        return (from * (1 - ratio)) + (to * ratio)
    }
    
    @ObservedObject var settings = SliderSettings() {
        didSet { onSettingsReplaced() }
    }
        

    // MARK: UI State
    // Last time that tilting the device slid a tile
    private var lastTiltShift: Date = Date()

    // MARK: Connections
    private var cancellableBag = Set<AnyCancellable>()
    // Object to fetch accelerometer/gyro data
    private var motionManager: CMMotionManager? = nil
    
    // MARK: Children
    // The current board
    private var currentBoard: BoardNode? = nil
    // Place to show text for debugging
    private var debugText: SKLabelNode? = nil
    
    override init() {
        super.init(size: CGSize(width: 0, height: 0))
        backgroundColor = .black
        scaleMode = .resizeFill
        onSettingsReplaced()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func didMove(to view: SKView) {
        //setEnableTiltToSlide(true)
        //makeDebugText()
        setup()
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
            //subShuffleTile(tile)
            //return true
        }
        
        return false
    }
    
    // Called when the settings property is set so that we can
    // reset sinks for our manual bindings
    private func onSettingsReplaced() {
        // Clear old sinks
        for o in cancellableBag {
            o.cancel()
        }
        cancellableBag.removeAll()
        // Set up new sinks
        settings.$tileLabelType.sink { [weak self] value in
            self?.forEachTile { board, tile in
                tile.label?.text = value.glyphFor(
                    columns: board.model.columns,
                    rows: board.model.rows,
                    ordinal: tile.ordinal)
            }
        }.store(in: &cancellableBag)
        settings.$tileLabelColor.sink { [weak self] value in
            self?.forEachTile { (board, tile) in
                tile.label?.fontColor = UIColor(value)
            }
        }.store(in: &cancellableBag)
        settings.$tileLabelFont.sink { [weak self] value in
            self?.forEachTile { board, tile in
                tile.label?.fontName = value
            }
        }.store(in: &cancellableBag)
        settings.$tileLabelSize.sink { [weak self] value in
            self?.forEachTile { (board, tile) in
                tile.label?.fontSize = tile.size.height * CGFloat(value)
            }
        }.store(in: &cancellableBag)
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
    
    private func setup() {
        let name = String(format: "Doguillo-%d", Int.random(in: 1...19))
        setupNewBoard(columns: 3, 
                      rows: 3, 
                      emptyOrdinal: 8, 
                      texture: SKTexture(imageNamed: name))
    }
    
    // MARK: BoardNode methods
    
    private func cleanupBoard() {
        // Fade out and remove old stuff
        enumerateChildNodes(withName: BoardNode.nodeName) { (board, stop) in
            (board as! BoardNode).cleanup()
        }
        currentBoard = nil
    }
    
    private func setupNewBoard(columns: Int, rows: Int, emptyOrdinal: Int, texture: SKTexture?) {
        cleanupBoard()
        let rect = frame.middleWithAspect(texture?.size().aspect ?? 1)
        let model = SliderBoard(columns: columns, rows: rows, emptyOrdinal: emptyOrdinal)
        let board = BoardNode(model: model, texture: texture, rect: rect)
        board.shuffle()
        
        var subBoard = board;
        for i in stride(from: 3, to: 1, by: -1) {
            let subModel = SliderBoard(columns: columns, rows: rows, emptyOrdinal: emptyOrdinal)
            subBoard = subBoard.tiles[i].createSubBoard(model: subModel)
            subBoard.shuffle()
        }

        addChild(board)
        board.revealTiles()
    }
    
    // Called when the board enters the solved state - inverse of unsolved
    private func solved(_ board: BoardNode) {

        // Determine if all other boards are solved as well
        let rootBoard: BoardNode = board.lastAncestorOfType()!
        let isFullySolved = forEachBoardAndTile(board: rootBoard) { board in
            return board.model.isSolved
        } onTile: { board, tile in
            return true
        }

        if isFullySolved {
            // This is a temp success screen
            backgroundColor = .white
            
            let w = frame.width * 0.6
            let h = frame.height * 0.6
            let r = CGRect(x: frame.midX - w / 2, y: frame.midY - h / 2, width: w, height: h)
            for _ in 0...10 {
                let n = SKSpriteNode(color: .red, size: CGSize(width: 25, height: 25))
                n.position = CGPoint(x: r.midX, y: r.minY)
                addChild(n)
                let dur = 2.0
                n.run(.group([
                    .fadeOut(withDuration: dur),
                    .move(to: CGPoint(x: lerp(from: r.minX, to: r.maxY, ratio: Double.random(in: 0...1)), y: r.maxY), duration: dur)
                ])) {
                    n.removeFromParent()
                }
            }
        }
    }
    
    // Turns a tile into a sub-board if it's not already and then shuffles it
    private func subShuffleTile(_ tile: TileNode) {
        var subBoard = tile.content as? BoardNode
        if subBoard == nil {
            let model = SliderBoard(columns: tile.board.model.columns, rows: tile.board.model.rows, emptyOrdinal: tile.ordinal)
            subBoard = tile.createSubBoard(model: model)
        }
        subBoard!.shuffle(3)
    }
    
    // MARK: Node Lookup
    
    // Enumerate all the TileNode in the visual tree
    private func forEachTile(_ onTile: (BoardNode, TileNode) -> Void) {
        for child in children {
            _ = forEachBoardAndTile(board: child) { board in
                return true
            } onTile: { board, tile in
                onTile(board, tile)
                return true
            }
        }
    }
    
    // Enumerate all the TileNode in the visual tree under the provided board
    // Callbacks should return true to continue the enumeration. This method
    // evaluates to true if all the callbacks return true and the enumeration
    // completes. If one callback returns false the enumeration is canceled
    // and this method evalues to false
    private func forEachBoardAndTile(board: SKNode,
                                     onBoard: (BoardNode) -> Bool,
                                     onTile: (BoardNode, TileNode) -> Bool) -> Bool {
        guard let board = board as? BoardNode  else {
            return true
        }
        guard onBoard(board) else {
            return false
        }
        for tile in board.tiles {
            guard onTile(board, tile) && forEachBoardAndTile(board: tile.content!, onBoard: onBoard, onTile: onTile) else {
                return false
            }
        }
        return true
    }
}
