//
//  ConversationSession+Rename.swift
//  FlowDown
//
//  Created by 秋星桥 on 3/19/25.
//

import ChatClientKit
import Foundation
import Storage

extension ConversationSession {
    func updateTitleAndIcon() async {
        if let title = await generateConversationTitle() {
            ConversationManager.shared.editConversation(identifier: id) {
                $0.update(\.title, to: title)
                $0.update(\.shouldAutoRename, to: false)
            }
        }
        if let emoji = await generateConversationIcon() {
            ConversationManager.shared.editConversation(identifier: id) {
                let icon = emoji.textToImage(size: 128)?.pngData() ?? .init()
                $0.update(\.icon, to: icon)
                $0.update(\.shouldAutoRename, to: false)
            }
        }
    }
}
