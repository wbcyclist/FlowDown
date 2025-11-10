//
//  MLXModelCoordinatorTests.swift
//  ChatClientKitTests
//
//  Created by GPT-5 Codex on 2025/11/10.
//

@testable import ChatClientKit
import Foundation
import MLX
import MLXLMCommon
import MLXNN
import Testing
import Tokenizers

@Suite("MLX Model Coordinator")
struct MLXModelCoordinatorTests {
    @Test("Coordinator caches containers for identical configuration and kind")
    func coordinator_cachesContainerForSameKey() async throws {
        let loader = MockLoader()
        let coordinator = MLXModelCoordinator(loader: loader)
        let configuration = makeConfiguration(label: "cache")

        let first = try await coordinator.container(for: configuration, kind: .llm)
        let second = try await coordinator.container(for: configuration, kind: .llm)

        #expect(first === second)

        let counts = await loader.loadCounts()
        #expect(counts.llm == 1)
        #expect(counts.vlm == 0)
    }

    @Test("Coordinator releases previous container when switching kinds")
    func coordinator_releasesPreviousContainerWhenSwitchingKinds() async throws {
        let loader = MockLoader()
        let coordinator = MLXModelCoordinator(loader: loader)
        let configuration = makeConfiguration(label: "switch")

        let llmContainer = try await coordinator.container(for: configuration, kind: .llm)
        let vlmContainer = try await coordinator.container(for: configuration, kind: .vlm)
        let llmContainerReloaded = try await coordinator.container(for: configuration, kind: .llm)

        #expect(llmContainer !== vlmContainer)
        #expect(llmContainer !== llmContainerReloaded)

        let counts = await loader.loadCounts()
        #expect(counts.llm == 2)
        #expect(counts.vlm == 1)
    }

    @Test("Coordinator reuses in-flight task for identical concurrent requests")
    func coordinator_reusesInFlightLoads() async throws {
        let loader = MockLoader(simulateDelay: 0.05)
        let coordinator = MLXModelCoordinator(loader: loader)
        let configuration = makeConfiguration(label: "concurrent")

        async let first = coordinator.container(for: configuration, kind: .vlm)
        async let second = coordinator.container(for: configuration, kind: .vlm)

        let containers = try await (first, second)
        #expect(containers.0 === containers.1)

        let counts = await loader.loadCounts()
        #expect(counts.vlm == 1)
    }

    @Test("Reset clears cached container")
    func coordinator_resetClearsCache() async throws {
        let loader = MockLoader()
        let coordinator = MLXModelCoordinator(loader: loader)
        let configuration = makeConfiguration(label: "reset")

        let first = try await coordinator.container(for: configuration, kind: .llm)
        await coordinator.reset()
        let second = try await coordinator.container(for: configuration, kind: .llm)

        #expect(first !== second)

        let counts = await loader.loadCounts()
        #expect(counts.llm == 2)
    }
}

private func makeConfiguration(label: String) -> ModelConfiguration {
    if let fixture = TestHelpers.fixtureURL(named: "mlx_testing_model") {
        return ModelConfiguration(directory: fixture)
    }

    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("mlx-model-\(label)")
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return ModelConfiguration(directory: directory)
}

private actor MockLoader: MLXModelLoading {
    private(set) var llmLoadCount = 0
    private(set) var vlmLoadCount = 0
    private let simulateDelay: TimeInterval

    init(simulateDelay: TimeInterval = 0) {
        self.simulateDelay = simulateDelay
    }

    func loadLLM(configuration: ModelConfiguration) async throws -> ModelContainer {
        llmLoadCount += 1
        if simulateDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(simulateDelay * 1_000_000_000))
        }
        return StubContainerFactory.makeContainer(configuration: configuration, label: "llm-\(llmLoadCount)")
    }

    func loadVLM(configuration: ModelConfiguration) async throws -> ModelContainer {
        vlmLoadCount += 1
        if simulateDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(simulateDelay * 1_000_000_000))
        }
        return StubContainerFactory.makeContainer(configuration: configuration, label: "vlm-\(vlmLoadCount)")
    }

    func loadCounts() -> (llm: Int, vlm: Int) {
        (llmLoadCount, vlmLoadCount)
    }
}

