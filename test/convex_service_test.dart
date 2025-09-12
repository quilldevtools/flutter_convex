import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_convex/flutter_convex.dart';

void main() {
  group('ConvexService', () {
    setUp(() {
      ConvexConfig.initialize('https://service-test.convex.cloud');
    });

    group('Singleton Pattern', () {
      test('returns same instance', () {
        final instance1 = ConvexService.instance;
        final instance2 = ConvexService.instance;
        
        expect(identical(instance1, instance2), isTrue);
      });

      test('maintains same instance across multiple calls', () {
        final instances = List.generate(10, (_) => ConvexService.instance);
        
        for (int i = 1; i < instances.length; i++) {
          expect(identical(instances[0], instances[i]), isTrue);
        }
      });
    });

    group('Initialization', () {
      late ConvexService service;

      setUp(() {
        service = ConvexService.instance;
      });

      test('can be initialized without authentication', () {
        expect(() => service.initialize(), returnsNormally);
      });

      test('can be initialized with static auth token', () {
        const testToken = 'test-jwt-token';
        expect(() => service.initialize(null, testToken), returnsNormally);
      });

      test('can be initialized with AuthService', () {
        final authService = TestAuthService();
        expect(() => service.initialize(authService), returnsNormally);
        expect(authService.hasActiveListeners, isTrue);
      });

      test('can switch between authentication modes', () {
        final authService = TestAuthService();
        
        // Start with no auth
        service.initialize();
        
        // Switch to AuthService
        service.initialize(authService);
        expect(authService.hasActiveListeners, isTrue);
        
        // Switch to static token
        service.initialize(null, 'static-token');
      });
    });

    group('Connection State', () {
      late ConvexService service;

      setUp(() {
        service = ConvexService.instance;
      });

      test('has initial connection state', () {
        expect(service.connectionState, isNotNull);
        expect(service.isConnected, isA<bool>());
        expect(service.activeSubscriptions, isA<int>());
        expect(service.activeSubscriptions, equals(0)); // Should start at 0
      });

      test('provides connection state monitoring', () {
        expect(service.connectionState, isNotNull);
        expect(service.isConnected, isFalse); // Initially not connected
      });
    });

    group('Event Streams', () {
      late ConvexService service;

      setUp(() {
        service = ConvexService.instance;
      });

      test('provides all required event streams', () {
        expect(service.onMutationResponse, isA<Stream<Map<String, dynamic>>>());
        expect(service.onActionResponse, isA<Stream<Map<String, dynamic>>>());
        expect(service.onAuthError, isA<Stream<String>>());
        expect(service.onFatalError, isA<Stream<String>>());
        expect(service.onPing, isA<Stream<void>>());
      });

      test('all event streams are broadcast streams', () {
        expect(service.onMutationResponse.isBroadcast, isTrue);
        expect(service.onActionResponse.isBroadcast, isTrue);
        expect(service.onAuthError.isBroadcast, isTrue);
        expect(service.onFatalError.isBroadcast, isTrue);
        expect(service.onPing.isBroadcast, isTrue);
      });

      test('supports multiple listeners on event streams', () async {
        var mutationCount1 = 0;
        var mutationCount2 = 0;
        
        final sub1 = service.onMutationResponse.listen((_) => mutationCount1++);
        final sub2 = service.onMutationResponse.listen((_) => mutationCount2++);
        
        // Clean up
        await sub1.cancel();
        await sub2.cancel();
        
        // Should not throw errors when setting up multiple listeners
      });
    });

    group('Subscription Management', () {
      late ConvexService service;

      setUp(() {
        service = ConvexService.instance;
      });

      test('can create subscriptions without network calls', () {
        final stream = service.subscribe<Map<String, dynamic>>('test:getData', {});
        expect(stream, isA<Stream<Map<String, dynamic>?>>());
      });

      test('supports multiple subscription types', () {
        final mapStream = service.subscribe<Map<String, dynamic>>('test:getMap', {});
        final listStream = service.subscribe<List<dynamic>>('test:getList', {});
        final stringStream = service.subscribe<String>('test:getString', {});
        
        expect(mapStream, isA<Stream<Map<String, dynamic>?>>());
        expect(listStream, isA<Stream<List<dynamic>?>>());
        expect(stringStream, isA<Stream<String?>>());
      });

      test('different subscriptions create different streams', () {
        final stream1 = service.subscribe<Map<String, dynamic>>('test:data1', {});
        final stream2 = service.subscribe<Map<String, dynamic>>('test:data2', {});
        
        expect(identical(stream1, stream2), isFalse);
      });
    });

    group('Authentication Integration', () {
      late ConvexService service;
      late TestAuthService authService;

      setUp(() {
        service = ConvexService.instance;
        authService = TestAuthService();
      });

      test('integrates with AuthService correctly', () {
        service.initialize(authService);
        expect(authService.hasActiveListeners, isTrue);
      });

      test('responds to auth token changes', () {
        service.initialize(authService);
        
        // Change the token - should notify ConvexService
        authService.updateToken('new-token');
        expect(authService.hasActiveListeners, isTrue);
      });

      test('handles multiple auth operations', () {
        service.initialize(authService);
        
        authService.updateToken('token1');
        authService.updateToken('token2');
        authService.updateToken(null);
        authService.updateToken('token3');
        
        // Should handle all changes without errors
        expect(authService.hasActiveListeners, isTrue);
      });
    });

    group('Token Management', () {
      late ConvexService service;

      setUp(() {
        service = ConvexService.instance;
      });

      test('can update auth token manually', () {
        expect(() => service.updateAuthToken('manual-token'), returnsNormally);
        expect(() => service.updateAuthToken(null), returnsNormally);
      });

      test('handles token updates gracefully', () {
        service.updateAuthToken('token1');
        service.updateAuthToken('token2');
        service.updateAuthToken(null);
        service.updateAuthToken('token3');
        
        // All should work without throwing
      });
    });

    group('HTTP Operations Interface', () {
      late ConvexService service;

      setUp(() {
        service = ConvexService.instance;
        service.initialize();
      });

      test('provides query method', () {
        expect(() => service.query('test:function', {}), returnsNormally);
      });

      test('provides mutation method', () {
        expect(() => service.mutation('test:function', {}), returnsNormally);
      });

      test('provides action method', () {
        expect(() => service.action('test:function', {}), returnsNormally);
      });
    });

    group('ChangeNotifier Integration', () {
      late ConvexService service;

      setUp(() {
        service = ConvexService.instance;
      });

      test('implements ChangeNotifier correctly', () {
        expect(service, isA<ChangeNotifier>());
      });

      test('can add and remove listeners', () {
        var notified = false;
        void listener() => notified = true;
        
        service.addListener(listener);
        expect(service.hasListeners, isTrue);
        
        service.removeListener(listener);
        expect(notified, isFalse); // No notification triggered in test
      });
    });
  });
}

/// Test AuthService implementation for testing ConvexService integration
class TestAuthService extends ChangeNotifier {
  String? _token;
  
  String? get token => _token;
  
  /// Public method to check if there are listeners (avoids protected member access)
  bool get hasActiveListeners => hasListeners;
  
  void updateToken(String? newToken) {
    _token = newToken;
    notifyListeners();
  }
}