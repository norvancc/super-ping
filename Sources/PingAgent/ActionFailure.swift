import Foundation

struct ActionFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

