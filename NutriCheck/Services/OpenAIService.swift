import Foundation

enum AnalysisError: LocalizedError {
    case missingAPIKey
    case http(status: Int, message: String)
    case refusal(String)
    case incomplete(String)
    case emptyResponse
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Add your OpenAI API key in Settings first."
        case let .http(status, message):
            switch status {
            case 401: return "OpenAI rejected your API key. Check it in Settings.\n\n\(message)"
            case 404: return "The selected model isn't available on your OpenAI account. Pick another model in Settings.\n\n\(message)"
            case 429: return "OpenAI rate limit or quota reached. Check your billing, or wait a moment and try again.\n\n\(message)"
            default: return "OpenAI error (\(status)).\n\n\(message)"
            }
        case let .refusal(reason):
            return "The model couldn't help with this: \(reason)"
        case let .incomplete(reason):
            return "The response was cut short (\(reason)). Please try again."
        case .emptyResponse:
            return "OpenAI returned an empty response. Please try again."
        case let .decoding(detail):
            return "Couldn't read the response from OpenAI. Please try again.\n\n\(detail)"
        }
    }
}

/// Talks to the OpenAI Responses API with Structured Outputs.
struct OpenAIService: Sendable {
    let apiKey: String
    let model: String

    private static let baseURL = URL(string: "https://api.openai.com/v1")!

    // MARK: - Food analysis

    /// - Parameters:
    ///   - imageJPEG: Photo of the food or label (nil for text-only descriptions).
    ///   - details: Optional context from the user, or the food description in text mode.
    ///   - correction: The user's correction when refining an earlier result.
    ///   - previous: The earlier result being refined.
    func analyze(
        imageJPEG: Data?,
        details: String?,
        correction: String? = nil,
        previous: NutritionAnalysis? = nil
    ) async throws -> NutritionAnalysis {
        let prompt = Self.analysisPrompt(hasImage: imageJPEG != nil, details: details, correction: correction, previous: previous)
        var content: [[String: Any]] = [["type": "input_text", "text": prompt]]
        if let imageJPEG {
            content.append([
                "type": "input_image",
                "image_url": "data:image/jpeg;base64,\(imageJPEG.base64EncodedString())",
                "detail": "high",
            ])
        }
        let text = try await respond(
            instructions: NutritionPrompts.system,
            input: [["role": "user", "content": content]],
            schemaName: "nutrition_analysis",
            schema: NutritionSchema.json,
            maxOutputTokens: 16000
        )
        do {
            var analysis = try Self.snakeDecoder.decode(NutritionAnalysis.self, from: Data(text.utf8))
            analysis.healthScore = min(max(analysis.healthScore, 1), 10)
            return analysis
        } catch {
            throw AnalysisError.decoding(error.localizedDescription)
        }
    }

    // MARK: - Assistant chat

    /// - Parameters:
    ///   - history: The conversation so far, oldest first, ending with the user's new message.
    ///   - context: Snapshot of the user's profile, goals and logs.
    func chat(history: [ChatTurn], context: String) async throws -> AssistantReply {
        let input: [[String: Any]] = history.map { ["role": $0.role.rawValue, "content": $0.text] }
        let text = try await respond(
            instructions: AssistantPrompts.system + "\n\n" + context,
            input: input,
            schemaName: "assistant_reply",
            schema: AssistantSchema.json,
            maxOutputTokens: 8000
        )
        do {
            var reply = try Self.snakeDecoder.decode(AssistantReply.self, from: Data(text.utf8))
            reply.actions = reply.actions.filter { $0.isValid }
            return reply
        } catch {
            throw AnalysisError.decoding(error.localizedDescription)
        }
    }

