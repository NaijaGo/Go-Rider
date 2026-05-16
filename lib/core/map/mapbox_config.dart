class MapboxConfig {
  static const _fallbackAccessToken = String.fromEnvironment(
    'MAPBOX_ACCESS_TOKEN',
  );
  static const _fallbackStyleId = String.fromEnvironment(
    'MAPBOX_STYLE_ID',
    defaultValue: 'streets-v12',
  );

  static String? _backendTileUrl;
  static bool _backendHasToken = false;

  static bool get hasToken =>
      _backendHasToken || _fallbackAccessToken.trim().isNotEmpty;

  static String get styleId => _fallbackStyleId;

  static String get tileUrl =>
      _backendTileUrl ??
      'https://api.mapbox.com/styles/v1/mapbox/$_fallbackStyleId/tiles/512/{z}/{x}/{y}'
          '?access_token=$_fallbackAccessToken';

  static void applyBackendConfig(Map<String, dynamic> data) {
    _backendHasToken = data['hasToken'] == true;
    final tileUrl = data['tileUrl']?.toString();
    if (tileUrl != null && tileUrl.trim().isNotEmpty) {
      _backendTileUrl = tileUrl;
    }
  }
}
