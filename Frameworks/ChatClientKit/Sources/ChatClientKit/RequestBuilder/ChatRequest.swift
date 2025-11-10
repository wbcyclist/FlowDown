//
//  ChatRequest.swift
//  ChatClientKit
//
//  Created by GPT-5 Codex on 2025/11/10.
//

import CryptoKit
import Foundation

/// Domain representation of a chat completion request.
///
/// The structure mirrors `ChatRequestBody` while offering additional
/// conveniences such as result-builder initializers, normalization, and
/// caching helpers.
///
/// ```swift
/// let request = ChatRequest {
///     ChatRequest.model("gpt-4o-mini")
///     ChatRequest.temperature(0.4)
///     ChatRequest.messages {
///         .system(content: .text("You are a haiku assistant."))
///         .user(content: .text("Write about autumn."))
///     }
/// }
/// let response = try await client.chatCompletion(request)
/// ```
public struct ChatRequest: Sendable {
    public typealias Message = ChatRequestBody.Message
    public typealias MessageContent = ChatRequestBody.Message.MessageContent
    public typealias ContentPart = ChatRequestBody.Message.ContentPart
    public typealias Tool = ChatRequestBody.Tool
    public typealias ToolChoice = ChatRequestBody.ToolChoice
    public typealias ResponseFormat = ChatRequestBody.ResponseFormat
    public typealias StreamOptions = ChatRequestBody.StreamOptions

    public var model: String?
    public var messages: [Message]
    public var frequencyPenalty: Double?
    public var logitBias: [String: Double]?
    public var logprobs: Bool?
    public var maxCompletionTokens: Int?
    public var n: Int?
    public var parallelToolCalls: Bool?
    public var presencePenalty: Double?
    public var responseFormat: ResponseFormat?
    public var seed: Int?
    public var stop: [String]?
    public var store: Bool?
    public var stream: Bool?
    public var streamOptions: StreamOptions?
    public var temperature: Double?
    public var tools: [Tool]?
    public var toolChoice: ToolChoice?
    public var topLogprobs: Int?
    public var topP: Double?
    public var user: String?

    public init(
        model: String? = nil,
        messages: [Message],
        frequencyPenalty: Double? = nil,
        logitBias: [String: Double]? = nil,
        logprobs: Bool? = nil,
        maxCompletionTokens: Int? = nil,
        n: Int? = nil,
        parallelToolCalls: Bool? = nil,
        presencePenalty: Double? = nil,
        responseFormat: ResponseFormat? = nil,
        seed: Int? = nil,
        stop: [String]? = nil,
        store: Bool? = nil,
        stream: Bool? = nil,
        streamOptions: StreamOptions? = nil,
        temperature: Double? = nil,
        tools: [Tool]? = nil,
        toolChoice: ToolChoice? = nil,
        topLogprobs: Int? = nil,
        topP: Double? = nil,
        user: String? = nil
    ) {
        self.model = model
        self.messages = messages
        self.frequencyPenalty = frequencyPenalty
        self.logitBias = logitBias
        self.logprobs = logprobs
        self.maxCompletionTokens = maxCompletionTokens
        self.n = n
        self.parallelToolCalls = parallelToolCalls
        self.presencePenalty = presencePenalty
        self.responseFormat = responseFormat
        self.seed = seed
        self.stop = stop
        self.store = store
        self.stream = stream
        self.streamOptions = streamOptions
        self.temperature = temperature
        self.tools = tools
        self.toolChoice = toolChoice
        self.topLogprobs = topLogprobs
        self.topP = topP
        self.user = user
    }

    public init(
        model: String? = nil,
        frequencyPenalty: Double? = nil,
        logitBias: [String: Double]? = nil,
        logprobs: Bool? = nil,
        maxCompletionTokens: Int? = nil,
        n: Int? = nil,
        parallelToolCalls: Bool? = nil,
        presencePenalty: Double? = nil,
        responseFormat: ResponseFormat? = nil,
        seed: Int? = nil,
        stop: [String]? = nil,
        store: Bool? = nil,
        stream: Bool? = nil,
        streamOptions: StreamOptions? = nil,
        temperature: Double? = nil,
        tools: [Tool]? = nil,
        toolChoice: ToolChoice? = nil,
        topLogprobs: Int? = nil,
        topP: Double? = nil,
        user: String? = nil,
        @ChatMessageBuilder messages: () -> [Message]
    ) {
        self.init(
            model: model,
            messages: messages(),
            frequencyPenalty: frequencyPenalty,
            logitBias: logitBias,
            logprobs: logprobs,
            maxCompletionTokens: maxCompletionTokens,
            n: n,
            parallelToolCalls: parallelToolCalls,
            presencePenalty: presencePenalty,
            responseFormat: responseFormat,
            seed: seed,
            stop: stop,
            store: store,
            stream: stream,
            streamOptions: streamOptions,
            temperature: temperature,
            tools: tools,
            toolChoice: toolChoice,
            topLogprobs: topLogprobs,
            topP: topP,
            user: user
        )
    }

    public var cacheIdentifier: CacheIdentifier {
        CacheIdentifier(request: self)
    }
}

