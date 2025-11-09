//
//  ConversationSession+Trim.swift
//  FlowDown
//
//  Created by 秋星桥 on 3/19/25.
//

import ChatClientKit
import Foundation

extension ConversationSession {
    func removeOutOfContextContents(
        _ requestMessages: inout [ChatRequestBody.Message],
        _ tools: [ChatRequestBody.Tool]?,
        _ modelContextLength: Int
    ) throws -> Bool {
        var isTrimmed = false

        var estimatedTokenCount = ModelManager.shared.calculateEstimateTokensUsingCommonEncoder(
            input: requestMessages,
            tools: tools ?? []
        )
        Logger.model.debugFile("estimated token count: \(estimatedTokenCount)")

        deleteLoop: while estimatedTokenCount > modelContextLength {
            Logger.model.debugFile("estimated token count \(estimatedTokenCount) exceeds limit \(modelContextLength), removing messages!")
            defer {
                estimatedTokenCount = ModelManager.shared.calculateEstimateTokensUsingCommonEncoder(
                    input: requestMessages,
                    tools: tools ?? []
                )
            }
            // 所有的 system prompt 不删除 除此以外 从前往后删除
            for idx in 0 ..< requestMessages.count {
                let item = requestMessages[idx]
                if case .system = item { continue }
                Logger.model.debugFile("removing message at index \(idx)")
                requestMessages.remove(at: idx)
                isTrimmed = true
                continue deleteLoop
            }
            Logger.model.errorFile("unable to remove any more messages, estimated token count: \(estimatedTokenCount)")
            throw NSError(
                domain: String(localized: "Inference Service"),
                code: 1,
                userInfo: ["reason": "unable to remove any more messages"]
            )
        }

        return isTrimmed
    }
}
