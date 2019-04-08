//
//  Order.swift
//  GooreatRestaurant
//
//  Created by Samuel Henry Kurniawan on 14/3/19.
//  Copyright © 2019 CS3217. All rights reserved.
//

import UIKit
import SpriteKit

class OrderQueue: SKSpriteNode {
    let amountOfRecipeShown: Int
    var possibleRecipes: Set<Recipe> = []
    var recipeOrdered: [Recipe] = []

    init(withNumberOfRecipeShown amount: Int) {
        self.amountOfRecipeShown = amount
        super.init(texture: nil, color: .clear, size: CGSize.zero)
        self.position = CGPoint.zero
        self.name = StageConstants.orderQueueName
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func generateMenu(ofRecipe recipe: Recipe) {
        let menuObj = MenuPrefab(color: .clear, size: CGSize(width: 100, height: 100))
        menuObj.addRecipe(recipe)
        self.addChild(menuObj)
    }

    func addOrder(ofRecipe recipe: Recipe) {
        recipeOrdered.append(recipe)
        generateMenu(ofRecipe: recipe)
    }

    func generateRandomRecipe() -> Recipe? {
        return self.possibleRecipes.randomElement()?.regenerateRecipe()
    }

    func addRandomOrder() {
        guard let randomRecipe = self.generateRandomRecipe() else {
            return
        }
        self.addOrder(ofRecipe: randomRecipe)
    }

    func addPossibleRecipe(_ recipe: Recipe) {
        self.possibleRecipes.insert(recipe)
    }

    func initialize() {
        guard !possibleRecipes.isEmpty else {
            return
        }

        while recipeOrdered.count < amountOfRecipeShown {
            self.addRandomOrder()
        }
    }

    // True if success, false if failed (no corresponding orders)
    func completeOrder(withFood food: Food) -> Bool {
        let ingredientsPrepared = food.ingredientsList
        guard let matchedOrder = recipeOrdered.firstIndex(where:{ $0.ingredientsNeeded == ingredientsPrepared }) else {
            return false
        }
        recipeOrdered.remove(at: matchedOrder)
        self.addRandomOrder()
        return true
    }

    // The view will call this function if there is timeout of an order
    func orderTimeOut(ofRecipe recipe: Recipe) {
        guard let matchedOrder = recipeOrdered.firstIndex(where:{ $0 == recipe }) else {
            return
        }
        recipeOrdered.remove(at: matchedOrder)
        self.addRandomOrder()
    }
}