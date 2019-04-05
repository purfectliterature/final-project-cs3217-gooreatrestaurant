//
//  Stage.swift
//  GooreatRestaurant
//
//  Created by Samuel Henry Kurniawan on 14/3/19.
//  Copyright © 2019 CS3217. All rights reserved.
//

import UIKit
import SpriteKit

class Stage: SKScene {
    typealias DictString = [String: String]
    typealias RecipeData = [String: [DictString]]

    var spaceship: Spaceship
    var orders: [Order] = []
    var possibleRecipes: Set<Recipe> = []

    // RI: the players are unique
    var players: [Player] = []

    override func didMove(to view: SKView) {
        view.showsPhysics = true
    }

    override init(size: CGSize = CGSize(width: StageConstants.maxXAxisUnits, height: StageConstants.maxYAxisUnits)) {
        spaceship = Spaceship(inPosition: StageConstants.spaceshipPosition, withSize: StageConstants.spaceshipSize)
        super.init(size: size)
        let background = SKSpriteNode(imageNamed: "background-1")
        background.position = StageConstants.spaceshipPosition
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        background.size = size
        background.scaleTo(screenWidthPercentage: 1.0)
        background.zPosition = StageConstants.backgroundZPos
        self.addChild(background)
        self.addChild(spaceship)
        setupControl()
    }

    func generateLevel(inLevel levelName: String) {
        if let levelDesignURL = Bundle.main.url(forResource: levelName, withExtension: "plist") {
            do {
                let data = try? Data(contentsOf: levelDesignURL)
                let decoder = PropertyListDecoder()
                let value = try decoder.decode(SerializableGameData.self, from: data!)
                spaceship.addRoom()
                spaceship.addSlime(inPosition: value.slimeInitPos)
                spaceship.addWall(inCoord: value.border)
                spaceship.addWall(inCoord: value.blockedArea)
                spaceship.addLadder(inPositions: value.ladder)
                spaceship.addChoppingEquipment(inPositions: value.choppingEquipment)
                spaceship.addFryingEquipment(inPositions: value.fryingEquipment)
                spaceship.addOven(inPositions: value.oven)
                spaceship.addPlateStorage(inPositions: value.plateStorage)
                spaceship.addStoreFront(inPosition: value.storefront)
                spaceship.addTable(inPositions: value.table)
                spaceship.addTrashBin(inPositions: value.trashBin)

                // add Ingredient Storages (station to take out ingredient) in the spaceship
                var ingredientStorageData: [(type: String, position: String)] = []
                for data in value.ingredientStorage {
                    guard let type = data["type"] else {
                        continue
                    }
                    guard let pos = data["position"] else {
                        continue
                    }
                    ingredientStorageData.append((type: type, position: pos))
                }
                spaceship.addIngredientStorage(withDetails: ingredientStorageData)

                // initialize the starting orders and the orders pool
                self.initializeOrders(withData: value.possibleRecipes)
            } catch {
                print(error.localizedDescription)
            }
        }
    }

    // Setupping Joystick and Buttons

