import AppCore
import Foundation

// MARK: - Gemini Provider

/// Google Gemini AI provider implementation
public final class GeminiProvider: LLMProviderProtocol, @unchecked Sendable {
    // MARK: - Properties

    public let id = "gemini"
    public let name = "Google Gemini"

    public var capabilities: LLMProviderCapabilities {
        LLMProviderCapabilities(
            supportsStreaming: true,
            supportsEmbeddings: true,
            supportsVision: true,
            supportsFunctionCalling: true,
            maxTokens: 8192,
            maxContextLength: 1_000_000,
            supportedModels: [
                LLMModel(
                    id: "gemini-2.0-flash-exp",
                    name: "Gemini 2.0 Flash",
                    description: "Latest Gemini 2.0 Flash model",
                    contextLength: 1_000_000,
                    pricing: ModelPricing(
                        inputPricePerMillion: 0.075,
                        outputPricePerMillion: 0.30
                    )
                ),
                LLMModel(
                    id: "gemini-1.5-pro",
                    name: "Gemini 1.5 Pro",
                    description: "Advanced reasoning and complex tasks",
                    contextLength: 2_000_000,
                    pricing: ModelPricing(
                        inputPricePerMillion: 1.25,
                        outputPricePerMillion: 5.00
                    )
                ),
                LLMModel(
                    id: "gemini-1.5-flash",
                    name: "Gemini 1.5 Flash",
                    description: "Fast and efficient model",
                    contextLength: 1_000_000,
                    pricing: ModelPricing(
                        inputPricePerMillion: 0.075,
                        outputPricePerMillion: 0.30
                    )
                ),
            ]
        )
    }

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
        guard let config = try await LLMConfigurationManager.shared.loadConfiguration(for: id) else {
            throw LLMProviderError.notConfigured
        }

