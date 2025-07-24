import AppCore
import Foundation

// MARK: - Local Model Provider

/// Local model provider implementation (for Ollama, LM Studio, etc.)
public final class LocalModelProvider: LLMProviderProtocol, @unchecked Sendable {
    // MARK: - Properties

    public let id = "local-model"
    public let name = "Local Model"

    public var capabilities: LLMProviderCapabilities {
        LLMProviderCapabilities(
            supportsStreaming: true,
            supportsEmbeddings: true,
            supportsVision: false,
            supportsFunctionCalling: false,
            maxTokens: 4096,
            maxContextLength: 128_000,
            supportedModels: [
                LLMModel(
                    id: "llama3.2:latest",
                    name: "Llama 3.2",
                    description: "Meta's Llama 3.2 model",
                    contextLength: 128_000,
                    pricing: ModelPricing(
                        inputPricePerMillion: 0.0,
                        outputPricePerMillion: 0.0
                    )
                ),
                LLMModel(
                    id: "llama3.1:latest",
                    name: "Llama 3.1",
                    description: "Meta's Llama 3.1 model",
                    contextLength: 128_000,
                    pricing: ModelPricing(
                        inputPricePerMillion: 0.0,
                        outputPricePerMillion: 0.0
                    )
                ),
                LLMModel(
                    id: "mistral:latest",
                    name: "Mistral",
                    description: "Mistral local model",
                    contextLength: 32_000,
                    pricing: ModelPricing(
                        inputPricePerMillion: 0.0,
                        outputPricePerMillion: 0.0
                    )
                ),
                LLMModel(
                    id: "codegemma:latest",
                    name: "Code Gemma",
                    description: "Google's Code Gemma model",
                    contextLength: 8192,
                    pricing: ModelPricing(
                        inputPricePerMillion: 0.0,
                        outputPricePerMillion: 0.0
                    )
                ),
            ]
        )
    }

    private let session: URLSession

    // MARK: - Initialization

    public init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 60 // Local models may be slower
        configuration.timeoutIntervalForResource = 600
        session = URLSession(configuration: configuration)
    }

    // MARK: - LLMProviderProtocol

    public var isConfigured: Bool {
        get async {
            // Check if local endpoint is configured
            if let config = try? await LLMConfigurationManager.shared.loadConfiguration(for: id) {
                return config.customEndpoint != nil
            }
            return false
        }
    }

    public func validateCredentials() async throws -> Bool {
        guard let config = try await LLMConfigurationManager.shared.loadConfiguration(for: id),
              let endpoint = config.customEndpoint
        else {
            throw LLMProviderError.notConfigured
        }

        // Test endpoint availability
        let url = "\(endpoint)/api/tags"
        guard let urlObject = URL(string: url) else {
            throw LLMProviderError.networkError("Invalid URL")
        }

        var urlRequest = URLRequest(url: urlObject)
        urlRequest.httpMethod = "GET"

        do {
            let (_, response) = try await session.data(for: urlRequest)
            guard let httpResponse = response as? HTTPURLResponse else {
                return false
            }
            return httpResponse.statusCode == 200
        } catch {
            return false
        }
    }

    public func chatCompletion(_ request: LLMChatRequest) async throws -> LLMChatResponse {
        guard let config = try await LLMConfigurationManager.shared.loadConfiguration(for: id),
              let endpoint = config.customEndpoint
        else {
            throw LLMProviderError.notConfigured
        }

        // Build messages for Ollama/OpenAI-compatible format
        var messages: [[String: Any]] = []

        // Add system message if provided
        if let systemPrompt = request.systemPrompt {
            messages.append(["role": "system", "content": systemPrompt])
        }

        // Add conversation messages
        messages.append(contentsOf: request.messages.map { message in
            ["role": message.role.rawValue, "content": message.content]
        })

        // Build request body
        let body: [String: Any] = [
            "model": request.model,
            "messages": messages,
            "options": [
                "temperature": request.temperature,
                "num_predict": request.maxTokens ?? 4096
            ],
            "stream": false
        ]

        // Local model API endpoint (Ollama format)
        let url = "\(endpoint)/api/chat"

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

        if httpResponse.statusCode == 404 {
            throw LLMProviderError.networkError("Model not found. Try pulling the model first.")
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let message = errorBody?["error"] as? String ?? "Unknown error"
            throw LLMProviderError.networkError("HTTP \(httpResponse.statusCode): \(message)")
        }

        // Parse response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LLMProviderError.invalidResponse("Invalid JSON")
        }

        guard let message = json["message"] as? [String: Any],
              let content = message["content"] as? String
        else {
            throw LLMProviderError.invalidResponse("Missing required fields")
        }

        let responseMessage = LLMMessage(
            role: .assistant,
            content: content
        )

        // Extract usage metadata if available
        let promptEvalCount = json["prompt_eval_count"] as? Int ?? 0
        let evalCount = json["eval_count"] as? Int ?? 0

        let tokenUsage = TokenUsage(
            promptTokens: promptEvalCount,
            completionTokens: evalCount
        )

        let isDone = json["done"] as? Bool ?? true
        let reason: FinishReason = isDone ? .stop : .length

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
                    guard let config = try await LLMConfigurationManager.shared.loadConfiguration(for: id),
                          let endpoint = config.customEndpoint
                    else {
                        throw LLMProviderError.notConfigured
                    }

                    // Build messages for Ollama format
                    var messages: [[String: Any]] = []

                    if let systemPrompt = request.systemPrompt {
                        messages.append(["role": "system", "content": systemPrompt])
                    }

                    messages.append(contentsOf: request.messages.map { message in
                        ["role": message.role.rawValue, "content": message.content]
                    })

                    // Build request body
                    let body: [String: Any] = [
                        "model": request.model,
                        "messages": messages,
                        "options": [
                            "temperature": request.temperature,
                            "num_predict": request.maxTokens ?? 4096
                        ],
                        "stream": true
                    ]

                    // Local model streaming endpoint
                    let url = "\(endpoint)/api/chat"

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
                           let message = json["message"] as? [String: Any],
                           let content = message["content"] as? String {
                            continuation.yield(LLMStreamChunk(delta: content))

                            if let done = json["done"] as? Bool, done {
                                continuation.yield(LLMStreamChunk(delta: "", finishReason: .stop))
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
        guard let config = try await LLMConfigurationManager.shared.loadConfiguration(for: id),
              let endpoint = config.customEndpoint
        else {
            throw LLMProviderError.notConfigured
        }

        let body: [String: Any] = [
            "model": "nomic-embed-text", // Default embedding model for Ollama
            "prompt": text
        ]

        let url = "\(endpoint)/api/embeddings"

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
              let embedding = json["embedding"] as? [Double]
        else {
            throw LLMProviderError.invalidResponse("Invalid embeddings response")
        }

        return embedding.map { Float($0) }
    }

    public func tokenCount(for text: String) async throws -> Int {
        // Estimate based on character count
        text.count / 4
    }

    public func getSettings() -> LLMProviderSettings {
        LLMProviderSettings(
            apiEndpoint: "http://localhost:11434", // Default Ollama endpoint
            apiVersion: "1.0",
            customHeaders: [:],
            timeout: 60,
            retryCount: 2
        )
    }
}