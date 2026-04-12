import Foundation

struct AppStoreReceiptProvider {
    func base64EncodedReceipt() throws -> String {
        guard let receiptURL = Bundle.main.appStoreReceiptURL else {
            throw AppStoreReceiptError.missingReceiptURL
        }

        let receiptData: Data
        do {
            receiptData = try Data(contentsOf: receiptURL)
        } catch {
            throw AppStoreReceiptError.unreadableReceipt(error.localizedDescription)
        }

        guard !receiptData.isEmpty else {
            throw AppStoreReceiptError.emptyReceipt
        }

        return receiptData.base64EncodedString()
    }
}

enum AppStoreReceiptError: LocalizedError {
    case missingReceiptURL
    case unreadableReceipt(String)
    case emptyReceipt

    var errorDescription: String? {
        switch self {
        case .missingReceiptURL:
            return "The app bundle does not contain an App Store receipt."
        case let .unreadableReceipt(message):
            return "The App Store receipt could not be read: \(message)"
        case .emptyReceipt:
            return "The app bundle contains an empty App Store receipt."
        }
    }
}
