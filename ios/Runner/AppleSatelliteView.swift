import Flutter
import MapKit
import UIKit

final class AppleSatelliteFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    AppleSatellitePlatformView(frame: frame, id: viewId, arguments: args, messenger: messenger)
  }
}

private final class AppleSatellitePlatformView: NSObject, FlutterPlatformView {
  private let map: AppleImageryMap
  private let channel: FlutterMethodChannel

  init(frame: CGRect, id: Int64, arguments: Any?, messenger: FlutterBinaryMessenger) {
    map = AppleImageryMap(frame: frame)
    channel = FlutterMethodChannel(
      name: "com.oneupbyte.trakkar/apple-satellite/\(id)", binaryMessenger: messenger
    )
    super.init()
    map.update(arguments)
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "update" else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.map.update(call.arguments)
      result(nil)
    }
  }

  func view() -> UIView { map }

  deinit {
    channel.setMethodCallHandler(nil)
  }
}

private final class AppleImageryMap: UIView {
  private struct Camera: Equatable {
    let latitude: Double
    let longitude: Double
    let worldWidth: Double
    let heading: Double
  }

  private var requestedCamera: Camera?
  private var appliedCamera: Camera?
  private var appliedSize = CGSize.zero
  private var distancePerGroundHeight = 1.2
  private let map = MKMapView()

  override init(frame: CGRect) {
    super.init(frame: frame)
    if #available(iOS 16.0, *) {
      map.preferredConfiguration = MKImageryMapConfiguration(elevationStyle: .flat)
    } else {
      map.mapType = .satellite
    }
    map.isPitchEnabled = false
    isUserInteractionEnabled = false
    map.showsCompass = false
    map.showsScale = false
    addSubview(map)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func update(_ arguments: Any?) {
    guard let values = arguments as? [String: Double],
          let latitude = values["latitude"], let longitude = values["longitude"],
          let worldWidth = values["worldWidth"], worldWidth > 0,
          let heading = values["heading"], let bottomInset = values["bottomInset"]
    else { return }

    // Give MapKit's own logo and legal attribution room above the glass tabs.
    if map.layoutMargins.bottom != bottomInset {
      map.layoutMargins.bottom = bottomInset
    }
    requestedCamera = Camera(latitude: latitude, longitude: longitude, worldWidth: worldWidth, heading: heading)
    applyCamera()
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    map.frame = bounds
    applyCamera()
  }

  private func applyCamera() {
    guard let requestedCamera, bounds.width > 64, bounds.height > 64,
          requestedCamera != appliedCamera || bounds.size != appliedSize else { return }
    appliedCamera = requestedCamera
    appliedSize = bounds.size

    let wrappedLongitude = (requestedCamera.longitude + 180).truncatingRemainder(dividingBy: 360)
    let center = CLLocationCoordinate2D(
      latitude: max(-85.05112878, min(85.05112878, requestedCamera.latitude)),
      longitude: (wrappedLongitude < 0 ? wrappedLongitude + 360 : wrappedLongitude) - 180
    )
    let worldWidth = MKMapRect.world.width
    let mapPointsPerPoint = worldWidth / requestedCamera.worldWidth
    let groundHeight = Double(bounds.height) * mapPointsPerPoint *
      MKMetersPerMapPointAtLatitude(center.latitude)
    let target = MKMapCamera(
      lookingAtCenter: center,
      fromDistance: groundHeight * distancePerGroundHeight,
      pitch: 0,
      heading: requestedCamera.heading
    )
    map.setCamera(target, animated: false)

    // Match the Web Mercator scale used to position Flutter's markers.
    let left = MKMapPoint(map.convert(CGPoint(x: map.bounds.midX - 16, y: map.bounds.midY), toCoordinateFrom: map))
    let right = MKMapPoint(map.convert(CGPoint(x: map.bounds.midX + 16, y: map.bounds.midY), toCoordinateFrom: map))
    let dx = abs(right.x - left.x)
    let measured = hypot(min(dx, worldWidth - dx), right.y - left.y) / 32
    let correction = mapPointsPerPoint / measured
    if (0.5...2).contains(correction), abs(correction - 1) > 0.0025 {
      target.centerCoordinateDistance *= correction
      map.setCamera(target, animated: false)
      // Keep a bounded estimate in case MapKit clamps a subsequent zoom.
      distancePerGroundHeight = min(2, max(0.5, target.centerCoordinateDistance / groundHeight))
    }
  }
}
