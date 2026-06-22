import Foundation

enum StreamStatus: String, Codable {
    case live
    case archived
}

struct Stream: Identifiable, Codable {
    let id: String
    let title: String
    let creatorAddress: String
    let status: StreamStatus
    let createdAt: Date
    var rootHash: String?
    var duration: Int?

    var shortAddress: String {
        guard creatorAddress.count > 10 else { return creatorAddress }
        return creatorAddress.prefix(6) + "..." + creatorAddress.suffix(4)
    }

    var hlsUrl: URL? {
        URL(string: "\(Constants.backendBaseUrl)/api/streams/\(id)/live.m3u8")
    }

    var archivedUrl: URL? {
        guard rootHash != nil else { return nil }
        return URL(string: "\(Constants.backendBaseUrl)/api/streams/\(id)/archived")
    }
}

// MARK: - Mock data for development without backend
extension Stream {
    static let mocks: [Stream] = [
        Stream(
            id: "mock-1",
            title: "Cannes vibes 🎬",
            creatorAddress: "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045",
            status: .live,
            createdAt: Date().addingTimeInterval(-45),
            rootHash: nil,
            duration: nil
        ),
        Stream(
            id: "mock-2",
            title: "Building on 0G chain",
            creatorAddress: "0x71C7656EC7ab88b098defB751B7401B5f6d8976F",
            status: .archived,
            createdAt: Date().addingTimeInterval(-3600),
            rootHash: "0xabc123def456",
            duration: 58
        ),
        Stream(
            id: "mock-3",
            title: "Hackathon day 1",
            creatorAddress: "0xAb5801a7D398351b8bE11C439e05C5B3259aeC9B",
            status: .archived,
            createdAt: Date().addingTimeInterval(-7200),
            rootHash: "0x789xyz456abc",
            duration: 42
        ),
    ]
}
