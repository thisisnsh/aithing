//
//  TitleGenerator.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 12/4/25.
//

import Foundation

// MARK: - Public API

/// Generates a title for a chat based on the query and response.
///
/// Creates a three-word title that summarizes the conversation.
/// Returns the existing tab title if:
/// - The query is empty
/// - The tab already has a valid title
/// - The version is breakglassed or expired
/// - The API request fails
///
/// - Parameter context: The title generation context
/// - Returns: The generated title or the existing tab title
func createTitle(context: TitleGenerationContext) async -> String {
    // Early returns for edge cases
    if context.query.isEmpty {
        return context.tabTitle
    }
    if !context.tabTitle.isEmpty && context.tabTitle != "New Chat" {
        return context.tabTitle
    }

    // Skip if version checks fail
    if await shouldSkipTitleGeneration(firestoreManager: context.firestoreManager) {
        return context.tabTitle
    }

    // Generate the title via API
    return await generateTitleViaAPI(context: context)
}

// MARK: - Private Helpers

/// Checks if title generation should be skipped due to version issues.
///
/// - Parameter firestoreManager: The Firestore manager instance
/// - Returns: `true` if generation should be skipped
private func shouldSkipTitleGeneration(firestoreManager: FirestoreManager) async -> Bool {
    // Check if version is breakglassed
    if await firestoreManager.getBreakglass() {
        return true
    }

    // Check if version is expired
    if await firestoreManager.getExpired() {
        return true
    }

    return false
}

/// Generates the title by calling the appropriate provider API.
///
/// - Parameter context: The title generation context
/// - Returns: The generated title or the fallback tab title
private func generateTitleViaAPI(context: TitleGenerationContext) async -> String {
    // Determine the provider for the model
    let provider = context.provider

    guard let providerImpl = AIProviderRegistry.shared.getProvider(for: provider) else {
        return context.tabTitle
    }

    let prompt = buildTitlePrompt(query: context.query, response: context.response)
    let messages = [ChatItem(role: .user, payload: .text(text: prompt))]

    guard
        let request = providerImpl.buildRequest(
            apiKey: context.apiKey,
            model: context.model,
            messages: messages,
            tools: [],
            systemMessages: [],
            maxTokens: 1024,
            stream: false
        )
    else {
        return context.tabTitle
    }

    do {
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
            (200..<300).contains(httpResponse.statusCode)
        else {
            logger.error("Bad HTTP response for title generation")
            return context.tabTitle
        }

        return parseTitleResponse(data: data, provider: provider) ?? context.tabTitle
    } catch {
        logger.error("Error generating title: \(error.localizedDescription)")
        return context.tabTitle
    }
}

/// Builds the prompt for title generation.
///
/// - Parameters:
///   - query: The user's query
///   - response: The AI's response
/// - Returns: The formatted prompt string
private func buildTitlePrompt(query: String, response: String) -> String {
    """
    Create a title based on the user query and the AI's first response.
    The title must contain less than 32 characters, each using alphanumeric characters only.
    Spaces between words are allowed. The title must not be a question.
    Output only the title.                

    User Query:
    \(buildQuery(query: query))

    AI First Response:
    \(response)    
    """
}

/// Parses the title from the API response based on the provider.
///
/// - Parameters:
///   - data: The response data
///   - provider: The AI provider
/// - Returns: The extracted title or nil if parsing fails
private func parseTitleResponse(data: Data, provider: AIProvider) -> String? {
    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        return nil
    }

    switch provider {
    case .anthropic:
        return parseAnthropicResponse(json: json)
    case .openai:
        return parseOpenAIResponse(json: json)
    case .google:
        return parseGoogleResponse(json: json)
    }
}

private func parseAnthropicResponse(json: [String: Any]) -> String? {
    guard let contentArray = json["content"] as? [[String: Any]] else {
        return nil
    }

    for item in contentArray {
        if let type = item["type"] as? String, type == "text",
            let text = item["text"] as? String
        {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    return nil
}

private func parseOpenAIResponse(json: [String: Any]) -> String? {
    guard let choices = json["choices"] as? [[String: Any]],
        let firstChoice = choices.first,
        let message = firstChoice["message"] as? [String: Any],
        let content = message["content"] as? String
    else {
        return nil
    }
    return content.trimmingCharacters(in: .whitespacesAndNewlines)
}

private func parseGoogleResponse(json: [String: Any]) -> String? {
    guard let candidates = json["candidates"] as? [[String: Any]],
        let firstCandidate = candidates.first,
        let content = firstCandidate["content"] as? [String: Any],
        let parts = content["parts"] as? [[String: Any]],
        let firstPart = parts.first,
        let text = firstPart["text"] as? String
    else {
        return nil
    }
    return text.trimmingCharacters(in: .whitespacesAndNewlines)
}
