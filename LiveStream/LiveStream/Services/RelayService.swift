import Foundation

enum RelayError: LocalizedError {
    case invalidURL
    case httpError(Int, String?)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid relay URL"
        case .httpError(let code, let message):
            return message ?? "HTTP \(code)"
        case .decodingError(let err):
            return "Response parsing failed: \(err.localizedDescription)"
        }
    }
}

final class RelayService {
    static let shared = RelayService()

    private let session: URLSession

    private var baseURL: URL {
        URL(string: Constants.relayBaseURL)!
    }

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Endpoints

    func fetchCategories() async throws -> [CategoryPool] {
        try await get(baseURL.appendingPathComponent("categories"))
    }

    func fetchCategory(_ name: String) async throws -> CategoryPool {
        try await get(baseURL.appendingPathComponent("categories/\(name)"))
    }

    func uploadClip(
        _ videoData: Data,
        filename: String = "clip.mp4",
        category: String,
        workerAddress: String
    ) async throws -> SubmissionResult {
        let url = baseURL.appendingPathComponent("upload")
        let boundary = "Boundary-\(UUID().uuidString)"

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = multipartBody(
            videoData: videoData,
            filename: filename,
            category: category,
            workerAddress: workerAddress,
            boundary: boundary
        )

        return try await perform(request)
    }

    // MARK: - Private

    private func get<T: Decodable>(_ url: URL) async throws -> T {
        try await perform(URLRequest(url: url))
    }

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let message = try? JSONDecoder().decode([String: String].self, from: data)["error"]
            throw RelayError.httpError(http.statusCode, message)
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw RelayError.decodingError(error)
        }
    }

    private func multipartBody(
        videoData: Data,
        filename: String,
        category: String,
        workerAddress: String,
        boundary: String
    ) -> Data {
        var body = Data()

        func append(_ string: String) {
            guard let data = string.data(using: .utf8) else { return }
            body.append(data)
        }

        let crlf = "\r\n"

        append("--\(boundary)\(crlf)")
        append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\(crlf)")
        append("Content-Type: video/mp4\(crlf)\(crlf)")
        body.append(videoData)
        append(crlf)

        append("--\(boundary)\(crlf)")
        append("Content-Disposition: form-data; name=\"category\"\(crlf)\(crlf)")
        append(category)
        append(crlf)

        append("--\(boundary)\(crlf)")
        append("Content-Disposition: form-data; name=\"workerAddress\"\(crlf)\(crlf)")
        append(workerAddress)
        append(crlf)

        append("--\(boundary)--\(crlf)")

        return body
    }
}
