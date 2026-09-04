import Foundation
import StoreKit

@available(iOS 15.0, *)
@objcMembers
public class SimpleStoreKit: NSObject {

    private var products: [Product] = []

    public override init() {
        super.init()
    }

    /// Fetch and purchase a product by ID
    public func purchaseWithProductID(_ productID: String, completion: @escaping (Bool) -> Void) {
        Task {
            do {
                let fetchedProducts = try await Product.products(for: [productID])
                guard let product = fetchedProducts.first else {
                    await MainActor.run { completion(false) }
                    return
                }
                self.products = fetchedProducts

                let result = try await product.purchase()

                switch result {
                case .success(let verification):
                    switch verification {
                    case .verified(let transaction):
                        await transaction.finish()
                        await MainActor.run { completion(true) }
                    case .unverified(_, _):
                        await MainActor.run { completion(false) }
                    }
                case .userCancelled:
                    await MainActor.run { completion(false) }
                case .pending:
                    await MainActor.run { completion(false) }
                @unknown default:
                    await MainActor.run { completion(false) }
                }
            } catch {
                NSLog("[SimpleStoreKit] Purchase error: %@", error.localizedDescription)
                await MainActor.run { completion(false) }
            }
        }
    }

    /// Restore purchases
    public func restorePurchasesWithCompletion(_ completion: @escaping (Bool) -> Void) {
        Task {
            do {
                try await AppStore.sync()
                await MainActor.run { completion(true) }
            } catch {
                NSLog("[SimpleStoreKit] Restore error: %@", error.localizedDescription)
                await MainActor.run { completion(false) }
            }
        }
    }
}