    lazy var analogJoystick: AnalogJoystick = {
        let js = AnalogJoystick(diameter: StageConstants.joystickSize,
                                colors: nil,
                                images: (substrate: #imageLiteral(resourceName: "jSubstrate"),
                                stick: #imageLiteral(resourceName: "jStick")))
        js.position = StageConstants.joystickPosition
        js.zPosition = StageConstants.joystickZPos
        return js
    }()

    lazy var jumpButton: BDButton = {
        var button = BDButton(imageNamed: "Up", buttonAction: {
            self.slimeToControl?.jump()
            })
        button.setScale(0.1)
        button.isEnabled = true
        button.position = StageConstants.jumpButtonPosition
        button.zPosition = StageConstants.buttonZPos
        return button
    }()

    lazy var interactButton: BDButton = {
        var button = BDButton(imageNamed: "Interact", buttonAction: {
            self.slimeToControl?.interact()
            })
        button.setScale(0.1)
        button.isEnabled = true
        button.position = StageConstants.interactButtonPosition
        button.zPosition = StageConstants.buttonZPos
        return button
    }()

    var counter = 0
    var counterTime = Timer()
    var counterStartTime = 30
    var isGameOver = false

    lazy var countdownLabel: SKLabelNode =  {
        var label = SKLabelNode(fontNamed: "HelveticaNeue-UltraLight")
        label.fontSize = CGFloat(100)
        label.zPosition = 10
        label.color = .red
        label.horizontalAlignmentMode = .left
        label.verticalAlignmentMode = .center
        label.text = "\(counterStartTime)"
        label.position = StageConstants.timerPosition
        return label
    }()

    func setupControl() {
        self.addChild(jumpButton)
        self.addChild(interactButton )
        self.addChild(analogJoystick)
        self.addChild(countdownLabel)

        counter = counterStartTime
        startCounter()

        analogJoystick.trackingHandler = { [unowned self] data in
            if data.velocity.x > 0.0 {
                self.slimeToControl?.moveRight(withSpeed: data.velocity.x)
            } else if data.velocity.x < 0.0 {
                self.slimeToControl?.moveLeft(withSpeed: -data.velocity.x)
            }

            if data.velocity.y > 0.0 {
                self.slimeToControl?.moveUp(withSpeed: data.velocity.y)
            } else if data.velocity.y < 0.0 {
                self.slimeToControl?.moveDown(withSpeed: -data.velocity.y)
            }
        }
    }

    // Starting Orders Initialization

    private func getIngredient(fromDictionaryData data: [String: String]) -> Ingredient? {
        guard let type = data["type"] else {
            return nil
        }

        guard let ingredientEnum = Int(type) else {
            return nil
        }

        guard let ingredientType = IngredientType(rawValue: ingredientEnum) else {
            return nil
        }

        let ingredient = Ingredient(type: ingredientType)

        guard let processingValue = data["processing"] else {
            return nil
        }

        // multiple processing separated by comma in the plist
        for processing in processingValue.split(separator: ",") {
            guard let processingEnum = Int(processing) else {
                return nil
            }

            guard let processingType = CookingType(rawValue: processingEnum) else {
                return nil
            }

            ingredient.cook(by: processingType)
        }

        return ingredient
    }

    func initializeOrders(withData data: [RecipeData]) {
        for datum in data {
            var recipeName: String = ""
            var compulsoryIngredients: [Ingredient] = []
            var optionalIngredients: [(item: Ingredient, probability: Double)] = []

            for name in datum["recipeName"] ?? [] {
                recipeName = (name.first?.value)!
            }

            for ingredientRequirement in datum["compulsoryIngredients"] ?? [] {
                guard let ingredient = getIngredient(fromDictionaryData: ingredientRequirement) else {
                    continue
                }
                compulsoryIngredients.append(ingredient)
            }

            for ingredientRequirement in datum["optionalIngredients"] ?? [] {
                guard let ingredient = getIngredient(fromDictionaryData: ingredientRequirement) else {
                    continue
                }

                guard let probabilityString = ingredientRequirement["probability"] else {
                    continue
                }

                guard let probability = Double(probabilityString) else {
                    continue
                }

                optionalIngredients.append((item: ingredient, probability: probability))
            }
            let recipe = Recipe(inRecipeName: recipeName, withCompulsoryIngredients: compulsoryIngredients,
                                withOptionalIngredients: optionalIngredients)
            _ = possibleRecipes.insert(recipe)
        }

        guard !possibleRecipes.isEmpty else {
            return
        }

        while orders.count < StageConstants.numbersOfOrdersShown {
            self.addRandomOrder()
        }
    }

    func addOrder(ofRecipe recipe: Recipe, withinTime time: CGFloat = StageConstants.defaultTimeLimitOrder) {
        let order = Order(recipe, withinTime: time)
        orders.append(order)
        generateMenu(inOrder: order)
    }

    // For multiplayer (future use)
    // if the player is already in the list, will do nothing
    func addPlayer(_ player: Player) {
        if !players.contains(player) && players.count < StageConstants.maxPlayer {
            players.append(player)
        }
    }

    // if the player is not found, will do nothing
    func removePlayer(_ player: Player) {
        players.removeAll { $0 == player }
    }

    override func didSimulatePhysics() {
        self.slimeToControl?.resetMovement()
        super.didSimulatePhysics()
    }

    // which slime to control
    var slimeToControl: Slime? {
        var playerSlime: Slime?

        spaceship.enumerateChildNodes(withName: "slime") {
            node, stop in

            guard let slime = node as? Slime else {
                return
            }

            playerSlime = slime
            stop.initialize(to: true)
        }
        return playerSlime
    }

    // Game serving and adding orders logic

    func serve(_ plate: Plate) {
        let foodToServe = plate.food
        let ingredientsPrepared = foodToServe.ingredientsList
        guard let matchedOrder = orders.firstIndex(
                                        where:{ $0.recipeWanted.ingredientsNeeded == ingredientsPrepared }) else {
            return
        }
        orders.remove(at: matchedOrder)
        self.addRandomOrder()
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

    func generateMenu(inOrder order: Order) {
        let temp = MenuPrefab(color: .clear, size: CGSize(width: 100, height: 100))
        temp.addRecipe(inOrder: order)
        self.addChild(temp)
    }

    func startCounter() {
        counterTime = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(decrementCounter), userInfo: nil, repeats: true)
    }

    @objc func decrementCounter() {
        if !isGameOver {
            if counter <= 1 {
                isGameOver = true
                gameOver(ifWon: false)
            }

            counter -= 1
            countdownLabel.text = "\(counter)"
        }
    }

    func gameOver(ifWon: Bool) {
        print("gameOver!")
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("initiation using storyboard is not implemented yet.")
    }
}
