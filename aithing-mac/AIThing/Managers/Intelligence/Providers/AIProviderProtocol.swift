//
//  AIProviderProtocol.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 12/5/25.
//

import Foundation
import MCP

// MARK: - Stream Event

/// Represents events that can occur during streaming responses from AI providers.
enum StreamEvent {
    /// Text content received from the model. Wait for done.
    case text(String)

    /// Last text content received from the model.
    case endText(String)

    /// Tool use block started with id and name. Wait for toolInput and done.
    case toolUseStart(id: String, name: String)

    /// Tool use in one-go. Call the tool
    case toolUse(id: String, name: String, input: String)

    /// Partial JSON input for tool use.
    case toolInput(String)

    /// Stream completed with a stop reason. Take required action.
    case done(stopReason: StopReason)

    /// Error occurred during streaming.
    case error(String)
}

/// Represents the reason why the model stopped generating.
enum StopReason {
    case endTurn
    case stopSequence
    case maxTokens
    case toolUse
    case unknown

    init(from string: String) {
        switch string {
        // Anthropic: "end_turn"
        // OpenAI:    "stop"
        // Google:    "STOP"
        case "end_turn", "stop", "STOP":
            self = .endTurn

        // Anthropic: "max_tokens"
        // OpenAI:    "length"
        // Google:    "MAX_TOKENS"
        case "max_tokens", "length", "MAX_TOKENS":
            self = .maxTokens

        // Anthropic: "tool_use"
        // OpenAI:    "tool_calls"
        case "tool_use", "tool_calls":
            self = .toolUse

        // Anthropic: "stop_sequence"
        // OpenAI:    "content_filter"
        case "stop_sequence", "content_filter":
            self = .stopSequence

        default:
            self = .unknown
        }
    }
}

// MARK: - Provider Protocol

/// Protocol that all AI provider implementations must conform to.
protocol AIProviderProtocol {
    /// The provider type this implementation handles.
    var provider: AIProvider { get }

    /// Builds an API request for the provider.
    ///
    /// - Parameters:
    ///   - apiKey: The API key for authentication
    ///   - model: The model identifier to use
    ///   - messages: The conversation messages
    ///   - tools: Available tools for the model
    ///   - systemMessages: System messages/instructions
    ///   - maxTokens: Maximum tokens in the response
    /// - Returns: Configured URLRequest or nil if invalid
    func buildRequest(
        apiKey: String,
        model: String,
        messages: [ChatItem],
        tools: [Tool],
        systemMessages: [ChatPayload],
        maxTokens: Int,
        stream: Bool
    ) -> URLRequest?

    /// Parses a single line from the streaming response.
    ///
    /// - Parameter line: A line from the SSE stream
    /// - Returns: A StreamEvent if the line contains relevant data, nil otherwise
    func parseStreamLine(_ line: String) -> StreamEvent?

    /// Converts the internal message format to the provider's expected format.
    ///
    /// - Parameter messages: Messages in the internal format
    /// - Returns: Messages converted to provider's format
    func convertMessages(_ messages: [ChatItem]) -> [[String: Any]]

    /// Converts the internal tool format to the provider's expected format.
    ///
    /// - Parameter tools: Tools in the internal format
    /// - Returns: Tools converted to provider's format
    func convertTools(_ tools: [Tool]) -> [[String: Any]]

    func convertSystemMessages(_ messages: [ChatPayload]) -> [[String: Any]]

    /// Builds a tool result message in the provider's format.
    ///
    /// - Parameters:
    ///   - toolUseId: The ID of the tool use
    ///   - result: The tool execution result
    /// - Returns: A message dictionary in the provider's format
    func buildToolResultMessage(toolUseId: String, toolName: String, result: String) -> [ChatItem]

    /// Builds an assistant message with tool use in the provider's format.
    ///
    /// - Parameters:
    ///   - text: Optional text content
    ///   - toolUseId: The ID of the tool use
    ///   - toolName: The name of the tool
    ///   - toolInput: The tool input as a dictionary
    /// - Returns: A message dictionary in the provider's format
    func buildAssistantToolUseMessage(text: String?, toolUseId: String, toolName: String, toolInput: [String: Any]) -> [ChatItem]

    /// Builds an assistant text message in the provider's format.
    ///
    /// - Parameter text: The text content
    /// - Returns: A message dictionary in the provider's format
    func buildAssistantTextMessage(text: String) -> [ChatItem]
}

// MARK: - Provider Registry

/// Registry for AI provider implementations.
final class AIProviderRegistry {
    static let shared = AIProviderRegistry()

    private var providers: [AIProvider: AIProviderProtocol] = [:]

    private init() {
        // Register default providers
        register(AnthropicProvider())
        register(OpenAIProvider())
        register(GoogleProvider())
    }

    /// Registers a provider implementation.
    func register(_ provider: AIProviderProtocol) {
        providers[provider.provider] = provider
    }

    /// Gets the provider implementation for a given provider type.
    func getProvider(for type: AIProvider) -> AIProviderProtocol? {
        providers[type]
    }
}
