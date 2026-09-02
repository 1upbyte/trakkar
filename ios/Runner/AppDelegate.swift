import CoreLocation
import Flutter
import GoogleMaps
import UIKit
import TraccarClientSDK

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var locationPermissionManager: CLLocationManager?
  private var trackingSupportChannel: FlutterMethodChannel?
  private var mapSdkChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Rebuild the persisted SDK tracker as early as possible when iOS relaunches
    // the app for a significant location change or monitored-region exit.
    Task {
      _ = try? await TrackerKt.sharedTracker()
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let channel = FlutterMethodChannel(
      name: "com.oneupbyte.trakkar/tracking-support",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      DispatchQueue.main.async {
        switch call.method {
        case "requestAlwaysIfNeeded":
          self?.requestAlwaysLocationIfNeeded()
          result(nil)
        case "getTrackingHealth":
          let status = CLLocationManager().authorizationStatus
          result([
            "locationAlways": status == .authorizedAlways,
            "batteryOptimizationOkay": true,
            "batteryOptimizationRelevant": false,
          ])
        case "openLocationSettings":
          guard let url = URL(string: UIApplication.openSettingsURLString) else {
            result(nil)
            return
          }
          UIApplication.shared.open(url)
          result(nil)
        case "openBatterySettings":
          // iOS does not expose a per-app battery-optimization exemption.
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }
    trackingSupportChannel = channel

    // The Google Maps key is stored on the Traccar server and handed over
    // before the first map view is created, instead of being compiled in.
    let mapChannel = FlutterMethodChannel(
      name: "com.oneupbyte.trakkar/map-sdk",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    mapChannel.setMethodCallHandler { call, result in
      DispatchQueue.main.async {
        switch call.method {
        case "setGoogleMapsApiKey":
          guard
            let arguments = call.arguments as? [String: Any],
            let key = (arguments["key"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
            !key.isEmpty
          else {
            result(false)
            return
          }
          result(GMSServices.provideAPIKey(key))
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }
    mapSdkChannel = mapChannel
  }

  private func requestAlwaysLocationIfNeeded() {
    let manager = locationPermissionManager ?? CLLocationManager()
    locationPermissionManager = manager

    // Traccar SDK handles the initial Not Determined request. This covers a
    // prior While Using choice without creating a second tracking pipeline.
    if manager.authorizationStatus == .authorizedWhenInUse {
      manager.requestAlwaysAuthorization()
    }
  }
}
