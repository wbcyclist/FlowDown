//
//  ChatSelection.swift
//  FlowDown
//
//  Created by 秋星桥 on 2025/10/31.
//

import Combine
import Foundation
import Storage

class ChatSelection {
    static let shared = ChatSelection()

    private let subject = CurrentValueSubject<Conversation.ID?, Never>(nil)
    let selection: AnyPublisher<Conversation.ID?, Never>

    private var cancellables = Set<AnyCancellable>()

    private init() {
        selection = subject
            .ensureMainThread()
            .eraseToAnyPublisher()

        let conversations = sdb.conversationList()
        if let firstConversation = conversations.first {
            subject.send(firstConversation.id)
        } else {
            let initialConversation = ConversationManager.shared.createNewConversation(autoSelect: false)
            subject.send(initialConversation.id)
        }

        // Listen for conversation list changes and auto-create conversation if list becomes empty
        ConversationManager.shared.conversations
            .receive(on: DispatchQueue.main)
            .sink { [weak self] conversationDict in
                if conversationDict.isEmpty, self?.subject.value != nil {
                    // Current selection is invalid (conversation was deleted), create a new one
                    Logger.ui.infoFile("No conversations left, auto-creating a new conversation")
                    let newConversation = ConversationManager.shared.createNewConversation(autoSelect: false)
                    self?.subject.send(newConversation.id)
                }
            }
            .store(in: &cancellables)
    }

    func select(_ conversationId: Conversation.ID?) {
        Logger.ui.debugFile("ChatSelection.select called with: \(conversationId ?? "nil")")
        subject.send(conversationId)
    }
}
