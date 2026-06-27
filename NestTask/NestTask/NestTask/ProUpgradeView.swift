import SwiftUI

enum ProUpgradeReason: Identifiable {
    case templateLimit
    case templateDepth
    case templateDuplication
    case history
    case backup
    case appearance
    case executionTaskEditing

    var id: String {
        title
    }

    var title: String {
        switch self {
        case .templateLimit:
            return "テンプレートをもっと増やせます"
        case .templateDepth:
            return "タスクをさらに細かく分解できます"
        case .templateDuplication:
            return "テンプレート複製はPro機能です"
        case .history:
            return "履歴をもっと活用できます"
        case .backup:
            return "JSONバックアップはPro機能です"
        case .appearance:
            return "外観カスタムはPro機能です"
        case .executionTaskEditing:
            return "実行中の名前を調整できます"
        }
    }

    var message: String {
        switch self {
        case .templateLimit:
            return "無料版ではテンプレートを\(ProFeatureLimits.freeTemplateLimit)件まで作成できます。もっと多くの業務テンプレートを管理するには、NestTask Proをご利用ください。"
        case .templateDepth:
            return "孫タスクまで細かく分解するにはNestTask Proが必要です。"
        case .templateDuplication:
            return "元のテンプレートを残したまま別パターンを作るには、NestTask Proで複製を使えます。"
        case .history:
            return "履歴検索・フィルタ・詳細確認はNestTask Proの機能です。"
        case .backup:
            return "JSONバックアップはNestTask Proの機能です。"
        case .appearance:
            return "ライト/ダーク手動切り替えとアクセントカラー変更はNestTask Proの機能です。"
        case .executionTaskEditing:
            return "未完了の実行タスクで、今回のタスク名や元テンプレート名を編集し、テンプレートへ反映するか選べます。"
        }
    }
}

