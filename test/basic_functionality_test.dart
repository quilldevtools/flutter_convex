import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_convex/flutter_convex.dart';

void main() {
  group('Flutter Convex Package - Basic Functionality', () {
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
    });

    group('ConvexService', () {
      setUp(() {
        ConvexConfig.initialize('https://test.convex.cloud');
      });

      test('is a singleton', () {
        final instance1 = ConvexService.instance;
        final instance2 = ConvexService.instance;
        
        expect(identical(instance1, instance2), isTrue);
      });

      test('can be initialized without authentication', () {
        final service = ConvexService.instance;
        
        expect(() => service.initialize(), returnsNormally);
      });

      test('can be initialized with static auth token', () {
        final service = ConvexService.instance;
        const testToken = 'test-jwt-token';
        
        expect(() => service.initialize(null, testToken), returnsNormally);
      });

      test('has expected connection state properties', () {
        final service = ConvexService.instance;
        
        // connectionState might be an enum, not a String
        expect(service.connectionState, isNotNull);
        expect(service.isConnected, isA<bool>());
        expect(service.activeSubscriptions, isA<int>());
      });

      test('provides event streams', () {
        final service = ConvexService.instance;
        
        expect(service.onMutationResponse, isA<Stream<Map<String, dynamic>>>());
        expect(service.onActionResponse, isA<Stream<Map<String, dynamic>>>());
        expect(service.onAuthError, isA<Stream<String>>());
        expect(service.onFatalError, isA<Stream<String>>());
        expect(service.onPing, isA<Stream<void>>());
      });

      test('can create subscriptions', () {
        final service = ConvexService.instance;
        
        final stream = service.subscribe<Map<String, dynamic>>('test:getData', {});
        expect(stream, isA<Stream<Map<String, dynamic>?>>());
      });
    });

    group('ConvexClient', () {
      setUp(() {
        ConvexConfig.initialize('https://test.convex.cloud');
      });

      test('can be instantiated with deployment URL', () {
        const deploymentUrl = 'https://test.convex.cloud';
        
        expect(() => ConvexClient(deploymentUrl: deploymentUrl), returnsNormally);
      });

      test('can be instantiated with auth token', () {
        const deploymentUrl = 'https://test.convex.cloud';
        const authToken = 'test-token';
        
        expect(() => ConvexClient(
          deploymentUrl: deploymentUrl,
          authToken: authToken,
        ), returnsNormally);
      });
    });

    group('Authentication Integration', () {
      late TestAuthService authService;
      late ConvexService convexService;

      setUp(() {
        ConvexConfig.initialize('https://test.convex.cloud');
        authService = TestAuthService();
        convexService = ConvexService.instance;
      });

      test('ConvexService can be initialized with AuthService', () {
        expect(() => convexService.initialize(authService), returnsNormally);
        expect(authService.hasListeners, isTrue);
      });

      test('ConvexService responds to auth token changes', () {
        convexService.initialize(authService);
        
        // Change the token - should notify ConvexService
        authService.updateToken('new-token');
        
        // Should not throw any errors
        expect(authService.hasListeners, isTrue);
      });

      test('ConvexService can update auth token manually', () {
        expect(() => convexService.updateAuthToken('manual-token'), returnsNormally);
        expect(() => convexService.updateAuthToken(null), returnsNormally);
      });
    });

    group('HTTP Operations Interface', () {
      late ConvexService service;

      setUp(() {
        ConvexConfig.initialize('https://test.convex.cloud');
        service = ConvexService.instance;
        service.initialize();
      });

      test('query method exists and accepts parameters', () {
        expect(() => service.query('test:function', {}), returnsNormally);
      });

      test('mutation method exists and accepts parameters', () {
        expect(() => service.mutation('test:function', {}), returnsNormally);
      });

      test('action method exists and accepts parameters', () {
        expect(() => service.action('test:function', {}), returnsNormally);
      });
    });

    group('Stream-based Architecture', () {
      late ConvexService service;

      setUp(() {
        ConvexConfig.initialize('https://test.convex.cloud');
        service = ConvexService.instance;
      });

      test('all event streams are broadcast streams', () {
        expect(service.onMutationResponse.isBroadcast, isTrue);
        expect(service.onActionResponse.isBroadcast, isTrue);
        expect(service.onAuthError.isBroadcast, isTrue);
        expect(service.onFatalError.isBroadcast, isTrue);
        expect(service.onPing.isBroadcast, isTrue);
      });

      test('streams can have multiple listeners', () async {
        var count1 = 0;
        var count2 = 0;
        
        final sub1 = service.onPing.listen((_) => count1++);
        final sub2 = service.onPing.listen((_) => count2++);
        
        // Clean up
        await sub1.cancel();
        await sub2.cancel();
        
        // Should not throw errors
      });
    });
  });
}

/// Test implementation of ChangeNotifier for auth testing
class TestAuthService extends ChangeNotifier {
  String? _token;
  
  String? get token => _token;
  
  void updateToken(String? newToken) {
    _token = newToken;
    notifyListeners();
  }
}