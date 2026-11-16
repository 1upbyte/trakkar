import Flutter
import UIKit

/// UIKit owns the material so iOS supplies refraction, lighting, and accessibility.
final class LiquidGlassFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    LiquidGlassPlatformView(frame: frame, id: viewId, arguments: args, messenger: messenger)
  }
}

private final class LiquidGlassPlatformView: NSObject, FlutterPlatformView {
  private let glass: GlassMaterialView
  private let channel: FlutterMethodChannel

  init(frame: CGRect, id: Int64, arguments: Any?, messenger: FlutterBinaryMessenger) {
    glass = GlassMaterialView(frame: frame)
    channel = FlutterMethodChannel(
      name: "com.oneupbyte.trakkar/liquid-glass/\(id)", binaryMessenger: messenger
    )
    super.init()
    glass.update(arguments as? [String: Any] ?? [:], animated: false)
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "update" else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.glass.update(call.arguments as? [String: Any] ?? [:], animated: true)
      result(nil)
    }
  }

  deinit {
    channel.setMethodCallHandler(nil)
  }

  func view() -> UIView { glass }
}

final class GlassMaterialView: UIView {
  private let material = UIVisualEffectView()
  private let selection = UIVisualEffectView()
  private var configuration: [String: Any] = [:]
  private var materialConfiguration: NSDictionary?
  private var selectionIndex: Int?
  private var radius: CGFloat = 28

  override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = .clear
    isUserInteractionEnabled = false
    material.isUserInteractionEnabled = false
    addSubview(material)
    material.contentView.addSubview(selection)
    NotificationCenter.default.addObserver(
      self, selector: #selector(accessibilityChanged),
      name: UIAccessibility.reduceTransparencyStatusDidChangeNotification, object: nil
    )
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  deinit { NotificationCenter.default.removeObserver(self) }

  @objc private func accessibilityChanged() {
    update(configuration, animated: false)
  }

  func update(_ values: [String: Any], animated: Bool) {
    let previousIndex = selectionIndex
    configuration = values
    radius = (values["radius"] as? NSNumber)?.doubleValue ?? 28
    selectionIndex = (values["selectedIndex"] as? NSNumber)?.intValue
    overrideUserInterfaceStyle = (values["dark"] as? Bool == true) ? .dark : .light
    let tint = (values["tint"] as? NSNumber).map { value -> UIColor in
      let argb = value.uint32Value
      return UIColor(
        red: CGFloat((argb >> 16) & 255) / 255,
        green: CGFloat((argb >> 8) & 255) / 255,
        blue: CGFloat(argb & 255) / 255,
        alpha: CGFloat((argb >> 24) & 255) / 255
      )
    }
    // Do not restart the optical effect on unrelated Flutter rebuilds.
    let nextMaterialConfiguration = NSDictionary(dictionary: [
      "dark": values["dark"] ?? false,
      "tint": values["tint"] ?? NSNull(),
      "reduceTransparency": UIAccessibility.isReduceTransparencyEnabled,
    ])
    if materialConfiguration != nextMaterialConfiguration {
      materialConfiguration = nextMaterialConfiguration
      if UIAccessibility.isReduceTransparencyEnabled {
        material.effect = nil
        material.backgroundColor = tint ?? .secondarySystemGroupedBackground
        selection.effect = nil
        selection.backgroundColor = UIColor.label.withAlphaComponent(0.10)
      } else if #available(iOS 26.0, *) {
        let effect = UIGlassEffect(style: .regular)
        effect.tintColor = tint
        material.effect = effect
        material.backgroundColor = .clear
        let selectedEffect = UIGlassEffect(style: .clear)
        selectedEffect.tintColor = UIColor.systemTeal.withAlphaComponent(0.12)
        selection.effect = selectedEffect
        selection.backgroundColor = .clear
      } else {
        material.effect = UIBlurEffect(style: .systemMaterial)
        material.backgroundColor = tint?.withAlphaComponent(0.6) ?? .clear
        selection.effect = nil
        selection.backgroundColor = UIColor.label.withAlphaComponent(0.08)
      }
    }
    selection.isHidden = selectionIndex == nil
    setNeedsLayout()
    let reduceMotion = UIAccessibility.isReduceMotionEnabled || values["reduceMotion"] as? Bool == true
    if animated && previousIndex != nil && previousIndex != selectionIndex && !reduceMotion {
      UIView.animate(
        withDuration: 0.38, delay: 0, usingSpringWithDamping: 0.85,
        initialSpringVelocity: 0, options: [.beginFromCurrentState, .allowUserInteraction]
      ) { self.layoutIfNeeded() }
    } else {
      layoutIfNeeded()
    }
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    material.frame = bounds
    if #available(iOS 26.0, *) {
      material.cornerConfiguration = .corners(radius: .fixed(Double(radius)))
    } else {
      material.layer.cornerRadius = radius
      material.layer.cornerCurve = .continuous
      material.clipsToBounds = true
    }
    let inset: CGFloat = 5
    let width = max(0, (bounds.width - inset * 2) / 4)
    selection.frame = CGRect(
      x: inset + CGFloat(selectionIndex ?? 0) * width,
      y: inset, width: width, height: max(0, bounds.height - inset * 2)
    )
    if #available(iOS 26.0, *) {
      selection.cornerConfiguration = .capsule()
    } else {
      selection.layer.cornerRadius = max(0, (bounds.height - inset * 2) / 2)
      selection.layer.cornerCurve = .continuous
      selection.clipsToBounds = true
    }
  }
}
