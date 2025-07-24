import AppCore
import Foundation

// MARK: - Azure OpenAI Provider

/// Azure OpenAI Service provider implementation (for government compliance)
public final class AzureOpenAIProvider: LLMProviderProtocol, @unchecked Sendable {
    // MARK: - Properties

    public let id = "azure-openai"
    public let name = "Azure OpenAI"

    public var capabilities: LLMProviderCapabilities {
        LLMProviderCapabilities(
            supportsStreaming: true,
            supportsEmbeddings: true,
            supportsVision: true,
            supportsFunctionCalling: true,
            maxTokens: 4096,
            maxContextLength: 128_000,
            supportedModels: [
                LLMModel(
                    id: "gpt-4-turbo-2024-04-09",
                    name: "GPT-4 Turbo (Azure)",
                    description: "Latest GPT-4 Turbo on Azure",
                    contextLength: 128_000,
                    pricing: ModelPricing(
                        inputPricePerMillion: 10.0,
                        outputPricePerMillion: 30.0
                    )
                ),
                LLMModel(
                    id: "gpt-4-32k",
                    name: "GPT-4 32K (Azure)",
                    description: "Extended context GPT-4",
                    contextLength: 32768,
                    pricing: ModelPricing(
                        inputPricePerMillion: 60.0,
                        outputPricePerMillion: 120.0
                    )
                ),
                LLMModel(
                    id: "gpt-35-turbo",
                    name: "GPT-3.5 Turbo (Azure)",
                    description: "Fast and efficient model",
                    contextLength: 16385,
                    pricing: ModelPricing(
                        inputPricePerMillion: 0.5,
                        outputPricePerMillion: 1.5
                    )
                ),
                LLMModel(
                    id: "gpt-4o",
                    name: "GPT-4o (Azure)",
                    description: "Optimized GPT-4 on Azure",
                    contextLength: 128_000,
                    pricing: ModelPricing(
                        inputPricePerMillion: 5.0,
                        outputPricePerMillion: 15.0
                    )
                ),
            ]
        )
    }

    private var baseURL: String = ""
    private var deploymentName: String = ""
    private let apiVersion = "2024-02-01"
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
            guard await LLMConfigurationManager.shared.isProviderConfigured(id) else { return false }

