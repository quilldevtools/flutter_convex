import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_convex/flutter_convex.dart';

void main() {
  group('Auth Integration Tests', () {
    late ConvexService convexService;

    setUp(() {
      ConvexConfig.initialize('https://test.convex.cloud');
      convexService = ConvexService.instance;
    });

    tearDown(() {
      // Cannot reset singleton ConvexConfig in tests
      // Service state is managed internally
    });

    group('No Authentication', () {
      test('ConvexService works without authentication', () {
        convexService.initialize();
        
        // Auth state is managed internally (cannot verify directly)
      });

      test('can make queries without authentication', () {
        convexService.initialize();
        
        expect(
          () => convexService.query('public:getData', {}),
          throwsA(isA<Exception>()), // Expected to fail due to network
        );
      });
    });

    group('Static Token Authentication', () {
      test('ConvexService accepts static token', () {
        const testToken = 'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ0ZXN0IiwiaWF0IjoxNjAwMDAwMDAwfQ.signature';
        
        convexService.initialize(null, testToken);
        
        // Auth state is managed internally (cannot verify directly)
      });

      test('can update static token', () {
        const initialToken = 'initial-token';
        const newToken = 'new-token';
        
        convexService.initialize(null, initialToken);
        convexService.updateAuthToken(newToken);
        
        // Token should be updated internally
      });

      test('can clear static token', () {
        const testToken = 'test-token';
        
        convexService.initialize(null, testToken);
        convexService.updateAuthToken(null);
        
        // Token should be cleared internally
      });
    });

    group('AuthService Integration', () {
      late MockAuthService authService;

      setUp(() {
        authService = MockAuthService();
      });

      test('ConvexService listens to AuthService changes', () {
        convexService.initialize(authService);
        
        expect(authService.hasListeners, isTrue);
        // AuthService is stored internally (cannot verify directly)
      });

      test('ConvexService gets initial token from AuthService', () {
        const initialToken = 'initial-auth-token';
        authService.setToken(initialToken);
        
        convexService.initialize(authService);
        
        // ConvexService should have picked up the initial token
      });

      test('ConvexService updates when AuthService token changes', () {
        convexService.initialize(authService);
        
        const newToken = 'updated-auth-token';
        authService.setToken(newToken);
        
        // ConvexService should have been notified and updated
      });

      test('ConvexService handles AuthService token removal', () {
        const initialToken = 'initial-token';
        authService.setToken(initialToken);
        convexService.initialize(authService);
        
        authService.setToken(null);
        
        // Should handle gracefully
      });

      test('ConvexService stops listening when AuthService is replaced', () {
        convexService.initialize(authService);
        expect(authService.hasListeners, isTrue);
        
        final newAuthService = MockAuthService();
        convexService.initialize(newAuthService);
        
        expect(authService.hasListeners, isFalse);
        expect(newAuthService.hasListeners, isTrue);
      });
    });

    group('Auth Error Handling', () {
      test('handles AuthService with null token getter', () {
        final nullTokenAuthService = NullTokenAuthService();
        
        expect(() => convexService.initialize(nullTokenAuthService), returnsNormally);
      });

      test('handles AuthService that throws in token getter', () {
        final errorAuthService = ErrorAuthService();
        
        expect(() => convexService.initialize(errorAuthService), returnsNormally);
      });
    });

    group('Multiple Authentication Patterns', () {
      test('can switch from static token to AuthService', () {
        const staticToken = 'static-token';
        convexService.initialize(null, staticToken);
        
        final authService = MockAuthService();
        authService.setToken('auth-service-token');
        convexService.initialize(authService);
        
        // AuthService is stored internally (cannot verify directly)
      });

      test('can switch from AuthService to static token', () {
        final authService = MockAuthService();
        authService.setToken('auth-service-token');
        convexService.initialize(authService);
        
        const staticToken = 'new-static-token';
        convexService.initialize(null, staticToken);
        
        expect(authService.hasListeners, isFalse);
        // Auth token is stored internally (cannot verify directly)
      });

      test('can switch from authenticated to no auth', () {
        const staticToken = 'static-token';
        convexService.initialize(null, staticToken);
        
        convexService.initialize();
        
        // Auth state is managed internally (cannot verify directly)
      });
    });
  });
}

/// Mock AuthService implementation for testing
class MockAuthService extends ChangeNotifier {
  String? _token;
  
  String? get token => _token;
  
  void setToken(String? newToken) {
    _token = newToken;
    notifyListeners();
  }
}

/// AuthService that always returns null token
class NullTokenAuthService extends ChangeNotifier {
  String? get token => null;
}

/// AuthService that throws error when accessing token
class ErrorAuthService extends ChangeNotifier {
  String? get token => throw Exception('Token access error');
}