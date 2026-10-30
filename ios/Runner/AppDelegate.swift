import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // google_sign_in_ios re-raises the Google SDK's NSException when the app
    // has no OAuth client ID or is missing its URL scheme, which kills the
    // app. AuthService asks this channel first so it can fail gracefully.
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "GoogleSignInConfig") {
      let channel = FlutterMethodChannel(
        name: "clearcase/google_sign_in",
        binaryMessenger: registrar.messenger()
      )
      channel.setMethodCallHandler { call, result in
        if call.method == "isConfigured" {
          result(AppDelegate.isGoogleSignInConfigured())
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }
  }

  /// True when a Google client ID is set (Info.plist `GIDClientID`, or
  /// `CLIENT_ID` in GoogleService-Info.plist) and its reversed form is
  /// registered under CFBundleURLTypes.
  private static func isGoogleSignInConfigured() -> Bool {
    var clientId = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String
    if clientId?.isEmpty ?? true,
       let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
       let plist = NSDictionary(contentsOfFile: path) {
      clientId = plist["CLIENT_ID"] as? String
    }
    guard let id = clientId, !id.isEmpty else { return false }

    let reversedId = id.components(separatedBy: ".").reversed().joined(separator: ".")
    let urlTypes = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] ?? []
    let schemes = urlTypes.flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }
    return schemes.contains { $0.caseInsensitiveCompare(reversedId) == .orderedSame }
  }
}
