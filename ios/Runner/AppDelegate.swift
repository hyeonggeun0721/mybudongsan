import UIKit
import Flutter
import GoogleMaps     // 1. Google Maps import
import FirebaseCore   // 2. Firebase Core import

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    // 3. Firebase 초기화 (Crashlytics 등에 필요)
    FirebaseApp.configure()

    // 4. Google Maps API 키 설정
    GMSServices.provideAPIKey("AIzaSyDDEMu6gdsvgl6srD-kDGrUTVtVwJ28hmM")

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
