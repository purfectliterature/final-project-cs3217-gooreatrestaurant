//
//  Slime.swift
//  GooreatRestaurant
//
//  Created by Samuel Henry Kurniawan on 14/3/19.
//  Copyright © 2019 CS3217. All rights reserved.
//

import UIKit
import SpriteKit

class Slime: SKSpriteNode {

    var isContactingWithLadder = false
    
    init(inPosition position: CGPoint, withSize size: CGSize = StageConstants.slimeSize) {
        let slimeAnimatedAtlas = SKTextureAtlas(named: "Slime")
        var walkFrames: [SKTexture] = []

        let numImages = slimeAnimatedAtlas.textureNames.count
        for i in 1...numImages {
            let slimeTextureName = "slime\(i)"
            walkFrames.append(slimeAnimatedAtlas.textureNamed(slimeTextureName))
        }

        super.init(texture: walkFrames[0], color: .clear, size: size)

        self.name = StageConstants.slimeName

        self.position = position
        self.zPosition = StageConstants.slimeZPos
        self.physicsBody = SKPhysicsBody(texture: slimeAnimatedAtlas.textureNamed("slime1"), size: size)
        self.physicsBody?.isDynamic = true
        self.physicsBody?.allowsRotation = false
        self.physicsBody?.collisionBitMask = StageConstants.wallCategoryCollision
        self.physicsBody?.categoryBitMask = StageConstants.slimeCategory
        self.physicsBody?.contactTestBitMask = 0

        self.physicsBody?.contactTestBitMask |= StageConstants.cookerCategory
        self.physicsBody?.contactTestBitMask |= StageConstants.plateCategory
        self.physicsBody?.contactTestBitMask |= StageConstants.ingredientCategory
        self.physicsBody?.contactTestBitMask |= StageConstants.tableCategory
        self.physicsBody?.contactTestBitMask |= StageConstants.slimeCategory
        self.physicsBody?.contactTestBitMask |= StageConstants.ladderCategory

        // animate slime
        self.run(SKAction.repeatForever(
            SKAction.animate(with: walkFrames,
                             timePerFrame: 0.2,
                             resize: false,
                             restore: true)),
                 withKey: "walkingInPlaceSlime")
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("initiation using storyboard is not implemented yet.")
    }


    var plateCarried: Plate? {
        guard let node = childNode(withName: "plate") else {
            return nil
        }

        return node as? Plate
    }

    var ingredientsCarried: Ingredient? {
        guard let node = childNode(withName: "ingredient") else {
            return nil
        }

        return node as? Ingredient
    }

    var itemCarried: SKSpriteNode? {
        if let plate = plateCarried {
            return plate
        } 

        if let ingredient = ingredientsCarried {
            return ingredient
        }

        return nil
    }

    var spaceship: Spaceship? {
        guard let node = parent else {
            return nil
        }

        return node as? Spaceship
    }

    var isCarryingSomething: Bool {
        return itemCarried != nil
    }

    func interact() {
    }
}