private enum StubContainerFactory {
    static func makeContainer(configuration: ModelConfiguration, label: String) -> ModelContainer {
        let tokenizer = StubTokenizer()
        let processor = StubUserInputProcessor()
        let model = StubLanguageModel()
        let context = ModelContext(
            configuration: configuration,
            model: model,
            processor: processor,
            tokenizer: tokenizer
        )
        return ModelContainer(context: context)
    }
}

private final class StubLanguageModel: Module, LanguageModel {
    override init() {
        super.init()
    }

    func prepare(_ input: LMInput, cache: [KVCache], windowSize: Int?) throws -> PrepareResult {
        .tokens(input.text)
    }

    func callAsFunction(_ input: LMInput.Text, cache: [KVCache]?, state: LMOutput.State?) -> LMOutput {
        LMOutput(logits: MLXArray(0))
    }

    func callAsFunction(_ inputs: MLXArray, cache: [KVCache]?) -> MLXArray {
        inputs
    }

    func newCache(parameters: GenerateParameters?) -> [KVCache] {
        []
    }
}

private struct StubUserInputProcessor: UserInputProcessor {
    func prepare(input: UserInput) async throws -> LMInput {
        let tokenCount: Int = {
            switch input.prompt {
            case .text(let text):
                return text.count
            case .messages(let messages):
                return messages.count
            case .chat(let messages):
                return messages.count
            }
        }()

        return LMInput(text: .init(tokens: MLXArray(tokenCount)))
    }
}

private final class StubTokenizer: Tokenizer {
    func tokenize(text: String) -> [String] {
        text.split(separator: " ").map(String.init)
    }

    func encode(text: String) -> [Int] {
        [text.count]
    }

    func encode(text: String, addSpecialTokens: Bool) -> [Int] {
        encode(text: text)
    }

    func callAsFunction(_ text: String, addSpecialTokens: Bool) -> [Int] {
        encode(text: text, addSpecialTokens: addSpecialTokens)
    }

    func decode(tokens: [Int]) -> String {
        decode(tokens: tokens, skipSpecialTokens: false)
    }

    func decode(tokens: [Int], skipSpecialTokens: Bool) -> String {
        tokens.map(String.init).joined(separator: ",")
    }

    func convertTokenToId(_ token: String) -> Int? {
        token.count
    }

    func convertTokensToIds(_ tokens: [String]) -> [Int?] {
        tokens.map { _ in 0 }
    }

    func convertIdToToken(_ id: Int) -> String? {
        String(id)
    }

    func convertIdsToTokens(_ ids: [Int]) -> [String?] {
        ids.map { String($0) }
    }

    var bosToken: String? { nil }
    var bosTokenId: Int? { nil }
    var eosToken: String? { nil }
    var eosTokenId: Int? { nil }
    var unknownToken: String? { nil }
    var unknownTokenId: Int? { nil }
    var hasChatTemplate: Bool { false }

    func applyChatTemplate(messages: [Message]) throws -> [Int] {
        [messages.count]
    }

    func applyChatTemplate(messages: [Message], tools: [ToolSpec]?) throws -> [Int] {
        [messages.count]
    }

    func applyChatTemplate(messages: [Message], tools: [ToolSpec]?, additionalContext: [String: Any]?) throws -> [Int] {
        [messages.count]
    }

    func applyChatTemplate(messages: [Message], chatTemplate: ChatTemplateArgument) throws -> [Int] {
        [messages.count]
    }

    func applyChatTemplate(messages: [Message], chatTemplate: String) throws -> [Int] {
        [messages.count]
    }

    func applyChatTemplate(
        messages: [Message],
        chatTemplate: ChatTemplateArgument?,
        addGenerationPrompt: Bool,
        truncation: Bool,
        maxLength: Int?,
        tools: [ToolSpec]?
    ) throws -> [Int] {
        [messages.count]
    }

    func applyChatTemplate(
        messages: [Message],
        chatTemplate: ChatTemplateArgument?,
        addGenerationPrompt: Bool,
        truncation: Bool,
        maxLength: Int?,
        tools: [ToolSpec]?,
        additionalContext: [String: Any]?
    ) throws -> [Int] {
        [messages.count]
    }
}

