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
    
    // multiplayer stuff
    var isMultiplayer: Bool = false
    var previousRoom: RoomModel?
    var db: GameDatabase?
    var hasStarted: Bool = false
    var gameHasEnded: Bool = false
    var streamingTimer: Timer?
    var isUserHost: Bool = false
    var allSlimesDict: [String : Slime] = [:] // [uid: Slime]
    var allStationsDict: [String : Station] = [:]

    // RI: the players are unique
    var players: [Player] = []

    //Level score
    var levelScore: Int = 0

    //Camera
    var sceneCam: SKCameraNode?

    override init(size: CGSize = CGSize(width: StageConstants.maxXAxisUnits, height: StageConstants.maxYAxisUnits)) {
        spaceship = Spaceship(inPosition: StageConstants.spaceshipPosition, withSize: StageConstants.spaceshipSize)
        super.init(size: size)

        sceneCam = SKCameraNode()
        self.camera = sceneCam
        self.addChild(sceneCam!)

        let background = SKSpriteNode(imageNamed: "background-1")
        background.position = StageConstants.spaceshipPosition
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        background.size = size
        background.scaleTo(screenWidthPercentage: 1.0)
        background.zPosition = StageConstants.backgroundZPos
        self.addChild(background)
        self.addChild(spaceship)

        let order = OrderQueue()
        self.sceneCam?.addChild(order)
    }

    override func update(_ currentTime: TimeInterval) {
        super.update(currentTime)
        if let camera = sceneCam {
            camera.position = (self.slimeToControl?.position)!
        }
    }
    
    func joinGame(forGameId id: String) {
        self.db?.joinGame(forGameId: id, {
            print("game has been successfully joined")
        }, { (err) in
            print(err.localizedDescription)
        })
    }
    
    func setupSinglePlayer() {
        guard let onlyUser = GameAuth.currentUser else {
            return
        }
        // Level 1 here only placeholder TO DO
        let onlyPlayer = Player(name: onlyUser.uid, level: 1)
        self.addPlayer(onlyPlayer)
    }
    
    func setupMultiplayer(forRoom room: RoomModel) {
        self.previousRoom = room
        
        db = GameDB()
        
        guard let user = GameAuth.currentUser else {
            return
        }
        
        // add all players
        for player in room.players {
            // sets isUserHost in current game instance
            if user.uid == player.uid { self.isUserHost = player.isHost }
            let playerInGame = Player(name: player.uid, level: player.level)
            self.addPlayer(playerInGame)
            // TODO: put into the slime dict
        }
        
        db?.observeGameState(forRoom: room, onPlayerUpdate: { (player) in
            guard let currentSlime = self.allSlimesDict[player.uid] else { return }
            
            currentSlime.position = CGPoint(x: player.positionX, y: player.positionY)
            currentSlime.physicsBody?.velocity = CGVector(dx: player.velocityX, dy: player.velocityY)
            currentSlime.xScale = player.xScale
        }, onStationUpdate: {
            // not yet implemented
            // this updates whenever one station
            // experiences a change
            
        }, onGameEnd: {
            self.gameHasEnded = true
            self.stopStreamingSelf()
            self.gameOver(ifWon: false)
            guard let database = self.db else { return }
            database.removeAllObservers()
            // TODO: game end goes here
        }, onOrderChange: { (orders) in
            // the function here occurs everytime the
            // order in the db changes
            // TODO: render this into the screen
            // when order changes
            for order in orders {
                print(order.name)
            }
        }, onScoreChange: { (score) in
            self.levelScore = score
            self.scoreLabel.text = "Score: \(self.levelScore)"
        }, onAllPlayersReady: {
            // only for host, starts the game proper
            self.multiplayerIndicateGameHasStarted()
        }, onGameStart: {
            self.hasStarted = true
            self.startStreamingSelf()
            if self.isUserHost { self.startCounter() }
            // TODO: do setup when game has started
        }, onSelfItemChange: { (item) in
            guard let slime = self.slimeToControl else { return }
            slime.removeItem()
            if let newItem = item { slime.takeItem(newItem) }
        }, onTimeLeftChange: { (timeLeft) in
            self.countdownLabel.text = "Time: \(timeLeft)"
            if self.isUserHost && self.isGameOver { self.endMultiplayerGame() }
        }, onComplete: {
            // joins game after attaching all
            // relevant observers, this onComplete
            // does not refer to the game state at all
            self.joinGame(forGameId: room.id)
        }) { (err) in
            print(err.localizedDescription)
        }
    }
    
    private func startStreamingSelf() {
        self.streamingTimer = Timer.init(timeInterval: StageConstants.streamingInterval, repeats: true, block: { (timer) in
            guard let slime = self.slimeToControl else { return }
            guard let room = self.previousRoom else { return }
            guard let slimeVelocity = slime.physicsBody?.velocity else { return }
            guard let database = self.db else { return }
            let slimePos = slime.position
            let slimeXScale = slime.xScale
            
            database.updatePlayerPosition(forGameId: room.id, position: slimePos, velocity: slimeVelocity, xScale: slimeXScale, { }, { (err) in
                print(err.localizedDescription)
            })
        })
    }
    
    private func stopStreamingSelf() {
        guard let timer = self.streamingTimer else { return }
        timer.invalidate()
    }

    func generateLevel(inLevel levelName: String) {
        if let levelDesignURL = Bundle.main.url(forResource: levelName, withExtension: "plist") {
            do {
                let data = try? Data(contentsOf: levelDesignURL)
                let decoder = PropertyListDecoder()
                let value = try decoder.decode(SerializableGameData.self, from: data!)
                spaceship.addRoom()
                
                if !isMultiplayer {
                    spaceship.addSlime(inPosition: value.slimeInitPos)
                }
                
                if isMultiplayer {
                    guard let room = self.previousRoom else { return }
                    for _ in room.players { spaceship.addSlime(inPosition: value.slimeInitPos) }
                }
                
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
        button.setScale(0.15)
        button.isEnabled = true
        button.position = StageConstants.jumpButtonPosition
        button.zPosition = StageConstants.buttonZPos
        return button
    }()

    lazy var interactButton: BDButton = {
        var button = BDButton(imageNamed: "Interact", buttonAction: {
            self.slimeToControl?.interact()
            
            })
        button.setScale(0.15)
        button.isEnabled = true
        button.position = StageConstants.interactButtonPosition
        button.zPosition = StageConstants.buttonZPos
        return button
    }()

    lazy var backButton: BDButton = {
        var button = BDButton(imageNamed: "BackButton", buttonAction: {
            print("AAAA")
        })
        button.setScale(0.1)
        button.isEnabled = true
        button.position = StageConstants.backButtonPosition
        button.zPosition = StageConstants.buttonZPos
        return button
    }()

    var counter = 0
    var counterTime = Timer()
    var counterStartTime = 200
    var isGameOver = false

    lazy var countdownLabel: SKLabelNode = {
        var label = SKLabelNode(fontNamed: "SquidgySlimes")
        label.fontSize = CGFloat(40)
        label.zPosition = 10
        label.color = .red
        label.horizontalAlignmentMode = .left
        label.verticalAlignmentMode = .center
        label.text = "Time: \(counterStartTime)"
        label.position = StageConstants.timerPosition
        return label
    }()

    lazy var scoreLabel: SKLabelNode = {
        var label = SKLabelNode(fontNamed: "SquidgySlimes")
        label.fontSize = CGFloat(30)
        label.zPosition = 10
        label.color = .red
        label.horizontalAlignmentMode = .left
        label.verticalAlignmentMode = .center
        label.text = "Score: \(levelScore)"
        label.position = StageConstants.scorePosition
        return label
    }()

    func setupControl() {
        self.sceneCam?.addChild(jumpButton)
        self.sceneCam?.addChild(interactButton)
        self.sceneCam?.addChild(backButton)
        self.sceneCam?.addChild(analogJoystick)
        self.sceneCam?.addChild(countdownLabel)
        self.sceneCam?.addChild(scoreLabel)

        if !isMultiplayer {
            counter = counterStartTime
            startCounter()
        }

        analogJoystick.trackingHandler = { [unowned self] data in
            if self.isMultiplayer && !self.hasStarted { return }
            
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

        guard let ingredientType = IngredientType(rawValue: type) else {
            return nil
        }

        let ingredient = Ingredient(type: ingredientType)

        guard let processingValue = data["processing"] else {
            return nil
        }

        // multiple processing separated by comma in the plist
        for processing in processingValue.split(separator: ",") {

            guard let processingType = CookingType(rawValue: String(processing)) else {
                return nil
            }

            ingredient.cook(by: processingType)
        }

        return ingredient
    }

    func initializeOrders(withData data: [RecipeData]) {
        if !isMultiplayer {
            guard let orderQueue = self.sceneCam?.childNode(withName: StageConstants.orderQueueName) as? OrderQueue else {
                return
            }
            
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
                orderQueue.addPossibleRecipe(recipe)
            }
            orderQueue.initialize()
        } else {
            
        }
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

    // when all the players is put into the game
    func setupPlayers() {
        var currentPlayerIndex = 0
        spaceship.enumerateChildNodes(withName: "slime") {
            node, stop in

            guard let slime = node as? Slime else { return }

            guard currentPlayerIndex < self.players.count else {
                stop.initialize(to: true)
                return
            }

            let player = self.players[currentPlayerIndex]
            slime.addUser(player)
            self.allSlimesDict.updateValue(slime, forKey: player.name)
            currentPlayerIndex += 1
        }
    }

    override func didSimulatePhysics() {
        self.spaceship.setAutomaticCooking()
        self.slimeToControl?.resetMovement()
        super.didSimulatePhysics()
    }

    // which slime to control
    var slimeToControl: Slime? {
        guard let user = GameAuth.currentUser else { return nil }
        return self.allSlimesDict[user.uid]
    }

    func serve(_ plate: Plate) {
        if !isMultiplayer {
            let foodToServe = plate.food
            
            guard let orderQueue = self.sceneCam?.childNode(withName: StageConstants.orderQueueName) as? OrderQueue else {
                print("error")
                return
            }
            
            guard orderQueue.completeOrder(withFood: foodToServe) == true else {
                print("failed")
                return
            }
            
            levelScore += 20 // TODO: put score in constants
            scoreLabel.text = "Score: \(levelScore)"
        } else {
            // multiplayer serve food
            guard let database = self.db else { return }
            guard let room = self.previousRoom else { return }

            // TODO:
            let recipe = Recipe(inRecipeName: "halo", withIngredients: [])
            database.submitOrder(forGameId: room.id, withRecipe: recipe, {
            }) { (err) in
                print(err.localizedDescription)
            }
        }
        
    }

    func startCounter() {
        if !isMultiplayer {
            counterTime = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(decrementCounter), userInfo: nil, repeats: true)
        } else {
            counterTime = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true, block: { (timer) in
                guard let database = self.db else { return }
                guard let room = self.previousRoom else { return }
                
                database.decrementTimeLeft(forGameId: room.id, { }, { (err) in
                    print(err.localizedDescription)
                })
            })
        }
    }

    @objc func decrementCounter() {
        if !isGameOver {
            if counter <= 1 {
                isGameOver = true
                gameOver(ifWon: false)
            }

            counter -= 1
            countdownLabel.text = "Time: \(counter)"
        }
    }
    
    private func multiplayerIndicateGameHasStarted() {
        guard let database = self.db else { return }
        guard let room = self.previousRoom else { return }
        
        database.updateGameHasStarted(forGameId: room.id, to: true, { }, { (err) in
            print(err.localizedDescription)
        })
    }
    
    private func isMultiplayerTimeUp(forTime time: Int) -> Bool {
        if time <= 0 { return true }
        return false
    }
    
    private func endMultiplayerGame() {
        guard let database = self.db else { return }
        guard let room = self.previousRoom else { return }
        
        database.updateGameHasEnded(forGameId: room.id, to: true, { }) { (err) in
            print(err.localizedDescription)
        }
    }

    func gameOver(ifWon: Bool) {
        let temp = GameOverPrefab(color: .clear, size: StageConstants.gameOverPrefabSize)
        temp.setScore(inScore: levelScore)
        self.addChild(temp)
        print("gameOver!")
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("initiation using storyboard is not implemented yet.")
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let touch = touches.first!
        let location = touch.location(in: self)
        if (location.x < -150 && location.y < 80) {
            analogJoystick.position = location
            analogJoystick.touchesBegan(touches, with: event)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        analogJoystick.touchesMoved(touches, with: event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        analogJoystick.touchesEnded(touches, with: event)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        analogJoystick.touchesEnded(touches, with: event)
    }
}
