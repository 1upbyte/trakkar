import 'dart:io';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';

enum DiagnosticEvent {
  appStarted,
  appForegrounded,
  appBackgrounded,
  trackerConfiguring,
  trackerStarting,
  trackerStopping,
  flutterError,
  uncaughtDartError,
}

abstract final class LocalDiagnostics {
  static const _channel = MethodChannel('com.oneupbyte.trakkar/diagnostics');
  static const _retention = Duration(days: 7);
  static const _maxLogBytes = 32 * 1024;
  static const _logNames = ['events.previous.log', 'events.log'];
  static const _exportName = 'trakkar-diagnostics.txt';
  static Future<Directory?>? _directory;
  static Future<void> _pending = Future.value();
  static AppLifecycleListener? _lifecycle;
  static int _queuedEntries = 0;

  static bool get supported =>
      !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  static void install() {
    if (!supported || _lifecycle != null) return;
    final flutterHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      record(DiagnosticEvent.flutterError, details.stack);
      flutterHandler?.call(details);
    };
    final dispatcher = PlatformDispatcher.instance;
    final dartHandler = dispatcher.onError;
    dispatcher.onError = (error, stack) {
      record(DiagnosticEvent.uncaughtDartError, stack);
      return dartHandler?.call(error, stack) ?? false;
    };
    _lifecycle = AppLifecycleListener(
      onResume: () => record(DiagnosticEvent.appForegrounded),
      onPause: () => record(DiagnosticEvent.appBackgrounded),
    );
    record(DiagnosticEvent.appStarted);
  }

  static final _frame = RegExp(
    r'^#\d+\s+[\w.$<>/ -]+\s+\((?:package:|dart:)[\w./:-]+\)$',
  );

  static void record(DiagnosticEvent event, [StackTrace? stack]) {
    // Diagnostics never delay or change the outcome of the operation recorded.
    if (_lifecycle == null || _queuedEntries >= 16) return;
    final timestamp = DateTime.now().toUtc().toIso8601String();
    _queuedEntries++;
    _pending = _pending
        .then((_) async {
          final frames = stack
              ?.toString()
              .split('\n')
              .where((line) => line.length <= 256 && _frame.hasMatch(line))
              .take(12);
          final entry = ['$timestamp ${event.name}', ...?frames, ''].join('\n');
          final directory = await _getDirectory();
          if (directory == null) return;
          final current = File('${directory.path}/events.log');
          final previous = File('${directory.path}/events.previous.log');
          await _removeIfExpired(previous);
          await _removeIfExpired(current);
          if (await current.exists() &&
              await current.length() + entry.length > _maxLogBytes) {
            await current.rename(previous.path);
          }
          await current.writeAsString(entry, mode: FileMode.append);
        })
        .catchError((Object _) {
          _directory = null;
        })
        .whenComplete(() {
          _queuedEntries--;
        });
  }

  static Future<Directory?> _getDirectory() async {
    try {
      return await (_directory ??= _prepareDirectory());
    } on Object {
      _directory = null;
      return null;
    }
  }

  static Future<Directory?> _prepareDirectory() async {
    final path = await _channel.invokeMethod<String>('cacheDirectory');
    if (path == null) return null;
    final directory = Directory(path);
    await directory.create(recursive: true);
    for (final name in [..._logNames, _exportName]) {
      await _removeIfExpired(File('$path/$name'));
    }
    return directory;
  }

  static Future<void> _removeIfExpired(File file) async {
    final stat = await file.stat();
    if (stat.type == FileSystemEntityType.file &&
        DateTime.now().difference(stat.modified) > _retention) {
      await file.delete();
    }
  }

  static Future<String> export() {
    final export = _pending.then((_) => _writeExport());
    _pending = export.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return export;
  }

  static Future<String> _writeExport() async {
    final directory = await _getDirectory();
    if (directory == null) throw StateError('Diagnostics cache unavailable');
    final info = await PackageInfo.fromPlatform();
    String? native;
    try {
      native = await _channel.invokeMethod<String>('nativeReport');
    } on PlatformException {
      native = 'Platform crash details unavailable';
    }
    final report = StringBuffer()
      ..writeln('Trakkar ${info.version} (${info.buildNumber})')
      ..writeln(
        '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
      )
      ..writeln('Exported ${DateTime.now().toUtc().toIso8601String()}')
      ..writeln();
    for (final name in _logNames) {
      final file = File('${directory.path}/$name');
      await _removeIfExpired(file);
      if (await file.exists()) report.write(await file.readAsString());
    }
    if (native != null && native.isNotEmpty) {
      report
        ..writeln()
        ..writeln(native);
    }
    // Reuse a single cache file. A receiving app may read it after the share
    // sheet closes, so it expires on a later launch.
    final file = File('${directory.path}/$_exportName');
    await file.writeAsString(report.toString());
    return file.path;
  }
}
