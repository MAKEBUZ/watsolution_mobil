import 'package:flutter_test/flutter_test.dart';
import 'package:watsolution_mobil/config/api_config.dart';

void main() {
  test(
    'AWS transport retains the original encrypted production namespace',
    () async {
      await ApiConfig.load(origin: ApiConfig.railwayProductionOrigin);
      final previousStorage = ApiConfig.storageOrigin;
      await ApiConfig.load(
        origin: '${ApiConfig.awsProductionOrigin}/',
        preserveRailwayStorage: true,
      );
      expect(ApiConfig.storageOrigin, previousStorage);
      expect(ApiConfig.account, '${ApiConfig.awsProductionOrigin}/api/account');
      expect(ApiConfig.meters, '${ApiConfig.awsProductionOrigin}/api/meters');
      expect(
        ApiConfig.invoices,
        '${ApiConfig.awsProductionOrigin}/api/invoices',
      );
    },
  );

  test(
    'other environments remain isolated and cannot claim production data',
    () async {
      for (final origin in [
        'https://test.example.com',
        '${ApiConfig.awsProductionOrigin}.attacker.example',
        ApiConfig.railwayProductionOrigin,
      ]) {
        await ApiConfig.load(origin: origin);
        expect(ApiConfig.storageOrigin, origin);
        await expectLater(
          ApiConfig.load(origin: origin, preserveRailwayStorage: true),
          throwsStateError,
        );
        expect(() => ApiConfig.baseUrl, throwsA(isA<TypeError>()));
      }
    },
  );

  test('migration rejects insecure origins and embedded credentials', () async {
    for (final origin in [
      'http://api.watsolution.3-142-23-99.sslip.io',
      'https://user:password@api.watsolution.3-142-23-99.sslip.io',
      '${ApiConfig.awsProductionOrigin}/api',
      '${ApiConfig.awsProductionOrigin}?target=other',
    ]) {
      await expectLater(
        ApiConfig.load(origin: origin, preserveRailwayStorage: true),
        throwsStateError,
      );
    }
  });
}