    /// Cheap call that checks the key works and the model is accessible.
    func validate() async throws {
        guard !apiKey.isEmpty else { throw AnalysisError.missingAPIKey }
        var request = URLRequest(url: Self.baseURL.appending(path: "models").appending(path: model))
        request.timeoutInterval = 20
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AnalysisError.emptyResponse }
        if (200..<300).contains(http.statusCode) { return }
        if http.statusCode == 404 {
            // Aliases (e.g. "gpt-5.6") aren't listed under /models; try a tiny real request instead.
            let body = """
            {"model":\(try Self.jsonString(model)),"input":"Reply with OK","max_output_tokens":32,"store":false}
            """
            _ = try await send(body: Data(body.utf8))
            return
        }
        throw AnalysisError.http(status: http.statusCode, message: Self.errorMessage(from: data))
    }

    // MARK: - Core request

    /// Sends one Responses API request and returns the structured output text.
    private func respond(
        instructions: String,
        input: [[String: Any]],
        schemaName: String,
        schema: String,
        maxOutputTokens: Int
    ) async throws -> String {
        guard !apiKey.isEmpty else { throw AnalysisError.missingAPIKey }

        let inputJSON = String(decoding: try JSONSerialization.data(withJSONObject: input, options: [.withoutEscapingSlashes]), as: UTF8.self)
        var includeReasoning = Self.supportsReasoning(model)
        let data: Data
        do {
            data = try await send(body: makeBody(instructions: instructions, inputJSON: inputJSON, schemaName: schemaName,
                                                 schema: schema, maxOutputTokens: maxOutputTokens, includeReasoning: includeReasoning))
        } catch let AnalysisError.http(status, message) where status == 400 && includeReasoning && message.localizedCaseInsensitiveContains("reasoning") {
            // Custom / older models may not accept reasoning settings: retry without them.
            includeReasoning = false
            data = try await send(body: makeBody(instructions: instructions, inputJSON: inputJSON, schemaName: schemaName,
                                                 schema: schema, maxOutputTokens: maxOutputTokens, includeReasoning: includeReasoning))
        }

        let envelope: ResponseEnvelope
        do {
            envelope = try Self.snakeDecoder.decode(ResponseEnvelope.self, from: data)
        } catch {
            throw AnalysisError.decoding(error.localizedDescription)
        }

        if let message = envelope.error?.message { throw AnalysisError.http(status: 500, message: message) }

        var text = ""
        for item in envelope.output ?? [] where item.type == "message" {
            for part in item.content ?? [] {
                if part.type == "refusal", let refusal = part.refusal { throw AnalysisError.refusal(refusal) }
                if part.type == "output_text", let t = part.text { text += t }
            }
        }
        if envelope.status == "incomplete" {
            throw AnalysisError.incomplete(envelope.incompleteDetails?.reason ?? "unknown reason")
        }
        guard !text.isEmpty else { throw AnalysisError.emptyResponse }
        return text
    }

    private func send(body: Data) async throws -> Data {
        var request = URLRequest(url: Self.baseURL.appending(path: "responses"))
        request.httpMethod = "POST"
        request.timeoutInterval = 180
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AnalysisError.emptyResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw AnalysisError.http(status: http.statusCode, message: Self.errorMessage(from: data))
        }
        return data
    }

    /// Builds the request JSON by hand so the schema keeps its property order.
    func makeBody(instructions: String, inputJSON: String, schemaName: String, schema: String,
                  maxOutputTokens: Int, includeReasoning: Bool) throws -> Data {
        let reasoning = includeReasoning ? #""reasoning":{"effort":"low"},"# : ""
        let body = """
        {"model":\(try Self.jsonString(model)),\
        "instructions":\(try Self.jsonString(instructions)),\
        "store":false,\
        "max_output_tokens":\(maxOutputTokens),\
        \(reasoning)\
        "input":\(inputJSON),\
        "text":{"format":{"type":"json_schema","name":\(try Self.jsonString(schemaName)),"strict":true,"schema":\(schema)}}}
        """
        return Data(body.utf8)
    }

    // MARK: - Helpers

    private static func analysisPrompt(hasImage: Bool, details: String?, correction: String?, previous: NutritionAnalysis?) -> String {
        let details = details?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var text: String
        if hasImage {
            text = "Analyze the food or drink in this photo and estimate its nutrition."
            if !details.isEmpty { text += "\n\nDetails from the user (authoritative): \(details)" }
        } else {
            text = "Estimate the nutrition for this food or drink, described by the user:\n\(details)"
        }
        if let correction = correction?.trimmingCharacters(in: .whitespacesAndNewlines), !correction.isEmpty {
            if let previous {
                text += "\n\nYour previous estimate was \"\(previous.name)\" (\(previous.servingDescription), \(Int(previous.nutrients.calories.rounded())) kcal)."
            }
            text += "\nThe user corrected it: \(correction)\nRe-analyze and apply this correction."
        }
        return text
    }

    private static func supportsReasoning(_ model: String) -> Bool {
        let m = model.lowercased()
        if m.contains("chat") { return false }
        return m.hasPrefix("gpt-5") || m.hasPrefix("gpt-6") || m.hasPrefix("o3") || m.hasPrefix("o4")
    }

    private static func jsonString(_ s: String) throws -> String {
        String(decoding: try JSONEncoder().encode(s), as: UTF8.self)
    }

    private static var snakeDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }

    private static func errorMessage(from data: Data) -> String {
        if let envelope = try? snakeDecoder.decode(ResponseEnvelope.self, from: data), let message = envelope.error?.message {
            return message
        }
        return String(decoding: data.prefix(300), as: UTF8.self)
    }
}

// MARK: - Response types

private struct ResponseEnvelope: Decodable {
    struct APIError: Decodable { let message: String? }
    struct Incomplete: Decodable { let reason: String? }
    struct OutputItem: Decodable {
        let type: String
        let content: [ContentPart]?
    }
    struct ContentPart: Decodable {
        let type: String
        let text: String?
        let refusal: String?
    }

    let status: String?
    let error: APIError?
    let incompleteDetails: Incomplete?
    let output: [OutputItem]?
}
