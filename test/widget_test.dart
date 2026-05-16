import 'package:flutter_test/flutter_test.dart';
import 'package:naijago_ridersapp/core/api/api_paths.dart';
import 'package:naijago_ridersapp/core/map/mapbox_config.dart';

void main() {
  test('rider API paths match the backend route contract', () {
    expect(ApiPaths.login, '/riders/login');
    expect(ApiPaths.register, '/riders/register');
    expect(ApiPaths.uploadRiderBundlePublic, '/uploads/rider-bundle-public');
    expect(ApiPaths.availableOrders, '/riders/orders/available');
    expect(ApiPaths.claimOrder('abc123'), '/riders/orders/claim/abc123');
    expect(ApiPaths.verifyPickup, '/riders/orders/verify-pickup');
    expect(ApiPaths.verifyDelivery, '/riders/orders/verify-delivery');
    expect(ApiPaths.withdraw, '/riders/withdraw');
  });

  test('Mapbox config keeps secrets out of source by default', () {
    expect(MapboxConfig.hasToken, isFalse);
    expect(MapboxConfig.styleId, 'streets-v12');
  });
}
