import Foundation

struct SubmissionResult: Codable {
    let submissionId: Int
    let storageHash: String
    let score: Int
    let status: Status
    let payout: String

    enum Status: String, Codable {
        case accepted
        case rejected
    }

    var isAccepted: Bool { status == .accepted }

    var payoutA0GI: Double {
        guard let value = Double(payout) else { return 0 }
        return value / 1e18
    }
}
