//
//  GameOverPrefab.swift
//  slime
//
//  Created by Developer on 6/4/19.
//  Copyright © 2019 nus.cs3217.a0166733y. All rights reserved.
//

import Foundation
import SpriteKit

class GameOverPrefab : SKSpriteNode {
    override init(texture: SKTexture?, color: UIColor, size: CGSize) {
        let base = SKTexture(imageNamed: "Base")
        base.filteringMode = .nearest
        let baseNode = SKSpriteNode(texture: base)

        super.init(texture: base, color: color, size: size)
        self.position = CGPoint.zero
        self.size = size
        self.zPosition = 10

        let slime = SKSpriteNode(imageNamed: "Shocked Slime")
        slime.texture?.filteringMode = .nearest
        slime.position = CGPoint.zero
        slime.size = CGSize(width: 150, height: 150)
        slime.zPosition = 11

        baseNode.addChild(slime)
        baseNode.addChild(titleLabel)
        baseNode.addChild(replayButton)
        baseNode.addChild(exitButton)

        self.addChild(baseNode)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    lazy var titleLabel: SKLabelNode =  {
        var label = SKLabelNode(fontNamed: "SquidgySlimes")
        label.fontSize = CGFloat(60)
        label.zPosition = 10
        label.color = .red
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .top
        label.text = "GAME OVER"
        label.position = CGPoint(x: 0, y: 150)
        return label
    }()

    lazy var scoreLabel: SKLabelNode =  {
        var label = SKLabelNode(fontNamed: "SquidgySlimes")
        label.fontSize = CGFloat(60)
        label.zPosition = 10
        label.color = .red
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.text = ""
        label.position = CGPoint.zero
        return label
    }()

    lazy var replayButton: BDButton = {
        var button = BDButton(imageNamed: "ReplayButton", buttonAction: {
            print("REPLAY GAME")
        })
        button.setScale(0.5)
        button.isEnabled = true
        button.position = CGPoint(x: -50, y: -100)
        button.zPosition = StageConstants.buttonZPos
        return button
    }()

    lazy var exitButton: BDButton = {
        var button = BDButton(imageNamed: "ExitButton", buttonAction: {
            print("EXIT GAME")
        })
        button.setScale(0.5)
        button.isEnabled = true
        button.position = CGPoint(x: 50, y: -100)
        button.zPosition = StageConstants.buttonZPos
        return button
    }()

    func setScore(inScore: Int) {
        scoreLabel.text = String(inScore)
    }
}