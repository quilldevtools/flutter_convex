import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_convex/flutter_convex.dart';

void main() {
  group('ConvexConfig', () {
    test('can be initialized with deployment URL', () {
      const testUrl = 'https://test.convex.cloud';
      
      expect(() => ConvexConfig.initialize(testUrl), returnsNormally);
      expect(ConvexConfig.isConfigured, isTrue);
      expect(ConvexConfig.deploymentUrl, equals(testUrl));
    });

    test('can be reconfigured with different URL', () {
      const firstUrl = 'https://first.convex.cloud';
      const secondUrl = 'https://second.convex.cloud';
      
      ConvexConfig.initialize(firstUrl);
      expect(ConvexConfig.deploymentUrl, equals(firstUrl));
      
      ConvexConfig.initialize(secondUrl);
      expect(ConvexConfig.deploymentUrl, equals(secondUrl));
    });

    test('maintains configuration state', () {
      const testUrl = 'https://config-test.convex.cloud';
      ConvexConfig.initialize(testUrl);
      
      expect(ConvexConfig.isConfigured, isTrue);
      expect(ConvexConfig.deploymentUrl, equals(testUrl));
    });

    test('handles multiple initializations safely', () {
      for (int i = 0; i < 10; i++) {
        ConvexConfig.initialize('https://test-$i.convex.cloud');
      }
      
      expect(ConvexConfig.isConfigured, isTrue);
      expect(ConvexConfig.deploymentUrl, equals('https://test-9.convex.cloud'));
    });
  });
}