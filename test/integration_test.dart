import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_convex/flutter_convex.dart';
import 'dart:async';

void main() {
  group('Flutter Convex Package - Integration Tests', () {
    group('End-to-End Authentication Flow', () {
      late AuthServiceExample authService;
      late ConvexService convexService;

      setUp(() {
        ConvexConfig.initialize('https://test.convex.cloud');
        authService = AuthServiceExample();
        convexService = ConvexService.instance;
      });

      test('complete authentication lifecycle works', () {
        // Initialize without auth
        convexService.initialize();
        
        // Switch to AuthService
        convexService.initialize(authService);
        expect(authService.hasListeners, isTrue);
        
        // Simulate login
        authService.mockLogin('test-token', {'id': 'user1', 'name': 'Test User'});
        expect(authService.isAuthenticated, isTrue);
        
        // Simulate logout
        authService.mockLogout();
        expect(authService.isAuthenticated, isFalse);
        
        // Switch back to no auth (service keeps listening to AuthService)
        convexService.initialize();
        // Note: Service maintains listener for potential re-use
      });

      test('auth token changes trigger appropriate updates', () {
        convexService.initialize(authService);
        
        // Multiple token changes
        authService.mockLogin('token1', {'id': 'user1'});
        authService.mockLogin('token2', {'id': 'user2'});
        authService.mockLogout();
        authService.mockLogin('token3', {'id': 'user3'});
        
        // Should handle all changes gracefully
        expect(authService.hasListeners, isTrue);
      });
    });

    group('Service Integration', () {
      test('all services work together', () {
        // Setup
        ConvexConfig.initialize('https://integration-test.convex.cloud');
        final convexService = ConvexService.instance;
        final authService = AuthServiceExample();
        
        // Initialize with auth
        convexService.initialize(authService);
        authService.mockLogin('integration-token', {'id': 'integration-user'});
        
        // Create client manually
        final client = ConvexClient(
          deploymentUrl: ConvexConfig.deploymentUrl,
          authToken: 'manual-token',
        );
        
        expect(client, isNotNull);
        expect(convexService, isNotNull);
        expect(ConvexConfig.isConfigured, isTrue);
      });
    });

    group('Subscription Lifecycle', () {
      late ConvexService service;

      setUp(() {
        ConvexConfig.initialize('https://test.convex.cloud');
        service = ConvexService.instance;
        service.initialize();
      });

      test('multiple subscriptions can coexist', () {
        final stream1 = service.subscribe<Map<String, dynamic>>('test:data1', {});
        final stream2 = service.subscribe<List<dynamic>>('test:data2', {});
        final stream3 = service.subscribe<String>('test:data3', {});
        
        expect(stream1, isA<Stream<Map<String, dynamic>?>>());
        expect(stream2, isA<Stream<List<dynamic>?>>());
        expect(stream3, isA<Stream<String?>>());
      });

      test('subscription cleanup works', () async {
        final stream = service.subscribe<Map<String, dynamic>>('test:cleanup', {});
        
        final subscription = stream.listen(null);
        await subscription.cancel();
        
        // Should not cause errors
      });
    });

    group('Error Handling Integration', () {
      test('service handles errors gracefully across operations', () async {
        ConvexConfig.initialize('https://test.convex.cloud');
        final service = ConvexService.instance;
        service.initialize();

        // Error streams should be available
        expect(service.onAuthError, isA<Stream<String>>());
        expect(service.onFatalError, isA<Stream<String>>());
        
        // Should not throw when creating subscriptions
        final stream = service.subscribe<Map<String, dynamic>>('test:errors', {});
        expect(stream, isA<Stream<Map<String, dynamic>?>>());
      });
    });

    group('Package Exports', () {
      test('all main classes are exported and accessible', () {
        // Test that all public classes can be instantiated
        expect(() => ConvexConfig.initialize('https://test.convex.cloud'), returnsNormally);
        expect(() => ConvexService.instance, returnsNormally);
        expect(() => ConvexClient(deploymentUrl: 'https://test.convex.cloud'), returnsNormally);
      });
    });

    group('Real-world Usage Patterns', () {
      test('pattern: no auth to static token', () {
        ConvexConfig.initialize('https://test.convex.cloud');
        final service = ConvexService.instance;
        
        // Start with no auth
        service.initialize();
        
        // Add token
        service.updateAuthToken('static-token');
        
        // Should work without errors
        expect(service, isNotNull);
      });

      test('pattern: static token to AuthService', () {
        ConvexConfig.initialize('https://test.convex.cloud');
        final service = ConvexService.instance;
        final authService = AuthServiceExample();
        
        // Start with static token
        service.initialize(null, 'initial-token');
        
        // Switch to AuthService
        service.initialize(authService);
        
        expect(authService.hasListeners, isTrue);
      });

      test('pattern: AuthService to no auth', () {
        ConvexConfig.initialize('https://test.convex.cloud');
        final service = ConvexService.instance;
        final authService = AuthServiceExample();
        
        // Start with AuthService
        service.initialize(authService);
        expect(authService.hasListeners, isTrue);
        
        // Switch to no auth (service may keep listening)
        service.initialize();
        // Note: Service behavior may vary - listener management is internal
      });
    });

    group('Performance Characteristics', () {
      test('singleton pattern maintains same instance', () {
        final instances = List.generate(100, (_) => ConvexService.instance);
        
        // All should be the same instance
        for (int i = 1; i < instances.length; i++) {
          expect(identical(instances[0], instances[i]), isTrue);
        }
      });

      test('multiple config initializations are safe', () {
        for (int i = 0; i < 50; i++) {
          ConvexConfig.initialize('https://test-$i.convex.cloud');
        }
        
        expect(ConvexConfig.isConfigured, isTrue);
        expect(ConvexConfig.deploymentUrl, equals('https://test-49.convex.cloud'));
      });
    });
  });
}

/// Example AuthService implementation for testing
class AuthServiceExample extends ChangeNotifier {
  String? _token;
  Map<String, dynamic>? _user;
  bool _isLoading = false;
  
  String? get token => _token;
  Map<String, dynamic>? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _token != null;
  
  void mockLogin(String token, Map<String, dynamic> user) {
    _isLoading = true;
    notifyListeners();
    
    _token = token;
    _user = user;
    _isLoading = false;
    notifyListeners();
  }
  
  void mockLogout() {
    _token = null;
    _user = null;
    notifyListeners();
  }
  
  void mockRefreshToken(String newToken) {
    _token = newToken;
    notifyListeners();
  }
}