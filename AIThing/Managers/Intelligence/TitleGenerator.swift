//
//  TitleGenerator.swift
//  AIThing
//
//  Helper function for generating chat titles.
//

import Foundation

func createTitle(
    query: String,
    response: String,
    model: String,
    apiKey: String,
    tabTitle: String,
    firestoreManager: FirestoreManager
) async -> String {
    if query.isEmpty {
        return tabTitle
    }
    if !tabTitle.isEmpty && tabTitle != "New Chat" {
        return tabTitle
    }

    // Check if version is breakglassed
    if await firestoreManager.getBreakglass() {
        return tabTitle
    }

    // Check if version is expired
    if await firestoreManager.getExpired() {
        return tabTitle
    }

    guard let url = URL(string: "https://api.anthropic.com/v1/messages") else { return tabTitle }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
    request.setValue("\(apiKey)", forHTTPHeaderField: "x-api-key")
    request.setValue("extended-cache-ttl-2025-04-11", forHTTPHeaderField: "anthropic-beta")

    let prompt = """
        Create a title based on the user query and the AI's first response.
        The title must contain exactly three words, each using alphanumeric characters only.
        Spaces between words are allowed. The title must not be a question.
        Output only the title.                

        User Query:
        \(buildQuery(query: query))

        AI First Response:
        \(response)    
        """

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

    let body: [String: Any] = [
        "model": model,
        "stream": false,
        "max_tokens": 32,
        "temperature": 0.7,
        "messages": input,
    ]

    request.httpBody = try? JSONSerialization.data(withJSONObject: body)

    do {
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
            (200..<300).contains(httpResponse.statusCode)
        else {
            logger.error("Bad HTTP response")
            return tabTitle
        }

        // Parse JSON manually
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let contentArray = json["content"] as? [[String: Any]]
        {
            // Find the first item with type = "text"
            for item in contentArray {
                if let type = item["type"] as? String, type == "text",
                    let text = item["text"] as? String
                {
                    return text
                }
            }
        }
        return tabTitle
    } catch {
        return tabTitle
    }
}

