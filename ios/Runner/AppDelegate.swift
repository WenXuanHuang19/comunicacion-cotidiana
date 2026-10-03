import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(name: "mx.edu.comunicacion/local_storage", binaryMessenger: controller.binaryMessenger)
      channel.setMethodCallHandler { call, result in
        guard call.method == "excludeFromBackup",
              let arguments = call.arguments as? [String: Any],
              let path = arguments["path"] as? String else {
          result(FlutterMethodNotImplemented)
          return
        }
        do {
          var url = URL(fileURLWithPath: path, isDirectory: true)
          var values = URLResourceValues()
          values.isExcludedFromBackup = true
          try url.setResourceValues(values)
          result(nil)
        } catch {
          result(FlutterError(code: "BACKUP_EXCLUSION", message: "No se pudo configurar el almacenamiento local.", details: nil))
        }
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
