import AppCore
import Foundation

// MARK: - Claude Provider

/// Claude API provider implementation
public final class ClaudeProvider: LLMProviderProtocol, @unchecked Sendable {
    // MARK: - Properties

    public let id = "claude"
    public let name = "Anthropic Claude"

    public var capabilities: LLMProviderCapabilities {
        LLMProviderCapabilities(
            supportsStreaming: true,
            supportsEmbeddings: false,
            supportsVision: true,
            supportsFunctionCalling: true,
            maxTokens: 4096,
            maxContextLength: 200_000,
            supportedModels: [
                LLMModel(
                    id: "claude-3-opus-20240229",
                    name: "Claude 3 Opus",
                    description: "Most capable model for complex tasks",
                    contextLength: 200_000,
                    pricing: ModelPricing(
                        inputPricePerMillion: 15.0,
                        outputPricePerMillion: 75.0
                    )
                ),
                LLMModel(
                    id: "claude-3-sonnet-20240229",
                    name: "Claude 3 Sonnet",
                    description: "Balanced performance and cost",
                    contextLength: 200_000,
                    pricing: ModelPricing(
                        inputPricePerMillion: 3.0,
                        outputPricePerMillion: 15.0
                    )
                ),
                LLMModel(
                    id: "claude-3-haiku-20240307",
                    name: "Claude 3 Haiku",
                    description: "Fast and efficient for simple tasks",
                    contextLength: 200_000,
                    pricing: ModelPricing(
                        inputPricePerMillion: 0.25,
                        outputPricePerMillion: 1.25
                    )
                ),
                LLMModel(
                    id: "claude-3-5-sonnet-20241022",
                    name: "Claude 3.5 Sonnet",
                    description: "Latest and most capable Sonnet model",
                    contextLength: 200_000,
                    pricing: ModelPricing(
                        inputPricePerMillion: 3.0,
                        outputPricePerMillion: 15.0
                    )
                ),
            ]
        )
    }

    private let baseURL = "https://api.anthropic.com/v1"
    private let apiVersion = "2023-06-01"
    private var apiKey: String?
    private let session: URLSession

    // MARK: - Initialization

