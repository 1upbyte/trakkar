import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'credential_store.dart';
import 'traccar_api.dart';

enum GeocodingProvider { traccarServer, geoapify, mapTiler, custom }

class GeocodingSettings {
  const GeocodingSettings({
    this.provider = GeocodingProvider.traccarServer,
    this.apiKey = '',
    this.customUrlTemplate = '',
  });

  final GeocodingProvider provider;
  final String apiKey;
  final String customUrlTemplate;

  bool get requiresApiKey =>
      provider == GeocodingProvider.geoapify ||
      provider == GeocodingProvider.mapTiler;
}

class ReverseGeocoder {
  ReverseGeocoder(
    this._credentialStore, {
    SharedPreferencesAsync? preferences,
    http.Client? client,
  }) : _preferences = preferences ?? SharedPreferencesAsync(),
       _client = client ?? http.Client();

  static const _providerKey = 'geocoding.provider';
  static const _templateKey = 'geocoding.customUrlTemplate';

  final CredentialStore _credentialStore;
  final SharedPreferencesAsync _preferences;
  final http.Client _client;

  Future<GeocodingSettings> loadSettings() async {
    final providerName = await _preferences.getString(_providerKey);
    GeocodingProvider? provider;
    for (final value in GeocodingProvider.values) {
      if (value.name == providerName) {
        provider = value;
        break;
      }
    }
    return GeocodingSettings(
      provider: provider ?? GeocodingProvider.traccarServer,
      apiKey: await _credentialStore.readGeocodingKey(),
      customUrlTemplate: await _preferences.getString(_templateKey) ?? '',
    );
  }

  Future<void> saveSettings(GeocodingSettings settings) async {
    await Future.wait(<Future<void>>[
      _preferences.setString(_providerKey, settings.provider.name),
      _preferences.setString(_templateKey, settings.customUrlTemplate.trim()),
      _credentialStore.saveGeocodingKey(settings.apiKey),
    ]);
  }

  Future<String> lookup({
    required double latitude,
    required double longitude,
    required GeocodingSettings settings,
    required TraccarApi api,
  }) async {
    if (settings.provider == GeocodingProvider.traccarServer) {
      return api.reverseGeocode(latitude, longitude);
    }
    if (settings.requiresApiKey && settings.apiKey.trim().isEmpty) {
      throw const FormatException('Add an API key in Settings first.');
    }

    late final Uri uri;
    switch (settings.provider) {
      case GeocodingProvider.traccarServer:
        throw StateError('Handled above');
      case GeocodingProvider.geoapify:
        uri = Uri.https('api.geoapify.com', '/v1/geocode/reverse', {
          'lat': latitude.toString(),
          'lon': longitude.toString(),
          'apiKey': settings.apiKey,
        });
        break;
      case GeocodingProvider.mapTiler:
        uri = Uri.https(
          'api.maptiler.com',
          '/geocoding/$longitude,$latitude.json',
          <String, String>{'key': settings.apiKey},
        );
        break;
      case GeocodingProvider.custom:
        final template = settings.customUrlTemplate;
        if (!template.contains('{lat}') || !template.contains('{lon}')) {
          throw const FormatException(
            'The custom URL must contain {lat} and {lon}.',
          );
        }
        uri = Uri.parse(
          template
              .replaceAll('{lat}', Uri.encodeComponent('$latitude'))
              .replaceAll('{lon}', Uri.encodeComponent('$longitude'))
              .replaceAll('{key}', Uri.encodeComponent(settings.apiKey)),
        );
        break;
    }

    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw TraccarApiException(
        'Reverse geocoding failed (${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }
    return _parseResponse(response.body, settings.provider);
  }

  static String _parseResponse(String body, GeocodingProvider provider) {
    if (provider == GeocodingProvider.custom) {
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map) {
          for (final key in const ['formatted', 'display_name', 'place_name']) {
            final value = decoded[key];
            if (value is String && value.isNotEmpty) return value;
          }
        }
      } on FormatException {
        return body.trim();
      }
      return body.trim();
    }

    final decoded = Map<String, dynamic>.from(jsonDecode(body) as Map);
    final features = decoded['features'] as List<dynamic>? ?? const [];
    if (features.isEmpty) return 'No address found';
    final feature = Map<String, dynamic>.from(features.first as Map);
    if (provider == GeocodingProvider.mapTiler) {
      return feature['place_name'] as String? ?? 'No address found';
    }
    final properties = Map<String, dynamic>.from(
      feature['properties'] as Map? ?? const <String, dynamic>{},
    );
    return properties['formatted'] as String? ?? 'No address found';
  }

  void close() => _client.close();
}