            // Check if Azure-specific settings are configured
            if let config = try? await LLMConfigurationManager.shared.loadConfiguration(for: id) {
                return config.customEndpoint != nil &&
                    config.customHeaders?["X-Azure-Deployment-Name"] != nil
            }
            return false
        }
    }

    public func validateCredentials() async throws -> Bool {
        guard let config = try await LLMConfigurationManager.shared.loadConfiguration(for: id),
              let endpoint = config.customEndpoint,
              let deployment = config.customHeaders?["X-Azure-Deployment-Name"]
        else {
            throw LLMProviderError.notConfigured
        }

        baseURL = endpoint
        deploymentName = deployment

        // Test API key with a simple request
        let testRequest = LLMChatRequest(
            messages: [LLMMessage(role: .user, content: "Hi")],
            model: deploymentName,
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
        guard let config = try await LLMConfigurationManager.shared.loadConfiguration(for: id),
              let endpoint = config.customEndpoint,
              let deployment = config.customHeaders?["X-Azure-Deployment-Name"]
        else {
            throw LLMProviderError.notConfigured
        }

        baseURL = endpoint
        deploymentName = deployment

        // Build messages array
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
        var body: [String: Any] = [
            "messages": messages,
            "temperature": request.temperature,
        ]

        if let maxTokens = request.maxTokens {
            body["max_tokens"] = maxTokens
        }

        // Azure OpenAI endpoint format
        let url = "\(baseURL)/openai/deployments/\(deployment)/chat/completions?api-version=\(apiVersion)"

        // Make API request
        guard let urlObject = URL(string: url) else {
            throw LLMProviderError.networkError("Invalid URL")
        }
        var urlRequest = URLRequest(url: urlObject)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(config.apiKey, forHTTPHeaderField: "api-key")
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
            let error = errorBody?["error"] as? [String: Any]
            let message = error?["message"] as? String ?? "Unknown error"
            throw LLMProviderError.networkError("HTTP \(httpResponse.statusCode): \(message)")
        }

        // Parse response (same format as OpenAI)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LLMProviderError.invalidResponse("Invalid JSON")
        }

        guard let id = json["id"] as? String,
              let model = json["model"] as? String,
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let role = message["role"] as? String,
              let content = message["content"] as? String,
              let usage = json["usage"] as? [String: Any],
              let promptTokens = usage["prompt_tokens"] as? Int,
              let completionTokens = usage["completion_tokens"] as? Int
        else {
            throw LLMProviderError.invalidResponse("Missing required fields")
        }

        let responseMessage = LLMMessage(
            role: MessageRole(rawValue: role) ?? .assistant,
            content: content
        )

        let tokenUsage = TokenUsage(
            promptTokens: promptTokens,
            completionTokens: completionTokens
        )

        let finishReason = firstChoice["finish_reason"] as? String
        let reason: FinishReason = switch finishReason {
        case "length": .length
        case "function_call": .functionCall
        case "content_filter": .contentFilter
        default: .stop
        }

        return LLMChatResponse(
            id: id,
            model: model,
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
                          let endpoint = config.customEndpoint,
                          let deployment = config.customHeaders?["X-Azure-Deployment-Name"]
                    else {
                        throw LLMProviderError.notConfigured
                    }

                    self.baseURL = endpoint
                    self.deploymentName = deployment

                    // Build messages array
                    var messages: [[String: Any]] = []

                    if let systemPrompt = request.systemPrompt {
                        messages.append(["role": "system", "content": systemPrompt])
                    }

                    messages.append(contentsOf: request.messages.map { message in
                        ["role": message.role.rawValue, "content": message.content]
                    })

                    // Build request body
                    var body: [String: Any] = [
                        "messages": messages,
                        "temperature": request.temperature,
                        "stream": true,
                    ]

                    if let maxTokens = request.maxTokens {
                        body["max_tokens"] = maxTokens
                    }

                    // Azure OpenAI endpoint format
                    let url = "\(baseURL)/openai/deployments/\(deployment)/chat/completions?api-version=\(apiVersion)"

                    // Make streaming request
                    guard let urlObject = URL(string: url) else {
                        throw LLMProviderError.networkError("Invalid URL")
                    }
                    var urlRequest = URLRequest(url: urlObject)
                    urlRequest.httpMethod = "POST"
                    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    urlRequest.setValue(config.apiKey, forHTTPHeaderField: "api-key")
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
                           let choices = json["choices"] as? [[String: Any]],
                           let firstChoice = choices.first,
                           let delta = firstChoice["delta"] as? [String: Any] {
                            if let content = delta["content"] as? String {
                                continuation.yield(LLMStreamChunk(delta: content))
                            }

                            if let finishReason = firstChoice["finish_reason"] as? String {
                                let reason: FinishReason = switch finishReason {
                                case "length": .length
                                case "function_call": .functionCall
                                case "content_filter": .contentFilter
                                default: .stop
                                }
                                continuation.yield(LLMStreamChunk(delta: "", finishReason: reason))
                            }
                        }
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    public func generateEmbeddings(_ text: String) async throws -> [Float] {
        guard let config = try await LLMConfigurationManager.shared.loadConfiguration(for: id),
              let endpoint = config.customEndpoint,
              let embeddingDeployment = config.customHeaders?["X-Azure-Embedding-Deployment-Name"]
        else {
            throw LLMProviderError.notConfigured
        }

        let body: [String: Any] = ["input": text]

        let url = "\(endpoint)/openai/deployments/\(embeddingDeployment)/embeddings?api-version=\(apiVersion)"

        guard let urlObject = URL(string: url) else {
            throw LLMProviderError.networkError("Invalid URL")
        }
        var urlRequest = URLRequest(url: urlObject)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(config.apiKey, forHTTPHeaderField: "api-key")
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200
        else {
            throw LLMProviderError.networkError("Embeddings request failed")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataArray = json["data"] as? [[String: Any]],
              let firstData = dataArray.first,
              let embedding = firstData["embedding"] as? [Double]
        else {
            throw LLMProviderError.invalidResponse("Invalid embeddings response")
        }

        return embedding.map { Float($0) }
    }

    public func tokenCount(for text: String) async throws -> Int {
        // Same estimation as OpenAI
        text.count / 4
    }

    public func getSettings() -> LLMProviderSettings {
        LLMProviderSettings(
            apiEndpoint: baseURL,
            apiVersion: apiVersion,
            customHeaders: ["api-key": "****"], // Placeholder to show it uses api-key header
            timeout: 30,
            retryCount: 3
        )
    }
}
