import SwiftUI
import SwiftData
import UIKit
import UserNotifications

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system:
            return "システム設定に合わせる"
        case .light:
            return "ライト"
        case .dark:
            return "ダーク"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

final class NestTaskAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        // Tapping a local notification launches NestTask. Deep-link routing can be added in a later step.
    }
}

@main
struct NestTaskApp: App {
    @UIApplicationDelegateAdaptor(NestTaskAppDelegate.self) private var appDelegate
    @AppStorage("appearanceMode") private var appearanceModeRawValue = AppearanceMode.system.rawValue
    @StateObject private var purchaseManager = PurchaseManager()

    private var appearanceMode: AppearanceMode {
        AppearanceMode(rawValue: appearanceModeRawValue) ?? .system
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .preferredColorScheme(appearanceMode.colorScheme)
                .environmentObject(purchaseManager)
                .onChange(of: purchaseManager.isPro) { _, isPro in
                    if !isPro {
                        appearanceModeRawValue = AppearanceMode.system.rawValue
                    }
                }
                .task {
                    await purchaseManager.start()
                }
        }
        .modelContainer(for: [
            TaskTemplate.self,
            TemplateStep.self,
            ExecutionTask.self,
            ExecutionStep.self
        ])
    }
}