        // Test API key with a simple request
        let testRequest = LLMChatRequest(
            messages: [LLMMessage(role: .user, content: "Hi")],
            model: "gemini-1.5-flash",
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

        // Build messages for Gemini format
        var contents: [[String: Any]] = []

        // Add system message if provided
        if let systemPrompt = request.systemPrompt {
            contents.append([
                "role": "user",
                "parts": [["text": "System: \(systemPrompt)"]]
            ])
        }

        // Add conversation messages
        for message in request.messages {
            let role = message.role == .assistant ? "model" : "user"
            contents.append([
                "role": role,
                "parts": [["text": message.content]]
            ])
        }

        // Build request body
        var body: [String: Any] = [
            "contents": contents,
            "generationConfig": [
                "temperature": request.temperature,
                "maxOutputTokens": request.maxTokens ?? 8192
            ]
        ]

        // Gemini API endpoint
        let url = "https://generativelanguage.googleapis.com/v1beta/models/\(request.model):generateContent?key=\(config.apiKey)"

        // Make API request
        guard let urlObject = URL(string: url) else {
            throw LLMProviderError.networkError("Invalid URL")
        }
        var urlRequest = URLRequest(url: urlObject)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMProviderError.networkError("Invalid response")
        }

        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw LLMProviderError.invalidCredentials
        }

        if httpResponse.statusCode == 429 {
            throw LLMProviderError.rateLimitExceeded
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let error = errorBody?["error"] as? [String: Any]
            let message = error?["message"] as? String ?? "Unknown error"
            throw LLMProviderError.networkError("HTTP \(httpResponse.statusCode): \(message)")
        }

        // Parse response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LLMProviderError.invalidResponse("Invalid JSON")
        }

        guard let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let text = firstPart["text"] as? String
        else {
            throw LLMProviderError.invalidResponse("Missing required fields")
        }

        let responseMessage = LLMMessage(
            role: .assistant,
            content: text
        )

        // Extract usage metadata if available
        let usage = json["usageMetadata"] as? [String: Any]
        let promptTokens = usage?["promptTokenCount"] as? Int ?? 0
        let completionTokens = usage?["candidatesTokenCount"] as? Int ?? 0

        let tokenUsage = TokenUsage(
            promptTokens: promptTokens,
            completionTokens: completionTokens
        )

        let finishReason = firstCandidate["finishReason"] as? String
        let reason: FinishReason = switch finishReason {
        case "MAX_TOKENS": .length
        case "SAFETY": .contentFilter
        default: .stop
        }

        return LLMChatResponse(
            id: UUID().uuidString,
            model: request.model,
            message: responseMessage,
            usage: tokenUsage,
            finishReason: reason
        )
    }

    public func streamChatCompletion(_ request: LLMChatRequest) -> AsyncThrowingStream<LLMStreamChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard let config = try await LLMConfigurationManager.shared.loadConfiguration(for: id) else {
                        throw LLMProviderError.notConfigured
                    }

                    // Build messages for Gemini format
                    var contents: [[String: Any]] = []

                    if let systemPrompt = request.systemPrompt {
                        contents.append([
                            "role": "user",
                            "parts": [["text": "System: \(systemPrompt)"]]
                        ])
                    }

                    for message in request.messages {
                        let role = message.role == .assistant ? "model" : "user"
                        contents.append([
                            "role": role,
                            "parts": [["text": message.content]]
                        ])
                    }

                    // Build request body
                    let body: [String: Any] = [
                        "contents": contents,
                        "generationConfig": [
                            "temperature": request.temperature,
                            "maxOutputTokens": request.maxTokens ?? 8192
                        ]
                    ]

                    // Gemini streaming endpoint
                    let url = "https://generativelanguage.googleapis.com/v1beta/models/\(request.model):streamGenerateContent?key=\(config.apiKey)"

                    guard let urlObject = URL(string: url) else {
                        throw LLMProviderError.networkError("Invalid URL")
                    }
                    var urlRequest = URLRequest(url: urlObject)
                    urlRequest.httpMethod = "POST"
                    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, response) = try await session.bytes(for: urlRequest)

                    guard let httpResponse = response as? HTTPURLResponse,
                          httpResponse.statusCode == 200
                    else {
                        throw LLMProviderError.networkError("Stream request failed")
                    }

                    // Process streaming response
                    for try await line in bytes.lines {
                        if let data = line.data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let candidates = json["candidates"] as? [[String: Any]],
                           let firstCandidate = candidates.first,
                           let content = firstCandidate["content"] as? [String: Any],
                           let parts = content["parts"] as? [[String: Any]],
                           let firstPart = parts.first,
                           let text = firstPart["text"] as? String {
                            continuation.yield(LLMStreamChunk(delta: text))

                            if let finishReason = firstCandidate["finishReason"] as? String {
                                let reason: FinishReason = switch finishReason {
                                case "MAX_TOKENS": .length
                                case "SAFETY": .contentFilter
                                default: .stop
                                }
                                continuation.yield(LLMStreamChunk(delta: "", finishReason: reason))
                                break
                            }
                        }
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    public func generateEmbeddings(_ text: String) async throws -> [Float] {
        guard let config = try await LLMConfigurationManager.shared.loadConfiguration(for: id) else {
            throw LLMProviderError.notConfigured
        }

        let body: [String: Any] = [
            "model": "models/text-embedding-004",
            "content": [
                "parts": [["text": text]]
            ]
        ]

        let url = "https://generativelanguage.googleapis.com/v1beta/models/text-embedding-004:embedContent?key=\(config.apiKey)"

        guard let urlObject = URL(string: url) else {
            throw LLMProviderError.networkError("Invalid URL")
        }
        var urlRequest = URLRequest(url: urlObject)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200
        else {
            throw LLMProviderError.networkError("Embeddings request failed")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let embedding = json["embedding"] as? [String: Any],
              let values = embedding["values"] as? [Double]
        else {
            throw LLMProviderError.invalidResponse("Invalid embeddings response")
        }

        return values.map { Float($0) }
    }

    public func tokenCount(for text: String) async throws -> Int {
        // Estimate based on character count (Gemini uses similar tokenization to GPT)
        text.count / 4
    }

    public func getSettings() -> LLMProviderSettings {
        LLMProviderSettings(
            apiEndpoint: "https://generativelanguage.googleapis.com",
            apiVersion: "v1beta",
            customHeaders: [:],
            timeout: 30,
            retryCount: 3
        )
    }
}