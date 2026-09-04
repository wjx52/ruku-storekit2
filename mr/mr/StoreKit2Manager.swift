import Foundation
import StoreKit

// MARK: - StoreKit 2 Manager (iOS 15+)

@available(iOS 15.0, *)
@objcMembers
public class StoreKit2Manager: NSObject {

    public static let shared = StoreKit2Manager()

    public enum PurchaseState: Int {
        case idle = 0
        case inProgress
        case complete
        case failed
        case failedVerification
        case cancelled
        case pending
        case unknown
    }

    private var products: [Product] = []
    private var updateListenerTask: Task<Void, Error>?
    private(set) var purchaseState: PurchaseState = .idle

    public var transactionCallback: (([String: Any]) -> Void)?

    private override init() {
        super.init()
    }

    // MARK: - Lifecycle

    public func startTransactionListener() {
        updateListenerTask = listenForTransactions()
    }

    public func stopTransactionListener() {
        updateListenerTask?.cancel()
        updateListenerTask = nil
    }

    // MARK: - Request Products

    public func requestProducts(productIds: [String]) async -> [Product]? {
        do {
            products = try await Product.products(for: Set(productIds))
            return products
        } catch {
            NSLog("[StoreKit2] Failed to request products: %@", error.localizedDescription)
            return nil
        }
    }

    @objc public func requestProduct(_ productId: String, completion: @escaping ([String: Any]?) -> Void) {
        Task {
            guard let fetched = await requestProducts(productIds: [productId]),
                  let product = fetched.first else {
                completion(nil)
                return
            }
            let info: [String: Any] = [
                "productIdentifier": product.id,
                "localizedTitle": product.displayName,
                "price": product.displayPrice,
                "currencyCode": product.priceFormatStyle.currencyCode
            ]
            completion(info)
        }
    }

    // MARK: - Purchase

    public func purchase(productId: String, uuid: String? = nil) async throws -> [String: Any]? {
        guard purchaseState != .inProgress else {
            throw NSError(domain: "StoreKit2", code: -1, userInfo: [NSLocalizedDescriptionKey: "Purchase already in progress"])
        }

        guard let product = products.first(where: { $0.id == productId }) else {
            if let fetched = await requestProducts(productIds: [productId]),
               let product = fetched.first {
                return try await executePurchase(product: product, uuid: uuid)
            }
            throw NSError(domain: "StoreKit2", code: -2, userInfo: [NSLocalizedDescriptionKey: "Product not found"])
        }

        return try await executePurchase(product: product, uuid: uuid)
    }

    private func executePurchase(product: Product, uuid: String?) async throws -> [String: Any]? {
        purchaseState = .inProgress

        var options: Set<Product.PurchaseOption> = []
        if let uuid = uuid, let token = UUID(uuidString: uuid) {
            options.insert(.appAccountToken(token))
        }

        let result: Product.PurchaseResult
        do {
            result = try await product.purchase(options: options)
        } catch {
            purchaseState = .failed
            throw error
        }

        switch result {
        case .success(let verification):
            let checkResult = checkVerification(verification)
            if !checkResult.verified {
                purchaseState = .failedVerification
                throw NSError(domain: "StoreKit2", code: -3, userInfo: [NSLocalizedDescriptionKey: "Transaction verification failed"])
            }
            purchaseState = .complete
            let transaction = checkResult.transaction
            await transaction.finish()
            return buildTransactionInfo(from: transaction, product: product)

        case .userCancelled:
            purchaseState = .cancelled
            throw NSError(domain: "StoreKit2", code: -4, userInfo: [NSLocalizedDescriptionKey: "User cancelled"])

        case .pending:
            purchaseState = .pending
            return ["status": "pending"]

        @unknown default:
            purchaseState = .unknown
            return nil
        }
    }

    @objc public func purchaseProduct(_ productId: String, uuid: String?, completion: @escaping ([String: Any]?, NSError?) -> Void) {
        Task {
            do {
                let info = try await purchase(productId: productId, uuid: uuid)
                await MainActor.run { completion(info, nil) }
            } catch {
                await MainActor.run { completion(nil, error as NSError) }
            }
        }
    }

    // MARK: - Transaction Verification

    private func checkVerification<T>(_ result: VerificationResult<T>) -> (transaction: T, verified: Bool) {
        switch result {
        case .unverified(let transaction, _):
            return (transaction: transaction, verified: false)
        case .verified(let transaction):
            return (transaction: transaction, verified: true)
        }
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached { [weak self] in
            for await verificationResult in Transaction.updates {
                guard let self = self else { return }
                let checkResult = self.checkVerification(verificationResult)
                if checkResult.verified {
                    let transaction = checkResult.transaction
                    await transaction.finish()
                    let info = self.buildTransactionInfo(from: transaction, product: nil)
                    await MainActor.run {
                        self.transactionCallback?(info)
                    }
                } else {
                    NSLog("[StoreKit2] Transaction failed verification in listener")
                }
            }
        }
    }

    // MARK: - Restore

    @objc public func restorePurchases() {
        Task {
            try? await AppStore.sync()
        }
    }

    // MARK: - Refund

    @objc public func requestRefund(transactionId: UInt64, scene: UIWindowScene?) {
        guard let scene = scene else { return }
        Task {
            do {
                let result = try await Transaction.beginRefundRequest(for: transactionId, in: scene)
                switch result {
                case .userCancelled:
                    NSLog("[StoreKit2] Refund: user cancelled")
                case .success:
                    NSLog("[StoreKit2] Refund: submitted successfully")
                @unknown default:
                    NSLog("[StoreKit2] Refund: unknown result")
                }
            } catch {
                NSLog("[StoreKit2] Refund error: %@", error.localizedDescription)
            }
        }
    }

    // MARK: - Build Transaction Info

    private func buildTransactionInfo(from transaction: Transaction, product: Product?) -> [String: Any] {
        var info: [String: Any] = [
            "transactionIdentifier": String(transaction.id),
            "productIdentifier": transaction.productID,
            "transactiondate": ISO8601DateFormatter().string(from: transaction.purchaseDate),
            "orderNo": String(transaction.id),
            "storeKitVersion": 2
        ]

        if let originalID = transaction.originalID as UInt64?,
           originalID != transaction.id {
            info["srcOrderNo"] = String(originalID)
        }

        if let token = transaction.appAccountToken {
            info["appAccountToken"] = token.uuidString
        }

        if let product = product {
            info["profductId"] = product.id
            info["profductName"] = product.displayName
            info["currency"] = product.priceFormatStyle.currencyCode
        } else {
            info["profductId"] = transaction.productID
        }

        if let jsonRep = transaction.jsonRepresentation as Data? {
            info["jwsRepresentation"] = jsonRep.base64EncodedString()
        }

        return info
    }

    // MARK: - Check StoreKit 2 Availability

    @objc public static var isAvailable: Bool {
        if #available(iOS 15.0, *) {
            return true
        }
        return false
    }
}
