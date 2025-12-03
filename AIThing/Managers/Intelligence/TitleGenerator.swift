//
//  TitleGenerator.swift
//  AIThing
//
//  Helper function for generating chat titles.
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

/// Generates the title by calling the Anthropic API.
///
/// - Parameter context: The title generation context
/// - Returns: The generated title or the fallback tab title
private func generateTitleViaAPI(context: TitleGenerationContext) async -> String {
    guard let request = buildTitleRequest(context: context) else {
        return context.tabTitle
    }
    
    do {
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode)
        else {
            logger.error("Bad HTTP response")
            return context.tabTitle
        }
        
        return parseTitleResponse(data: data) ?? context.tabTitle
    } catch {
        return context.tabTitle
    }
}

/// Builds the API request for title generation.
///
/// - Parameter context: The title generation context
/// - Returns: Configured URLRequest or nil if URL is invalid
private func buildTitleRequest(context: TitleGenerationContext) -> URLRequest? {
    guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
        return nil
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
    request.setValue("\(context.apiKey)", forHTTPHeaderField: "x-api-key")
    request.setValue("extended-cache-ttl-2025-04-11", forHTTPHeaderField: "anthropic-beta")
    
    let prompt = buildTitlePrompt(query: context.query, response: context.response)
    let body = buildTitleRequestBody(model: context.model, prompt: prompt)
    
    request.httpBody = try? JSONSerialization.data(withJSONObject: body)
    return request
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
    The title must contain exactly three words, each using alphanumeric characters only.
    Spaces between words are allowed. The title must not be a question.
    Output only the title.                

    User Query:
    \(buildQuery(query: query))

    AI First Response:
    \(response)    
    """
}

/// Builds the request body for title generation.
///
/// - Parameters:
///   - model: The model identifier
///   - prompt: The prompt text
/// - Returns: The request body dictionary
private func buildTitleRequestBody(model: String, prompt: String) -> [String: Any] {
    let input = [
        [
            "role": "user",
            "content": [
                [
                    "type": "text",
                    "text": prompt,
                ]
            ],
        ]
    ]
    
    return [
        "model": model,
        "stream": false,
        "max_tokens": 32,
        "temperature": 0.7,
        "messages": input,
    ]
}

/// Parses the title from the API response.
///
/// - Parameter data: The response data
/// - Returns: The extracted title or nil if parsing fails
private func parseTitleResponse(data: Data) -> String? {
    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let contentArray = json["content"] as? [[String: Any]]
    else {
        return nil
    }
    
    // Find the first item with type = "text"
    for item in contentArray {
        if let type = item["type"] as? String, type == "text",
           let text = item["text"] as? String {
            return text
        }
    }
    
    return nil
}
