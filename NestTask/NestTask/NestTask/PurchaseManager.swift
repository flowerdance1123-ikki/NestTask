import Foundation
import StoreKit

@MainActor
final class PurchaseManager: ObservableObject {
    static let proProductID = "nesttask500"
    private static let cachedProEntitlementKey = "cachedProEntitlement"

    @Published private(set) var proProduct: Product?
    @Published private(set) var isPro: Bool
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var isPurchasing = false
    @Published private(set) var isRestoringPurchases = false
    @Published var lastErrorMessage: String?
    @Published var lastInfoMessage: String?

    private var transactionUpdatesTask: Task<Void, Never>?
    private var hasStarted = false

    var proDisplayPrice: String? {
        proProduct?.displayPrice
    }

    init() {
        isPro = UserDefaults.standard.bool(forKey: Self.cachedProEntitlementKey)
    }

    deinit {
        transactionUpdatesTask?.cancel()
    }

    func start() async {
        guard !hasStarted else { return }
        hasStarted = true

        await refreshEntitlements()
        listenForTransactionUpdatesIfNeeded()
    }

    func loadProducts() async {
        guard proProduct == nil else { return }
        guard !isLoadingProducts else { return }

        lastInfoMessage = nil
        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do {
            let products = try await Self.withTimeout(seconds: 8) {
                try await Product.products(for: [Self.proProductID])
            }
            proProduct = products.first { $0.id == Self.proProductID }
            if proProduct == nil {
                lastErrorMessage = "NestTask Proの商品情報を取得できませんでした。"
            }
        } catch PurchaseError.timeout {
            lastErrorMessage = "商品情報の取得に時間がかかっています。通信状況を確認してもう一度お試しください。"
        } catch {
            lastErrorMessage = "商品情報を取得できませんでした。時間をおいてもう一度お試しください。"
        }
    }

    func purchasePro() async {
        guard !isPurchasing, !isRestoringPurchases else { return }

        lastErrorMessage = nil
        lastInfoMessage = nil

        if proProduct == nil {
            await loadProducts()
        }

        guard let proProduct else {
            lastErrorMessage = "NestTask Proの商品情報を取得できませんでした。"
            return
        }

        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let result = try await proProduct.purchase()

            switch result {
            case .success(let verification):
                let transaction = try Self.verifiedTransaction(from: verification)
                await transaction.finish()
                setProEntitlement(true)
            case .pending:
                break
            case .userCancelled:
                break
            @unknown default:
                await refreshEntitlements()
            }
        } catch {
            lastErrorMessage = "購入処理を完了できませんでした。時間をおいてもう一度お試しください。"
        }
    }

    func restorePurchases() async {
        guard !isPurchasing, !isRestoringPurchases else { return }

        lastErrorMessage = nil
        lastInfoMessage = nil
        isRestoringPurchases = true
        defer { isRestoringPurchases = false }

        do {
            try await Self.withTimeout(seconds: 12) {
                try await AppStore.sync()
            }
            guard let hasProEntitlement = await refreshEntitlements(showsError: true) else { return }

            lastInfoMessage = hasProEntitlement
                ? "NestTask Proの購入情報を復元しました。"
                : "復元できる購入情報が見つかりませんでした。購入時と同じApple IDでサインインしているか確認してください。"
        } catch PurchaseError.timeout {
            lastErrorMessage = "購入情報の復元に時間がかかっています。通信状況を確認してもう一度お試しください。"
        } catch {
            lastErrorMessage = "購入情報を復元できませんでした。時間をおいてもう一度お試しください。"
        }
    }

    @discardableResult
    func refreshEntitlements(showsError: Bool = false) async -> Bool? {
        do {
            let hasProEntitlement = try await Self.withTimeout(seconds: 6) {
                try await Self.fetchCurrentProEntitlement()
            }
            setProEntitlement(hasProEntitlement)
            return hasProEntitlement
        } catch {
            if showsError {
                lastErrorMessage = "購入情報を確認できませんでした。時間をおいてもう一度お試しください。"
            }
            return nil
        }
    }

    private func listenForTransactionUpdatesIfNeeded() {
        guard transactionUpdatesTask == nil else { return }

        transactionUpdatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }

                do {
                    let transaction = try Self.verifiedTransaction(from: result)
                    await transaction.finish()
                    await self.refreshEntitlements()
                } catch {
                    await self.refreshEntitlements()
                }
            }
        }
    }

    private func setProEntitlement(_ isPro: Bool) {
        self.isPro = isPro
        UserDefaults.standard.set(isPro, forKey: Self.cachedProEntitlementKey)
    }

    private static func fetchCurrentProEntitlement() async throws -> Bool {
        var hasProEntitlement = false

        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try verifiedTransaction(from: result)
                guard transaction.productID == proProductID else { continue }

                if transaction.revocationDate == nil {
                    hasProEntitlement = true
                }
            } catch {
                continue
            }
        }

        return hasProEntitlement
    }

    private static func withTimeout<T>(
        seconds: UInt64,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: seconds * 1_000_000_000)
                throw PurchaseError.timeout
            }

            guard let result = try await group.next() else {
                throw PurchaseError.timeout
            }

            group.cancelAll()
            return result
        }
    }

    private static func verifiedTransaction(
        from result: VerificationResult<Transaction>
    ) throws -> Transaction {
        switch result {
        case .verified(let transaction):
            return transaction
        case .unverified:
            throw PurchaseError.unverifiedTransaction
        }
    }
}

private enum PurchaseError: LocalizedError {
    case unverifiedTransaction
    case timeout

    var errorDescription: String? {
        switch self {
        case .unverifiedTransaction:
            return "購入情報を確認できませんでした。"
        case .timeout:
            return "処理がタイムアウトしました。"
        }
    }
}
