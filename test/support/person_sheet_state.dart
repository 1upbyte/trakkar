import 'package:trakkar/app_state.dart';
import 'package:trakkar/models/traccar_device.dart';
import 'package:trakkar/models/traccar_position.dart';

class PersonSheetState extends AppState {
  PersonSheetState() {
    phase = AppPhase.ready;
    devices = const [
      TraccarDevice(
        id: 1,
        name: 'Alex',
        uniqueId: 'sheet-test',
        status: 'online',
        raw: {},
      ),
    ];
    positions = const {
      1: TraccarPosition(
        id: 1,
        deviceId: 1,
        latitude: 40.7527,
        longitude: -73.9772,
        valid: true,
        address: 'Grand Central Terminal, New York',
      ),
    };
  }

  @override
  void setAppForeground(bool visible) {}

  @override
  Future<void> refreshTrackingHealth() async {}
}
