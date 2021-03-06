//
//  JoinRoomViewController.swift
//  slime
//
//  Created by Gabriel Tan on 27/3/19.
//  Copyright © 2019 nus.cs3217.a0166733y. All rights reserved.
//

import UIKit

class JoinRoomViewController: ViewController<JoinRoomView> {
    override func configureSubviews() {
        let codeInputController = CodeInputController(withXib: view.codeInputView)
        let numberPadController = SlimeNumberPadController(withXib: view.numPadView)

        codeInputController.bindTo(numberPad: numberPadController)
        codeInputController.configure()
        codeInputController.onComplete { _ in
            // TODO: replace with true code
            let code = try? codeInputController.inputCode.value()
            guard let codeArr = code else { return }
            
            var roomJoinId = ""
            
            for int in codeArr {
                roomJoinId = "\(roomJoinId)\(int)"
            }
            
            print(roomJoinId)
            
            self.showLoadingAlert(withDescription: "Teleporting slime agent...")

            guard let userCharacter = try? self.context.data.userCharacter?.value() else {
                return
            }
            
            guard let userChar = userCharacter else {
                return
            }
            
            self.context.db.joinRoom(forRoomId: roomJoinId, withUser: userChar, {
                let lobbyController: MultiplayerLobbyViewController = self.context.routeToAndPrepareFor(.MultiplayerLobby)
                lobbyController.setupRoom(withId: roomJoinId)
                self.context.modal.closeAllModals()
            }, {
                // room contains 4 players already
                self.context.modal.closeAllModals()
                self.showErrorAlert(withDescription: "Room is full!")
            }, {
                // room does not exist
                self.context.modal.closeAllModals()
                self.showErrorAlert(withDescription: "Room does not exist!!")
            }, {
                // room has started game
                self.context.modal.closeAllModals()
                self.showErrorAlert(withDescription: "This room has started the game")
            }, { (err) in
                self.showErrorAlert(withDescription: err.localizedDescription)
            })
        }
        numberPadController.configure()

        remember(codeInputController)
        remember(numberPadController)
        
        configureUpButton(to: .MultiplayerScreen)
    }

    private func showLoadingAlert(withDescription description: String) {
        let alert = context.modal.createAlert()
            .setTitle("Loading...")
            .setDescription(description)
        context.modal.presentUnimportantAlert(alert)
    }

    private func showErrorAlert(withDescription description: String) {
        let alert = context.modal.createAlert()
            .setTitle("Error!")
            .setDescription(description)
            .addAction(AlertAction(with: "OK"))
        context.modal.presentAlert(alert)
    }
}