    public init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 300
        session = URLSession(configuration: configuration)
    }

    // MARK: - LLMProviderProtocol

    public var isConfigured: Bool {
        get async {
            await LLMConfigurationManager.shared.isProviderConfigured(id)
        }
    }

    public func validateCredentials() async throws -> Bool {
        guard try await LLMConfigurationManager.shared.loadConfiguration(for: id) != nil else {
            throw LLMProviderError.notConfigured
        }

        // Test API key with a simple request
        let testRequest = LLMChatRequest(
            messages: [LLMMessage(role: .user, content: "Hi")],
            model: "claude-3-haiku-20240307",
            maxTokens: 10
        )

        do {
            _ = try await chatCompletion(testRequest)
            return true
        } catch {
            if case LLMProviderError.invalidCredentials = error {
                return false
            }
            throw error
        }
    }

    public func chatCompletion(_ request: LLMChatRequest) async throws -> LLMChatResponse {
        guard let config = try await LLMConfigurationManager.shared.loadConfiguration(for: id) else {
            throw LLMProviderError.notConfigured
        }

        // Build request body
        var body: [String: Any] = [
            "model": request.model,
            "messages": request.messages.map { message in
                ["role": message.role.rawValue, "content": message.content]
            },
            "max_tokens": request.maxTokens ?? 4096,
            "temperature": request.temperature,
        ]

        if let systemPrompt = request.systemPrompt {
            body["system"] = systemPrompt
        }

        // Make API request
        guard let url = URL(string: "\(baseURL)/messages") else {
            throw LLMProviderError.networkError("Invalid URL")
        }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(config.apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMProviderError.networkError("Invalid response")
        }

        if httpResponse.statusCode == 401 {
            throw LLMProviderError.invalidCredentials
        }

        if httpResponse.statusCode == 429 {
            throw LLMProviderError.rateLimitExceeded
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let errorMessage = errorBody?["error"] as? [String: Any]
            let message = errorMessage?["message"] as? String ?? "Unknown error"
            throw LLMProviderError.networkError("HTTP \(httpResponse.statusCode): \(message)")
        }

        // Parse response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LLMProviderError.invalidResponse("Invalid JSON")
        }

        guard let id = json["id"] as? String,
              let model = json["model"] as? String,
              let content = json["content"] as? [[String: Any]],
              let firstContent = content.first,
              let text = firstContent["text"] as? String,
              let usage = json["usage"] as? [String: Any],
              let inputTokens = usage["input_tokens"] as? Int,
              let outputTokens = usage["output_tokens"] as? Int
        else {
            throw LLMProviderError.invalidResponse("Missing required fields")
        }

        let message = LLMMessage(role: .assistant, content: text)
        let tokenUsage = TokenUsage(promptTokens: inputTokens, completionTokens: outputTokens)
        let finishReason = (json["stop_reason"] as? String == "max_tokens") ? FinishReason.length : FinishReason.stop

        return LLMChatResponse(
            id: id,
            model: model,
            message: message,
            usage: tokenUsage,
            finishReason: finishReason
        )
    }

    public func streamChatCompletion(_ request: LLMChatRequest) -> AsyncThrowingStream<LLMStreamChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard let config = try await LLMConfigurationManager.shared.loadConfiguration(for: id) else {
                        throw LLMProviderError.notConfigured
                    }

                    // Build request body
                    var body: [String: Any] = [
                        "model": request.model,
                        "messages": request.messages.map { message in
                            ["role": message.role.rawValue, "content": message.content]
                        },
                        "max_tokens": request.maxTokens ?? 4096,
                        "temperature": request.temperature,
                        "stream": true,
                    ]

                    if let systemPrompt = request.systemPrompt {
                        body["system"] = systemPrompt
                    }

                    // Make streaming request
                    guard let url = URL(string: "\(baseURL)/messages") else {
                        throw LLMProviderError.networkError("Invalid URL")
                    }
                    var urlRequest = URLRequest(url: url)
                    urlRequest.httpMethod = "POST"
                    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    urlRequest.setValue(config.apiKey, forHTTPHeaderField: "x-api-key")
                    urlRequest.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
                    urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, response) = try await session.bytes(for: urlRequest)

                    guard let httpResponse = response as? HTTPURLResponse,
                          httpResponse.statusCode == 200
                    else {
                        throw LLMProviderError.networkError("Stream request failed")
                    }

                    // Process SSE stream
                    for try await line in bytes.lines where line.hasPrefix("data: ") {
                        let jsonString = String(line.dropFirst(6))
                        if jsonString == "[DONE]" {
                            continuation.finish()
                            break
                        }

                        if let data = jsonString.data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let type = json["type"] as? String {
                            if type == "content_block_delta",
                               let delta = json["delta"] as? [String: Any],
                               let text = delta["text"] as? String {
                                continuation.yield(LLMStreamChunk(delta: text))
                            } else if type == "message_stop" {
                                continuation.yield(LLMStreamChunk(delta: "", finishReason: .stop))
                            }
                        }
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    public func generateEmbeddings(_: String) async throws -> [Float] {
        throw LLMProviderError.embeddingsNotSupported
    }

    public func tokenCount(for text: String) async throws -> Int {
        // Rough estimation for Claude - actual tokenization is more complex
        // Claude uses a similar tokenizer to GPT models
        let words = text.split(separator: " ").count
        return Int(Double(words) * 1.3)
    }

    public func getSettings() -> LLMProviderSettings {
        LLMProviderSettings(
            apiEndpoint: baseURL,
            apiVersion: apiVersion,
            timeout: 30,
            retryCount: 3
        )
    }
}
