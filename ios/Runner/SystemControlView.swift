import Flutter
import UIKit

final class SystemControlFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    SystemControlPlatformView(frame: frame, id: viewId, arguments: args, messenger: messenger)
  }
}

private final class SystemControlPlatformView: NSObject, FlutterPlatformView {
  private let container = UIView()
  private let control: UIControl
  private let channel: FlutterMethodChannel
  private var configuration: [String: Any] = [:]

  init(frame: CGRect, id: Int64, arguments: Any?, messenger: FlutterBinaryMessenger) {
    let values = arguments as? [String: Any] ?? [:]
    switch values["kind"] as? String {
    case "switch": control = UISwitch()
    case "slider": control = UISlider()
    default: control = UISegmentedControl(items: values["labels"] as? [String] ?? [])
    }
    channel = FlutterMethodChannel(
      name: "com.oneupbyte.trakkar/system-control/\(id)", binaryMessenger: messenger
    )
    super.init()
    container.frame = frame
    container.backgroundColor = .clear
    control.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(control)
    NSLayoutConstraint.activate([
      control.centerYAnchor.constraint(equalTo: container.centerYAnchor),
      control.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      control.trailingAnchor.constraint(equalTo: container.trailingAnchor),
    ])
    control.addTarget(self, action: #selector(changed), for: .valueChanged)
    update(values)
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "update" else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.update(call.arguments as? [String: Any] ?? [:])
      result(nil)
    }
  }

  deinit { channel.setMethodCallHandler(nil) }

  func view() -> UIView { container }

  private func update(_ values: [String: Any]) {
    configuration = values
    container.overrideUserInterfaceStyle = values["dark"] as? Bool == true ? .dark : .light
    control.isEnabled = values["enabled"] as? Bool ?? true
    control.accessibilityLabel = values["label"] as? String
    if let toggle = control as? UISwitch {
      toggle.setOn(values["value"] as? Bool ?? false, animated: false)
    } else if let slider = control as? UISlider {
      slider.minimumValue = (values["min"] as? NSNumber)?.floatValue ?? 0
      slider.maximumValue = (values["max"] as? NSNumber)?.floatValue ?? 1
      // Preserve the thumb's direct manipulation while Flutter saves changes.
      if !slider.isTracking {
        slider.setValue((values["value"] as? NSNumber)?.floatValue ?? 0, animated: false)
      }
    } else if let segments = control as? UISegmentedControl {
      segments.selectedSegmentIndex = (values["value"] as? NSNumber)?.intValue ?? 0
    }
  }

  @objc private func changed() {
    if let toggle = control as? UISwitch {
      channel.invokeMethod("changed", arguments: toggle.isOn)
    } else if let slider = control as? UISlider {
      var value = Double(slider.value)
      if let steps = (configuration["divisions"] as? NSNumber)?.doubleValue, steps > 0 {
        let minimum = Double(slider.minimumValue)
        let step = (Double(slider.maximumValue) - minimum) / steps
        if step > 0 { value = minimum + ((value - minimum) / step).rounded() * step }
      }
      channel.invokeMethod("changed", arguments: value)
    } else if let segments = control as? UISegmentedControl {
      channel.invokeMethod("changed", arguments: segments.selectedSegmentIndex)
    }
  }
}