extension ChatRequest: ChatRequestConvertible {
    public func asChatRequestBody() throws -> ChatRequestBody {
        var body = ChatRequestBody(
            messages: Self.normalize(messages),
            frequencyPenalty: frequencyPenalty,
            logitBias: logitBias.map(Self.normalizeLogitBias),
            logprobs: logprobs,
            maxCompletionTokens: maxCompletionTokens,
            n: n,
            parallelToolCalls: parallelToolCalls,
            presencePenalty: presencePenalty,
            responseFormat: responseFormat,
            seed: seed,
            stop: stop?.map(Self.normalizeStop),
            store: store,
            stream: stream,
            streamOptions: streamOptions,
            temperature: temperature,
            tools: tools.map(Self.normalizeTools),
            toolChoice: toolChoice.map(Self.normalizeToolChoice),
            topLogprobs: topLogprobs,
            topP: topP,
            user: Self.trimmed(user)
        )
        body.model = Self.trimmed(model)
        if body.stream != true {
            body.streamOptions = nil
        }
        return body
    }
}

// MARK: - Cache Identifier

public extension ChatRequest {
    struct CacheIdentifier: Sendable, Hashable {
        public let rawValue: String

        init(request: ChatRequest) {
            do {
                let canonical = try request.asChatRequestBody()
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
                let data = try encoder.encode(canonical)
                let digest = SHA256.hash(data: data)
                rawValue = digest.map { String(format: "%02x", $0) }.joined()
            } catch {
                rawValue = ""
            }
        }
    }
}

// MARK: - Normalization Helpers

private extension ChatRequest {
    static func normalize(_ messages: [Message]) -> [Message] {
        messages.map(normalizeMessage)
    }

    static func normalizeMessage(_ message: Message) -> Message {
        switch message {
        case let .assistant(content, name, refusal, toolCalls):
            .assistant(
                content: normalizeAssistantContent(content),
                name: trimmed(name),
                refusal: trimmed(refusal),
                toolCalls: normalizeToolCalls(toolCalls)
            )
        case let .developer(content, name):
            .developer(content: normalizeTextContent(content), name: trimmed(name))
        case let .system(content, name):
            .system(content: normalizeTextContent(content), name: trimmed(name))
        case let .tool(content, toolCallID):
            .tool(content: normalizeTextContent(content), toolCallID: trimmed(toolCallID) ?? toolCallID)
        case let .user(content, name):
            .user(content: normalizeUserContent(content), name: trimmed(name))
        }
    }

    static func normalizeAssistantContent(
        _ content: MessageContent<String, [String]>?
    ) -> MessageContent<String, [String]>? {
        guard let content else { return nil }
        switch content {
        case let .text(text):
            guard let normalized = trimmed(text), !normalized.isEmpty else { return nil }
            return .text(normalized)
        case let .parts(parts):
            let normalized = parts
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            return normalized.isEmpty ? nil : .parts(normalized)
        }
    }

    static func normalizeTextContent(
        _ content: MessageContent<String, [String]>
    ) -> MessageContent<String, [String]> {
        switch content {
        case let .text(text):
            return .text(trimmed(text) ?? "")
        case let .parts(parts):
            let normalized = parts
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            return normalized.isEmpty ? .parts([]) : .parts(normalized)
        }
    }

    static func normalizeUserContent(
        _ content: MessageContent<String, [ContentPart]>
    ) -> MessageContent<String, [ContentPart]> {
        switch content {
        case let .text(text):
            return .text(trimmed(text) ?? "")
        case let .parts(parts):
            let normalized = parts.compactMap(normalizeContentPart)
            return .parts(normalized)
        }
    }

    static func normalizeContentPart(_ part: ContentPart) -> ContentPart? {
        switch part {
        case let .text(text):
            guard let normalized = trimmed(text), !normalized.isEmpty else { return nil }
            return .text(normalized)
        case let .imageURL(url, detail):
            return .imageURL(url, detail: detail)
        case let .audioBase64(data, format):
            guard let normalized = trimmed(data), !normalized.isEmpty else { return nil }
            return .audioBase64(normalized, format: format)
        }
    }

    static func normalizeToolCalls(
        _ toolCalls: [Message.ToolCall]?
    ) -> [Message.ToolCall]? {
        guard let toolCalls, !toolCalls.isEmpty else { return nil }
        let normalized = toolCalls.map { call in
            Message.ToolCall(
                id: trimmed(call.id) ?? call.id,
                function: .init(
                    name: trimmed(call.function.name) ?? call.function.name,
                    arguments: trimmed(call.function.arguments)
                )
            )
        }
        return normalized.sorted { $0.id < $1.id }
    }

    static func normalizeLogitBias(_ bias: [String: Double]) -> [String: Double] {
        var normalized: [String: Double] = [:]
        for (key, value) in bias {
            normalized[key.trimmingCharacters(in: .whitespacesAndNewlines)] = value
        }
        return normalized
    }

    static func normalizeStop(_ value: String) -> String {
        trimmed(value) ?? value
    }

    static func normalizeTools(_ tools: [Tool]) -> [Tool] {
        tools.sorted(by: toolSortKey).map(normalizeTool)
    }

    static func normalizeToolChoice(_ choice: ToolChoice) -> ToolChoice {
        switch choice {
        case .none, .auto, .required:
            choice
        case let .specific(functionName):
            .specific(functionName: trimmed(functionName) ?? functionName)
        }
    }

    static func normalizeTool(_ tool: Tool) -> Tool {
        switch tool {
        case let .function(name, description, parameters, strict):
            .function(
                name: trimmed(name) ?? name,
                description: trimmed(description),
                parameters: parameters,
                strict: strict
            )
        }
    }

    static func toolSortKey(lhs: Tool, rhs: Tool) -> Bool {
        switch (lhs, rhs) {
        case let (.function(lhsName, _, _, _), .function(rhsName, _, _, _)):
            lhsName < rhsName
        }
    }

    static func trimmed(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func trimmed(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
