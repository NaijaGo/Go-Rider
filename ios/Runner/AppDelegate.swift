import Flutter
import UIKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var alertPlayer: AVAudioPlayer?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(name: "naijago/rider_alerts", binaryMessenger: controller.binaryMessenger)
      channel.setMethodCallHandler { [weak self] call, result in
        switch call.method {
        case "playAlert":
          do {
            guard let url = Bundle.main.url(forResource: "rider_job_alert", withExtension: "wav") else {
              result(FlutterError(code: "ALERT_UNAVAILABLE", message: "Missing alert sound", details: nil)); return
            }
            // Ambient respects the rider's silent switch and audio settings.
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            self?.alertPlayer?.stop()
            self?.alertPlayer = try AVAudioPlayer(contentsOf: url)
            self?.alertPlayer?.volume = 1.0
            let played = self?.alertPlayer?.play() ?? false
            result(played)
          } catch { result(FlutterError(code: "ALERT_UNAVAILABLE", message: "Unable to play alert", details: nil)) }
        case "openSettings":
          if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
          }
          result(nil)
        default: result(FlutterMethodNotImplemented)
        }
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