struct ProUpgradeView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var purchaseManager: PurchaseManager

    let reason: ProUpgradeReason?
    let onClose: () -> Void

    private let features: [ProFeature] = [
        ProFeature(systemName: "square.stack.3d.up", title: "テンプレート数の上限解除", detail: "定型業務を件数を気にせず保存できます。"),
        ProFeature(systemName: "list.bullet.indent", title: "孫タスクまで細かく分解", detail: "親・子の先まで手順を整理できます。"),
        ProFeature(systemName: "doc.on.doc", title: "テンプレート複製", detail: "既存テンプレートから別パターンを素早く作れます。"),
        ProFeature(systemName: "square.and.pencil", title: "未完了タスク名の編集", detail: "実行タスク名・元テンプレート名を変え、テンプレートへ反映するか選べます。"),
        ProFeature(systemName: "clock.arrow.circlepath", title: "履歴検索・フィルタ・詳細確認", detail: "完了済みの作業をあとから探しやすくします。"),
        ProFeature(systemName: "tray.and.arrow.up", title: "JSONバックアップ", detail: "テンプレートの書き出し・読み込みができます。"),
        ProFeature(systemName: "paintpalette", title: "外観テーマとアクセントカラー変更", detail: "見た目を作業環境に合わせられます。")
    ]

    init(reason: ProUpgradeReason? = nil, onClose: @escaping () -> Void = {}) {
        self.reason = reason
        self.onClose = onClose
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    if let reason {
                        ProReasonCard(reason: reason)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitle("Proでできること")

                        VStack(spacing: 0) {
                            ForEach(features) { feature in
                                ProFeatureRow(feature: feature)

                                if feature.id != features.last?.id {
                                    Divider()
                                        .overlay(NestTaskStyle.separator)
                                }
                            }
                        }
                        .padding(14)
                        .background(NestTaskStyle.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(NestTaskStyle.separator.opacity(0.82), lineWidth: 1)
                        )
                    }

                    purchasePanel
                }
                .padding(22)
            }
            .background(NestTaskStyle.background)
            .navigationTitle("NestTask Pro")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") {
                        onClose()
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .bold))
                }
            }
        }
        .presentationDetents([.large])
        .task {
            await purchaseManager.loadProducts()
        }
        .alert(
            "購入処理を完了できませんでした",
            isPresented: Binding(
                get: { purchaseManager.lastErrorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        purchaseManager.lastErrorMessage = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {
                purchaseManager.lastErrorMessage = nil
            }
        } message: {
            Text(purchaseManager.lastErrorMessage ?? "時間をおいてもう一度お試しください。")
        }
        .alert(
            "購入情報",
            isPresented: Binding(
                get: { purchaseManager.lastInfoMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        purchaseManager.lastInfoMessage = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {
                purchaseManager.lastInfoMessage = nil
            }
        } message: {
            Text(purchaseManager.lastInfoMessage ?? "")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: purchaseManager.isPro ? "checkmark.seal.fill" : "sparkles")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(purchaseManager.isPro ? NestTaskStyle.green : NestTaskStyle.teal)
                    .frame(width: 44, height: 44)
                    .background(
                        purchaseManager.isPro ? NestTaskStyle.green.opacity(0.12) : NestTaskStyle.tealSoft,
                        in: Circle()
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text("NestTask Pro")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(NestTaskStyle.ink)

                    Text(purchaseManager.isPro ? "Pro機能が有効です" : "くり返し業務を、もっと本格的に管理できます。")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(NestTaskStyle.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Text("購入はApple IDに紐づく買い切りです。機種変更後も復元できます。")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(NestTaskStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var purchasePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            if purchaseManager.isPro {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(NestTaskStyle.green)

                    Text("NestTask Pro有効")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(NestTaskStyle.ink)

                    Spacer()
                }
                .padding(16)
                .background(NestTaskStyle.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(NestTaskStyle.green.opacity(0.32), lineWidth: 1.2)
                )
            } else {
                Button {
                    Task {
                        await purchaseManager.purchasePro()
                    }
                } label: {
                    HStack {
                        if purchaseManager.isPurchasing {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "sparkles")
                                .font(.system(size: 16, weight: .bold))
                        }

                        Text(purchaseButtonTitle)
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(NestTaskStyle.teal, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: NestTaskStyle.teal.opacity(0.22), radius: 14, x: 0, y: 7)
                }
                .buttonStyle(.plain)
                .disabled(purchaseManager.isPurchasing || purchaseManager.isRestoringPurchases || purchaseManager.isLoadingProducts)

                Button {
                    Task {
                        await purchaseManager.restorePurchases()
                    }
                } label: {
                    HStack(spacing: 8) {
                        if purchaseManager.isRestoringPurchases {
                            ProgressView()
                                .tint(NestTaskStyle.teal)
                        }

                        Text(purchaseManager.isRestoringPurchases ? "復元中" : "購入を復元")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundStyle(NestTaskStyle.teal)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                .disabled(purchaseManager.isPurchasing || purchaseManager.isRestoringPurchases)
                .opacity(purchaseManager.isRestoringPurchases ? 0.55 : 1)
            }
        }
    }

    private var purchaseButtonTitle: String {
        if purchaseManager.isPurchasing {
            return "購入処理中"
        }
        if let price = purchaseManager.proDisplayPrice {
            return "NestTask Proを購入（\(price)）"
        }
        if purchaseManager.isLoadingProducts {
            return "価格を読み込み中"
        }
        return "NestTask Proを購入"
    }
}

private struct ProFeature: Identifiable {
    let systemName: String
    let title: String
    let detail: String

    var id: String {
        title
    }
}

private struct ProReasonCard: View {
    let reason: ProUpgradeReason

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(reason.title)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(NestTaskStyle.ink)

            Text(reason.message)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(NestTaskStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NestTaskStyle.tealSoft, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(NestTaskStyle.teal.opacity(0.22), lineWidth: 1)
        )
    }
}

private struct ProFeatureRow: View {
    let feature: ProFeature

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: feature.systemName)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(NestTaskStyle.teal)
                .frame(width: 30, height: 30)
                .background(NestTaskStyle.tealSoft, in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(feature.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(NestTaskStyle.ink)

                Text(feature.detail)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(NestTaskStyle.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 9)
    }
}
