import UIKit
import Flutter
import GoogleMaps // 👈 Importa o Google Maps

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    // 👇 Registra a sua API Key do Google Maps
    GMSServices.provideAPIKey("AIzaSyB4kbYyj-hhUeLLeRTlwwB93JyS7scyH_o")

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
