//
//  Ingredient.swift
//  GooreatRestaurant
//
//  Created by Samuel Henry Kurniawan on 14/3/19.
//  Copyright © 2019 CS3217. All rights reserved.
//

import UIKit
import SpriteKit

class Ingredient: SKSpriteNode {
    var type: IngredientType
    var processed: [CookingType] = []

    var currentProcessing: CookingType?
    var processingProgress = 0

    init(type: IngredientType,
         size: CGSize = StageConstants.ingredientSize,
         inPosition position: CGPoint = CGPoint.zero) {

        self.type = type
        super.init(texture: nil, color: .red, size: size)
        self.name = StageConstants.ingredientName
        self.position = position
        self.physicsBody = SKPhysicsBody(rectangleOf: size)
        self.physicsBody?.categoryBitMask = StageConstants.ingredientCategory
        self.physicsBody?.collisionBitMask = StageConstants.wallCategoryCollision
    }

    // Progress 100 denotes that cooking will be done
    func cook(by method: CookingType, withProgress progress: Int = 100) {
        guard currentProcessing == nil || currentProcessing == method else {
            return
        }

        // to prevent overcook trauma because of misclick when tapping repeatedly
        guard processed.last != method else {
            return
        }

        currentProcessing = method
        processingProgress += progress

        if processingProgress >= 100 {
            currentProcessing = nil
            processingProgress = 0
            processed.append(method)
        }
    }

    func ruin() {
        self.type = .junk
    }

    override var hash: Int {
        var hasher = Hasher()
        hasher.combine(self.type)
        hasher.combine(self.processed)
        return hasher.finalize()
    }

    override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? Ingredient else {
            return false
        }

        return self.type == other.type && self.processed == other.processed
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}