import Flutter
import UIKit
import UserNotifications
import workmanager_apple

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// The one BGTaskScheduler identifier. It must equal the entry in
  /// Info.plist BGTaskSchedulerPermittedIdentifiers. F67c (Sprint 82) decides
  /// how the Dart side uses it; this sprint only registers it (ADR-0050 Q1).
  private static let backgroundScanTaskIdentifier = "com.myemailspamfilter.backgroundscan"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // flutter_local_notifications 22.3.2 README "iOS setup > General setup"
    // (README.md:473-482): show notifications through the plugin's delegate.
    UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate

    // workmanager_apple 0.9.11: register the BGTaskScheduler launch handler
    // before didFinishLaunching returns. An app on the UIScene lifecycle (this
    // one) must call registerLaunchHandlers() itself, because Flutter registers
    // plugins after this method returns
    // (WorkmanagerPlugin.swift:915-927). Register only; the task body is F67c.
    WorkmanagerPlugin.registerPeriodicTask(
      withIdentifier: AppDelegate.backgroundScanTaskIdentifier)
    WorkmanagerPlugin.registerLaunchHandlers()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
