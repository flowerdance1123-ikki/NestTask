import SwiftUI
import SwiftData
import UIKit
import UserNotifications

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

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .preferredColorScheme(.light)
        }
        .modelContainer(for: [
            TaskTemplate.self,
            TemplateStep.self,
            ExecutionTask.self,
            ExecutionStep.self
        ])
    }
}
