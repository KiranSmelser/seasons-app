import StoreKit
import os

private let monthlyProductID = "com.kiransmelser.seasons.pro.monthly"
private let annualProductID = "com.kiransmelser.seasons.pro.annual"

@Observable @MainActor
final class SubscriptionService {
    private(set) var isPro: Bool = false
    private(set) var monthlyProduct: Product?
    private(set) var annualProduct: Product?
    private(set) var isLoading: Bool = false
    private(set) var errorMessage: String?

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.kiransmelser.seasons",
        category: "SubscriptionService"
    )

    init() {
        Task {
            await loadProducts()
            await checkEntitlement()
        }
        Task {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await checkEntitlement()
                } else if case .unverified(let transaction, _) = result {
                    // Finish without granting entitlement — clears it from the queue.
                    await transaction.finish()
                }
            }
        }
    }

    func loadProducts() async {
        do {
            let products = try await Product.products(for: [monthlyProductID, annualProductID])
            for product in products {
                switch product.id {
                case monthlyProductID:
                    monthlyProduct = product
                case annualProductID:
                    annualProduct = product
                default:
                    break
                }
            }
        } catch {
            logger.error("Failed to load products: \(error.localizedDescription, privacy: .public)")
        }
    }

    func checkEntitlement() async {
        var hasPro = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.revocationDate == nil,
               transaction.productID == monthlyProductID || transaction.productID == annualProductID {
                hasPro = true
                break
            }
        }
        isPro = hasPro
    }

    func purchase(_ product: Product) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    await checkEntitlement()
                case .unverified(_, let error):
                    logger.error("Purchase verification failed: \(error, privacy: .private)")
                    errorMessage = "Purchase couldn't be verified. Please restore purchases or contact support."
                }
            case .pending, .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            logger.error("Purchase failed: \(error.localizedDescription, privacy: .public)")
            errorMessage = "Purchase failed. Please try again."
        }
    }

    func restorePurchases() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await AppStore.sync()
            await checkEntitlement()
        } catch {
            logger.error("Restore purchases failed: \(error.localizedDescription, privacy: .public)")
            errorMessage = "Restore failed. Please try again."
        }
    }

}
