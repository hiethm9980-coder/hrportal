import Flutter
import UIKit
import awesome_notifications
import firebase_messaging
import flutter_secure_storage_darwin

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Register plugins that are used inside Awesome Notifications background
    // actions (SilentBackgroundAction). These run in a separate Dart isolate
    // that does NOT auto-register plugins — without explicit registration
    // they crash with MissingPluginException.
    //
    // Plugins needed in background:
    //   - AwesomeNotifications: to dismiss/create follow-up notifications
    //   - FlutterSecureStorage: to read auth token + baseUrl for API calls
    SwiftAwesomeNotificationsPlugin.setPluginRegistrantCallback { registry in
      SwiftAwesomeNotificationsPlugin.register(
        with: registry.registrar(forPlugin: "io.flutter.plugins.awesomenotifications.AwesomeNotificationsPlugin")!
      )
      FlutterSecureStorageDarwinPlugin.register(
        with: registry.registrar(forPlugin: "FlutterSecureStorageDarwinPlugin")!
      )
    }

    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }
    application.registerForRemoteNotifications()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
